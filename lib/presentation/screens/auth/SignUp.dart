import 'package:awesome_dialog/awesome_dialog.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:tarek_proj/presentation/screens/auth/personal_info2.dart';
import 'package:tarek_proj/data/web_services/web_services.dart';

class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});

  @override
  _SignUpPageState createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  TextEditingController emailController = TextEditingController();
  TextEditingController passController = TextEditingController();
  TextEditingController repassController = TextEditingController();
  bool _obscureTextPass = true;
  bool _obscureTextRePass = true;
  String? _emailErrorText;
  bool _isLoading = false;

  @override
  void dispose() {
    emailController.dispose();
    passController.dispose();
    repassController.dispose();
    super.dispose();
  }

  void showErrorDialog(String title, String message) {
    AwesomeDialog(
      context: context,
      dialogType: DialogType.error,
      animType: AnimType.rightSlide,
      title: title,
      desc: message,
      btnOkOnPress: () {},
    ).show();
  }

  bool isValidEmail(String email) {
    final RegExp emailRegex =
        RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
    return emailRegex.hasMatch(email);
  }

  bool isValidPassword(String password) {
    return password.length >=
        3; // Relaxed to 3 to test extremely short passwords
  }

  Future<void> handleSignUp() async {
    setState(() {
      _emailErrorText = null;
    });

    String email = emailController.text.trim();
    String password = passController.text.trim();
    String repassword = repassController.text.trim();

    if (email.isEmpty) {
      setState(() {
        _emailErrorText = "Please enter an email address";
      });
      return;
    }

    if (password.isEmpty || repassword.isEmpty) {
      showErrorDialog("Error", "Please fill in all password fields.");
      return;
    }

    if (!isValidEmail(email)) {
      setState(() {
        _emailErrorText = "Please enter a valid email address";
      });
      return;
    }

    if (!isValidPassword(password)) {
      showErrorDialog(
          "Weak Password", "Password must be at least 3 characters.");
      return;
    }

    if (password != repassword) {
      showErrorDialog("Password Mismatch", "Passwords do not match.");
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // 1. Check if email already exists in Auth
      final methods =
          await FirebaseAuth.instance.fetchSignInMethodsForEmail(email);
      if (methods.isNotEmpty) {
        setState(() {
          _emailErrorText = "This email is already in use. Please try another.";
          _isLoading = false;
        });
        return;
      }

      // 2. Check if email already exists in Firestore (Backup check)
      try {
        final querySnapshot = await FirebaseFirestore.instance
            .collection('users')
            .where('email', isEqualTo: email)
            .get();

        if (querySnapshot.docs.isNotEmpty) {
          setState(() {
            _emailErrorText =
                "This email is already in use. Please try another.";
            _isLoading = false;
          });
          return;
        }
      } catch (e) {
        print("Firestore email check failed: $e");
      }

      // 3. Check custom backend (Main source of truth for 400 Username exists)
      final existingUser = await WebServices().getUserByEmail(email);
      if (existingUser != null) {
        setState(() {
          _emailErrorText =
              "This email is already registered on our servers. Please try another.";
          _isLoading = false;
        });
        return;
      }

      // 4. Email is available, proceed to next step
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
              builder: (context) =>
                  PersonalInfo2(email: email, password: password)),
        );
      }
    } on FirebaseAuthException catch (e) {
      String errorMessage = "An error occurred. Please try again.";
      if (e.code == 'invalid-email') {
        setState(() {
          _emailErrorText = "Invalid email format.";
          _isLoading = false;
        });
        return;
      }
      setState(() {
        _isLoading = false;
      });
      showErrorDialog("Error", errorMessage);
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      showErrorDialog("Error", e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sign Up')),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage("images/bg.jpg"),
            fit: BoxFit.cover,
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 70),
                  const Text(
                    "Let's create an account",
                    style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    "Step 1: Enter Email & Set Password",
                    style: TextStyle(fontSize: 16, color: Colors.white),
                  ),
                  const SizedBox(height: 40),
                  TextField(
                    controller: emailController,
                    keyboardType: TextInputType.emailAddress,
                    onChanged: (value) {
                      if (_emailErrorText != null) {
                        setState(() {
                          _emailErrorText = null;
                        });
                      }
                    },
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.email, color: Colors.indigo),
                      hintText: 'name@gmail.com',
                      errorText: _emailErrorText,
                      errorStyle: const TextStyle(
                          color: Colors.redAccent,
                          fontWeight: FontWeight.bold,
                          fontSize: 14),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(15)),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.8),
                    ),
                  ),
                  const SizedBox(height: 40),
                  TextField(
                    controller: passController,
                    obscureText: _obscureTextPass,
                    maxLength: 16,
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.lock, color: Colors.indigo),
                      hintText: 'Password',
                      counterText: "",
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(15)),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.8),
                      suffixIcon: IconButton(
                        icon: Icon(_obscureTextPass
                            ? Icons.visibility
                            : Icons.visibility_off),
                        onPressed: () {
                          setState(() {
                            _obscureTextPass = !_obscureTextPass;
                          });
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: repassController,
                    obscureText: _obscureTextRePass,
                    maxLength: 16,
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.lock, color: Colors.indigo),
                      hintText: 'Confirm Password',
                      counterText: "",
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(15)),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.8),
                      suffixIcon: IconButton(
                        icon: Icon(_obscureTextRePass
                            ? Icons.visibility
                            : Icons.visibility_off),
                        onPressed: () {
                          setState(() {
                            _obscureTextRePass = !_obscureTextRePass;
                          });
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                  ElevatedButton(
                    onPressed: _isLoading ? null : handleSignUp,
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2.0,
                            ),
                          )
                        : const Text('Next'),
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
