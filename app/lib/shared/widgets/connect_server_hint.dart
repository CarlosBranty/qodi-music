import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/theme/tokens.dart';
import 'vinyl_cover.dart';

/// Empty state for server-only sections in device-only mode.
class ConnectServerHint extends StatelessWidget {
  const ConnectServerHint({super.key, required this.title, required this.message});
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final c = QodiColors.of(context);
    final text = Theme.of(context).textTheme;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const VinylCover(seed: 'server', size: 110),
            const SizedBox(height: 20),
            Text(title, textAlign: TextAlign.center, style: text.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center, style: TextStyle(color: c.textMuted)),
            const SizedBox(height: 20),
            FilledButton.icon(
              key: const Key('connect-server'),
              onPressed: () => context.push('/login'),
              icon: const Icon(Icons.dns_rounded),
              label: const Text('Connect to a server'),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => context.go('/library?tab=device'),
              style: TextButton.styleFrom(foregroundColor: QodiTokens.orange),
              child: const Text('Browse music on this device'),
            ),
          ],
        ),
      ),
    );
  }
}
