// メイン画面。上からメッセージ・マップ・ステータス・操作ボタン。
// 持ち物や説明は、画面全体を覆う「パネル」として重ねて表示する。
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../game/game.dart';
import '../game/models.dart';
import '../game/util.dart';
import '../purchases.dart';
import '../storage.dart';
import 'controls.dart';
import 'map_view.dart';

enum _Panel { inventory, item, log, help, end, store }

class GameScreen extends StatefulWidget {
  const GameScreen({super.key, required this.scores, required this.purchases});

  final PrefsScoreBook scores;
  final Purchases purchases;

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late final Game game = Game(widget.scores, () => widget.purchases.fullUnlocked);
  _Panel? _panel;
  bool _sealedStore = false; // 購入画面を「深さ3の階段」から開いた
  Item? _selected;
  bool _runMode = false; // 「走」ボタン
  Timer? _endTimer;
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    game.addListener(_onGameChanged);
  }

  @override
  void dispose() {
    _endTimer?.cancel();
    game.removeListener(_onGameChanged);
    game.dispose();
    _focus.dispose();
    super.dispose();
  }

  /// ゲームが終わったら、最後の画面を少し見せてから結果を出す。
  void _onGameChanged() {
    if (game.sealed) {
      game.sealed = false;
      _openStore(sealed: true);
    }
    if (game.end != null && _panel != _Panel.end && _endTimer == null) {
      _endTimer = Timer(const Duration(milliseconds: 500), () {
        if (mounted) setState(() => _panel = _Panel.end);
      });
    }
  }

  void _open(_Panel p) {
    game.stopRun();
    setState(() => _panel = p);
  }

  void _close() => setState(() => _panel = null);

  void _openStore({bool sealed = false}) {
    _sealedStore = sealed;
    widget.purchases.message = null;
    _open(_Panel.store);
    widget.purchases.loadProducts().catchError((Object _) {});
  }

  bool get _blocked => game.over || _panel != null;

  // ------------------------------------------------------------ 入力
  void _dir(int dx, int dy) {
    if (_blocked) return;
    game.stopRun();
    if (game.aim != null) {
      game.fireAim(dx, dy);
    } else if (_runMode) {
      game.startRun(dx, dy);
    } else {
      game.move(dx, dy);
    }
  }

  void _dirHold(int dx, int dy) {
    if (_blocked || game.aim != null) return;
    game.startRun(dx, dy);
  }

  void _center() {
    if (_blocked) return;
    game.stopRun();
    if (game.aim != null) {
      game.cancelAim();
    } else {
      game.rest();
    }
  }

  void _tapCell(int x, int y) {
    if (_blocked) return;
    game.stopRun();
    final dx = x - game.p.x, dy = y - game.p.y;
    if (game.aim != null) {
      // タップした方向へ（ななめは8方向に丸める）
      if (dx != 0 || dy != 0) game.fireAim(_round(dx, dy).$1, _round(dx, dy).$2);
      return;
    }
    if (dx == 0 && dy == 0) {
      game.rest();
    } else if (dx.abs() <= 1 && dy.abs() <= 1) {
      game.move(dx, dy);
    } else {
      game.travelTo(x, y);
    }
  }

  (int, int) _round(int dx, int dy) {
    final ax = dx.abs(), ay = dy.abs();
    if (ax > ay * 2) return (dx.sign, 0);
    if (ay > ax * 2) return (0, dy.sign);
    return (dx.sign, dy.sign);
  }

  KeyEventResult _onKey(FocusNode _, KeyEvent e) {
    if (e is! KeyDownEvent && e is! KeyRepeatEvent) return KeyEventResult.ignored;
    final k = e.logicalKey;
    if (k == LogicalKeyboardKey.escape) {
      if (_panel != null && !game.over) _close();
      if (game.aim != null) game.cancelAim();
      return KeyEventResult.handled;
    }
    if (_blocked) return KeyEventResult.ignored;
    const dirs = {
      'h': (-1, 0), 'j': (0, 1), 'k': (0, -1), 'l': (1, 0),
      'y': (-1, -1), 'u': (1, -1), 'b': (-1, 1), 'n': (1, 1),
    };
    final arrows = {
      LogicalKeyboardKey.arrowLeft: (-1, 0),
      LogicalKeyboardKey.arrowRight: (1, 0),
      LogicalKeyboardKey.arrowUp: (0, -1),
      LogicalKeyboardKey.arrowDown: (0, 1),
    };
    final ch = e.character;
    final shift = HardwareKeyboard.instance.isShiftPressed;
    final d = arrows[k] ?? (ch == null ? null : dirs[ch.toLowerCase()]);
    if (d != null) {
      if (shift && game.aim == null) {
        game.startRun(d.$1, d.$2);
      } else {
        _dir(d.$1, d.$2);
      }
      return KeyEventResult.handled;
    }
    switch (ch) {
      case '.' || 's':
        _center();
      case 'Z':
        game.startRest();
      case '>' || '<':
        game.descend();
      case 'i':
        _open(_Panel.inventory);
      case '?':
        _open(_Panel.help);
      default:
        return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  // ------------------------------------------------------------ 戻るボタン
  Future<void> _onBack() async {
    if (_panel != null && !(game.over && _panel == _Panel.end)) {
      _close();
      return;
    }
    if (game.aim != null) {
      game.cancelAim();
      return;
    }
    game.stopRun();
    final quit = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: const Color(0xFF111111),
        title: const Text('ゲームを終了しますか？'),
        content: const Text('進行中の冒険は保存されません。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('キャンセル')),
          TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('終了')),
        ],
      ),
    );
    if (quit == true) await SystemNavigator.pop();
  }

  // ------------------------------------------------------------ 画面
  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _onBack();
      },
      child: Focus(
        focusNode: _focus,
        autofocus: true,
        onKeyEvent: _onKey,
        child: Scaffold(
          body: SafeArea(
            child: ListenableBuilder(
              listenable: Listenable.merge([game, widget.purchases]),
              builder: (context, _) => Stack(children: [
                Column(children: [
                  _messages(),
                  Expanded(child: MapView(game: game, onTapCell: _tapCell)),
                  _status(),
                  _controls(),
                ]),
                if (_panel != null) Positioned.fill(child: _panelView()),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  Widget _messages() {
    final last = game.log.length > 3 ? game.log.sublist(game.log.length - 3) : game.log;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _open(_Panel.log),
      child: Container(
        width: double.infinity,
        height: 64,
        padding: const EdgeInsets.fromLTRB(8, 6, 8, 2),
        child: Text.rich(
          TextSpan(children: [
            for (final (i, t) in last.indexed)
              TextSpan(
                text: i == last.length - 1 ? t : '$t\n',
                style: TextStyle(color: i == last.length - 1 ? const Color(0xFFEEEEEE) : const Color(0xFF777777)),
              ),
          ]),
          style: const TextStyle(fontSize: 14, height: 1.3),
          overflow: TextOverflow.clip,
        ),
      ),
    );
  }

  Widget _status() {
    final p = game.p;
    final full = p.fullness;
    final hunger = p.food > 300 ? '' : p.food > 150 ? ' 空腹' : p.food > 50 ? ' 衰弱' : ' 瀕死';
    final cond = [
      if (p.confused > 0) '混乱',
      if (p.heldBy != null) '捕縛',
      if (p.detect) '千里眼',
      if (game.hasAmulet) '護符',
    ].join(' ');
    final style = TextStyle(fontFamily: monoFamily, fontSize: 13, color: const Color(0xFFCFCFCF));
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(8, 2, 8, 6),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('深${game.depth}  HP${p.hp}/${p.maxHp}  力${p.str}  防${p.armorValue}  Lv${p.level}(${p.xp})',
            style: style, maxLines: 1, overflow: TextOverflow.clip),
        Text.rich(
          TextSpan(children: [
            TextSpan(text: '金${p.gold}  '),
            TextSpan(
              text: '満腹度$full%$hunger',
              style: TextStyle(color: p.food > 300 ? null : const Color(0xFFFFB070)),
            ),
            if (cond.isNotEmpty) TextSpan(text: '  $cond', style: const TextStyle(color: Color(0xFFFFCF7A))),
          ]),
          style: style,
          maxLines: 1,
        ),
      ]),
    );
  }

  Widget _controls() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 4, 10, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          DPad(
            aiming: game.aim != null,
            onDir: _dir,
            onDirHold: _dirHold,
            onCenter: _center,
            onCenterHold: () {
              if (!_blocked && game.aim == null) game.startRest();
            },
          ),
          SizedBox(
            width: 150,
            child: GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 6,
              crossAxisSpacing: 6,
              childAspectRatio: 72 / 58,
              children: [
                PadButton(
                  label: '走',
                  fontSize: 16,
                  on: _runMode,
                  onDown: () => setState(() => _runMode = !_runMode),
                ),
                PadButton(
                  label: '持物',
                  fontSize: 16,
                  onDown: () {
                    if (!game.over) _open(_Panel.inventory);
                  },
                ),
                PadButton(
                  label: '階段',
                  fontSize: 16,
                  onDown: () {
                    if (!_blocked) game.descend();
                  },
                ),
                PadButton(label: '？', fontSize: 16, onDown: () => _open(_Panel.help)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------ パネル
  Widget _panelView() {
    final children = switch (_panel!) {
      _Panel.inventory => _inventory(),
      _Panel.item => _itemMenu(_selected!),
      _Panel.log => [
          _title('メッセージ履歴'),
          _pre(game.log.length > 60 ? game.log.sublist(game.log.length - 60).join('\n') : game.log.join('\n')),
          _button('閉じる', _close),
        ],
      _Panel.help => [
          _title('あそびかた'),
          _pre(_helpText),
          _button('深部解放・購入の復元・応援', _openStore),
          _button('閉じる', _close),
        ],
      _Panel.end => _endScreen(),
      _Panel.store => _store(),
    };
    return ColoredBox(
      color: Colors.black,
      child: ListView(padding: const EdgeInsets.fromLTRB(14, 12, 14, 14), children: children),
    );
  }

  List<Widget> _inventory() {
    final p = game.p;
    return [
      _title('持ち物（タップで選択）'),
      if (p.inv.isEmpty) const Text('何も持っていない', style: TextStyle(color: Color(0xFF888888))),
      for (final (i, it) in p.inv.indexed)
        _button('${letter(i)}) ${game.nameOf(it)}${p.weapon == it || p.armor == it ? ' [装備中]' : ''}', () {
          setState(() {
            _selected = it;
            _panel = _Panel.item;
          });
        }),
      _button('閉じる', _close),
    ];
  }

  List<Widget> _itemMenu(Item it) {
    final label = game.actionLabel(it);
    void act(void Function() f) {
      _close();
      f();
    }

    return [
      _title('${letter(game.p.inv.indexOf(it))}) ${game.nameOf(it)}'),
      if (label != null) _button(label, () => act(() => game.use(it))),
      _button('投げる', () => act(() => game.startAim(it, zap: false))),
      _button('置く', () => act(() => game.drop(it))),
      _button('戻る', () => setState(() => _panel = _Panel.inventory)),
    ];
  }

  List<Widget> _endScreen() {
    final p = game.p, e = game.end!, b = widget.scores.best;
    return [
      _title(e.title),
      _pre('${e.cause}\n\n到達した深さ: ${game.deepest}\n所持金: ${p.gold}\nレベル: ${p.level}\n'
          '経過ターン: ${p.turns}\nスコア: ${game.score}'
          '${b == null ? '' : '\nベスト: ${b.score} (深さ${b.depth})'}'),
      _button('もう一度挑戦する', () {
        _endTimer = null;
        _close();
        game.newGame();
      }),
      _button('最後の画面を見る', _close),
    ];
  }

  List<Widget> _store() {
    final pur = widget.purchases;
    String price(String id, [String fallback = '']) {
      final p = pur.products[id]?.price;
      return p == null ? fallback : '（$p）';
    }

    void Function()? ifIdle(void Function() f) => pur.busy ? null : f;
    const note = TextStyle(fontSize: 13, color: Color(0xFF999999), height: 1.4);
    return [
      _title(_sealedStore && !pur.fullUnlocked ? 'ここから先は製品版で' : '深部解放・購入の復元'),
      if (pur.fullUnlocked)
        _pre('「深部解放」購入済み。\n深さ${Game.maxDepth}まで潜り、迷宮の護符を持ち帰る旅に挑めます。')
      else ...[
        _pre('無料版で遊べるのは深さ${Game.freeMaxDepth}まで。\n'
            '「深部解放」を購入すると、深さ${Game.freeMaxDepth + 1}〜${Game.maxDepth}と\n迷宮の護符の持ち帰りに挑めます。\n'
            '買い切りです（一度の購入でずっと使えます）。'),
        _button('「深部解放」を購入する${price(ProductIds.fullUnlock)}', ifIdle(() => pur.buy(ProductIds.fullUnlock))),
      ],
      if (_sealedStore && pur.fullUnlocked && !game.over)
        _button('階段を降りる', () {
          _close();
          game.descend();
        }),
      _button('購入を復元', ifIdle(pur.restore)),
      if (pur.busy) const Padding(padding: EdgeInsets.only(bottom: 8), child: LinearProgressIndicator(minHeight: 2)),
      if (pur.message case final m?)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Text(m, style: const TextStyle(fontSize: 14, color: Color(0xFFFFCF7A))),
        ),
      if (!pur.storeAvailable)
        const Padding(
          padding: EdgeInsets.only(bottom: 10),
          child: Text('ストアに接続できません。通信環境を確認してください。', style: note),
        ),
      const SizedBox(height: 14),
      _title('開発者を応援'),
      const Padding(
        padding: EdgeInsets.only(bottom: 8),
        child: Text('※応援の購入で、ゲームの内容や機能は変わりません。「深部解放」も含まれません。\n'
            '気に入っていただけたら、開発を続ける励みになります。', style: note),
      ),
      if (pur.tipped)
        const Padding(
          padding: EdgeInsets.only(bottom: 8),
          child: Text('応援ありがとうございます！', style: TextStyle(fontSize: 14, color: Color(0xFFFFCF7A))),
        ),
      _button('応援する${price(ProductIds.tip120, '（120円）')}', ifIdle(() => pur.buy(ProductIds.tip120))),
      _button('応援する${price(ProductIds.tip360, '（360円）')}', ifIdle(() => pur.buy(ProductIds.tip360))),
      _button('応援する${price(ProductIds.tip1000, '（1000円）')}', ifIdle(() => pur.buy(ProductIds.tip1000))),
      const SizedBox(height: 8),
      const Padding(
        padding: EdgeInsets.only(bottom: 8),
        child: Text('購入の処理は App Store / Google Play が行います。このアプリが通信するのは購入と復元のときだけです。',
            style: note),
      ),
      _button(_sealedStore && !pur.fullUnlocked ? '閉じる（深さ${Game.freeMaxDepth}の探索を続ける）' : '閉じる', _close),
    ];
  }

  Widget _title(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(t, style: const TextStyle(fontSize: 16, color: Colors.white)),
      );

  Widget _pre(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(t, style: TextStyle(fontFamily: monoFamily, fontSize: 14, height: 1.5)),
      );

  Widget _button(String label, VoidCallback? onTap) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: OutlinedButton(
          style: OutlinedButton.styleFrom(
            alignment: Alignment.centerLeft,
            minimumSize: const Size.fromHeight(46),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            foregroundColor: const Color(0xFFDDDDDD),
            side: const BorderSide(color: Color(0xFF555555)),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          onPressed: onTap,
          child: Text(label, style: const TextStyle(fontSize: 16)),
        ),
      );
}

const _helpText = '''目的: 深さ${Game.maxDepth}まで降りて護符(,)を手に入れ、地上へ持ち帰る。
護符を持つと階段(%)は上りになる。深さ1の階段を登れば脱出。
登るたびに階は新しく作り直される。死ぬと最初から。

【無料版と深部解放】
深さ${Game.freeMaxDepth}までは無料で遊べる。
「深部解放」（買い切り）を購入すると、深さ${Game.freeMaxDepth + 1}より先と護符に挑める。
機種変更や再インストールのあとは、下の画面の「購入を復元」で戻せる。

@ 自分     . 床      | - 壁
# 通路     + 扉      % 階段
^ 罠       * 金貨    ! 薬
? 巻物     / 杖      ) 武器・投げ矢
] 防具     : 食料    A-Z 怪物

【満腹度】
1歩ごとに減っていく。0%になると餓死する。
15%を切ると「空腹」、減りすぎると体力が回復しなくなる。
食料(:)を食べると100%に戻る。食料は見つけたら拾っておこう。

【投げる・振る】
持物から「投げる」を選び、方向を十字ボタン（またはマップをタップ）で決める。
投げ矢や短剣は投げるとよく当たる。薬を怪物に投げると、その効き目が怪物に出る（眠りの薬なら眠らせる）。
杖は「振る」で、最初に当たった怪物に効く。

【隠し扉と罠】
深い階では、扉が壁に隠れていることがある。行き止まりや出口のない部屋では、壁の近くで[休]を長押しすると調べられる。
床には見えない罠(^)がある。落とし穴、眠りガス、毒矢、転移。一度見つけた罠は自動移動で避ける。

【怪物の特技】
眠らせる・凍らせる・混乱させる・捕まえる・金貨や持ち物を盗む・鎧を錆びさせる・レベルを吸う・矢を射る・炎を吐く・アイテムに化ける・姿が見えない、などがいる。

【操作】
・十字ボタン: 1歩進む（怪物へ動くと攻撃）
・十字ボタンを長押し: その方向へ「何かあるまで」走る
・[走]ボタンON: 十字ボタンのタップで走る
・マップをタップ: 見えている場所まで自動移動
・中央[休]: 1ターン休む（まわりを調べる）／長押し: 回復まで休む
・[階段]: 階段の上なら降りる（護符を持っていれば登る）。見えていれば階段まで自動移動
・[持物]: 使う・装備・投げる・置く
・上のメッセージ欄をタップ: 履歴

【キーボード】
hjklyubn/矢印: 移動  Shift+移動: 走る
. : 休む  Z : 回復まで休む  > < : 階段  i : 持物  Esc : 取消''';
