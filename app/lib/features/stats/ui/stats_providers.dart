import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/config/core_providers.dart';
import '../data/plays_reporter.dart';
import '../data/stats_api.dart';
import '../domain/play_recorder.dart';
import '../domain/stats_summary.dart';

final statsApiProvider = Provider<StatsApi>((ref) => StatsApi(ref.watch(apiClientProvider)));

final playsReporterProvider = Provider<PlaysReporter>((ref) => PlaysReporter(
      ref.watch(statsApiProvider),
      ref.watch(platformServicesProvider).outbox,
    ));

final playRecorderProvider =
    Provider<PlayRecorder>((ref) => PlayRecorder(newClientId: () => const Uuid().v4()));

final statsRangeProvider = NotifierProvider<StatsRangeController, StatsRange>(StatsRangeController.new);

class StatsRangeController extends Notifier<StatsRange> {
  @override
  StatsRange build() => StatsRange.month;
  void set(StatsRange r) => state = r;
}

final statsSummaryProvider = FutureProvider.autoDispose<StatsSummary>(
    (ref) => ref.watch(statsApiProvider).summary(ref.watch(statsRangeProvider)));

/// Summary used on Home for "most played" when there is no local history.
final weeklyStatsProvider = FutureProvider.autoDispose<StatsSummary>(
    (ref) => ref.watch(statsApiProvider).summary(StatsRange.week));
