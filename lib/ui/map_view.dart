// マップの描画。42×21 のマス目に1文字ずつ描く。
//
// 文字の幅はフォントによって違うので、1文字ずつ「マスの中央」に置いて描く。
// こうするとタップ位置からマスの座標を割り出すのも簡単になる。
import 'dart:io' show Platform;

import 'package:flutter/material.dart';

import '../game/dungeon.dart';
import '../game/game.dart';
import '../game/models.dart';

final monoFamily = Platform.isIOS ? 'Menlo' : 'monospace';

class MapView extends StatefulWidget {
  const MapView({super.key, required this.game, required this.onTapCell});

  final Game game;
  final void Function(int x, int y) onTapCell;

  @override
  State<MapView> createState() => _MapViewState();
}

class _MapViewState extends State<MapView> {
  // 同じ文字を何度もレイアウトしないよう、描画済みの文字をとっておく
  final _cache = <String, TextPainter>{};
  double _cachedSize = 0;

  @override
  void dispose() {
    for (final tp in _cache.values) {
      tp.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      // 横幅と高さの両方に収まる最大の文字サイズ
      final fs = [c.maxWidth / (Level.width * .62), c.maxHeight / (Level.height * 1.15), 26.0]
          .reduce((a, b) => a < b ? a : b)
          .clamp(6.0, 26.0);
      if (fs != _cachedSize) {
        for (final tp in _cache.values) {
          tp.dispose();
        }
        _cache.clear();
        _cachedSize = fs;
      }
      final cw = fs * .62, ch = fs * 1.15;
      final size = Size(cw * Level.width, ch * Level.height);
      return Center(
        child: GestureDetector(
          onTapUp: (d) => widget.onTapCell(
            (d.localPosition.dx / cw).floor(),
            (d.localPosition.dy / ch).floor(),
          ),
          child: CustomPaint(
            size: size,
            painter: _MapPainter(widget.game, fs, cw, ch, _glyph),
          ),
        ),
      );
    });
  }

  TextPainter _glyph(String s, Color color, bool bold) {
    final key = '$s|${color.toARGB32()}|$bold';
    return _cache.putIfAbsent(key, () {
      return TextPainter(
        text: TextSpan(
          text: s,
          style: TextStyle(
            fontFamily: monoFamily,
            fontFamilyFallback: const ['Menlo', 'monospace', 'Courier'],
            fontSize: _cachedSize,
            height: 1.0,
            color: color,
            fontWeight: bold ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
    });
  }
}

class _MapPainter extends CustomPainter {
  _MapPainter(this.game, this.fontSize, this.cw, this.ch, this.glyph);

  final Game game;
  final double fontSize, cw, ch;
  final TextPainter Function(String, Color, bool) glyph;

  static const cText = Color(0xFFCFCFCF);
  static const cDim = Color(0xFF6A6A6A);
  static const cWall = Color(0xFF9A9A9A);
  static const cMonster = Color(0xFFFFCF7A);
  static const cTrap = Color(0xFFE07A7A);
  static const cPlayer = Colors.white;

  @override
  void paint(Canvas canvas, Size size) {
    final lv = game.lv;
    final items = {for (final it in lv.items) (it.x, it.y): it};
    final mons = {
      for (final m in lv.monsters)
        if (game.isVisible(m)) (m.x, m.y): m
    };
    for (var y = 0; y < Level.height; y++) {
      for (var x = 0; x < Level.width; x++) {
        String s = ' ';
        Color color = cText;
        var bold = false;
        if (x == game.p.x && y == game.p.y) {
          s = '@';
          color = cPlayer;
          bold = true;
        } else if (mons[(x, y)] case final m?) {
          s = game.glyphOf(m);
          color = m.disguised ? cText : cMonster;
        } else if (lv.seen[y][x]) {
          final t = lv.grid[y][x];
          s = t.glyph;
          color = switch (t) {
            Tile.floor => cDim,
            Tile.wallH || Tile.wallV || Tile.secretDoorH || Tile.secretDoorV || Tile.corridor => cWall,
            _ => cText,
          };
          if (items[(x, y)] case final it?) {
            s = it.glyph;
            color = cText;
          } else if (lv.traps[(x, y)] case final tr? when tr.found) {
            s = '^';
            color = cTrap;
          }
        }
        if (s == ' ') continue;
        final tp = glyph(s, color, bold);
        tp.paint(canvas, Offset(x * cw + (cw - tp.width) / 2, y * ch + (ch - tp.height) / 2));
      }
    }
  }

  // ゲームの状態が変わると画面全体が作り直されるので、そのたびに描き直す
  @override
  bool shouldRepaint(_MapPainter old) => true;
}
