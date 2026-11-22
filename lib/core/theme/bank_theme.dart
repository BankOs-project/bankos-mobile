import 'package:flutter/material.dart';

import 'app_theme.dart';

enum BankPalette {
  andino(Color(0xFF145EA3), Color(0xFF78B9FF)),
  caribe(Color(0xFF006E79), Color(0xFF61D2D6)),
  bancolombia(Color(0xFF00694E), Color(0xFF00C389)),
  nu(Color(0xFF820AD1), Color(0xFFC98BFF)),
  daviplata(Color(0xFFA6192E), Color(0xFFFF8899)),
  uno(Color(0xFF7B4A15), Color(0xFFF3B469)),
  falabella(Color(0xFF2B6A1D), Color(0xFF9ED389));

  const BankPalette(this.lightAccent, this.darkAccent);

  final Color lightAccent;
  final Color darkAccent;

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

  ThemeData theme(Brightness brightness) => AppTheme.forBrand(
    brightness,
    brightness == Brightness.dark ? darkAccent : lightAccent,
  );
}
