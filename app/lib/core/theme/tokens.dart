import 'package:material_ui/material_ui.dart';

/// Design tokens taken from the reference designs.
abstract final class QodiTokens {
  // Brand
  static const orange = Color(0xFFE8653F);
  static const orangeDark = Color(0xFF3A1E14);
  static const navy = Color(0xFF0F2233);
  static const ink = Color(0xFF111111);

  // Light
  static const beige = Color(0xFFEFE6DD);
  static const beigeCard = Color(0xFFE6DAD0);
  static const white = Color(0xFFFFFFFF);
  static const searchField = Color(0xFFE4E8EE);
  static const greyText = Color(0xFF8C8580);
  static const waveRestLight = Color(0xFFD5CCC4);

  // Dark
  static const black = Color(0xFF000000);
  static const darkCard = Color(0xFF1A1A1A);
  static const darkCard2 = Color(0xFF242424);
  static const greyTextDark = Color(0xFF9A9A9A);
  static const waveRestDark = Color(0xFF3A3A3A);

  // Radii
  static const radiusS = 14.0;
  static const radiusM = 20.0;
  static const radiusL = 28.0;
  static const radiusXL = 32.0;
}

/// Semantic colors exposed through the theme.
@immutable
class QodiColors extends ThemeExtension<QodiColors> {
  const QodiColors({
    required this.background,
    required this.card,
    required this.cardStrong,
    required this.text,
    required this.textMuted,
    required this.accent,
    required this.waveRest,
    required this.navBar,
    required this.field,
  });

  final Color background;
  final Color card;
  final Color cardStrong;
  final Color text;
  final Color textMuted;
  final Color accent;
  final Color waveRest;
  final Color navBar;
  final Color field;

  static const light = QodiColors(
    background: QodiTokens.beige,
    card: QodiTokens.beigeCard,
    cardStrong: QodiTokens.white,
    text: QodiTokens.navy,
    textMuted: QodiTokens.greyText,
    accent: QodiTokens.orange,
    waveRest: QodiTokens.waveRestLight,
    navBar: QodiTokens.ink,
    field: QodiTokens.searchField,
  );

  static const dark = QodiColors(
    background: QodiTokens.black,
    card: QodiTokens.darkCard,
    cardStrong: QodiTokens.darkCard2,
    text: QodiTokens.white,
    textMuted: QodiTokens.greyTextDark,
    accent: QodiTokens.orange,
    waveRest: QodiTokens.waveRestDark,
    navBar: QodiTokens.darkCard,
    field: QodiTokens.darkCard2,
  );

  static QodiColors of(BuildContext context) =>
      Theme.of(context).extension<QodiColors>() ?? light;

  @override
  QodiColors copyWith() => this;

  @override
  QodiColors lerp(ThemeExtension<QodiColors>? other, double t) {
    if (other is! QodiColors) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return QodiColors(
      background: l(background, other.background),
      card: l(card, other.card),
      cardStrong: l(cardStrong, other.cardStrong),
      text: l(text, other.text),
      textMuted: l(textMuted, other.textMuted),
      accent: l(accent, other.accent),
      waveRest: l(waveRest, other.waveRest),
      navBar: l(navBar, other.navBar),
      field: l(field, other.field),
    );
  }
}
