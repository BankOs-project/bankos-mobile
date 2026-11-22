import 'package:flutter/material.dart';

import 'app_theme.dart';

enum BankPalette {
  andino(Color(0xFF145EA3), Color(0xFF78B9FF), Color(0xFF145EA3)),
  caribe(Color(0xFF006E79), Color(0xFF61D2D6), Color(0xFF006E79)),
  bancolombia(Color(0xFF00694E), Color(0xFF00C389), Color(0xFFFDDA24)),
  nu(Color(0xFF820AD1), Color(0xFFC98BFF), Color(0xFF820AD1)),
  daviplata(Color(0xFFA6192E), Color(0xFFFF8899), Color(0xFFFF0000)),
  uno(Color(0xFF7B4A15), Color(0xFFF3B469), Color(0xFF7B4A15)),
  falabella(Color(0xFF2B6A1D), Color(0xFF9ED389), Color(0xFF3B9326));

  const BankPalette(this.lightAccent, this.darkAccent, this.brandColor);

  final Color lightAccent;
  final Color darkAccent;
  final Color brandColor;

  static BankPalette? fromName(String normalizedName) =>
      switch (normalizedName) {
        'banco andino' || 'banco andino s.a.' => andino,
        'cooperativa caribe' || 'cooperativa caribe ltda.' => caribe,
        'bancolombia' => bancolombia,
        'nu' || 'nubank' => nu,
        'daviplata' => daviplata,
        'uno' => uno,
        'falabella' || 'banco falabella' => falabella,
        _ => null,
      };

  ThemeData theme(Brightness brightness) {
    final theme = AppTheme.forBrand(
      brightness,
      brightness == Brightness.dark ? darkAccent : lightAccent,
    );
    final colors = BankSurfaceColors(
      fill: brandColor,
      onFill: brandColor.computeLuminance() > 0.179
          ? Colors.black
          : Colors.white,
    );
    return theme.copyWith(
      extensions: [...theme.extensions.values, colors],
      appBarTheme: theme.appBarTheme.copyWith(
        backgroundColor: colors.fill,
        foregroundColor: colors.onFill,
        titleTextStyle: theme.appBarTheme.titleTextStyle?.copyWith(
          color: colors.onFill,
        ),
        iconTheme: IconThemeData(color: colors.onFill),
        actionsIconTheme: IconThemeData(color: colors.onFill),
      ),
    );
  }
}

class BankSurfaceColors extends ThemeExtension<BankSurfaceColors> {
  const BankSurfaceColors({required this.fill, required this.onFill});

  final Color fill;
  final Color onFill;

  @override
  BankSurfaceColors copyWith({Color? fill, Color? onFill}) =>
      BankSurfaceColors(fill: fill ?? this.fill, onFill: onFill ?? this.onFill);

  @override
  BankSurfaceColors lerp(BankSurfaceColors? other, double t) => other == null
      ? this
      : BankSurfaceColors(
          fill: Color.lerp(fill, other.fill, t)!,
          onFill: Color.lerp(onFill, other.onFill, t)!,
        );
}
