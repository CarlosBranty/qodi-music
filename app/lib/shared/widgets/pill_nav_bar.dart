import 'package:material_ui/material_ui.dart';

import '../../core/theme/tokens.dart';

class PillNavItem {
  const PillNavItem(this.icon, this.label);
  final IconData icon;
  final String label;
}

/// Solid black bottom bar with rounded top corners. Icons are grey; the
/// active one sits inside a dark-orange tinted circle and turns orange.
class PillNavBar extends StatelessWidget {
  const PillNavBar({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onTap,
  });

  final List<PillNavItem> items;
  final int currentIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final c = QodiColors.of(context);
    return Container(
      decoration: BoxDecoration(
        color: c.navBar,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(QodiTokens.radiusXL)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 72,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              for (var i = 0; i < items.length; i++)
                _NavButton(
                  item: items[i],
                  selected: i == currentIndex,
                  onTap: () => onTap(i),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({required this.item, required this.selected, required this.onTap});
  final PillNavItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: item.label,
      child: InkResponse(
        onTap: onTap,
        radius: 30,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: selected ? QodiTokens.orangeDark : Colors.transparent,
          ),
          child: Icon(
            item.icon,
            color: selected ? QodiTokens.orange : const Color(0xFF8A8A8A),
            size: 24,
          ),
        ),
      ),
    );
  }
}
