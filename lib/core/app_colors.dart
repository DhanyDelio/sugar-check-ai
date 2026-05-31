import 'package:flutter/material.dart';

/// Centralized color constants for Doctor Gula.
/// All hardcoded hex colors across the app should reference this file.
abstract final class AppColors {
  /// Main scaffold/screen background — darkest layer
  static const Color background = Color(0xFF12121A);

  /// Card and container background — mid layer
  static const Color card = Color(0xFF1E1E2E);

  /// Navigation bar background — slightly lighter than card
  static const Color navBar = Color(0xFF1A1A2E);

  /// Loading overlay dialog background
  static const Color overlay = Color(0xFF1A1A1A);
}
