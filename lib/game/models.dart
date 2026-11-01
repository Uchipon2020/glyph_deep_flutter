// ゲームに登場する「もの」のクラス: 地形・アイテム・怪物・プレイヤー・罠。
import 'data.dart';

/// 地形。glyph は画面に表示する文字。
enum Tile {
  rock(' '),
  floor('.'),
  wallH('-'),
  wallV('|'),
  corridor('#'),
  door('+'),
  secretDoorH('-'), // 隠し扉（見つかるまでは壁に見える）
  secretDoorV('|'),
  stairs('%');

  const Tile(this.glyph);
  final String glyph;

  bool get walkable =>
      this == floor || this == corridor || this == door || this == stairs;
  bool get isSecret => this == secretDoorH || this == secretDoorV;
}

enum ItemType { food, potion, scroll, wand, weapon, armor, dart, gold, amulet }

class Item {
  Item._(this.type);

  Item.food() : this._(ItemType.food);
  Item.gold(this.amount) : type = ItemType.gold;
  Item.amulet() : this._(ItemType.amulet);
  Item.potion(this.potion) : type = ItemType.potion;
  Item.scroll(this.scroll) : type = ItemType.scroll;
  Item.wand(this.wand, this.charges) : type = ItemType.wand;
  Item.darts(this.count) : type = ItemType.dart;
  Item.weapon(this.name, this.lo, this.hi, {this.ench = 0}) : type = ItemType.weapon;
  Item.armor(this.name, this.value, {this.ench = 0}) : type = ItemType.armor;

  final ItemType type;
  Potion? potion;
  Scroll? scroll;
  Wand? wand;
  String name = '';
  int lo = 0, hi = 0; // 武器の威力
  int value = 0; // 鎧の防御値
  int ench = 0; // 強化値 (+1 など)
  int charges = 0; // 杖の残り回数
  int amount = 0; // 金貨の枚数
  int count = 1; // 投げ矢の本数

  // 床に落ちているときの位置
  int x = -1, y = -1;

  /// 画面上の記号。
  String get glyph => switch (type) {
        ItemType.gold => '*',
        ItemType.potion => '!',
        ItemType.scroll => '?',
        ItemType.weapon || ItemType.dart => ')',
        ItemType.armor => ']',
        ItemType.food => ':',
        ItemType.wand => '/',
        ItemType.amulet => ',',
      };
}

class Monster {
  Monster(this.id, this.kind, this.hp, this.x, this.y);

  final int id;
  final MonsterKind kind;
  int hp;
  int x, y;
  bool asleep = false; // 自然な眠り（近づくと起きることがある）
  int deepSleep = 0; // 魔法の眠り。0 になるまで起きない
  int loot = 0; // 盗んだ金貨。倒すと落とす

  String get name => kind.name;
  bool has(Ability a) => kind.abilities.contains(a);
  bool get alive => hp > 0;
  bool get awake => !asleep && deepSleep <= 0;
}

class Trap {
  Trap(this.kind);
  final TrapKind kind;
  bool found = false;
}

class Player {
  int x = 0, y = 0;
  int hp = 16, maxHp = 16;
  int str = 16;
  int level = 1, xp = 0;
  int gold = 0;
  int food = 1800;
  int turns = 0;
  final inv = <Item>[];
  Item? weapon, armor;

  int asleep = 0; // 眠りで動けない残りターン
  (int, int)? armed; // 罠の警告を出したマス。もう一度動くと踏む

  int get armorValue => armor == null ? 0 : armor!.value + armor!.ench;

  /// 満腹度（%）。
  int get fullness => (food * 100 / maxFood).round().clamp(0, 100);
}
