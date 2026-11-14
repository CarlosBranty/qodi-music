import 'dart:math';

enum QueueRepeat { off, all, one }

/// Pure playback-queue logic: ordering, shuffle and repeat.
///
/// [items] keeps the original order. The play order is a permutation of item
/// indices; with shuffle on it is random but always keeps the current item.
class PlayQueue<T> {
  PlayQueue({Random? random}) : _random = random ?? Random();

  final Random _random;
  List<T> _items = [];
  List<int> _order = [];
  int _pos = -1;

  QueueRepeat repeat = QueueRepeat.off;
  bool _shuffle = false;

  List<T> get items => List.unmodifiable(_items);
  bool get shuffle => _shuffle;
  bool get isEmpty => _items.isEmpty;

  /// Items in play order.
  List<T> get playOrder => [for (final i in _order) _items[i]];

  /// Position of the current item within [playOrder], or -1.
  int get position => _pos;

  T? get current => _pos < 0 ? null : _items[_order[_pos]];

  /// Replaces the queue and starts at [startIndex] (index in [items]).
  void load(List<T> items, {int startIndex = 0}) {
    _items = List.of(items);
    if (_items.isEmpty) {
      _order = [];
      _pos = -1;
      return;
    }
    final start = startIndex.clamp(0, _items.length - 1);
    _order = List.generate(_items.length, (i) => i);
    _pos = start;
    if (_shuffle) _reshuffleKeeping(start);
  }

  /// Jumps to the item at [index] in [items].
  T? playIndex(int index) {
    if (index < 0 || index >= _items.length) return null;
    _pos = _order.indexOf(index);
    return current;
  }

  /// Jumps to [position] in [playOrder].
  T? jumpToPosition(int position) {
    if (position < 0 || position >= _order.length) return null;
    _pos = position;
    return current;
  }

  /// Advances. [auto] is true when the current item finished on its own:
  /// repeat-one then replays it. Returns null at the end with repeat off.
  T? next({bool auto = false}) {
    if (_items.isEmpty) return null;
    if (auto && repeat == QueueRepeat.one) return current;
    if (_pos + 1 < _order.length) {
      _pos++;
      return current;
    }
    if (repeat != QueueRepeat.off) {
      _pos = 0;
      return current;
    }
    return null;
  }

  /// Goes back one item. At the start wraps with repeat all, otherwise stays.
  T? previous() {
    if (_items.isEmpty) return null;
    if (_pos > 0) {
      _pos--;
    } else if (repeat == QueueRepeat.all) {
      _pos = _order.length - 1;
    }
    return current;
  }

  void setShuffle(bool enabled) {
    if (enabled == _shuffle) return;
    _shuffle = enabled;
    if (_items.isEmpty) return;
    final currentIndex = _order[_pos];
    if (enabled) {
      _reshuffleKeeping(currentIndex);
    } else {
      _order = List.generate(_items.length, (i) => i);
      _pos = currentIndex;
    }
  }

  /// Appends [item] at the end of the queue (and play order).
  void add(T item) {
    _items.add(item);
    _order.add(_items.length - 1);
    if (_pos < 0) _pos = 0;
  }

  /// Inserts [item] right after the current one in play order.
  void playNext(T item) {
    _items.add(item);
    _order.insert(_pos + 1, _items.length - 1);
    if (_pos < 0) _pos = 0;
  }

  void _reshuffleKeeping(int currentIndex) {
    final rest = List.generate(_items.length, (i) => i)..remove(currentIndex);
    rest.shuffle(_random);
    _order = [currentIndex, ...rest];
    _pos = 0;
  }
}
