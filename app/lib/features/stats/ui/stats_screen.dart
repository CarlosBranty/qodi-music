import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/theme/tokens.dart';
import '../../../l10n/l10n.dart';
import '../../../shared/format.dart';
import '../../../shared/widgets/bento_card.dart';
import '../../../shared/widgets/connect_server_hint.dart';
import '../../auth/ui/auth_controller.dart';
import '../../library/ui/track_actions.dart';
import '../domain/stats_summary.dart';
import 'stats_providers.dart';

String statsRangeLabel(AppLocalizations l, StatsRange r) => switch (r) {
      StatsRange.week => l.range7Days,
      StatsRange.month => l.range30Days,
      StatsRange.all => l.rangeAllTime,
    };

class StatsScreen extends ConsumerWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    if (!ref.watch(serverConnectedProvider)) {
      return ConnectServerHint(title: l.statsServerTitle, message: l.statsServerMessage);
    }
    final range = ref.watch(statsRangeProvider);
    final summary = ref.watch(statsSummaryProvider);
    final text = Theme.of(context).textTheme;
    return RefreshIndicator(
      color: QodiTokens.orange,
      onRefresh: () async => ref.invalidate(statsSummaryProvider),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 12),
            child: Text(l.yourStats, style: text.headlineMedium?.copyWith(fontWeight: FontWeight.w800)),
          ),
          _RangeSelector(
            value: range,
            onChanged: (r) => ref.read(statsRangeProvider.notifier).set(r),
          ),
          const SizedBox(height: 16),
          summary.when(
            data: (s) => StatsBento(summary: s, range: range),
            loading: () => const Padding(
              padding: EdgeInsets.all(48),
              child: Center(child: CircularProgressIndicator(color: QodiTokens.orange)),
            ),
            error: (e, _) => Padding(
              padding: const EdgeInsets.all(32),
              child: Text(l.statsLoadFailed('$e'), textAlign: TextAlign.center),
            ),
          ),
        ],
      ),
    );
  }
}

class _RangeSelector extends StatelessWidget {
  const _RangeSelector({required this.value, required this.onChanged});
  final StatsRange value;
  final ValueChanged<StatsRange> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = QodiColors.of(context);
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: c.card, borderRadius: BorderRadius.circular(40)),
      child: Row(
        children: [
          for (final r in StatsRange.values)
            Expanded(
              child: GestureDetector(
                onTap: () => onChanged(r),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: r == value ? QodiTokens.ink : Colors.transparent,
                    borderRadius: BorderRadius.circular(40),
                  ),
                  child: Text(statsRangeLabel(context.l10n, r),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: r == value ? Colors.white : c.text,
                      )),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Fills missing days with zero for 7d/30d; uses server days for "all".
List<DailyListening> fillDays(List<DailyListening> daily, StatsRange range, {DateTime? today}) {
  final days = switch (range) {
    StatsRange.week => 7,
    StatsRange.month => 30,
    StatsRange.all => 0,
  };
  if (days == 0) return daily.length > 30 ? daily.sublist(daily.length - 30) : daily;
  final byDate = {for (final d in daily) d.date: d.listenMs};
  final now = (today ?? DateTime.now()).toUtc();
  final base = DateTime.utc(now.year, now.month, now.day);
  return [
    for (var i = days - 1; i >= 0; i--)
      () {
        final d = base.subtract(Duration(days: i));
        final key = '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
        return DailyListening(key, byDate[key] ?? 0);
      }(),
  ];
}

class StatsBento extends ConsumerWidget {
  const StatsBento({super.key, required this.summary, required this.range});
  final StatsSummary summary;
  final StatsRange range;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = QodiColors.of(context);
    final text = Theme.of(context).textTheme;
    final share = summary.topArtistShare;
    final topArtist = summary.topArtists.isEmpty ? null : summary.topArtists.first;
    final tracks = summary.topTracks.map((t) => t.track).toList();
    final l = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        BentoCard(
          color: QodiTokens.orange,
          padding: EdgeInsets.zero,
          child: CustomPaint(
            painter: TopographicPainter(color: Colors.white.withValues(alpha: 0.13)),
            child: Padding(
              padding: const EdgeInsets.all(22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l.listeningTime,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  Text(formatListenTime(summary.totalListenMs),
                      style: text.displaySmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w800)),
                  Text(statsRangeLabel(l, range), style: TextStyle(color: Colors.white.withValues(alpha: 0.8))),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _Metric(icon: Icons.play_circle_outline_rounded, label: l.totalPlays, value: '${summary.totalPlays}')),
            const SizedBox(width: 12),
            Expanded(child: _Metric(icon: Icons.library_music_outlined, label: l.uniqueTracks, value: '${summary.uniqueTracks}')),
          ],
        ),
        const SizedBox(height: 12),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: BentoCard(
                  child: Column(
                    children: [
                      SizedBox(
                        width: 130,
                        height: 130,
                        child: CustomPaint(
                          painter: DonutPainter(value: share, track: c.waveRest),
                          child: Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text('${(share * 100).round()}%',
                                    style: text.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
                                Text(l.ofPlays, style: TextStyle(color: c.textMuted, fontSize: 11)),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(topArtist?.name ?? l.noPlaysYet,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                      Text(l.topArtist, style: TextStyle(color: c.textMuted, fontSize: 12)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: BentoCard(
                  color: c.navBar,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l.daily, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                      Text(l.minutesListened,
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 11)),
                      const SizedBox(height: 12),
                      Expanded(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(minHeight: 110),
                          child: CustomPaint(
                            size: Size.infinite,
                            painter: BarChartPainter(
                              values: fillDays(summary.daily, range).map((d) => d.listenMs.toDouble()).toList(),
                              color: QodiTokens.orange,
                              rest: Colors.white.withValues(alpha: 0.12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        BentoCard(
          color: c.cardStrong,
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
                child: Text(l.topTracks, style: text.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
              ),
              if (tracks.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text(l.topTracksEmpty, style: TextStyle(color: c.textMuted)),
                ),
              for (var i = 0; i < tracks.length; i++)
                ConnectedTrackTile(
                  track: tracks[i],
                  queue: tracks,
                  index: i,
                  trailing: Text('${summary.topTracks[i].plays}×',
                      style: const TextStyle(color: QodiTokens.orange, fontWeight: FontWeight.w800)),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.icon, required this.label, required this.value});
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final c = QodiColors.of(context);
    return BentoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: c.text.withValues(alpha: 0.25)),
            ),
            child: Icon(icon, size: 20, color: c.text),
          ),
          const SizedBox(height: 14),
          Text(label, style: TextStyle(color: c.textMuted, fontSize: 13)),
          Text(value,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

/// Ring with a striped orange segment for [value] (0..1).
class DonutPainter extends CustomPainter {
  DonutPainter({required this.value, required this.track});
  final double value;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.shortestSide * 0.14;
    final rect = Rect.fromCircle(center: size.center(Offset.zero), radius: size.shortestSide / 2 - stroke / 2);
    canvas.drawArc(rect, 0, math.pi * 2, false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke
          ..color = track);
    if (value <= 0) return;
    final sweep = math.pi * 2 * value.clamp(0.0, 1.0);
    canvas.drawArc(rect, -math.pi / 2, sweep, false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke
          ..strokeCap = StrokeCap.round
          ..color = QodiTokens.orange);
    // Stripes over the orange segment.
    final stripe = Paint()
      ..color = Colors.white.withValues(alpha: 0.28)
      ..strokeWidth = 2;
    final c = rect.center;
    final inner = rect.width / 2 - stroke / 2 + 1;
    final outer = rect.width / 2 + stroke / 2 - 1;
    for (var a = 0.0; a < sweep; a += 0.12) {
      final ang = -math.pi / 2 + a;
      final p1 = c + Offset(math.cos(ang), math.sin(ang)) * inner;
      final p2 = c + Offset(math.cos(ang + 0.08), math.sin(ang + 0.08)) * outer;
      canvas.drawLine(p1, p2, stripe);
    }
  }

  @override
  bool shouldRepaint(DonutPainter old) => old.value != value || old.track != track;
}

class BarChartPainter extends CustomPainter {
  BarChartPainter({required this.values, required this.color, required this.rest});
  final List<double> values;
  final Color color;
  final Color rest;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty || size.width <= 0 || size.height <= 0) return;
    final maxV = values.reduce(math.max);
    final slot = size.width / values.length;
    final barW = math.max(2.0, slot * 0.6);
    for (var i = 0; i < values.length; i++) {
      final x = i * slot + (slot - barW) / 2;
      final bg = RRect.fromRectAndRadius(Rect.fromLTWH(x, 0, barW, size.height), Radius.circular(barW / 2));
      canvas.drawRRect(bg, Paint()..color = rest);
      if (maxV <= 0 || values[i] <= 0) continue;
      final h = math.max(barW, size.height * values[i] / maxV);
      final r = RRect.fromRectAndRadius(Rect.fromLTWH(x, size.height - h, barW, h), Radius.circular(barW / 2));
      canvas.drawRRect(r, Paint()..color = color);
    }
  }

  @override
  bool shouldRepaint(BarChartPainter old) => old.values != values;
}

/// Subtle topographic contour lines (reference image 1 header).
class TopographicPainter extends CustomPainter {
  TopographicPainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = color;
    final center = Offset(size.width * 0.85, size.height * 0.2);
    for (var i = 1; i <= 9; i++) {
      final path = Path();
      final base = i * 22.0;
      for (var a = 0.0; a <= math.pi * 2 + 0.01; a += 0.1) {
        final r = base + math.sin(a * 3 + i) * 6 + math.cos(a * 5) * 3;
        final p = center + Offset(math.cos(a) * r * 1.4, math.sin(a) * r);
        a == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(TopographicPainter old) => old.color != color;
}
