// 怪物・アイテム・罠の定義表。数値の調整はここだけで済むようにしてある。

/// 怪物の特殊能力。1体が複数持つこともある。
enum Ability {
  erratic, // ふらふら動く
  fast, // 1ターンに2回動く
  slow, // 2ターンに1回しか動かない
  stationary, // その場から動かない
  regen, // 体力が自然回復する
  invisible, // 姿が見えない
  mimic, // アイテムに化けている
  ranged, // 離れたところから矢を射る
  breath, // 離れたところから炎を吐く
  steal, // 金貨を盗んで逃げる（倒せば取り戻せる）
  stealGold, // 金貨を盗んで消える
  stealItem, // 持ち物を盗んで消える
  rust, // 鎧を錆びさせる
  hold, // 捕まえて逃がさない
  freeze, // 凍らせて動けなくする
  sleep, // 眠りの鱗粉で眠らせる
  sleepTouch, // 花粉で眠らせる
  confuse, // 混乱させる
  drainStr, // 力を奪う
  drainLevel, // レベルを奪う
  drainMax, // 最大HPを奪う
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

/// A〜Z の28種類（F と L は2種類ずつ）。浅い階ほど弱い怪物が出る。
const monsterKinds = [
  MonsterKind('E', 'エミュー', 4, 1, 2, 2, 1, 3),
  MonsterKind('K', 'ケストレル', 3, 1, 3, 2, 1, 3, {Ability.erratic}),
  MonsterKind('B', 'コウモリ', 5, 1, 3, 3, 1, 4, {Ability.erratic}),
  MonsterKind('S', 'ヘビ', 8, 1, 3, 5, 2, 5),
  MonsterKind('F', '眠り花', 10, 1, 2, 9, 2, 7, {Ability.stationary, Ability.sleepTouch}),
  MonsterKind('L', 'レプラコーン', 10, 1, 2, 10, 2, 6, {Ability.stealGold}),
  MonsterKind('I', '氷の怪物', 10, 1, 2, 10, 2, 6, {Ability.freeze}),
  MonsterKind('H', 'ホブゴブリン', 12, 1, 5, 8, 3, 6),
  MonsterKind('L', '泥棒', 10, 1, 3, 14, 3, 9, {Ability.steal}),
  MonsterKind('R', 'ガラガラヘビ', 11, 1, 4, 10, 3, 6, {Ability.drainStr}),
  MonsterKind('Q', '眠り蛾', 9, 1, 2, 12, 3, 8, {Ability.sleep, Ability.erratic}),
  MonsterKind('F', 'ハエトリソウ', 14, 1, 4, 12, 3, 7, {Ability.hold, Ability.stationary}),
  MonsterKind('A', 'アクエイター', 18, 1, 3, 15, 3, 7, {Ability.rust}),
  MonsterKind('O', 'オーク', 16, 2, 6, 12, 4, 8),
  MonsterKind('Z', 'ゾンビ', 22, 2, 7, 18, 5, 9, {Ability.slow}),
  MonsterKind('N', 'ニンフ', 14, 1, 1, 20, 4, 9, {Ability.stealItem}),
  MonsterKind('C', 'ケンタウロス', 25, 2, 6, 25, 5, 9, {Ability.ranged}),
  MonsterKind('X', 'ゼロック', 30, 3, 9, 30, 5, 10, {Ability.mimic}),
  MonsterKind('Y', 'イエティ', 28, 3, 8, 26, 6, 10),
  MonsterKind('M', 'メデューサ', 32, 3, 8, 35, 6, 10, {Ability.confuse}),
  MonsterKind('P', 'ファントム', 30, 3, 9, 40, 6, 10, {Ability.invisible}),
  MonsterKind('G', 'グリフォン', 36, 4, 10, 45, 6, 10, {Ability.fast}),
  MonsterKind('T', 'トロル', 38, 4, 10, 40, 7, 10, {Ability.regen}),
  MonsterKind('U', 'ユニコーン', 45, 5, 12, 60, 7, 10),
  MonsterKind('W', 'レイス', 45, 5, 11, 55, 8, 10, {Ability.drainLevel}),
  MonsterKind('J', 'ジャバウォック', 60, 6, 14, 90, 8, 10),
  MonsterKind('V', 'ヴァンパイア', 55, 6, 13, 75, 9, 10, {Ability.drainMax, Ability.regen}),
  MonsterKind('D', 'ドラゴン', 75, 8, 18, 120, 10, 10, {Ability.breath}),
];

/// 薬。weight は出やすさ。
enum Potion {
  heal('回復の薬', 4),
  life('生命の薬', 1),
  strength('力の薬', 2),
  detect('千里眼の薬', 2),
  poison('毒の薬', 2),
  sleep('眠りの薬', 2),
  confuse('混乱の薬', 2);

  const Potion(this.label, this.weight);
  final String label;
  final int weight;
}

enum Scroll {
  teleport('瞬間移動の巻物', 2),
  map('地図の巻物', 2),
  enchantArmor('防具強化の巻物', 2),
  enchantWeapon('武器強化の巻物', 2),
  identify('識別の巻物', 2),
  sleepMonsters('眠りの霧の巻物', 2),
  wake('大声の巻物', 1);

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
