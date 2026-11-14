import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:qodi_music/features/player/domain/play_queue.dart';

void main() {
  PlayQueue<String> queue({int start = 0}) =>
      PlayQueue<String>(random: Random(42))..load(['a', 'b', 'c', 'd'], startIndex: start);

  test('play from list index starts at that item', () {
    final q = queue(start: 2);
    expect(q.current, 'c');
    expect(q.playIndex(0), 'a');
    expect(q.current, 'a');
  });

  test('next/previous walk the list; repeat off stops at the end', () {
    final q = queue(start: 2);
    expect(q.next(), 'd');
    expect(q.next(), isNull);
    expect(q.current, 'd');
    expect(q.previous(), 'c');
    q.jumpToPosition(0);
    expect(q.previous(), 'a', reason: 'stays on the first item with repeat off');
  });

  test('repeat all wraps around in both directions', () {
    final q = queue(start: 3)..repeat = QueueRepeat.all;
    expect(q.next(), 'a');
    expect(q.previous(), 'd');
  });

  test('repeat one replays on auto-advance but manual next moves on', () {
    final q = queue(start: 1)..repeat = QueueRepeat.one;
    expect(q.next(auto: true), 'b');
    expect(q.next(), 'c');
  });

  test('shuffle keeps the current track and contains every item once', () {
    final q = queue(start: 2);
    q.setShuffle(true);
    expect(q.current, 'c');
    expect(q.position, 0);
    expect(q.playOrder.toSet(), {'a', 'b', 'c', 'd'});
    expect(q.playOrder.length, 4);
    // Turning shuffle off restores the original order at the current item.
    q.next();
    final now = q.current;
    q.setShuffle(false);
    expect(q.current, now);
    expect(q.playOrder, ['a', 'b', 'c', 'd']);
    expect(q.position, ['a', 'b', 'c', 'd'].indexOf(now!));
  });

  test('loading with shuffle on starts with the chosen item', () {
    final q = PlayQueue<String>(random: Random(1))..setShuffle(true);
    q.load(['a', 'b', 'c'], startIndex: 1);
    expect(q.current, 'b');
    expect(q.playOrder.first, 'b');
  });

  test('playNext inserts after the current item; add appends', () {
    final q = queue(start: 0);
    q.playNext('x');
    q.add('y');
    expect(q.playOrder, ['a', 'x', 'b', 'c', 'd', 'y']);
    expect(q.next(), 'x');
  });
}
