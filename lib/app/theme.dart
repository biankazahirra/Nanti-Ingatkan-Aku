import 'package:flutter/material.dart';

/// Material 3 theme, Indonesian-first copy (layout tolerates ~35% expansion —
/// NFR-L10N-04).
class AppTheme {
  const AppTheme._();

  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF3F6C51),
      brightness: Brightness.light,
    );
    return _base(scheme);
  }

  static ThemeData dark() {
    final scheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF3F6C51),
      brightness: Brightness.dark,
    );
    return _base(scheme);
  }

  static ThemeData _base(ColorScheme scheme) {
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      // NFR-A11Y-01 — body text never below 14 sp.
      textTheme: const TextTheme(
        bodyMedium: TextStyle(fontSize: 15),
        bodySmall: TextStyle(fontSize: 14),
      ),
      listTileTheme: const ListTileThemeData(minVerticalPadding: 12),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
      ),
      visualDensity: VisualDensity.standard,
    );
  }
}
