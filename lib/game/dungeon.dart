// 1つの階（フロア）のデータと、その自動生成。
//
// 画面を 3×3 のマスに分け、それぞれに部屋（または通路の交差点だけの
// 「見えない部屋」）を置き、迷路状に通路でつなぐ。本家 Rogue と同じ方式。
import 'data.dart';
import 'models.dart';
import 'util.dart';

/// 1回の冒険を通して覚えておく、生成の偏りを減らすための記録。
class GenMemory {
  final potions = <Potion>{};
  final scrolls = <Scroll>{};
  final wands = <Wand>{};
  TrapKind? lastTrap;
}

class Room {
  Room.real(this.index, this.x, this.y, this.w, this.h)
      : real = true,
        px = 0,
        py = 0;
  Room.dummy(this.index, this.px, this.py)
      : real = false,
        x = 0,
        y = 0,
        w = 0,
        h = 0;

  final int index;
  final bool real;
  final int x, y, w, h; // 床の範囲（壁の内側）
  final int px, py; // 見えない部屋の通路の交点

  int get cx => index % 3;
  int get cy => index ~/ 3;
}

class Level {
  static const width = 42, height = 21;
  static const cellW = 14, cellH = 7;

  final grid = List.generate(height, (_) => List.filled(width, Tile.rock));
  final roomId = List.generate(height, (_) => List.filled(width, -1));
  final seen = List.generate(height, (_) => List.filled(width, false));
  final rooms = <Room>[];
  final items = <Item>[];
  final monsters = <Monster>[];
  final traps = <(int, int), Trap>{};
  (int, int)? stairs;
  (int, int) start = (0, 0);

  bool inBounds(int x, int y) => x >= 0 && y >= 0 && x < width && y < height;

  Item? itemAt(int x, int y) {
    for (final it in items) {
      if (it.x == x && it.y == y) return it;
    }
    return null;
  }

  Monster? monsterAt(int x, int y) {
    for (final m in monsters) {
      if (m.alive && m.x == x && m.y == y) return m;
    }
    return null;
  }

  Iterable<Room> get realRooms => rooms.where((r) => r.real);

  /// 部屋の中の空いている床を探す。
  (int, int)? freeCell(Room r, {(int, int)? avoid}) {
    for (var t = 0; t < 200; t++) {
      final x = rnd(r.x, r.x + r.w - 1), y = rnd(r.y, r.y + r.h - 1);
      if (grid[y][x] == Tile.floor &&
          itemAt(x, y) == null &&
          monsterAt(x, y) == null &&
          !traps.containsKey((x, y)) &&
          (x, y) != avoid) {
        return (x, y);
      }
    }
    return null;
  }

  bool walkable(int x, int y) => inBounds(x, y) && grid[y][x].walkable;

  /// (x,y) から (nx,ny) へ1歩で動けるか。扉は斜めに出入りできない。
  bool canStep(int x, int y, int nx, int ny) {
    if (!walkable(nx, ny)) return false;
    if (nx != x && ny != y && (grid[y][x] == Tile.door || grid[ny][nx] == Tile.door)) {
      return false;
    }
    return true;
  }

  /// (sx,sy) から各マスまでの歩数（幅優先探索）。怪物の追跡に使う。
  List<List<int>> distanceFrom(int sx, int sy) {
    final d = List.generate(height, (_) => List.filled(width, 999));
    final q = [(sx, sy)];
    d[sy][sx] = 0;
    for (var i = 0; i < q.length; i++) {
      final (x, y) = q[i];
      for (final (dx, dy) in dirs8) {
        final nx = x + dx, ny = y + dy;
        if (!inBounds(nx, ny) || d[ny][nx] < 999 || !canStep(x, y, nx, ny)) continue;
        d[ny][nx] = d[y][x] + 1;
        q.add((nx, ny));
      }
    }
    return d;
  }

  /// 隠し扉を普通の扉に変える。
  void revealDoor(int x, int y) {
    if (grid[y][x].isSecret) grid[y][x] = Tile.door;
  }
}

/// 新しい階を作る。最深部には護符を置く（amulet が false なら置かない＝持ち帰り中）。
Level generateLevel(int depth, int maxDepth, int Function() nextMonsterId,
    {bool amulet = true, GenMemory? memory}) {
  final lv = Level();
  final mem = memory ?? GenMemory();

  // 9マスのうち、少なくとも4つは本物の部屋にする
  final real = List.generate(9, (_) => chance(.82));
  while (real.where((r) => r).length < 4) {
    real[rnd(0, 8)] = true;
  }
  for (var i = 0; i < 9; i++) {
    final cx = i % 3, cy = i ~/ 3;
    if (real[i]) {
      final w = rnd(4, 8), h = rnd(3, 4);
      final x0 = cx * Level.cellW + rnd(0, Level.cellW - (w + 2) - 1);
      final y0 = cy * Level.cellH + rnd(0, Level.cellH - (h + 2) - 1);
      lv.rooms.add(Room.real(i, x0 + 1, y0 + 1, w, h));
      for (var y = y0; y <= y0 + h + 1; y++) {
        for (var x = x0; x <= x0 + w + 1; x++) {
          lv.roomId[y][x] = i;
          lv.grid[y][x] = (y == y0 || y == y0 + h + 1)
              ? Tile.wallH
              : (x == x0 || x == x0 + w + 1)
                  ? Tile.wallV
                  : Tile.floor;
        }
      }
    } else {
      final px = cx * Level.cellW + rnd(2, 10), py = cy * Level.cellH + rnd(1, 4);
      lv.rooms.add(Room.dummy(i, px, py));
      lv.grid[py][px] = Tile.corridor;
    }
  }

  // 隣り合うマス同士を「全域木」でつなぎ（必ず全部屋に行ける）、少しだけ余分な道を足す
  List<int> adj(int i) {
    final cx = i % 3, cy = i ~/ 3;
    return [if (cx > 0) i - 1, if (cx < 2) i + 1, if (cy > 0) i - 3, if (cy < 2) i + 3];
  }

  final edges = <(int, int)>[];
  final has = <(int, int)>{};
  (int, int) key(int a, int b) => a < b ? (a, b) : (b, a);
  final s = rnd(0, 8);
  final visited = {s};
  final stack = [s];
  while (stack.isNotEmpty) {
    final cur = stack.last;
    final nb = shuffled(adj(cur)).where((n) => !visited.contains(n)).toList();
    if (nb.isEmpty) {
      stack.removeLast();
      continue;
    }
    visited.add(nb.first);
    edges.add((cur, nb.first));
    has.add(key(cur, nb.first));
    stack.add(nb.first);
  }
  for (var k = 0; k < 3; k++) {
    final a = rnd(0, 8), b = pick(adj(a));
    if (!has.contains(key(a, b)) && chance(.6)) {
      has.add(key(a, b));
      edges.add((a, b));
    }
  }
  // 扉の一部が隠し扉になる。深いほど多い
  final secretChance = .06 + .02 * depth;
  for (final (a, b) in edges) {
    _connect(lv, a < b ? a : b, a < b ? b : a, secretChance);
  }

  final rr = lv.realRooms.toList();
  final startRoom = pick(rr);
  final stairRoom = pick(rr.where((r) => r != startRoom).toList());
  // 開始部屋に見える出口が1つも無いと詰むので、隠し扉を1つ普通の扉にする
  final exits = [
    for (var y = startRoom.y - 1; y <= startRoom.y + startRoom.h; y++)
      for (var x = startRoom.x - 1; x <= startRoom.x + startRoom.w; x++)
        if (lv.grid[y][x] == Tile.door || lv.grid[y][x].isSecret) (x, y)
  ];
  if (exits.isNotEmpty && !exits.any((e) => lv.grid[e.$2][e.$1] == Tile.door)) {
    final (x, y) = pick(exits);
    lv.revealDoor(x, y);
  }
  lv.start = lv.freeCell(startRoom)!;
  // 階段は常に置く（降りるときも、護符を手にした後に地上へ戻るときも使う）
  final c = lv.freeCell(stairRoom, avoid: lv.start)!;
  lv.grid[c.$2][c.$1] = Tile.stairs;
  lv.stairs = c;

  void place(Item it) {
    final p = lv.freeCell(pick(rr), avoid: lv.start);
    if (p == null) return;
    it
      ..x = p.$1
      ..y = p.$2;
    lv.items.add(it);
  }

  if (depth == maxDepth && amulet) place(Item.amulet());
  for (var n = rnd(3, 5); n > 0; n--) {
    place(randomItem(depth, mem));
  }
  for (var n = rnd(2, 3); n > 0; n--) {
    place(Item.gold(rnd(8, 25) + depth * 8));
  }

  // 深くなるほど落とし穴は出さない（体感がきつすぎるため）。同じ罠が連続しないようにする
  final trapKinds = TrapKind.values.where((k) => k != TrapKind.pit || depth <= maxDepth - 3).toList();
  for (var n = rnd(1, 2) + depth ~/ 3; n > 0; n--) {
    final p = lv.freeCell(pick(rr), avoid: lv.start);
    if (p == null) continue;
    final k = pick(trapKinds.where((k) => k != mem.lastTrap).toList());
    mem.lastTrap = k;
    lv.traps[p] = Trap(k)..found = !chance(.7);
  }

  final others = rr.where((r) => r != startRoom).toList();
  for (var n = rnd(3, 4) + depth ~/ 3; n > 0; n--) {
    final p = lv.freeCell(pick(others));
    if (p != null) spawnMonster(lv, depth, p, nextMonsterId(), asleep: chance(.4));
  }
  return lv;
}

void _connect(Level lv, int a, int b, double secretChance) {
  final ra = lv.rooms[a], rb = lv.rooms[b];
  final horizontal = b == a + 1;
  final ea = _exitPoint(ra, horizontal ? 'R' : 'D');
  final eb = _exitPoint(rb, horizontal ? 'L' : 'U');
  final List<(int, int)> pts;
  if (horizontal) {
    final mx = ra.cx * Level.cellW + 13;
    pts = [ea.out, (mx, ea.out.$2), (mx, eb.out.$2), eb.out];
  } else {
    final my = ra.cy * Level.cellH + 6;
    pts = [ea.out, (ea.out.$1, my), (eb.out.$1, my), eb.out];
  }
  for (var k = 0; k < pts.length - 1; k++) {
    var (x, y) = pts[k];
    final (tx, ty) = pts[k + 1];
    while (true) {
      if (lv.grid[y][x] == Tile.rock) lv.grid[y][x] = Tile.corridor;
      if (x == tx && y == ty) break;
      if (x != tx) {
        x += (tx - x).sign;
      } else {
        y += (ty - y).sign;
      }
    }
  }
  void door(Room r, (int, int) d) {
    if (!r.real) return;
    final secret = chance(secretChance);
    // 左右の壁は「|」、上下の壁は「-」
    final vertical = d.$1 == r.x - 1 || d.$1 == r.x + r.w;
    lv.grid[d.$2][d.$1] = !secret
        ? Tile.door
        : vertical
            ? Tile.secretDoorV
            : Tile.secretDoorH;
  }

  door(ra, ea.door);
  door(rb, eb.door);
}

/// 部屋の壁のどこに扉を開け、そのすぐ外のどこから通路を始めるか。
({(int, int) door, (int, int) out}) _exitPoint(Room r, String dir) {
  if (!r.real) return (door: (r.px, r.py), out: (r.px, r.py));
  switch (dir) {
    case 'R':
      final y = rnd(r.y, r.y + r.h - 1);
      return (door: (r.x + r.w, y), out: (r.x + r.w + 1, y));
    case 'L':
      final y = rnd(r.y, r.y + r.h - 1);
      return (door: (r.x - 1, y), out: (r.x - 2, y));
    case 'U':
      final x = rnd(r.x, r.x + r.w - 1);
      return (door: (x, r.y - 1), out: (x, r.y - 2));
    default:
      final x = rnd(r.x, r.x + r.w - 1);
      return (door: (x, r.y + r.h), out: (x, r.y + r.h + 1));
  }
}

/// 深さに応じた怪物を1体置く。
Monster spawnMonster(Level lv, int depth, (int, int) p, int id, {bool asleep = false}) {
  final kinds = monsterKinds.where((k) => k.minDepth <= depth && depth <= k.maxDepth).toList();
  final kind = pick(kinds);
  final m = Monster(id, kind, (kind.hp + rnd(-1, 2)).clamp(1, 999), p.$1, p.$2)..asleep = asleep;
  lv.monsters.add(m);
  return m;
}

/// 武器・防具の格。深いほど良いものが出る。
int _tier(int depth) {
  final base = depth ~/ 3;
  return rnd((base - 1).clamp(0, 3), (base + 1).clamp(0, 3));
}

/// 床に落ちているアイテムを1つ作る。
Item randomItem(int depth, GenMemory mem) {
  final r = rnd(0, 99);
  if (r < 24) return Item.potion(pickVariety<Potion>(Potion.values, (p) => p.weight, mem.potions));
  if (r < 48) return Item.scroll(pickVariety<Scroll>(Scroll.values, (s) => s.weight, mem.scrolls));
  if (r < 54) return Item.food();
  if (r < 67) {
    final (name, lo, hi) = weaponTable[_tier(depth)];
    return Item.weapon(name, lo, hi, ench: chance(.3) ? rnd(1, 2) : 0);
  }
  if (r < 80) {
    final (name, value) = armorTable[_tier(depth)];
    return Item.armor(name, value, ench: chance(.3) ? rnd(1, 2) : 0);
  }
  if (r < 89) return Item.darts(rnd(3, 7));
  return Item.wand(pickVariety<Wand>(Wand.values, (w) => w.weight, mem.wands), rnd(3, 6));
}
