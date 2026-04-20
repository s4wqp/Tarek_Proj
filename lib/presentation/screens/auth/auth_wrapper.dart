import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tarek_proj/data/web_services/web_services.dart';

// Screens
import 'package:tarek_proj/presentation/screens/auth/Login.dart';
import 'package:tarek_proj/presentation/screens/auth/approval_waiting.dart';
import 'package:tarek_proj/presentation/screens/home/Choice.dart';
import 'package:tarek_proj/presentation/screens/home/HomePage.dart';
import 'package:tarek_proj/presentation/screens/home/ServicesHomeScreen.dart';
import 'package:tarek_proj/presentation/screens/admin/AdminDashboardScreen.dart';
import 'package:tarek_proj/presentation/screens/home/service_router.dart';

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  Widget? _home;

  @override
  void initState() {
    super.initState();
    _checkSession();
  }

  Future<void> _checkSession() async {
    try {
      final resolved = await resolveInitialHome();
      if (mounted) setState(() => _home = resolved);
    } catch (e) {
      // In case of network error, just go to login to let them re-authenticate or handle it gracefully
      print('AuthWrapper Error: $e');
      if (mounted) setState(() => _home = const LoginPage());
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_home == null) {
      return const Scaffold(
        backgroundColor: Color(0xFF0A0E21), // App background color
      );
    }

    // Switch to the resolved screen smoothly!
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 500),
      child: _home!,
    );
  }
}

/// Check if a JWT token is expired by decoding its payload
bool _isTokenExpired(String token) {
  try {
    final parts = token.split('.');
    if (parts.length != 3) return true;
    // Decode the payload (second part)
    String payload = parts[1];
    // Add padding if needed
    switch (payload.length % 4) {
      case 2:
        payload += '==';
        break;
      case 3:
        payload += '=';
        break;
    }
    final decoded = utf8.decode(base64Url.decode(payload));
    final map = jsonDecode(decoded) as Map<String, dynamic>;
    final exp = map['exp'] as int?;
    if (exp == null) return true;
    // Check if expired (with 60s buffer)
    return DateTime.now().millisecondsSinceEpoch ~/ 1000 >= (exp - 60);
  } catch (_) {
    return true;
  }
}

Future<Widget> resolveInitialHome() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final email = prefs.getString('user_email');

    if (email == null || email.isEmpty) {
      return const LoginPage();
    }

    if (email == 'admin@gmail.com') {
      return const AdminDashboardScreen();
    }

    // Check if the stored token is still valid; if expired, force re-login
    final storedToken = prefs.getString('user_token') ?? '';
    if (storedToken.isEmpty || _isTokenExpired(storedToken)) {
      print('Token expired or missing — redirecting to login.');
      await prefs.remove('user_token');
      return const LoginPage();
    }

    final userData = await WebServices().getUserByEmail(email);
    if (userData == null) {
      await prefs.remove('user_email');
      return const Choice(registrationData: {});
    }

    await WebServices().backfillUserLocationIfMissing(
      email: email,
      country: (prefs.getString('user_country') ?? ''),
      city: (prefs.getString('user_city') ?? ''),
      district: (prefs.getString('user_district') ?? ''),
    );

    final int status = userData['statu'] ?? 1;
    final int typeId = userData['u_type_id'] ?? 1;
    final int catId = userData['cat_id'] ?? 0;
    final bool isProvider = (typeId == 2 || typeId == 3);

    final Widget dashboard = catId > 0
        ? getServiceDashboard(catId, isProvider: isProvider)
        : (isProvider ? const Homepage() : const ServicesHomeScreen());

    if (status == 2) return dashboard;
    if (status == 1) return ApprovalWaitingPage(targetScreen: dashboard);

    await prefs.remove('user_email');
    return const LoginPage();
  } catch (_) {
    return const LoginPage();
  }
}
