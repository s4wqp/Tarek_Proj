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
  /// explicit `FirebaseOptions` initialization).
  static const String firebaseApiKey = String.fromEnvironment(
    'FIREBASE_API_KEY',
    defaultValue: '',
  );
}

