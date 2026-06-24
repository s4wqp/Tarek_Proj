import 'dart:async';
import 'package:flutter/material.dart';
import 'package:awesome_dialog/awesome_dialog.dart';
import 'package:url_launcher/url_launcher.dart';

import 'SignUp.dart';
import 'approval_waiting.dart';
import 'package:tarek_proj/presentation/screens/auth/sponsor_register_screen.dart';
import 'package:tarek_proj/presentation/screens/home/Choice.dart';
import 'package:tarek_proj/presentation/screens/home/HomePage.dart';
import 'package:tarek_proj/presentation/screens/home/ServicesHomeScreen.dart';
import 'package:tarek_proj/presentation/screens/home/service_router.dart';
import 'package:tarek_proj/data/web_services/web_services.dart';
import 'package:tarek_proj/presentation/screens/admin/AdminDashboardScreen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  bool _isObscured = true;

  List<Map<String, dynamic>> sponsors = [];

  int currentIndex = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _fetchSponsors();
    // Rotate banner ads every 3 seconds
    _timer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (mounted) {
        setState(() {
          if (sponsors.isNotEmpty) {
            currentIndex = (currentIndex + 1) % sponsors.length;
          }
        });
      }
    });
  }

  Future<void> _fetchSponsors() async {
    try {
      final fetchedSponsors = await WebServices().getAllSponsors();
      if (fetchedSponsors.isNotEmpty) {
        if (mounted) {
          // Filter to ensure elements are Maps and allow dynamic keys
          final validSponsors = fetchedSponsors.whereType<Map>().toList();

          if (validSponsors.isNotEmpty) {
            final List<Map<String, dynamic>> mappedSponsors = [];

            for (var data in validSponsors) {
              final mapData = data;
              final String webSiteUrl = mapData['sponsor_web_site'] ?? '';
              final Set<String> uniqueUrls = {};

              // Check for multiple image keys and collect unique URLs
              List<String> potentialKeys = [
                'imag1_photo',
                'imag2_photo',
                'imag3_photo',
                'image' // Legacy fallback
              ];

              for (String key in potentialKeys) {
                final val = mapData[key];
                if (val != null && val is String && val.isNotEmpty) {
                  uniqueUrls.add(val);
                }
              }

              for (String rawUrl in uniqueUrls) {
                String imageUrl = rawUrl;
                if (!imageUrl.startsWith('http')) {
                  // Normalize path to prevent double slashes
                  if (imageUrl.startsWith('/')) {
                    imageUrl = imageUrl.substring(1);
                  }
                  // Fix backend discrepancy: new images miss "public/" prefix
                  if (!imageUrl.startsWith('public/')) {
                    imageUrl = "public/$imageUrl";
                  }

                  // Prepend base URL with HTTPS wrapper
                  imageUrl = "https://api.aidme.online/$imageUrl";
                }

                mappedSponsors.add({
                  "image": imageUrl,
                  "url": webSiteUrl,
                });
              }
            }

            if (mounted) {
              setState(() {
                sponsors = mappedSponsors;
                currentIndex = 0;
              });
            }
          }
        }
      }
    } catch (e) {
      debugPrint("Error fetching sponsors: $e");
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  // Function to launch URL
  void _launchURL(String? urlString) async {
    if (urlString == null || urlString.isEmpty) return;
    final uri = Uri.parse(urlString);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        // silently fail or show error
        print("Could not launch $urlString");
      }
    }
  }

  Future<void> handleLogin() async {
    String inputEmailOrUsername = emailController.text.trim();
    String password = passwordController.text.trim();

    if (inputEmailOrUsername.isEmpty || password.isEmpty) {
      showErrorDialog("Error", "Please fill in all fields.");
      return;
    }

    String emailToLoginWith = inputEmailOrUsername;

    // Local development admin shortcut:
    // allow entering admin dashboard even when admin user is not yet in backend.
    if (inputEmailOrUsername.toLowerCase() == 'admin@gmail.com' &&
        password == 'admin12345') {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_email', 'admin@gmail.com');
      await prefs.setString('user_token', 'local-admin-dev-token');
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const AdminDashboardScreen()),
        );
      }
      return;
    }

    // Check if the user typed a username (no '@' symbol)
    if (!inputEmailOrUsername.contains('@')) {
      // Show loading if possible, or just wait
      final userData =
          await WebServices().getUserByUsername(inputEmailOrUsername);
      if (userData != null && userData['email'] != null) {
        emailToLoginWith = userData['email'];
      } else if (userData != null && userData['user_email'] != null) {
        emailToLoginWith = userData['user_email'];
      } else {
        showErrorDialog("Login Failed",
            "Username not found in the database. Please check your spelling.");
        return;
      }
    }

    try {
      // Primary Login via Backend API (and get token)
      final String? token =
          await WebServices().loginUserForToken(inputEmailOrUsername, password);

      if (token == null || token.isEmpty) {
        showErrorDialog("Login Failed", "Incorrect email or password.");
        return;
      }

      // Save session via SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_token', token);
      await prefs.setString('user_email', emailToLoginWith);
      // Fire-and-forget: don't await this, it's a background optimization
      WebServices().backfillUserLocationIfMissing(
        email: emailToLoginWith,
        country: (prefs.getString('user_country') ?? ''),
        city: (prefs.getString('user_city') ?? ''),
        district: (prefs.getString('user_district') ?? ''),
      );

      // Admin bypass
      if (emailToLoginWith == 'admin@gmail.com') {
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
                builder: (context) => const AdminDashboardScreen()),
          );
        }
        return;
      }

      // Check approval status from Web API
      final userData = await WebServices().getUserByEmail(emailToLoginWith);

      if (userData != null) {
        final int status = userData['statu'] ?? 1; // 1: pending
        final int typeId = userData['u_type_id'] ?? 1; // 1: Seeker
        final int catId = userData['cat_id'] ?? 0;

        // Map status
        String approvalStatus = 'pending';
        if (status == 2) {
          approvalStatus = 'approved';
        } else if (status == 3) {
          approvalStatus = 'rejected';
        }

        // Map type: 1=Seeker, 2=Provider, 3=Both
        final bool isProvider = (typeId == 2 || typeId == 3);

        // Get the service-specific dashboard
        final Widget dashboard = catId > 0
            ? getServiceDashboard(catId, isProvider: isProvider)
            : (isProvider ? const Homepage() : const ServicesHomeScreen());

        if (approvalStatus == 'approved') {
          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => dashboard),
            );
          }
        } else if (approvalStatus == 'pending') {
          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                  builder: (context) =>
                      ApprovalWaitingPage(targetScreen: dashboard)),
            );
          }
        } else if (approvalStatus == 'rejected') {
          showErrorDialog("Account Rejected",
              "Your account has been rejected. Please contact support.");
          await prefs.remove('user_email');
        }
      } else {
        // User not found in API - redirect to choice
        if (mounted) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(
                builder: (context) => const Choice(registrationData: {})),
            (Route<dynamic> route) => false,
          );
        }
      }
    } catch (e) {
      String errorMsg = "An unexpected error occurred. Please try again later.";
      final String str = e.toString().toLowerCase();
      if (str.contains('network') ||
          str.contains('socketexception') ||
          str.contains('failed host lookup') ||
          str.contains('timeout')) {
        errorMsg = "Please check your internet connection and try again.";
      }
      showErrorDialog("Error", errorMsg);
    }
  }

  void showErrorDialog(String title, String message) {
    if (!mounted) return;
    AwesomeDialog(
      context: context,
      dialogType: DialogType.error,
      animType: AnimType.rightSlide,
      title: title,
      desc: message,
      btnOkOnPress: () {},
    ).show();
  }

  @override
  Widget build(BuildContext context) {
    String? currentImage = sponsors.isNotEmpty
        ? sponsors[currentIndex]["image"]
        : "images/amazon.png"; // Default fallback to Amazon

    // Extra safety: ensure we never pass an empty string to Image.asset
    if (currentImage == null || currentImage.isEmpty) {
      currentImage = "images/amazon.png";
    }

    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(120),
        child: GestureDetector(
          onTap: () {
            if (sponsors.isNotEmpty) {
              _launchURL(sponsors[currentIndex]["url"]);
            }
          },
          child: SizedBox(
            width: double.infinity,
            height: 200,
            child: (currentImage.startsWith('http'))
                ? Image.network(
                    currentImage,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Image.asset("images/amazon.png",
                          fit: BoxFit.cover);
                    },
                  )
                : Image.asset(
                    currentImage,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Image.asset("images/amazon.png",
                          fit: BoxFit.cover);
                    },
                  ),
          ),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage("images/bg.jpg"),
            fit: BoxFit.cover,
          ),
        ),
        width: double.infinity,
        height: double.infinity,
        child: SafeArea(
          child: SingleChildScrollView(
            // This makes the screen scrollable
            child: Padding(
              padding: const EdgeInsets.only(top: 40),
              child: Column(
                children: [
                  Container(
                    alignment: Alignment.centerLeft,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Welcome!',
                          style: TextStyle(
                              fontSize: 30,
                              fontWeight: FontWeight.bold,
                              color: Colors.white),
                        ),
                        Text(
                          "I'm waiting for you, please fill your info",
                          style: TextStyle(fontSize: 14, color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: 20),
                        const Align(
                          alignment: Alignment.centerLeft,
                          child: Padding(
                            padding: EdgeInsets.only(left: 5, bottom: 5),
                            child: Text(
                              'Email or Username',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                        TextField(
                          controller: emailController,
                          style: const TextStyle(color: Colors.black),
                          keyboardType: TextInputType.emailAddress,
                          autofillHints: const [
                            AutofillHints.email,
                            AutofillHints.username
                          ],
                          decoration: InputDecoration(
                            prefixIcon:
                                const Icon(Icons.person, color: Colors.indigo),
                            contentPadding: const EdgeInsets.symmetric(
                                vertical: 20, horizontal: 20),
                            hintText: 'name@gmail.com or username',
                            hintStyle: const TextStyle(color: Colors.black54),
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(15)),
                            filled: true,
                            fillColor: Colors.white.withOpacity(0.8),
                          ),
                        ),
                        const SizedBox(height: 40),
                        const Align(
                          alignment: Alignment.centerLeft,
                          child: Padding(
                            padding: EdgeInsets.only(left: 5, bottom: 5),
                            child: Text(
                              'Password',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                        TextField(
                          controller: passwordController,
                          style: const TextStyle(color: Colors.black),
                          obscureText: _isObscured,
                          autofillHints: const [AutofillHints.password],
                          decoration: InputDecoration(
                            prefixIcon:
                                const Icon(Icons.lock, color: Colors.indigo),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _isObscured
                                    ? Icons.visibility
                                    : Icons.visibility_off,
                                color: Colors.indigo,
                              ),
                              onPressed: () {
                                setState(() {
                                  _isObscured = !_isObscured;
                                });
                              },
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                                vertical: 20, horizontal: 20),
                            hintText: '********',
                            hintStyle: const TextStyle(color: Colors.black),
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(15)),
                            filled: true,
                            fillColor: Colors.white.withOpacity(0.8),
                          ),
                        ),
                        const SizedBox(height: 10),
                        // Adjust spacing for Forgot Password
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: () {
                              // Forgot Password Logic
                            },
                            child: const Text('Forgot Password?',
                                style: TextStyle(color: Colors.white)),
                          ),
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton(
                          onPressed: handleLogin,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.indigo,
                            padding: const EdgeInsets.symmetric(vertical: 15),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15),
                            ),
                          ),
                          child: const Text(
                            'Login',
                            style: TextStyle(fontSize: 18, color: Colors.white),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text(
                              "Don't have an account?",
                              style: TextStyle(color: Colors.white),
                            ),
                            TextButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (context) => const SignUpPage()),
                                );
                              },
                              child: const Text(
                                'Sign Up',
                                style: TextStyle(
                                    color: Colors.amber,
                                    fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      const SponsorRegisterScreen(),
                                ),
                              );
                            },
                            icon: const Icon(Icons.business,
                                color: Colors.amber, size: 20),
                            label: const Text(
                              'Register as Sponsor',
                              style: TextStyle(
                                color: Colors.amber,
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(
                                  color: Colors.amber, width: 1.5),
                              padding:
                                  const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(15),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
