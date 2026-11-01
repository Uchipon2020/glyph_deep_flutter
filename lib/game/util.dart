// 乱数と方向など、ゲーム全体で使う小さな道具。
import 'dart:math';

/// ゲーム全体で共有する乱数。テストでは [seedRandom] で固定できる。
Random _rng = Random();

void seedRandom(int seed) => _rng = Random(seed);

/// a 以上 b 以下の整数。
int rnd(int a, int b) => a + _rng.nextInt(b - a + 1);

/// 確率 p で true。
bool chance(double p) => _rng.nextDouble() < p;

T pick<T>(List<T> list) => list[_rng.nextInt(list.length)];

List<T> shuffled<T>(Iterable<T> items) => items.toList()..shuffle(_rng);

/// 重み付きで1つ選ぶ。
T pickWeighted<T>(List<T> items, int Function(T) weight) {
  final total = items.fold<int>(0, (s, e) => s + weight(e));
  var r = _rng.nextInt(total);
  for (final e in items) {
    r -= weight(e);
    if (r < 0) return e;
  }
  return items.last;
}

/// まだ出ていない種類を優先しつつ、たまに重みつきの通常抽選も混ぜる（図鑑が揃いやすくなる）。
T pickVariety<T>(List<T> kinds, int Function(T) weight, Set<T> seen) {
  final unseen = kinds.where((k) => !seen.contains(k)).toList();
  final k = unseen.isNotEmpty && chance(.75) ? pick(unseen) : pickWeighted(kinds, weight);
  seen.add(k);
  return k;
}

/// 8方向。Dart の「レコード」(dx, dy) で表す。
const dirs8 = [(-1, -1), (0, -1), (1, -1), (-1, 0), (1, 0), (-1, 1), (0, 1), (1, 1)];

/// 0 → a, 1 → b ...（持ち物の記号）
String letter(int i) => String.fromCharCode(97 + i);
