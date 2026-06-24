class AppSecrets {
  const AppSecrets._();

  /// Google Places + Directions API key (Android/iOS restricted).
  static const String googleMapsApiKey = String.fromEnvironment(
    'GOOGLE_PLACES_API_KEY',
    defaultValue: '',
  );

  /// Google Gemini API key.
  static const String geminiApiKey = String.fromEnvironment(
    'GEMINI_API_KEY',
    defaultValue: '',
  );

  /// Firebase API key (usually sourced from platform config, but used here for
  /// explicit `FirebaseOptions` initialization.
  static const String firebaseApiKey = String.fromEnvironment(
    'FIREBASE_API_KEY',
    defaultValue: '',
  );

  /// Supabase project URL.
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://ngagkjdtjcfiwgdjjeop.supabase.co',
  );

  /// Supabase anon key.
  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im5nYWdramR0amNmaXdnZGpqZW9wIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjQ1MDIxNTgsImV4cCI6MjA4MDA3ODE1OH0.CyzpZjAYddKrOJLycukOQObjuRPBpCssrnbVxt7jmDY',
  );
}
