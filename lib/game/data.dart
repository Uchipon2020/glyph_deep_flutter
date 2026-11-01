// 怪物・アイテム・罠の定義表。数値の調整はここだけで済むようにしてある。

/// 怪物の特殊能力。1体が複数持つこともある。
enum Ability {
  erratic, // ふらふら動く
  stationary, // その場から動かない
  sleepTouch, // 攻撃が当たると眠らせることがある
  steal, // 金貨を盗んで逃げる（倒せば取り戻せる）
}

class MonsterKind {
  const MonsterKind(this.ch, this.name, this.hp, this.lo, this.hi, this.xp,
      this.minDepth, this.maxDepth,
      [this.abilities = const {}]);

  final String ch;
  final String name;
  final int hp;
  final int lo, hi; // 攻撃力の幅
  final int xp;
  final int minDepth, maxDepth; // 出現する深さ
  final Set<Ability> abilities;
}

/// 13種類。浅い階ほど弱い怪物が出る。
const monsterKinds = [
  MonsterKind('E', 'エミュー', 4, 1, 2, 2, 1, 3),
  MonsterKind('B', 'コウモリ', 5, 1, 3, 3, 1, 4, {Ability.erratic}),
  MonsterKind('S', 'ヘビ', 8, 1, 3, 5, 2, 5),
  MonsterKind('F', '眠り花', 10, 1, 2, 9, 2, 7, {Ability.stationary, Ability.sleepTouch}),
  MonsterKind('H', 'ホブゴブリン', 12, 1, 5, 8, 3, 6),
  MonsterKind('L', '泥棒', 10, 1, 3, 14, 3, 9, {Ability.steal}),
  MonsterKind('O', 'オーク', 16, 2, 6, 12, 4, 8),
  MonsterKind('Z', 'ゾンビ', 22, 2, 7, 18, 5, 9),
  MonsterKind('Y', 'イエティ', 28, 3, 8, 26, 6, 10),
  MonsterKind('T', 'トロル', 38, 4, 10, 40, 7, 10),
  MonsterKind('W', 'レイス', 45, 5, 11, 55, 8, 10),
  MonsterKind('V', 'ヴァンパイア', 55, 6, 13, 75, 9, 10),
  MonsterKind('D', 'ドラゴン', 75, 8, 18, 120, 10, 10),
];

/// 薬。weight は出やすさ。
enum Potion {
  heal('回復の薬', 4),
  life('生命の薬', 1),
  strength('力の薬', 2),
  poison('毒の薬', 2),
  sleep('眠りの薬', 2);

  const Potion(this.label, this.weight);
  final String label;
  final int weight;
}

enum Scroll {
  teleport('瞬間移動の巻物', 2),
  map('地図の巻物', 2),
  enchantArmor('防具強化の巻物', 2),
  enchantWeapon('武器強化の巻物', 2);

  const Scroll(this.label, this.weight);
  final String label;
  final int weight;
}

/// 杖。向きを決めて振ると、最初に当たった怪物に効く。
enum Wand {
  sleep('眠りの杖', 3),
  teleport('転送の杖', 2),
  bolt('魔弾の杖', 3);

  const Wand(this.label, this.weight);
  final String label;
  final int weight;
}

enum TrapKind {
  pit('落とし穴'),
  sleepGas('眠りガス'),
  arrow('矢'),
  dart('毒針'),
  alarm('警報'),
  teleport('転送');

  const TrapKind(this.label);
  final String label;
}

/// (名前, 最小, 最大)
const weaponTable = [('短剣', 2, 4), ('長剣', 3, 8), ('戦斧', 4, 10), ('大剣', 6, 13)];

/// (名前, 防御値)
const armorTable = [('革鎧', 3), ('鎖帷子', 5), ('板金鎧', 7), ('全身鎧', 9)];

/// レベルアップに必要な経験値。
const xpNeeded = [10, 20, 40, 80, 160, 320, 640, 1280, 2560, 5120, 10240];

const potionColors = ['赤', '青', '緑', '黄', '紫', '白', '黒', '橙', '茶', '桃'];
const scrollSyllables = ['zug', 'rok', 'fim', 'xel', 'tob', 'nar', 'kel', 'vus', 'ple', 'dro', 'mim', 'saq'];
const wandMaterials = ['木', '鉄', '銀', '骨', '石'];

/// 満腹度の上限。1ターンに1ずつ減る。
const maxFood = 2000;

/// 未鑑定の薬・巻物・杖を鑑定する料金（金貨）。
const identifyCost = 25;
