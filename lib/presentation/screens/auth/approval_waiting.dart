import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:awesome_dialog/awesome_dialog.dart';
import 'package:tarek_proj/presentation/screens/home/HomePage.dart';
import 'package:tarek_proj/presentation/screens/home/ServicesHomeScreen.dart';
import 'package:tarek_proj/presentation/screens/home/service_router.dart';
import 'package:tarek_proj/data/web_services/web_services.dart';
import 'Login.dart';
import 'rejected_screen.dart';

class ApprovalWaitingPage extends StatefulWidget {
  final Widget? targetScreen;
  const ApprovalWaitingPage({super.key, this.targetScreen});

  @override
  State<ApprovalWaitingPage> createState() => _ApprovalWaitingPageState();
}

class _ApprovalWaitingPageState extends State<ApprovalWaitingPage> {
  bool isLoading = true;
  String approvalStatus = 'pending';
  Timer? _timer;
  bool isEmailVerified = false;

  @override
  void initState() {
    super.initState();
    _checkApprovalStatus();
    // Check status every 30 seconds
    _timer = Timer.periodic(const Duration(seconds: 30), (timer) {
      _checkApprovalStatus();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _checkApprovalStatus() async {
    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        _navigateToLogin();
        return;
      }

      await user.reload();
      user = FirebaseAuth.instance.currentUser; // Refresh user object

      if (mounted) {
        setState(() {
          isEmailVerified = user?.emailVerified ?? false;
        });
      }

      // Check status from Web API
      final userData = await WebServices().getUserByEmail(user!.email!);

      if (userData != null) {
        final int status = userData['statu'] ?? 1; // 1: pending
        String newStatus = 'pending';
        if (status == 2) {
          newStatus = 'approved';
        } else if (status == 3) {
          newStatus = 'rejected';
        }

        final int typeId = userData['u_type_id'] ?? 1;
        final int catId = userData['cat_id'] ?? 0;

        setState(() {
          approvalStatus = newStatus;
          isLoading = false;
        });

        if (newStatus == 'approved') {
          if (isEmailVerified) {
            if (widget.targetScreen == null) {
              // Route based on cat_id
              final bool isProvider = (typeId == 2 || typeId == 3);
              final Widget dashboard = catId > 0
                  ? getServiceDashboard(catId, isProvider: isProvider)
                  : (isProvider
                      ? const Homepage()
                      : const ServicesHomeScreen());
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => dashboard),
              );
            } else {
              _navigateToHome();
            }
          }
        } else if (newStatus == 'rejected') {
          _navigateToRejectedScreen();
        }
      } else {
        // Fallback to Firestore if Web API fails/returns null
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

        if (doc.exists) {
          final status = doc.data()?['approvalStatus'] ?? 'pending';
          setState(() {
            approvalStatus = status;
            isLoading = false;
          });

          if (status == 'approved') {
            if (isEmailVerified) {
              _navigateToHome();
            }
          } else if (status == 'rejected') {
            _navigateToRejectedScreen();
          }
        } else {
          // User doc doesn't exist in Firestore either.
          // Just set pending and wait (maybe API isn't synced yet)
          setState(() {
            approvalStatus = 'pending';
            isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
      print('Error checking approval status: $e');
    }
  }

  Future<void> _resendVerificationEmail() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null && !user.emailVerified) {
      try {
        await user.sendEmailVerification();
        if (mounted) {
          AwesomeDialog(
            context: context,
            dialogType: DialogType.success,
            animType: AnimType.rightSlide,
            title: 'Email Sent',
            desc: 'Verification email has been sent to ${user.email}',
            btnOkOnPress: () {},
          ).show();
        }
      } catch (e) {
        if (mounted) {
          AwesomeDialog(
            context: context,
            dialogType: DialogType.error,
            animType: AnimType.rightSlide,
            title: 'Error',
            desc: 'Failed to send verification email. Please try again later.',
            btnOkOnPress: () {},
          ).show();
        }
      }
    }
  }

  void _navigateToHome() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
          builder: (context) => widget.targetScreen ?? const Homepage()),
    );
  }

  void _navigateToLogin() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const LoginPage()),
    );
  }

  void _navigateToRejectedScreen() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const RejectedScreen()),
    );
  }

  Future<void> _logout() async {
    try {
      await FirebaseAuth.instance.signOut();
      _navigateToLogin();
    } catch (e) {
      print('Error logging out: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Registration Status'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
          ),
        ],
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage("images/bg.jpg"),
            fit: BoxFit.cover,
          ),
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (isLoading)
                  const CircularProgressIndicator(color: Colors.white)
                else if (approvalStatus == 'pending') ...[
                  const Icon(
                    Icons.hourglass_empty,
                    size: 100,
                    color: Colors.white,
                  ),
                  const SizedBox(height: 30),
                  const Text(
                    'Registration Pending',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Your registration is being reviewed by our team. You will be notified once your account is approved.',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white70,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 40),
                  ElevatedButton(
                    onPressed: _checkApprovalStatus,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.indigo,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 30,
                        vertical: 15,
                      ),
                    ),
                    child: const Text(
                      'Check Status',
                      style: TextStyle(fontSize: 16, color: Colors.white),
                    ),
                  ),
                ] else if (approvalStatus == 'approved' &&
                    !isEmailVerified) ...[
                  const Icon(
                    Icons.mark_email_unread,
                    size: 80,
                    color: Colors.orangeAccent,
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Account Approved!',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.greenAccent,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Please verify your email address to proceed.',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _resendVerificationEmail,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                    ),
                    child: const Text(
                      'Resend Verification Email',
                      style: TextStyle(fontSize: 16, color: Colors.white),
                    ),
                  ),
                  const SizedBox(height: 30),
                  ElevatedButton(
                    onPressed: _checkApprovalStatus,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 30,
                        vertical: 15,
                      ),
                    ),
                    child: const Text(
                      'I have verified my email',
                      style: TextStyle(fontSize: 16, color: Colors.white),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: ElevatedButton(
        onPressed: _logout,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.indigo,
          padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
        ),
        child: const Text(
          'Return to Login',
          style: TextStyle(fontSize: 16, color: Colors.white),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}
