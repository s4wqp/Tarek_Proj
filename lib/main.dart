import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:tarek_proj/presentation/screens/auth/auth_wrapper.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    // Check if Firebase is already initialized
    if (Firebase.apps.isEmpty) {
      // Use native platform config:
      // - Android: `android/app/google-services.json`
      // - iOS: `ios/Runner/GoogleService-Info.plist`
      await Firebase.initializeApp();
    }
    await SupabaseService.initialize();
    final initialHome = await resolveInitialHome();
    runApp(MyApp(initialHome: initialHome));
  } catch (e) {
    print("Firebase Initialization Error: $e");
  }
}

class SupabaseService {
  static Future<void> initialize() async {
    await Supabase.initialize(
      url: 'https://ngagkjdtjcfiwgdjjeop.supabase.co',
      anonKey:
          'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im5nYWdramR0amNmaXdnZGpqZW9wIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjQ1MDIxNTgsImV4cCI6MjA4MDA3ODE1OH0.CyzpZjAYddKrOJLycukOQObjuRPBpCssrnbVxt7jmDY',
    );
  }

  static SupabaseClient get client => Supabase.instance.client;
}

class MyApp extends StatelessWidget {
  final Widget initialHome;
  const MyApp({super.key, required this.initialHome});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: initialHome,
    );
  }
}
