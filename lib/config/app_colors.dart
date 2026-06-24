import 'package:flutter/material.dart';

/// Centralized color palette for the entire app.
/// Change once here → updates everywhere.
class AppColors {
  AppColors._(); // prevent instantiation

  // ─── Primary backgrounds ────────────────────────────────────────────
  static const Color background = Color(0xFF030927);
  static const Color surface = Color(0xFF0D173E);
  static const Color card = Color(0xFF2D3142);
  static const Color cardLight = Color(0xFF3A3F55);

  // ─── Accent / brand ─────────────────────────────────────────────────
  static const Color primary = Color(0xFF4A7DFF);
  static const Color primaryLight = Color(0xFF7BA4FF);
  static const Color secondary = Colors.orangeAccent;
  static const Color accent = Colors.blueAccent;

  // ─── Text ───────────────────────────────────────────────────────────
  static const Color textPrimary = Colors.white;
  static const Color textSecondary = Colors.white70;
  static const Color textHint = Colors.white54;
  static const Color textDisabled = Colors.white38;

  // ─── Status ─────────────────────────────────────────────────────────
  static const Color success = Color(0xFF4CAF50);
  static const Color warning = Color(0xFFFFC107);
  static const Color error = Color(0xFFEF5350);
  static const Color info = Color(0xFF29B6F6);

  // ─── Bottom nav ─────────────────────────────────────────────────────
  static const Color navBackground = Color(0xFF0D173E);
  static const Color navSelected = Colors.white;
  static const Color navUnselected = Colors.grey;

  // ─── Divider / borders ──────────────────────────────────────────────
  static const Color divider = Colors.white12;
  static const Color border = Colors.white24;

  // ─── Gradient presets ───────────────────────────────────────────────
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF4A7DFF), Color(0xFF6C63FF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient surfaceGradient = LinearGradient(
    colors: [Color(0xFF0D173E), Color(0xFF030927)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  // ─── Light theme overrides ──────────────────────────────────────────
  static const Color lightBackground = Color(0xFFF5F7FA);
  static const Color lightSurface = Colors.white;
  static const Color lightCard = Color(0xFFF0F2F5);
  static const Color lightTextPrimary = Color(0xFF1A1A2E);
  static const Color lightTextSecondary = Color(0xFF666680);
}
