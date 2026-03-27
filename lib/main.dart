import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:tarek_proj/presentation/screens/auth/Login.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tarek_proj/presentation/screens/home/Choice.dart';
import 'package:tarek_proj/presentation/screens/home/HomePage.dart';
import 'package:tarek_proj/presentation/screens/services/provide_services.dart';

import 'package:tarek_proj/presentation/screens/services/provide_services2.dart';
import 'package:tarek_proj/presentation/screens/services/provide_services4.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    // Check if Firebase is already initialized
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        name: 'Tarek-Proj',
        options: FirebaseOptions(
          apiKey: "AIzaSyAkNposTrjqFsT7zog5xXI1fk-mgvQ9vzM",
          appId: '1:847973994383:android:a72c205d18d4fe240605fa',
          messagingSenderId: "847973994383",
          projectId: "tarek-fd908",
        ),
      );
    }
    await SupabaseService.initialize();
    runApp(MyApp());
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
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: LoginPage(),
    );
  }
}
