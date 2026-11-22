import 'dart:math' as math;

import 'package:bankos_mobile/core/theme/app_theme.dart';
import 'package:bankos_mobile/core/theme/bank_theme.dart';
import 'package:bankos_mobile/features/accounts/presentation/screens/main_shell_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

double _contrast(Color foreground, Color background) {
  final first = foreground.computeLuminance();
  final second = background.computeLuminance();
  return (math.max(first, second) + 0.05) / (math.min(first, second) + 0.05);
}

void main() {
  testWidgets('la ruta activa pinta la pestaña completa en ambos modos', (
    tester,
  ) async {
    for (final bank in [BankPalette.bancolombia, BankPalette.nu]) {
      for (final brightness in Brightness.values) {
        final theme = bank.theme(brightness);
        final brand = theme.extension<BankSurfaceColors>()!;
        await tester.pumpWidget(
          MaterialApp(
            key: ValueKey((bank, brightness)),
            theme: theme,
            home: const Scaffold(
              bottomNavigationBar: BankNavigationBar(
                location: '/accounts/1234',
              ),
            ),
          ),
        );
        for (final label in [
          'Dashboard',
          'Cuentas',
          'Operaciones',
          'Movimientos',
        ]) {
          final tab = find.byKey(ValueKey('bank-tab-$label'));
          final material = tester.widget<Material>(
            find.descendant(of: tab, matching: find.byType(Material)),
          );
          final active = label == 'Cuentas';
          expect(
            material.color,
            active ? brand.fill : theme.scaffoldBackgroundColor,
          );
          final foreground = active
              ? brand.onFill
              : theme.colorScheme.onSurfaceVariant;
          expect(
            tester
                .widget<Text>(
                  find.descendant(of: tab, matching: find.text(label)),
                )
                .style
                ?.color,
            foreground,
          );
          expect(
            tester
                .widget<Icon>(
                  find.descendant(of: tab, matching: find.byType(Icon)),
                )
                .color,
            foreground,
          );
        }
      }
    }
  });
  test('las paletas mantienen contraste para texto, botones y controles', () {
    for (final brightness in Brightness.values) {
      final themes = {
        'BankOS': brightness == Brightness.dark
            ? AppTheme.darkTheme
            : AppTheme.lightTheme,
        for (final bank in BankPalette.values)
          bank.name: bank.theme(brightness),
      };
      for (final MapEntry(key: name, value: theme) in themes.entries) {
        final colors = theme.colorScheme;
        final field = colors.surfaceContainerHighest;
        if (theme.extension<BankSurfaceColors>() case final brand?) {
          expect(theme.appBarTheme.backgroundColor, brand.fill);
          expect(theme.appBarTheme.foregroundColor, brand.onFill);
          expect(
            _contrast(brand.onFill, brand.fill),
            greaterThanOrEqualTo(4.5),
          );
          expect(theme.scaffoldBackgroundColor, isNot(brand.fill));
        }
        for (final background in [
          theme.scaffoldBackgroundColor,
          colors.surface,
          field,
        ]) {
          for (final foreground in [
            colors.onSurface,
            colors.onSurfaceVariant,
          ]) {
            expect(
              _contrast(foreground, background),
              greaterThanOrEqualTo(4.5),
              reason: '$name $brightness, texto $foreground sobre $background',
            );
          }
        }
        for (final (label, foreground, background, minimum) in [
          ('botón', colors.onPrimary, colors.primary, 4.5),
          ('extremo del degradado', colors.onSecondary, colors.secondary, 4.5),
          ('enlace', colors.primary, colors.surface, 4.5),
          ('barra de navegación', colors.primary, theme.cardColor, 4.5),
          (
            'pista de campo',
            theme.inputDecorationTheme.hintStyle!.color!,
            field,
            4.5,
          ),
          ('error de campo', colors.error, field, 4.5),
          ('borde de campo', colors.outline, field, 3.0),
          ('focus de campo', colors.primary, field, 3.0),
        ]) {
          expect(
            _contrast(foreground, background),
            greaterThanOrEqualTo(minimum),
            reason: '$name $brightness, $label',
          );
        }
        for (final color in [
          colors.primary,
          colors.secondary,
          colors.tertiary,
        ]) {
          final iconBackground = Color.alphaBlend(
            color.withValues(alpha: 0.14),
            field,
          );
          expect(
            _contrast(color, iconBackground),
            greaterThanOrEqualTo(3),
            reason: '$name $brightness, ícono $color',
          );
        }
      }
    }
  });
}
