import 'package:flutter_test/flutter_test.dart';
import 'package:glyphdeep/game/data.dart';
import 'package:glyphdeep/game/dungeon.dart';
import 'package:glyphdeep/game/game.dart';
import 'package:glyphdeep/game/models.dart';
import 'package:glyphdeep/game/util.dart';

void main() {
  test('どの階も、隠し扉を開ければ全部屋と階段に行ける', () {
    seedRandom(1);
    var id = 0;
    for (var n = 0; n < 500; n++) {
      final depth = n % Game.maxDepth + 1;
      final lv = generateLevel(depth, Game.maxDepth, () => ++id);
      for (var y = 0; y < Level.height; y++) {
        for (var x = 0; x < Level.width; x++) {
          lv.revealDoor(x, y);
        }
      }
      final d = lv.distanceFrom(lv.start.$1, lv.start.$2);
      for (final r in lv.realRooms) {
        expect(d[r.y][r.x], lessThan(999), reason: 'room ${r.index} unreachable');
      }
      if (lv.stairs case final s?) expect(d[s.$2][s.$1], lessThan(999));
      if (depth == Game.maxDepth) {
        final a = lv.items.singleWhere((it) => it.type == ItemType.amulet);
        expect(d[a.y][a.x], lessThan(999));
      }
      expect(lv.traps.containsKey(lv.start), isFalse);
    }
  });

  test('投げ矢を投げると隣の怪物に当たる', () {
    seedRandom(2);
    final g = Game();
    g.lv.monsters.clear();
    final (x, y) = (g.p.x + 1, g.p.y);
    g.lv.grid[y][x] = Tile.floor;
    g.p
      ..hp = 999
      ..maxHp = 999;
    final m = Monster(999, monsterKinds.firstWhere((k) => k.ch == 'E'), 500, x, y);
    g.lv.monsters.add(m);
    final darts = g.p.inv.firstWhere((it) => it.type == ItemType.dart);
    for (var i = 0; i < 5; i++) {
      g.startAim(darts, zap: false);
      g.fireAim(1, 0);
    }
    expect(m.hp, lessThan(500));
    expect(g.p.inv.contains(darts), isFalse); // 5本とも投げきった
  });

  test('同じ薬は1つの欄にまとまる', () {
    seedRandom(3);
    final g = Game();
    g.lv.monsters.clear();
    final (x, y) = (g.p.x + 1, g.p.y);
    g.lv.grid[y][x] = Tile.floor;
    g.lv.traps.remove((x, y));
    g.lv.items.removeWhere((it) => it.x == x && it.y == y);
    g.p.inv.add(Item.potion(Potion.heal));
    final before = g.p.inv.length;
    g.lv.items.add(Item.potion(Potion.heal)
      ..x = x
      ..y = y);
    g.move(1, 0);
    expect(g.p.inv.length, before);
    expect(g.p.inv.last.count, 2);
  });

  test('ランダムに遊んでも例外が出ない', () {
    var deepest = 0;
    for (var seed = 0; seed < 40; seed++) {
      seedRandom(seed);
      final g = Game();
      for (var t = 0; t < 3000 && !g.over; t++) {
        g.p.hp = g.p.hp.clamp(1, 999) + (t % 50 == 0 ? 30 : 0);
        g.p.maxHp = g.p.maxHp < g.p.hp ? g.p.hp : g.p.maxHp;
        if (g.p.food < 100) g.p.food = 1500;
        final r = rnd(0, 99);
        if (g.aim != null) {
          final (dx, dy) = pick(dirs8);
          g.fireAim(dx, dy);
        } else if (r < 55) {
          final (dx, dy) = pick(dirs8);
          g.move(dx, dy);
        } else if (r < 62) {
          g.rest();
        } else if (r < 72 && g.p.inv.isNotEmpty) {
          g.use(pick(g.p.inv));
        } else if (r < 78 && g.p.inv.isNotEmpty) {
          g.startAim(pick(g.p.inv), zap: false);
        } else if (r < 80 && g.p.inv.isNotEmpty) {
          g.drop(pick(g.p.inv));
        } else if (r < 90) {
          // 階段まで直接歩かせる（見えていなくても）
          if (g.lv.stairs case final s? when r < 82) {
            g.p
              ..x = s.$1
              ..y = s.$2;
            g.descend();
          }
        } else {
          g.travelTo(rnd(0, Level.width - 1), rnd(0, Level.height - 1));
          g.stopRun();
        }
      }
      if (g.depth > deepest) deepest = g.depth;
    }
    expect(deepest, Game.maxDepth); // 最深部まで遊べている
  });

  test('無料版は深さ3の階段で止まり、購入すると先へ進める', () {
    seedRandom(5);
    var unlocked = false;
    final g = Game(null, () => unlocked);
    g.p
      ..hp = 999
      ..maxHp = 999;
    void stairs() {
      g.lv.monsters.clear();
      final s = g.lv.stairs!;
      g.p
        ..x = s.$1
        ..y = s.$2;
      g.descend();
    }

    for (var d = 1; d < Game.freeMaxDepth; d++) {
      stairs();
    }
    expect(g.depth, Game.freeMaxDepth);
    expect(g.sealed, isFalse);
    stairs();
    expect(g.depth, Game.freeMaxDepth); // 降りられない
    expect(g.sealed, isTrue); // 画面が購入案内を出す

    g.sealed = false;
    unlocked = true;
    g.descend(); // 階段の上にいるので、そのまま降りる
    expect(g.depth, Game.freeMaxDepth + 1);
    expect(g.sealed, isFalse);
  });

  test('無料版の深さ3では落とし穴でも下へ落ちない', () {
    seedRandom(6);
    final g = Game(null, () => false);
    while (g.depth < Game.freeMaxDepth) {
      final s = g.lv.stairs!;
      g.p
        ..x = s.$1
        ..y = s.$2;
      g.descend();
    }
    g.lv.monsters.clear();
    g.p
      ..hp = 999
      ..maxHp = 999;
    final (x, y) = (g.p.x + 1, g.p.y);
    g.lv.grid[y][x] = Tile.floor;
    g.lv.items.removeWhere((it) => it.x == x && it.y == y);
    g.lv.traps[(x, y)] = Trap(TrapKind.pit);
    g.move(1, 0);
    expect(g.depth, Game.freeMaxDepth);
  });

  test('最深部で護符を拾うと階段が上りになり、地上まで登ると脱出', () {
    seedRandom(7);
    final g = Game();
    void toStairs() {
      g.lv.monsters.clear();
      final s = g.lv.stairs!;
      g.p
        ..x = s.$1
        ..y = s.$2;
      g.descend();
    }

    g.p
      ..hp = 9999
      ..maxHp = 9999;
    while (g.depth < Game.maxDepth) {
      toStairs();
    }
    toStairs(); // 護符なしでは最深部より下へは行けない
    expect(g.depth, Game.maxDepth);

    // 護符の隣から踏んで拾う
    g.lv.monsters.clear();
    g.lv.traps.clear();
    final a = g.lv.items.singleWhere((it) => it.type == ItemType.amulet);
    final (dx, dy) = dirs8.firstWhere((d) => g.lv.canStep(a.x + d.$1, a.y + d.$2, a.x, a.y));
    g.p
      ..x = a.x + dx
      ..y = a.y + dy;
    g.move(-dx, -dy);
    expect(g.hasAmulet, isTrue);
    expect(g.over, isFalse); // 拾っただけではまだ終わらない

    for (var d = Game.maxDepth - 1; d >= 1; d--) {
      toStairs();
      expect(g.depth, d);
      expect(g.lv.items.any((it) => it.type == ItemType.amulet), isFalse);
    }
    toStairs(); // 深さ1の階段を登る
    expect(g.over, isTrue);
    expect(g.end!.title, '脱出成功！');
    expect(g.deepest, Game.maxDepth);
  });
}
