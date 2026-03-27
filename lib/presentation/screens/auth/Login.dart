import 'dart:async';
import 'package:flutter/material.dart';
import 'package:awesome_dialog/awesome_dialog.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';

import 'SignUp.dart';
import 'approval_waiting.dart';
import 'package:tarek_proj/presentation/screens/home/Choice.dart';
import 'package:tarek_proj/presentation/screens/home/HomePage.dart';
import 'package:tarek_proj/presentation/screens/home/ServicesHomeScreen.dart';
import 'package:tarek_proj/presentation/screens/home/service_router.dart';
import 'package:tarek_proj/data/web_services/web_services.dart';

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
  final FirebaseAuth _auth = FirebaseAuth.instance;

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
          final validSponsors =
              fetchedSponsors.where((element) => element is Map).toList();

          if (validSponsors.isNotEmpty) {
            final List<Map<String, dynamic>> mappedSponsors = [];

            for (var data in validSponsors) {
              final mapData = data as Map;
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
                  // Prepend base URL
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
    String email = emailController.text.trim();
    String password = passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      showErrorDialog("Error", "Please fill in all fields.");
      return;
    }

    try {
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      User? user = userCredential.user;
      if (user != null) {
        // Admin bypass — skip API/Firestore checks
        if (email == 'admin@gmail.com') {
          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const Homepage()),
            );
          }
          return;
        }

        // Check approval status
        // Check approval status from Web API
        final userData = await WebServices().getUserByEmail(email);

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
            await _auth.signOut();
          }
        } else {
          // Fallback to Firestore if Web API returns null (e.g., legacy user or API error)
          // Or show error? Better to fallback for now to be safe, or just show error.
          // User requested "change way", implying replacement.
          // But to avoid blocking if API fails, I'll log and maybe try Firestore as backup,
          // or just assume pending if not found?
          // Let's fallback to Firestore to be safe during transition.

          print("User not found in Web API, checking Firestore...");
          final doc = await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .get();

          if (doc.exists) {
            final approvalStatus = doc.data()?['approvalStatus'] ?? 'pending';
            final String? serviceType = doc.data()?['serviceType'];
            final bool isProvider = doc.data()?['isProvider'] ??
                (serviceType == 'Provider' || serviceType == 'Both');
            final bool isSeeker = doc.data()?['isSeeker'] ??
                (serviceType == 'Seeker' || serviceType == 'Both');

            // ... duplicate logic or simple redirect
            if (approvalStatus == 'approved') {
              if (mounted) {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                      builder: (context) => isProvider
                          ? const Homepage()
                          : const ServicesHomeScreen()),
                );
              }
            } else if (approvalStatus == 'pending') {
              if (mounted) {
                Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                        builder: (context) => ApprovalWaitingPage()));
              }
            } else {
              showErrorDialog(
                  "Account Rejected", "Your account has been rejected.");
              await _auth.signOut();
            }
          } else {
            // User really not found
            if (mounted) {
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(
                    builder: (context) => const Choice(registrationData: {})),
                (Route<dynamic> route) => false,
              );
            }
          }
        }
      }
    } on FirebaseAuthException catch (e) {
      // More specific error messages
      String errorMsg = "An error occurred. Please try again.";
      if (e.code == 'user-not-found') {
        errorMsg = "No user found for that email.";
      } else if (e.code == 'wrong-password') {
        errorMsg = "Wrong password provided for that user.";
      } else if (e.code == 'invalid-email') {
        errorMsg = "The email address is not valid.";
      } else if (e.code == 'user-disabled') {
        errorMsg = "This user has been disabled.";
      } else if (e.code == 'too-many-requests') {
        errorMsg = "Too many requests. Try again later.";
      } else if (e.message != null) {
        errorMsg = e.message!;
      }
      showErrorDialog("Login Failed", errorMsg);
    } catch (e) {
      showErrorDialog("Login Failed", "An unexpected error occurred.");
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
                              'Email',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                        TextField(
                          controller: emailController,
                          keyboardType: TextInputType.emailAddress,
                          autofillHints: const [AutofillHints.email],
                          decoration: InputDecoration(
                            prefixIcon:
                                const Icon(Icons.email, color: Colors.indigo),
                            contentPadding: const EdgeInsets.symmetric(
                                vertical: 20, horizontal: 20),
                            hintText: 'name@gmail.com',
                            hintStyle: const TextStyle(color: Colors.black),
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
