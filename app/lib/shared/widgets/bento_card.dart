import 'package:material_ui/material_ui.dart';

import '../../core/theme/tokens.dart';

/// Rounded "bento" card with the beige/dark card color by default.
class BentoCard extends StatelessWidget {
  const BentoCard({
    super.key,
    required this.child,
    this.color,
    this.padding = const EdgeInsets.all(18),
    this.radius = QodiTokens.radiusL,
    this.onTap,
  });

  final Widget child;
  final Color? color;
  final EdgeInsetsGeometry padding;
  final double radius;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = QodiColors.of(context);
    return Material(
      color: color ?? c.card,
      borderRadius: BorderRadius.circular(radius),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}
