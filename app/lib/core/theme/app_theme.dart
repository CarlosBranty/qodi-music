import 'package:google_fonts/google_fonts.dart';
import 'package:material_ui/material_ui.dart';

import 'tokens.dart';

/// Builds the light/dark themes. [useGoogleFonts] is false in tests so no
/// font is fetched over the network.
abstract final class AppTheme {
  static ThemeData light({bool useGoogleFonts = true}) =>
      _build(Brightness.light, QodiColors.light, useGoogleFonts);

  static ThemeData dark({bool useGoogleFonts = true}) =>
      _build(Brightness.dark, QodiColors.dark, useGoogleFonts);

  static ThemeData _build(Brightness b, QodiColors c, bool fonts) {
    final scheme = ColorScheme.fromSeed(
      seedColor: QodiTokens.orange,
      brightness: b,
      primary: QodiTokens.orange,
      onPrimary: QodiTokens.white,
      surface: c.background,
      onSurface: c.text,
    );
    final base = ThemeData(
      useMaterial3: true,
      brightness: b,
      colorScheme: scheme,
      scaffoldBackgroundColor: c.background,
      extensions: [c],
    );
    final textTheme = (fonts ? GoogleFonts.outfitTextTheme(base.textTheme) : base.textTheme)
        .apply(bodyColor: c.text, displayColor: c.text);
    final field = OutlineInputBorder(
      borderRadius: BorderRadius.circular(QodiTokens.radiusM),
      borderSide: BorderSide.none,
    );
    return base.copyWith(
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: c.background,
        foregroundColor: c.text,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        titleTextStyle: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: c.field,
        border: field,
        enabledBorder: field,
        focusedBorder: field.copyWith(borderSide: const BorderSide(color: QodiTokens.orange, width: 1.5)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        hintStyle: TextStyle(color: c.textMuted),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: QodiTokens.orange,
          foregroundColor: QodiTokens.white,
          minimumSize: const Size(48, 52),
          shape: const StadiumBorder(),
          textStyle: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: c.cardStrong,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(QodiTokens.radiusXL)),
        ),
        showDragHandle: true,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: c.cardStrong,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(QodiTokens.radiusL)),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: QodiTokens.navy,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(QodiTokens.radiusS)),
      ),
      listTileTheme: ListTileThemeData(iconColor: c.textMuted),
    );
  }
}
