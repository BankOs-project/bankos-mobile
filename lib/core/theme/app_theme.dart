import 'package:flutter/material.dart';

/// Sistema de diseño oficial de BankOs derivado de `Logo de billetera digital BankOs.png`.
/// Referencia documentada en Google Drive: `design/Deciciones de diseño`.
class AppTheme {
  const AppTheme._();

  // Marca
  static const Color primaryColor = Color(0xFF00D68F);
  static const Color onPrimaryColor = Color(0xFF041126);
  static const Color secondaryColor = Color(0xFF00A8A8);
  static const Color onSecondaryColor = Color(0xFF041126);
  static const Color tertiaryColor = Color(0xFF9CB4C9);
  static const Color mintGlowColor = Color(0xFF9EF0C4);

  // Fondos y superficies
  static const Color scaffoldBackgroundColor = Color(0xFF041126);
  static const Color cardColor = Color(0xFF0D1F3C);
  static const Color surfaceVariantColor = Color(0xFF142A4F);
  static const Color outlineColor = Color(0xFF1E3A63);

  // Texto y neutros
  static const Color textPrimaryColor = Color(0xFFF8FAFC);
  static const Color textSecondaryColor = Color(0xFF9CB4C9);
  static const Color textMutedColor = Color(0xFF647D9B);

  // Semánticos financieros
  static const Color successColor = Color(0xFF00D68F);
  static const Color errorColor = Color(0xFFFF5C72);
  static const Color warningColor = Color(0xFFFFB020);
  static const Color infoColor = Color(0xFF38BDF8);

  // Gradientes oficiales
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primaryColor, secondaryColor],
  );

  static const LinearGradient surfaceGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [cardColor, scaffoldBackgroundColor],
  );

  // Tokens de radios
  static const double radiusCard = 16;
  static const double radiusInput = 12;
  static const double radiusButton = 12;
  static const double radiusSheet = 24;
  static const double radiusPill = 999;

  static ThemeData get darkTheme {
    final base = ThemeData.dark(useMaterial3: true);

    return base.copyWith(
      scaffoldBackgroundColor: scaffoldBackgroundColor,
      cardColor: cardColor,
      dividerColor: outlineColor,
      colorScheme: const ColorScheme.dark(
        primary: primaryColor,
        onPrimary: onPrimaryColor,
        secondary: secondaryColor,
        onSecondary: onSecondaryColor,
        tertiary: tertiaryColor,
        onTertiary: onPrimaryColor,
        surface: cardColor,
        onSurface: textPrimaryColor,
        surfaceContainerHighest: surfaceVariantColor,
        onSurfaceVariant: textSecondaryColor,
        outline: outlineColor,
        error: errorColor,
        onError: textPrimaryColor,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: scaffoldBackgroundColor,
        foregroundColor: textPrimaryColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: textPrimaryColor,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
        iconTheme: IconThemeData(color: textPrimaryColor),
      ),
      cardTheme: CardThemeData(
        color: cardColor,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusCard),
          side: const BorderSide(color: outlineColor, width: 1),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceVariantColor,
        labelStyle: const TextStyle(color: textSecondaryColor, fontSize: 14),
        hintStyle: const TextStyle(color: textMutedColor, fontSize: 14),
        prefixIconColor: tertiaryColor,
        suffixIconColor: tertiaryColor,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusInput),
          borderSide: const BorderSide(color: outlineColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusInput),
          borderSide: const BorderSide(color: outlineColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusInput),
          borderSide: const BorderSide(color: primaryColor, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusInput),
          borderSide: const BorderSide(color: errorColor),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusInput),
          borderSide: const BorderSide(color: errorColor, width: 1.5),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: onPrimaryColor,
          disabledBackgroundColor: surfaceVariantColor,
          disabledForegroundColor: textMutedColor,
          elevation: 0,
          minimumSize: const Size.fromHeight(52),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusButton),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: textPrimaryColor,
          side: const BorderSide(color: outlineColor, width: 1.2),
          minimumSize: const Size.fromHeight(52),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusButton),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primaryColor,
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: surfaceVariantColor,
        selectedColor: primaryColor.withValues(alpha: 0.18),
        disabledColor: surfaceVariantColor,
        side: const BorderSide(color: outlineColor),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusPill),
        ),
        labelStyle: const TextStyle(
          color: textSecondaryColor,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
        secondaryLabelStyle: const TextStyle(
          color: primaryColor,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
        checkmarkColor: primaryColor,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: cardColor,
        selectedItemColor: primaryColor,
        unselectedItemColor: tertiaryColor,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: cardColor,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(radiusSheet),
          ),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: surfaceVariantColor,
        contentTextStyle: const TextStyle(
          color: textPrimaryColor,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusInput),
          side: const BorderSide(color: outlineColor),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: outlineColor,
        thickness: 1,
        space: 1,
      ),
    );
  }
}
