import 'package:material_ui/material_ui.dart';

/// Brand wordmark: black logo on light surfaces, white logo in dark mode.
class QodiWordmark extends StatelessWidget {
  const QodiWordmark({super.key, this.height = 36});
  final double height;

  static const black = 'assets/brand/logo_black.png';
  static const white = 'assets/brand/logo_white.png';

  /// Asset for the given theme brightness.
  static String assetFor(Brightness brightness) => brightness == Brightness.dark ? white : black;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      assetFor(Theme.of(context).brightness),
      key: const Key('qodi-wordmark'),
      height: height,
      fit: BoxFit.contain,
      semanticLabel: 'Qodi Music',
      filterQuality: FilterQuality.medium,
      // Never break a screen if the asset is missing (e.g. a test bundle).
      errorBuilder: (_, _, _) => SizedBox(height: height),
    );
  }
}
