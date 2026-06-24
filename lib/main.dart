import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:tarek_proj/config/app_secrets.dart';
import 'package:tarek_proj/config/theme_provider.dart';
import 'package:tarek_proj/presentation/screens/auth/auth_wrapper.dart';
import 'package:tarek_proj/presentation/screens/onboarding/onboarding_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp();
    }
    await SupabaseService.initialize();

    final prefs = await SharedPreferences.getInstance();
    final seenOnboarding = prefs.getBool('seen_onboarding') ?? false;

    Widget home;
    if (!seenOnboarding) {
      home = const OnboardingScreen();
    } else {
      home = await resolveInitialHome();
    }

    runApp(MyApp(initialHome: home));
  } catch (e) {
    debugPrint("Initialization Error: $e");
  }
}

class SupabaseService {
  static Future<void> initialize() async {
    await Supabase.initialize(
      url: AppSecrets.supabaseUrl,
      anonKey: AppSecrets.supabaseAnonKey,
    );
  }

  static SupabaseClient get client => Supabase.instance.client;
}

class MyApp extends StatefulWidget {
  final Widget initialHome;
  const MyApp({super.key, required this.initialHome});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final ThemeProvider _themeProvider = ThemeProvider();

  @override
  void initState() {
    super.initState();
    _themeProvider.addListener(_onThemeChanged);
  }

  void _onThemeChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _themeProvider.removeListener(_onThemeChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ThemeProviderScope(
      provider: _themeProvider,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Services App',
        theme: _themeProvider.theme,
        home: widget.initialHome,
      ),
    );
  }
}

/// InheritedWidget to provide ThemeProvider down the tree.
class ThemeProviderScope extends InheritedWidget {
  final ThemeProvider provider;

  const ThemeProviderScope({
    super.key,
    required this.provider,
    required super.child,
  });

  static ThemeProvider of(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<ThemeProviderScope>()!
        .provider;
  }

  static ThemeProvider? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<ThemeProviderScope>()
        ?.provider;
  }

  @override
  bool updateShouldNotify(ThemeProviderScope oldWidget) {
    return provider.isDark != oldWidget.provider.isDark;
  }
}
