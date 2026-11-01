// ゲームのルール本体。画面（Flutter の Widget）には依存しない。
//
// 流れ: プレイヤーが1回行動する → _afterPlayerAction() で1ターン進める
// （満腹度が減る・怪物が動く）→ notifyListeners() で画面を描き直す。
import 'dart:async';
import 'dart:math' show max, min;

import 'package:flutter/foundation.dart';

import 'data.dart';
import 'dungeon.dart';
import 'models.dart';
import 'util.dart';

class BestScore {
  const BestScore(this.score, this.depth, this.gold);
  final int score, depth, gold;
}

/// ベストスコアの保存先。実体は storage.dart（テストでは使わない）。
abstract class ScoreBook {
  BestScore? get best;
  void submit(BestScore s);
}

class EndInfo {
  const EndInfo(this.title, this.cause);
  final String title, cause;
}

/// 「投げる」「振る」の方向待ち。
class Aim {
  const Aim(this.item, this.zap);
  final Item item;
  final bool zap; // true: 杖を振る / false: 投げる
}

class Game extends ChangeNotifier {
  Game([this.scores, this.isFullUnlocked]) {
    newGame();
  }

  static const maxDepth = 10; // 最深部。ここで護符を拾い、地上まで持ち帰るとクリア
  static const freeMaxDepth = 3; // 無料で遊べる深さ。この先は「深部解放」の購入が必要
  final ScoreBook? scores;

  /// 「深部解放」を購入済みか。null なら制限なし（テスト用）。
  final bool Function()? isFullUnlocked;

  late Level lv;
  late Player p;
  int depth = 1;
  bool hasAmulet = false; // 護符を持っている＝階段は上りになる
  int _monsterId = 0;
  GenMemory _memory = GenMemory();

  // 未識別アイテムの見た目（毎回ランダム）と、識別済みの種類
  final known = <Enum>{};
  final potionLook = <Potion, String>{};
  final scrollLook = <Scroll, String>{};
  final wandLook = <Wand, String>{};

  final log = <String>[];
  int msgCount = 0;
  bool over = false;
  EndInfo? end;
  Aim? aim;

  /// 無料版の最深部から先へ進もうとした。画面が購入案内を出し、false に戻す。
  bool sealed = false;

  bool get canGoDeeper => depth < freeMaxDepth || (isFullUnlocked?.call() ?? true);

  int _visibleRoom = -1;

  // ---------------------------------------------------------------- 開始
  void newGame() {
    stopRun();
    over = false;
    end = null;
    aim = null;
    sealed = false;
    depth = 1;
    hasAmulet = false;
    _monsterId = 0;
    _memory = GenMemory();
    log.clear();
    msgCount = 0;
    known.clear();
    final colors = shuffled(potionColors);
    for (final (i, k) in Potion.values.indexed) {
      potionLook[k] = colors[i];
    }
    final used = <String>{};
    for (final k in Scroll.values) {
      String t;
      do {
        t = '${pick(scrollSyllables)} ${pick(scrollSyllables)}';
      } while (used.contains(t));
      used.add(t);
      scrollLook[k] = t;
    }
    final mats = shuffled(wandMaterials);
    for (final (i, k) in Wand.values.indexed) {
      wandLook[k] = mats[i];
    }
    final mace = Item.weapon('棍棒', 2, 4), leather = Item.armor('革鎧', 3);
    p = Player()
      ..inv.addAll([mace, leather, Item.food(), Item.darts(4)])
      ..weapon = mace
      ..armor = leather;
    _enterLevel(1);
    msg('地下迷宮へようこそ。深さ$maxDepthの護符を目指せ。（？で操作説明）');
    if (!(isFullUnlocked?.call() ?? true)) msg('無料版は深さ$freeMaxDepthまで遊べます');
    notifyListeners();
  }

  void _enterLevel(int d) {
    depth = d;
    lv = generateLevel(depth, maxDepth, () => ++_monsterId, amulet: !hasAmulet, memory: _memory);
    p
      ..x = lv.start.$1
      ..y = lv.start.$2;
    p.armed = null;
    _updateFov();
  }

  // ---------------------------------------------------------------- 表示用
  void msg(String t) {
    log.add(t);
    msgCount++;
    if (log.length > 300) log.removeAt(0);
  }

  bool isAdjacent(int x, int y) => (x - p.x).abs() <= 1 && (y - p.y).abs() <= 1;

  /// 怪物が画面に見えるか。
  bool isVisible(Monster m) {
    if (!m.alive) return false;
    return (_visibleRoom >= 0 && lv.roomId[m.y][m.x] == _visibleRoom) || isAdjacent(m.x, m.y);
  }

  void _updateFov() {
    _visibleRoom = lv.roomId[p.y][p.x];
    if (_visibleRoom >= 0) {
      final r = lv.rooms[_visibleRoom];
      for (var y = r.y - 1; y <= r.y + r.h; y++) {
        for (var x = r.x - 1; x <= r.x + r.w; x++) {
          lv.seen[y][x] = true;
        }
      }
    }
    for (final (dx, dy) in [(0, 0), ...dirs8]) {
      final x = p.x + dx, y = p.y + dy;
      if (lv.inBounds(x, y)) lv.seen[y][x] = true;
    }
  }

  String nameOf(Item it) {
    String plus(int e) => e == 0 ? '' : (e > 0 ? '+$e' : '$e');
    return switch (it.type) {
      ItemType.food => '食料',
      ItemType.potion => known.contains(it.potion) ? it.potion!.label : '${potionLook[it.potion]}色の薬',
      ItemType.scroll => known.contains(it.scroll) ? it.scroll!.label : '「${scrollLook[it.scroll]}」の巻物',
      ItemType.wand => known.contains(it.wand) ? '${it.wand!.label}[${it.charges}]' : '${wandLook[it.wand]}の杖',
      ItemType.dart => '投げ矢 x${it.count}',
      ItemType.gold => '金貨${it.amount}枚',
      ItemType.amulet => '迷宮の護符',
      ItemType.weapon => '${it.name}${plus(it.ench)} (${it.lo + it.ench}-${it.hi + it.ench})',
      ItemType.armor => '${it.name}${plus(it.ench)} [${it.value + it.ench}]',
    };
  }

  /// 持ち物メニューに出す説明文。
  String descOf(Item it) => switch (it.type) {
        ItemType.food => '食べると満腹度が全快します（約$maxFoodターン分）。満腹度が0になると餓死します。画面下の「腹」が満腹度です。',
        ItemType.potion => !known.contains(it.potion)
            ? '正体不明の薬。飲むと何が起こるか分かりません。敵に投げれば、自分は安全に効果を試せます。'
            : switch (it.potion!) {
                Potion.heal => '体力を回復します。満タンで飲むと最大HPが1増えます。',
                Potion.life => '最大HPが4増え、全回復します。',
                Potion.strength => '力が1上がります。',
                Potion.poison => '飲むと有害です。敵に投げるとダメージを与えられます。',
                Potion.sleep => '飲むと眠って危険です。敵に投げると眠らせられます。',
              },
        ItemType.scroll => !known.contains(it.scroll)
            ? '読むまで効果が分からない巻物です。'
            : switch (it.scroll!) {
                Scroll.teleport => 'ランダムな場所へ瞬間移動します。逃走に。',
                Scroll.map => 'この階の地図（隠し扉と罠を除く）が分かります。',
                Scroll.enchantArmor => '着ている防具が+1されます。',
                Scroll.enchantWeapon => '装備中の武器が+1されます。',
              },
        ItemType.wand => !known.contains(it.wand)
            ? '振って方向を選ぶと、光が直進して最初の敵に当たります。使うまで効果は分かりません。'
            : '${switch (it.wand!) {
                Wand.sleep => '当たった敵を長時間眠らせます。眠っている敵には2倍のダメージ。',
                Wand.teleport => '当たった敵を別の場所へ飛ばします。',
                Wand.bolt => '当たった敵に魔法ダメージ。',
              }}（残り${it.charges}回）',
        ItemType.dart => '投げて遠くの敵を攻撃できます。投げた矢は床に落ちるので拾えます。',
        ItemType.weapon => '装備すると攻撃力が変わります。投げることもできますが威力は下がります。',
        ItemType.armor => '着ると防御が上がり、敵の攻撃が当たりにくくなります。',
        _ => '',
      };

  int get score => p.gold + depth * 50;

  // ---------------------------------------------------------------- 1ターンの進行
  /// プレイヤーが行動したあとに呼ぶ。眠っている間はここでターンが進み続ける。
  void _afterPlayerAction() {
    if (!over) {
      _endTurn();
      if (p.asleep > 0 && !over) {
        var guard = 0;
        while (p.asleep > 0 && !over && guard++ < 20) {
          p.asleep--;
          _endTurn();
        }
        p.asleep = 0;
        if (!over) msg('目が覚めた');
      }
      if (!over) _updateFov();
    }
    notifyListeners();
  }

  void _endTurn() {
    p.turns++;
    p.food--;
    if (p.food == 300) msg('お腹が空いてきた。食料(:)を食べよう');
    if (p.food == 150) msg('空腹で力が入らない');
    if (p.food == 50) msg('空腹で目がかすむ…');
    if (p.food <= 0) {
      _die('餓死した');
      return;
    }
    if (p.hp < p.maxHp && p.turns % (12 - p.level).clamp(3, 12) == 0) p.hp++;
    _searchAround(.05);
    _monstersAct();
    if (over) return;
    if (p.turns % 180 == 0 && chance(.6)) {
      final rr = lv.realRooms.where((r) => r.index != _visibleRoom).toList();
      final pos = rr.isEmpty ? null : lv.freeCell(pick(rr), avoid: (p.x, p.y));
      if (pos != null) spawnMonster(lv, depth, pos, ++_monsterId);
    }
  }

  // ---------------------------------------------------------------- プレイヤーの行動
  /// 1歩動く（怪物がいれば攻撃）。動けなかったら false。
  bool move(int dx, int dy) {
    if (over) return false;
    final nx = p.x + dx, ny = p.y + dy;
    if (!lv.canStep(p.x, p.y, nx, ny)) return false;
    final m = lv.monsterAt(nx, ny);
    if (m != null) {
      p.armed = null;
      _attack(m);
    } else {
      final t = lv.traps[(nx, ny)];
      if (t != null && t.found && p.armed != (nx, ny)) {
        p.armed = (nx, ny);
        msg('罠がある！（${t.kind.label}）もう一度動くと踏みます');
        notifyListeners();
        return false;
      }
      p
        ..armed = null
        ..x = nx
        ..y = ny;
      if (t != null) _springTrap(t);
      if (!over) _pickup();
    }
    _afterPlayerAction();
    return true;
  }

  /// その場で1ターン休む。
  void rest() {
    if (over) return;
    _afterPlayerAction();
  }

  /// 周囲を最大5ターン調べる。何か見つけるか、邪魔が入ると止める。
  void search() {
    if (over) return;
    stopRun();
    msg('周囲を調べた…');
    final hp0 = p.hp;
    var found = false;
    for (var n = 0; n < 5 && !over && !found; n++) {
      found = _searchAround(.35);
      _afterPlayerAction();
      if (p.hp < hp0 || lv.monsters.any((m) => isVisible(m) && m.awake)) break;
    }
    notifyListeners();
  }

  bool _searchAround(double pr) {
    var found = false;
    for (final (dx, dy) in dirs8) {
      final x = p.x + dx, y = p.y + dy;
      if (!lv.inBounds(x, y)) continue;
      if (lv.grid[y][x].isSecret && chance(pr)) {
        lv.revealDoor(x, y);
        lv.seen[y][x] = true;
        msg('隠し扉を見つけた！');
        found = true;
      }
      final t = lv.traps[(x, y)];
      if (t != null && !t.found && chance(pr)) {
        t.found = true;
        msg('罠を見つけた！（${t.kind.label}）');
        found = true;
      }
    }
    return found;
  }

  void _springTrap(Trap t) {
    t.found = true;
    switch (t.kind) {
      case TrapKind.pit when !canGoDeeper:
        msg('落とし穴だ！…が、底は封印されていて落ちなかった');
      case TrapKind.pit:
        msg('落とし穴だ！下の階へ落ちた');
        _hurt(rnd(1, 3), '落とし穴の底で力尽きた');
        if (over) return;
        _enterLevel(depth + 1);
        msg('深さ $depth に落ちた');
        if (depth == maxDepth) msg('空気が重い…この階のどこかに護符がある');
      case TrapKind.sleepGas:
        msg('眠りガスだ！意識が遠のく…');
        p.asleep = max(p.asleep, rnd(4, 7));
      case TrapKind.arrow:
        final d = rnd(2, 6) + depth ~/ 2;
        msg('矢が飛んできた！$dダメージ');
        _hurt(d, '矢の罠にかかった');
      case TrapKind.dart:
        final d = rnd(1, 3);
        p.str = max(3, p.str - 1);
        msg('毒針だ！力が落ちた（$dダメージ）');
        _hurt(d, '毒針の罠にかかった');
      case TrapKind.alarm:
        msg('警報が鳴り響く！怪物たちが目を覚ました');
        for (final m in lv.monsters) {
          m
            ..asleep = false
            ..deepSleep = 0;
        }
      case TrapKind.teleport:
        _teleportPlayer();
        msg('転送の罠だ！別の場所へ飛ばされた');
    }
  }

  /// どこかの部屋の空いているマス。
  (int, int)? _randomCell() => lv.freeCell(pick(lv.realRooms.toList()), avoid: (p.x, p.y));

  void _teleportPlayer() {
    final pos = _randomCell();
    if (pos != null) {
      p
        ..x = pos.$1
        ..y = pos.$2;
    }
  }

  void _pickup() {
    while (true) {
      final it = lv.itemAt(p.x, p.y);
      if (it == null) return;
      if (it.type == ItemType.gold) {
        p.gold += it.amount;
        msg('金貨${it.amount}枚を拾った');
        lv.items.remove(it);
        continue;
      }
      if (it.type == ItemType.amulet) {
        if (!canGoDeeper) return; // 護符は「深部解放」で手に入る（無料の深さには出ない）
        lv.items.remove(it);
        hasAmulet = true;
        msg('迷宮の護符を手に入れた！地上に戻れば脱出成功だ（階段を上れ）');
        continue;
      }
      if (it.type == ItemType.dart) {
        final have = p.inv.where((x) => x.type == ItemType.dart).firstOrNull;
        if (have != null) {
          have.count += it.count;
          lv.items.remove(it);
          msg('投げ矢を拾った (計${have.count})');
          continue;
        }
      }
      if (p.inv.length >= 26) {
        msg('持ち物がいっぱいで拾えない');
        return;
      }
      lv.items.remove(it);
      p.inv.add(it);
      msg('${letter(p.inv.length - 1)}) ${nameOf(it)}を手に入れた');
    }
  }

  void _attack(Monster m) {
    final w = p.weapon;
    final lo = w == null ? 1 : w.lo + w.ench, hi = w == null ? 2 : w.hi + w.ench;
    final strBonus = p.str > 16 ? ((p.str - 16) / 2).ceil() : 0;
    if (chance((.78 + p.level * .01).clamp(0, .95))) {
      _damage(m, max(1, rnd(lo, hi) + p.level ~/ 2 + strBonus));
    } else {
      m.asleep = false;
      msg('${m.name}への攻撃は外れた');
    }
  }

  /// 怪物にダメージを与える（眠っていれば2倍。倒したら経験値）。
  void _damage(Monster m, int d) {
    final sleeping = !m.awake;
    if (sleeping) d *= 2;
    m
      ..asleep = false
      ..hp = m.hp - d;
    if (m.alive) {
      msg('${m.name}に$dダメージ${sleeping ? '（不意打ち）' : ''}');
      return;
    }
    msg('${m.name}を倒した (+${m.kind.xp}exp)${sleeping ? ' 不意打ち！' : ''}');
    if (m.loot > 0) {
      lv.items.add(Item.gold(m.loot)
        ..x = m.x
        ..y = m.y);
    }
    p.xp += m.kind.xp;
    while (p.level < xpNeeded.length && p.xp >= xpNeeded[p.level - 1]) {
      final g = rnd(4, 8);
      p
        ..level += 1
        ..maxHp += g
        ..hp += g;
      msg('レベルが ${p.level} に上がった！');
    }
    lv.monsters.removeWhere((x) => !x.alive);
  }

  /// 階段を使う。ふだんは降りる。護符を持っていれば登る（深さ1から登れば脱出）。
  void descend() {
    if (over) return;
    if (lv.grid[p.y][p.x] != Tile.stairs) {
      final s = lv.stairs;
      if (s != null && lv.seen[s.$2][s.$1]) {
        travelTo(s.$1, s.$2);
      } else {
        msg('階段はまだ見つかっていない。行き止まりでは「探」で隠し扉を探そう');
        notifyListeners();
      }
      return;
    }
    if (hasAmulet) {
      _ascend();
      return;
    }
    if (depth >= maxDepth) {
      msg('ここが最深部だ。護符を探せ');
      notifyListeners();
      return;
    }
    if (!canGoDeeper) {
      stopRun();
      msg('階段の先は封印されている…（深さ${freeMaxDepth + 1}から先は製品版）');
      sealed = true;
      notifyListeners();
      return;
    }
    _enterLevel(depth + 1);
    msg('深さ $depth に降りた');
    if (depth == maxDepth) msg('空気が重い…この階のどこかに護符がある');
    notifyListeners();
  }

  void _ascend() {
    if (depth <= 1) {
      _win();
      notifyListeners();
      return;
    }
    _enterLevel(depth - 1);
    msg('深さ $depth まで戻ってきた');
    notifyListeners();
  }

  // ---------------------------------------------------------------- 持ち物
  /// 持ち物メニューの主な操作の名前。
  String? actionLabel(Item it) => switch (it.type) {
        ItemType.potion => '飲む',
        ItemType.scroll => '読む',
        ItemType.food => '食べる',
        ItemType.wand => '振る（方向を選ぶ）',
        ItemType.weapon => p.weapon == it ? '外す' : '装備する',
        ItemType.armor => p.armor == it ? '脱ぐ' : '着る',
        _ => null,
      };

  /// 鑑定できる（種類がまだ分かっていない）か。
  bool canIdentify(Item it) {
    final kind = it.potion ?? it.scroll ?? it.wand;
    return kind != null && !known.contains(kind);
  }

  /// 金貨を払って正体を知る。ターンは進まない。
  void identify(Item it) {
    if (over || !canIdentify(it)) return;
    if (p.gold < identifyCost) {
      msg('お金が足りない（鑑定には金$identifyCost枚必要）');
      notifyListeners();
      return;
    }
    p.gold -= identifyCost;
    known.add((it.potion ?? it.scroll ?? it.wand)!);
    msg('鑑定した: ${nameOf(it)}（金$identifyCost枚を支払った）');
    notifyListeners();
  }

  void use(Item it) {
    if (over) return;
    switch (it.type) {
      case ItemType.food:
        p.food = maxFood;
        p.inv.remove(it);
        msg('食料を食べた。満腹になった（腹100%）');
      case ItemType.weapon:
        if (p.weapon == it) {
          p.weapon = null;
          msg('${nameOf(it)}を外した');
        } else {
          p.weapon = it;
          msg('${nameOf(it)}を装備した');
        }
      case ItemType.armor:
        if (p.armor == it) {
          p.armor = null;
          msg('${nameOf(it)}を脱いだ');
        } else {
          p.armor = it;
          msg('${nameOf(it)}を着た');
        }
      case ItemType.potion:
        p.inv.remove(it);
        known.add(it.potion!);
        _quaff(it.potion!);
      case ItemType.scroll:
        p.inv.remove(it);
        known.add(it.scroll!);
        _read(it.scroll!);
      case ItemType.wand:
        startAim(it, zap: true);
        return;
      case ItemType.dart:
        startAim(it, zap: false);
        return;
      default:
        return;
    }
    _afterPlayerAction();
  }

  void _quaff(Potion k) {
    msg('これは${k.label}だった');
    switch (k) {
      case Potion.heal:
        if (p.hp >= p.maxHp) {
          p.maxHp++;
          p.hp = p.maxHp;
          msg('体が丈夫になった');
        } else {
          p.hp = min(p.maxHp, p.hp + rnd(8, 14));
          msg('体力が回復した');
        }
      case Potion.life:
        p.maxHp += 4;
        p.hp = p.maxHp;
        msg('生命力がみなぎる！最大HP+4');
      case Potion.strength:
        p.str++;
        msg('力が湧いてきた');
      case Potion.poison:
        p.str = max(3, p.str - 1);
        p.hp = max(1, p.hp - rnd(1, 4));
        msg('毒だ！力が落ちた');
      case Potion.sleep:
        msg('眠ってしまった…');
        p.asleep = max(p.asleep, 4);
    }
  }

  void _read(Scroll k) {
    msg('これは${k.label}だった');
    switch (k) {
      case Scroll.teleport:
        _teleportPlayer();
        msg('体が別の場所へ飛ばされた');
      case Scroll.map:
        // 隠し扉は壁のまま見える
        for (var y = 0; y < Level.height; y++) {
          for (var x = 0; x < Level.width; x++) {
            if (lv.grid[y][x] != Tile.rock) lv.seen[y][x] = true;
          }
        }
        msg('迷宮の地図が頭に浮かんだ');
      case Scroll.enchantArmor:
        if (p.armor != null) {
          p.armor!.ench++;
          msg('鎧が淡く光った');
        } else {
          msg('何も起こらなかった');
        }
      case Scroll.enchantWeapon:
        if (p.weapon != null) {
          p.weapon!.ench++;
          msg('武器が淡く光った');
        } else {
          msg('何も起こらなかった');
        }
    }
  }

  void drop(Item it) {
    if (over) return;
    if (lv.itemAt(p.x, p.y) != null || lv.grid[p.y][p.x] == Tile.stairs) {
      msg('ここには置けない');
      notifyListeners();
      return;
    }
    if (p.weapon == it) p.weapon = null;
    if (p.armor == it) p.armor = null;
    p.inv.remove(it);
    it
      ..x = p.x
      ..y = p.y;
    lv.items.add(it);
    msg('${nameOf(it)}を置いた');
    _afterPlayerAction();
  }

  // ---------------------------------------------------------------- 投げる・振る
  void startAim(Item it, {required bool zap}) {
    if (over) return;
    aim = Aim(it, zap);
    msg(zap ? 'どの方向に振る？（十字ボタン・マップをタップ／中央で取消）' : 'どの方向に投げる？（十字ボタン・マップをタップ／中央で取消）');
    notifyListeners();
  }

  void cancelAim() {
    aim = null;
    msg('やめた');
    notifyListeners();
  }

  void fireAim(int dx, int dy) {
    final a = aim;
    if (a == null || over || (dx == 0 && dy == 0)) return;
    aim = null;
    if (!p.inv.contains(a.item)) return;
    if (a.zap) {
      _zap(a.item, dx, dy);
    } else {
      _throw(a.item, dx, dy);
    }
    _afterPlayerAction();
  }

  /// (dx,dy) 方向にまっすぐ飛ばす。壁の手前か、最初の怪物で止まる。
  ((int, int), Monster?) _ray(int dx, int dy, int range) {
    var (x, y) = (p.x, p.y);
    for (var k = 0; k < range; k++) {
      if (!lv.walkable(x + dx, y + dy)) break;
      x += dx;
      y += dy;
      final m = lv.monsterAt(x, y);
      if (m != null) return ((x, y), m);
    }
    return ((x, y), null);
  }

  void _throw(Item it, int dx, int dy) {
    final Item obj;
    if (it.type == ItemType.dart && it.count > 1) {
      it.count--;
      obj = Item.darts(1);
    } else {
      p.inv.remove(it);
      if (p.weapon == it) p.weapon = null;
      if (p.armor == it) p.armor = null;
      obj = it;
    }
    final (at, m) = _ray(dx, dy, 8);
    msg('${nameOf(obj)}を投げた');

    if (obj.type == ItemType.potion) {
      if (m != null) {
        _potionHits(m, obj.potion!);
      } else {
        msg('薬瓶が割れて中身が飛び散った');
      }
      return;
    }
    if (m != null) {
      if (obj.type == ItemType.scroll || obj.type == ItemType.wand || obj.type == ItemType.food) {
        msg('${m.name}には当たったが、効果はない');
      } else {
        final (hit, d) = switch (obj.type) {
          ItemType.dart => (.85, rnd(1, 4)),
          ItemType.weapon => (.65, rnd(obj.lo + obj.ench, obj.hi + obj.ench)),
          _ => (.55, rnd(1, 2)),
        };
        if (chance(hit)) {
          _damage(m, d);
        } else {
          m.asleep = false;
          msg('外れた');
        }
      }
    }
    obj
      ..x = at.$1
      ..y = at.$2;
    lv.items.add(obj);
  }

  void _potionHits(Monster m, Potion k) {
    known.add(k);
    switch (k) {
      case Potion.sleep:
        m.deepSleep = rnd(10, 16);
        msg('${m.name}は眠りに落ちた！');
      case Potion.poison:
        msg('毒の薬を浴びた！');
        _damage(m, rnd(4, 9));
      case Potion.heal || Potion.life:
        m.hp += rnd(5, 10);
        msg('${m.name}の傷が癒えた…');
      default:
        msg('薬は効果がなかったようだ');
    }
  }

  void _zap(Item it, int dx, int dy) {
    if (it.charges <= 0) {
      msg('杖は何も起こらなかった…（空のようだ）');
      return;
    }
    it.charges--;
    final k = it.wand!;
    known.add(k);
    final (_, m) = _ray(dx, dy, 10);
    msg('${k.label}を振った');
    if (m == null) {
      msg('光は何もない場所へ消えた');
      return;
    }
    switch (k) {
      case Wand.sleep:
        m.deepSleep = rnd(15, 25);
        msg('${m.name}は深い眠りについた');
      case Wand.teleport:
        final pos = _randomCell();
        if (pos != null) {
          m
            ..x = pos.$1
            ..y = pos.$2;
        }
        msg('${m.name}は消え去った');
      case Wand.bolt:
        msg('魔弾が${m.name}を貫いた！');
        _damage(m, rnd(6, 12) + depth);
    }
  }

  // ---------------------------------------------------------------- 怪物の行動
  void _monstersAct() {
    final dist = lv.distanceFrom(p.x, p.y);
    for (final m in lv.monsters.toList()) {
      if (over) return;
      if (!m.alive) continue;
      if (m.deepSleep > 0) {
        m.deepSleep--;
        continue;
      }
      final d = dist[m.y][m.x];
      if (m.asleep) {
        if (d <= 3 && chance(.3)) {
          m.asleep = false;
        } else {
          continue;
        }
      }
      if (isAdjacent(m.x, m.y) && lv.canStep(m.x, m.y, p.x, p.y)) {
        _monsterAttack(m);
        continue;
      }
      if (m.has(Ability.stationary)) continue;

      bool free(int x, int y) =>
          lv.canStep(m.x, m.y, x, y) && lv.monsterAt(x, y) == null && (x, y) != (p.x, p.y);
      (int, int)? mv;
      if ((m.has(Ability.erratic) && chance(.5)) || d > 14) {
        if (d <= 14 || chance(.2)) {
          for (final (dx, dy) in shuffled(dirs8)) {
            if (free(m.x + dx, m.y + dy)) {
              mv = (m.x + dx, m.y + dy);
              break;
            }
          }
        }
      } else {
        var best = d;
        for (final (dx, dy) in shuffled(dirs8)) {
          final x = m.x + dx, y = m.y + dy;
          if (lv.inBounds(x, y) && free(x, y) && dist[y][x] < best) {
            best = dist[y][x];
            mv = (x, y);
          }
        }
      }
      if (mv != null) {
        m
          ..x = mv.$1
          ..y = mv.$2;
      }
    }
    lv.monsters.removeWhere((m) => !m.alive);
  }

  void _monsterAttack(Monster m) {
    if (!chance((.9 - .05 * p.armorValue).clamp(.3, .95))) {
      msg('${m.name}の攻撃をかわした');
      return;
    }
    final dmg = rnd(m.kind.lo, m.kind.hi);
    msg('${m.name}に$dmgダメージを受けた');
    _hurt(dmg, '${m.name}に倒された');
    if (over) return;
    if (m.has(Ability.sleepTouch) && chance(.5)) {
      p.asleep = max(p.asleep, rnd(3, 5));
      msg('花粉を吸って眠り込んだ！');
    }
    if (m.has(Ability.steal) && p.gold > 0 && chance(.7)) {
      final g = min(p.gold, rnd(15, 40) + depth * 5);
      p.gold -= g;
      m.loot += g;
      msg('${m.name}に金貨$g枚を盗まれた！（倒せば取り戻せる）');
      final pos = _randomCell();
      if (pos != null) {
        m
          ..x = pos.$1
          ..y = pos.$2;
      }
    }
  }

  void _hurt(int d, String cause) {
    p.hp -= d;
    if (p.hp <= 0) {
      p.hp = 0;
      _die(cause);
    }
  }

  // ---------------------------------------------------------------- 終了
  void _die(String cause) {
    over = true;
    stopRun();
    msg('力尽きた… $cause');
    scores?.submit(BestScore(score, depth, p.gold));
    end = EndInfo('GAME OVER', cause);
  }

  void _win() {
    over = true;
    stopRun();
    p.gold += 500;
    msg('地上に戻った！迷宮からの脱出に成功した！');
    scores?.submit(BestScore(score, depth, p.gold));
    end = const EndInfo('脱出成功！', '護符を持って地上へ生還した');
  }

  // ---------------------------------------------------------------- 走る・自動移動
  //
  // 「走る」は1歩ずつタイマーで進め、何か起きたら（怪物が見えた・ダメージを
  // 受けた・分かれ道に来た など）止まる。
  _Run? _run;
  Timer? _timer;

  bool get running => _run != null;

  void stopRun() {
    _run = null;
    _timer?.cancel();
    _timer = null;
  }

  void startRun(int dx, int dy) {
    stopRun();
    if (over) return;
    _run = _Run.dir(dx, dy);
    _tick();
  }

  void startRest() {
    stopRun();
    if (over) return;
    _run = _Run.rest(p.hp >= p.maxHp ? 10 : 300, p.hp < p.maxHp);
    _tick();
  }

  /// 見えている場所まで自動で歩く。
  void travelTo(int tx, int ty) {
    stopRun();
    if (over || (tx == p.x && ty == p.y)) return;
    final prev = List.generate(Level.height, (_) => List<(int, int)?>.filled(Level.width, null));
    prev[p.y][p.x] = (-1, -1);
    final q = [(p.x, p.y)];
    for (var i = 0; i < q.length && prev[ty][tx] == null; i++) {
      final (x, y) = q[i];
      for (final (dx, dy) in dirs8) {
        final nx = x + dx, ny = y + dy;
        if (!lv.inBounds(nx, ny) || prev[ny][nx] != null || !lv.seen[ny][nx]) continue;
        if (!lv.canStep(x, y, nx, ny)) continue;
        if (_foundTrap(nx, ny) && (nx, ny) != (tx, ty)) continue; // 見つけた罠は避ける
        prev[ny][nx] = (x, y);
        q.add((nx, ny));
      }
    }
    if (prev[ty][tx] == null) {
      msg('そこへは行けない');
      notifyListeners();
      return;
    }
    final path = <(int, int)>[];
    var c = (tx, ty);
    while (c != (p.x, p.y)) {
      path.insert(0, c);
      c = prev[c.$2][c.$1]!;
    }
    _run = _Run.path(path);
    _tick();
  }

  bool _foundTrap(int x, int y) => lv.traps[(x, y)]?.found ?? false;

  Set<int> _visibleIds() => {
        for (final m in lv.monsters)
          if (isVisible(m)) m.id
      };

  /// まわり8マスの「気になるもの」（扉・階段・アイテム・見つけた罠）。
  Set<(int, int)> _interesting() {
    final s = <(int, int)>{};
    for (final (dx, dy) in dirs8) {
      final x = p.x + dx, y = p.y + dy;
      if (!lv.inBounds(x, y)) continue;
      final g = lv.grid[y][x];
      if (g == Tile.door || g == Tile.stairs || lv.itemAt(x, y) != null || _foundTrap(x, y)) {
        s.add((x, y));
      }
    }
    return s;
  }

  void _tick() {
    final run = _run;
    if (run == null || over) return;
    final hp0 = p.hp, msgs0 = msgCount, vis0 = _visibleIds(), sig0 = _interesting();
    var ok = true;
    switch (run.type) {
      case _RunType.rest:
        rest();
        run.n++;
        if (run.n >= run.limit || (run.untilHealed && p.hp >= p.maxHp)) ok = false;
      case _RunType.path:
        final (nx, ny) = run.path.removeAt(0);
        ok = move(nx - p.x, ny - p.y) && run.path.isNotEmpty;
      case _RunType.dir:
        ok = move(run.dx, run.dy);
        if (!ok) break;
        final g = lv.grid[p.y][p.x];
        if (g == Tile.door || g == Tile.stairs) {
          ok = false;
        } else if (g == Tile.corridor) {
          // 通路は曲がり角に沿って進む。分かれ道なら止まる
          if (run.dx != 0 && run.dy != 0) {
            ok = false;
          } else {
            final cand = [
              for (final (dx, dy) in const [(0, -1), (0, 1), (-1, 0), (1, 0)])
                if (!(dx == -run.dx && dy == -run.dy) && lv.canStep(p.x, p.y, p.x + dx, p.y + dy))
                  (dx, dy)
            ];
            if (cand.length == 1) {
              run
                ..dx = cand.first.$1
                ..dy = cand.first.$2;
            } else {
              ok = false;
            }
          }
        } else if (!lv.canStep(p.x, p.y, p.x + run.dx, p.y + run.dy) ||
            _foundTrap(p.x + run.dx, p.y + run.dy)) {
          ok = false;
        } else if (!sig0.containsAll(_interesting())) {
          ok = false;
        }
    }
    if (ok) {
      if (p.hp < hp0 || msgCount > msgs0) ok = false;
      for (final m in lv.monsters) {
        if (isVisible(m) && (m.awake || !vis0.contains(m.id))) ok = false;
      }
    }
    if (!ok) {
      stopRun();
      return;
    }
    _timer = Timer(const Duration(milliseconds: 45), _tick);
  }

  @override
  void dispose() {
    stopRun();
    super.dispose();
  }
}

enum _RunType { dir, rest, path }

class _Run {
  _Run.dir(this.dx, this.dy)
      : type = _RunType.dir,
        limit = 0,
        untilHealed = false,
        path = [];
  _Run.rest(this.limit, this.untilHealed)
      : type = _RunType.rest,
        dx = 0,
        dy = 0,
        path = [];
  _Run.path(this.path)
      : type = _RunType.path,
        dx = 0,
        dy = 0,
        limit = 0,
        untilHealed = false;

  final _RunType type;
  int dx, dy;
  int n = 0;
  final int limit;
  final bool untilHealed;
  final List<(int, int)> path;
}
