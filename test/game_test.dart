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
    for (var i = 0; i < 4; i++) {
      g.startAim(darts, zap: false);
      g.fireAim(1, 0);
    }
    expect(m.hp, lessThan(500));
    expect(g.p.inv.contains(darts), isFalse); // 4本とも投げきった
  });

  /// 右隣のマスを、何もない床にする。
  (int, int) clearRight(Game g) {
    final (x, y) = (g.p.x + 1, g.p.y);
    g.lv.monsters.clear();
    g.lv.grid[y][x] = Tile.floor;
    g.lv.traps.remove((x, y));
    g.lv.items.removeWhere((it) => it.x == x && it.y == y);
    return (x, y);
  }

  test('投げ矢は1つの欄にまとまり、薬は別の欄になる', () {
    seedRandom(3);
    final g = Game();
    final (x, y) = clearRight(g);
    g.p.inv.add(Item.potion(Potion.heal));
    final before = g.p.inv.length;
    g.lv.items.add(Item.darts(3)
      ..x = x
      ..y = y);
    g.lv.items.add(Item.potion(Potion.heal)
      ..x = x
      ..y = y);
    g.move(1, 0);
    expect(g.p.inv.length, before + 1);
    expect(g.p.inv.firstWhere((it) => it.type == ItemType.dart).count, 7);
  });

  test('見えている罠は警告で止まり、もう一度動くと踏む', () {
    seedRandom(8);
    final g = Game();
    final (x, y) = clearRight(g);
    final (x0, y0) = (g.p.x, g.p.y);
    g.lv.traps[(x, y)] = Trap(TrapKind.alarm)..found = true;
    final turns = g.p.turns;
    expect(g.move(1, 0), isFalse);
    expect((g.p.x, g.p.y), (x0, y0));
    expect(g.p.turns, turns); // 警告ではターンが進まない
    expect(g.move(1, 0), isTrue);
    expect((g.p.x, g.p.y), (x, y));
    expect(g.p.armed, isNull);
  });

  test('探すと隣の隠し扉と罠が見つかる', () {
    seedRandom(9);
    final g = Game();
    final (x, y) = clearRight(g);
    g.lv.grid[y][x] = Tile.secretDoorV;
    g.p
      ..hp = 999
      ..maxHp = 999;
    for (var i = 0; i < 20 && g.lv.grid[y][x].isSecret; i++) {
      g.search();
    }
    expect(g.lv.grid[y][x], Tile.door);
  });

  test('開始部屋には必ず見える扉がある', () {
    seedRandom(10);
    var id = 0;
    for (var n = 0; n < 500; n++) {
      final lv = generateLevel(Game.maxDepth, Game.maxDepth, () => ++id);
      final r = lv.rooms[lv.roomId[lv.start.$2][lv.start.$1]];
      final hasDoor = [
        for (var y = r.y - 1; y <= r.y + r.h; y++)
          for (var x = r.x - 1; x <= r.x + r.w; x++) lv.grid[y][x] == Tile.door
      ].any((e) => e);
      expect(hasDoor, isTrue);
    }
  });

  test('眠っている怪物へのダメージは2倍で、魔法の眠りは攻撃でも覚めない', () {
    seedRandom(11);
    final g = Game();
    final (x, y) = clearRight(g);
    final m = Monster(999, monsterKinds.first, 500, x, y)..deepSleep = 20;
    g.lv.monsters.add(m);
    final wand = Item.wand(Wand.bolt, 1);
    g.p.inv.add(wand);
    g.startAim(wand, zap: true);
    g.fireAim(1, 0);
    final dmg = 500 - m.hp;
    expect(dmg.isEven, isTrue);
    expect(dmg, greaterThanOrEqualTo((6 + g.depth) * 2));
    expect(m.awake, isFalse);
  });

  test('泥棒に盗まれた金貨は倒すと床に落ちる', () {
    seedRandom(12);
    final g = Game();
    final (x, y) = clearRight(g);
    final m = Monster(999, monsterKinds.firstWhere((k) => k.abilities.contains(Ability.steal)), 1, x, y)..loot = 40;
    g.lv.monsters.add(m);
    final wand = Item.wand(Wand.bolt, 1);
    g.p.inv.add(wand);
    g.startAim(wand, zap: true);
    g.fireAim(1, 0);
    expect(g.lv.monsters.contains(m), isFalse);
    expect(g.lv.itemAt(x, y)?.amount, 40);
  });

  test('鑑定は金貨を払って種類を知る。足りなければ何も起きない', () {
    seedRandom(13);
    final g = Game();
    final it = Item.potion(Potion.life);
    g.p.inv.add(it);
    g.identify(it);
    expect(g.known.contains(Potion.life), isFalse);
    g.p.gold = identifyCost;
    final turns = g.p.turns;
    g.identify(it);
    expect(g.known.contains(Potion.life), isTrue);
    expect(g.p.gold, 0);
    expect(g.p.turns, turns);
  });

  test('巻物を読んだあとも、離れた起きている怪物がいても走れる', () async {
    for (final k in Scroll.values) {
      seedRandom(14);
      final g = Game();
      // 一本道の通路だけの階にする
      for (var y = 0; y < Level.height; y++) {
        for (var x = 0; x < Level.width; x++) {
          g.lv.grid[y][x] = Tile.rock;
          g.lv.roomId[y][x] = -1;
        }
      }
      for (var x = 5; x <= 30; x++) {
        g.lv.grid[10][x] = Tile.corridor;
      }
      g.lv
        ..items.clear()
        ..traps.clear()
        ..monsters.clear();
      g.p
        ..x = 5
        ..y = 10
        ..inv.add(Item.scroll(k));
      if (k == Scroll.teleport) continue; // 部屋がないので飛べない
      g.use(g.p.inv.last);
      g.lv.grid[2][2] = Tile.floor;
      g.lv.monsters.add(Monster(999, monsterKinds.first, 10, 2, 2));
      g.startRun(1, 0);
      await Future<void>.delayed(const Duration(milliseconds: 400));
      g.stopRun();
      expect(g.p.x, greaterThan(7), reason: k.name);
    }
  });

  /// 一本道の通路だけの階で始める。
  Game corridorGame() {
    final g = Game();
    for (var y = 0; y < Level.height; y++) {
      for (var x = 0; x < Level.width; x++) {
        g.lv.grid[y][x] = Tile.rock;
        g.lv.roomId[y][x] = -1;
      }
    }
    for (var x = 5; x <= 30; x++) {
      g.lv.grid[10][x] = Tile.corridor;
    }
    g.lv
      ..items.clear()
      ..traps.clear()
      ..monsters.clear();
    g.p
      ..x = 5
      ..y = 10;
    return g;
  }

  Future<void> runRight(Game g) async {
    g.startRun(1, 0);
    await Future<void>.delayed(const Duration(milliseconds: 400));
    g.stopRun();
  }

  test('千里眼で遠くの怪物が見えていても走れる', () async {
    seedRandom(15);
    final g = corridorGame();
    g.p.inv.add(Item.potion(Potion.detect));
    g.use(g.p.inv.last);
    expect(g.p.detect, isTrue);
    g.lv.grid[2][2] = Tile.floor;
    final far = Monster(999, monsterKinds.first, 10, 2, 2);
    g.lv.monsters.add(far);
    expect(g.isVisible(far), isTrue); // 画面には映る
    expect(g.inSight(far), isFalse);
    await runRight(g);
    expect(g.p.x, greaterThan(7));
  });

  test('千里眼でも、近づいた怪物では止まる', () async {
    seedRandom(16);
    final g = corridorGame();
    g.p.detect = true;
    final kind = monsterKinds.firstWhere((k) => k.abilities.contains(Ability.stationary));
    g.lv.monsters.add(Monster(999, kind, 500, 9, 10));
    g.p
      ..hp = 999
      ..maxHp = 999;
    await runRight(g);
    expect(g.p.x, lessThanOrEqualTo(8));
  });

  test('A〜Zがそろい、どの深さにも怪物が出る', () {
    final letters = monsterKinds.map((k) => k.ch).toSet();
    expect(letters.length, 26);
    expect(monsterKinds.length, 28);
    for (var d = 1; d <= Game.maxDepth; d++) {
      expect(monsterKinds.any((k) => k.minDepth <= d && d <= k.maxDepth), isTrue);
    }
    for (final k in monsterKinds) {
      expect(k.minDepth, lessThanOrEqualTo(Game.maxDepth), reason: k.name);
    }
  });

  test('ゼロックは攻撃すると正体を現す', () {
    seedRandom(17);
    var id = 0;
    final g = corridorGame();
    final lv = Level();
    Monster? m;
    while (m == null || !m.has(Ability.mimic)) {
      m = spawnMonster(lv, 8, (11, 10), ++id);
    }
    expect(m.disguised, isTrue);
    g.lv.monsters.add(m..x = 6);
    expect(g.glyphOf(m), isNot('X'));
    g.p
      ..hp = 999
      ..maxHp = 999;
    g.move(1, 0);
    expect(m.disguised, isFalse);
    expect(g.glyphOf(m), 'X');
  });

  test('捕まると離れられず、倒すと解放される', () {
    seedRandom(18);
    final g = corridorGame();
    g.p
      ..x = 10
      ..hp = 999
      ..maxHp = 999;
    final kind = monsterKinds.firstWhere((k) => k.abilities.contains(Ability.hold));
    final m = Monster(999, kind, 1, 11, 10);
    g.lv.monsters.add(m);
    g.p.heldBy = m.id;
    expect(g.move(-1, 0), isFalse);
    expect(g.p.x, 10);
    final wand = Item.wand(Wand.bolt, 1);
    g.p.inv.add(wand);
    g.startAim(wand, zap: true);
    g.fireAim(1, 0);
    expect(g.p.heldBy, isNull);
    expect(g.move(-1, 0), isTrue);
  });

  test('見えない怪物は映らず、名前は「何か」になる', () {
    seedRandom(19);
    final g = corridorGame();
    final kind = monsterKinds.firstWhere((k) => k.abilities.contains(Ability.invisible));
    final m = Monster(999, kind, 10, 6, 10);
    g.lv.monsters.add(m);
    g.p.detect = true;
    expect(g.isVisible(m), isFalse);
    expect(g.who(m), '何か');
  });

  test('レプラコーンは金貨を盗んで消え、戻ってこない', () {
    seedRandom(20);
    final g = corridorGame();
    g.p
      ..gold = 1000
      ..hp = 999
      ..maxHp = 999;
    final kind = monsterKinds.firstWhere((k) => k.abilities.contains(Ability.stealGold));
    final m = Monster(999, kind, 10, 6, 10);
    g.lv.monsters.add(m);
    for (var i = 0; i < 50 && m.alive; i++) {
      g.rest();
    }
    expect(m.alive, isFalse);
    expect(g.p.gold, lessThan(1000));
    expect(g.lv.monsters.contains(m), isFalse);
    expect(g.lv.items.any((it) => it.type == ItemType.gold), isFalse);
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
        } else if (r < 60) {
          g.rest();
        } else if (r < 62) {
          g.search();
        } else if (r < 72 && g.p.inv.isNotEmpty) {
          final it = pick(g.p.inv);
          if (t % 7 == 0) g.identify(it);
          g.use(it);
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
    expect(g.depth, 1);
  });
}
