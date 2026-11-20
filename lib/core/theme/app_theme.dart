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
  static const Color errorColor = Color(0xFFFF7588);
  static const Color warningColor = Color(0xFFFFB020);
  static const Color infoColor = Color(0xFF38BDF8);

  // Gradientes de la interfaz
  static LinearGradient primaryGradient(ColorScheme scheme) => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [scheme.primary, scheme.secondary],
  );

  static LinearGradient surfaceGradient(ThemeData theme) => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [theme.colorScheme.surface, theme.scaffoldBackgroundColor],
  );

  // Tokens de radios
  static const double radiusCard = 16;
  static const double radiusInput = 12;
  static const double radiusButton = 12;
  static const double radiusSheet = 24;
  static const double radiusPill = 999;

  static final darkTheme = _build(Brightness.dark);
  static final lightTheme = _build(Brightness.light);

  static ThemeData forBrand(Brightness brightness, Color accent) =>
      _build(brightness, bankAccent: accent);

  static ThemeData _build(Brightness brightness, {Color? bankAccent}) {
    final dark = brightness == Brightness.dark;
    final base = ThemeData(brightness: brightness, useMaterial3: true);
    final textPrimaryColor = dark
        ? AppTheme.textPrimaryColor
        : const Color(0xFF142338);
    final textSecondaryColor = dark
        ? AppTheme.textSecondaryColor
        : const Color(0xFF455970);
    final textMutedColor = dark
        ? const Color(0xFF8FA6BE)
        : const Color(0xFF53677D);
    final outlineColor = dark
        ? const Color(0xFF687F9A)
        : const Color(0xFF65788D);
    final primaryColor =
        bankAccent ?? (dark ? AppTheme.primaryColor : const Color(0xFF007553));
    final secondaryColor = bankAccent == null
        ? (dark ? AppTheme.secondaryColor : const Color(0xFF006B72))
        : Color.lerp(primaryColor, textPrimaryColor, 0.18)!;
    final tertiaryColor = bankAccent == null
        ? (dark ? AppTheme.infoColor : const Color(0xFF075B84))
        : Color.lerp(primaryColor, textPrimaryColor, 0.32)!;
    final onPrimaryColor = dark ? AppTheme.onPrimaryColor : Colors.white;
    final errorColor = dark ? AppTheme.errorColor : const Color(0xFFA6203E);

    Color surface(Color darkBase, Color lightBase, double tint) {
      final neutral = dark ? darkBase : lightBase;
      if (bankAccent == null) return neutral;
      return Color.alphaBlend(bankAccent.withValues(alpha: tint), neutral);
    }

    final scaffoldBackgroundColor = surface(
      AppTheme.scaffoldBackgroundColor,
      const Color(0xFFF5F8FC),
      0.035,
    );
    final cardColor = surface(AppTheme.cardColor, Colors.white, 0.025);
    final surfaceVariantColor = surface(
      AppTheme.surfaceVariantColor,
      const Color(0xFFE9EFF6),
      0.055,
    );

    return base.copyWith(
      textTheme: base.textTheme.apply(
        bodyColor: textPrimaryColor,
        displayColor: textPrimaryColor,
      ),
      scaffoldBackgroundColor: scaffoldBackgroundColor,
      cardColor: cardColor,
      dividerColor: outlineColor,
      colorScheme:
          ColorScheme.fromSeed(
            seedColor: primaryColor,
            brightness: brightness,
          ).copyWith(
            primary: primaryColor,
            onPrimary: onPrimaryColor,
            secondary: secondaryColor,
            onSecondary: onPrimaryColor,
            tertiary: tertiaryColor,
            onTertiary: onPrimaryColor,
            surface: cardColor,
            onSurface: textPrimaryColor,
            surfaceContainerHighest: surfaceVariantColor,
            onSurfaceVariant: textSecondaryColor,
            outline: outlineColor,
            error: errorColor,
            onError: onPrimaryColor,
          ),
      appBarTheme: AppBarTheme(
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
          side: BorderSide(
            color: outlineColor.withValues(alpha: 0.45),
            width: 1,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceVariantColor,
        labelStyle: TextStyle(color: textSecondaryColor, fontSize: 14),
        hintStyle: TextStyle(color: textMutedColor, fontSize: 14),
        prefixIconColor: textSecondaryColor,
        suffixIconColor: textSecondaryColor,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusInput),
          borderSide: BorderSide(color: outlineColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusInput),
          borderSide: BorderSide(color: outlineColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusInput),
          borderSide: BorderSide(color: primaryColor, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusInput),
          borderSide: BorderSide(color: errorColor),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusInput),
          borderSide: BorderSide(color: errorColor, width: 1.5),
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
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusButton),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: textPrimaryColor,
          side: BorderSide(color: outlineColor, width: 1.2),
          minimumSize: const Size.fromHeight(52),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusButton),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primaryColor,
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: surfaceVariantColor,
        selectedColor: primaryColor.withValues(alpha: 0.18),
        disabledColor: surfaceVariantColor,
        side: BorderSide(color: outlineColor),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusPill),
        ),
        labelStyle: TextStyle(
          color: textSecondaryColor,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
        secondaryLabelStyle: TextStyle(
          color: textPrimaryColor,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
        checkmarkColor: primaryColor,
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: cardColor,
        selectedItemColor: primaryColor,
        unselectedItemColor: textSecondaryColor,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      bottomSheetTheme: BottomSheetThemeData(
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
        contentTextStyle: TextStyle(
          color: textPrimaryColor,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusInput),
          side: BorderSide(color: outlineColor),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: outlineColor,
        thickness: 1,
        space: 1,
      ),
    );
  }
}
