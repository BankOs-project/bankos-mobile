import 'package:flutter/material.dart';

class AppTheme {
  static const Color scaffoldBackgroundColor = Color(0xFF0A1628);
  static const Color cardColor = Color(0xFF132238);
  static const Color primaryColor = Color(0xFF00E5FF);
  static const Color secondaryColor = Color(0xFFD500F9);

  static ThemeData get darkTheme {
    return ThemeData.dark().copyWith(
      scaffoldBackgroundColor: scaffoldBackgroundColor,
      cardColor: cardColor,
      colorScheme: const ColorScheme.dark(
        primary: primaryColor,
        secondary: secondaryColor,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: cardColor,
        centerTitle: true,
      ),
    );
  }
}
