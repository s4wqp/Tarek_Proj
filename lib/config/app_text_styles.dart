import 'package:flutter/material.dart';
import 'app_colors.dart';

/// Centralized text styles for the entire app.
class AppTextStyles {
  AppTextStyles._();

  // ─── Headings ───────────────────────────────────────────────────────
  static const TextStyle h1 = TextStyle(
    color: AppColors.textPrimary,
    fontSize: 28,
    fontWeight: FontWeight.bold,
    letterSpacing: -0.5,
  );

  static const TextStyle h2 = TextStyle(
    color: AppColors.textPrimary,
    fontSize: 22,
    fontWeight: FontWeight.bold,
  );

  static const TextStyle h3 = TextStyle(
    color: AppColors.textPrimary,
    fontSize: 18,
    fontWeight: FontWeight.w600,
  );

  // ─── Body ───────────────────────────────────────────────────────────
  static const TextStyle body = TextStyle(
    color: AppColors.textPrimary,
    fontSize: 16,
    fontWeight: FontWeight.normal,
  );

  static const TextStyle bodySecondary = TextStyle(
    color: AppColors.textSecondary,
    fontSize: 14,
    fontWeight: FontWeight.normal,
  );

  static const TextStyle bodySmall = TextStyle(
    color: AppColors.textHint,
    fontSize: 12,
    fontWeight: FontWeight.normal,
  );

  // ─── Buttons ────────────────────────────────────────────────────────
  static const TextStyle button = TextStyle(
    color: AppColors.textPrimary,
    fontSize: 16,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.5,
  );

  static const TextStyle buttonSmall = TextStyle(
    color: AppColors.textPrimary,
    fontSize: 14,
    fontWeight: FontWeight.w600,
  );

  // ─── Labels / captions ─────────────────────────────────────────────
  static const TextStyle label = TextStyle(
    color: AppColors.textSecondary,
    fontSize: 13,
    fontWeight: FontWeight.w600,
  );

  static const TextStyle caption = TextStyle(
    color: AppColors.textHint,
    fontSize: 11,
    fontWeight: FontWeight.normal,
  );

  // ─── Section titles ────────────────────────────────────────────────
  static const TextStyle sectionTitle = TextStyle(
    color: AppColors.textPrimary,
    fontSize: 20,
    fontWeight: FontWeight.bold,
  );
}
