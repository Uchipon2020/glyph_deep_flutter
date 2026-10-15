// 画面下の操作ボタン（十字ボタンと横のボタン）。
import 'dart:async';

import 'package:flutter/material.dart';

/// 押した瞬間に反応し、長押し（0.33秒）で別の動作をするボタン。
///
/// 普通の ElevatedButton は「指を離したとき」に反応するので、
/// ゲームの移動には遅く感じる。ここでは指が触れた瞬間に動かす。
class PadButton extends StatefulWidget {
  const PadButton({
    super.key,
    required this.label,
    required this.onDown,
    this.onHold,
    this.on = false,
    this.fontSize = 22,
  });

  final String label;
  final VoidCallback onDown;
  final VoidCallback? onHold;
  final bool on; // 押しっぱなし表示（「走」の ON など）
  final double fontSize;

  @override
  State<PadButton> createState() => _PadButtonState();
}

class _PadButtonState extends State<PadButton> {
  Timer? _hold;
  bool _pressed = false;

  void _down(PointerDownEvent _) {
    setState(() => _pressed = true);
    _hold?.cancel();
    widget.onDown();
    if (widget.onHold != null) {
      _hold = Timer(const Duration(milliseconds: 330), widget.onHold!);
    }
  }

  void _up([PointerEvent? _]) {
    _hold?.cancel();
    if (mounted) setState(() => _pressed = false);
  }

  @override
  void dispose() {
    _hold?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lit = _pressed || widget.on;
    return Listener(
      onPointerDown: _down,
      onPointerUp: _up,
      onPointerCancel: _up,
      child: Container(
        height: 58,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: lit ? const Color(0xFF3A3A3A) : Colors.black,
          border: Border.all(
            color: widget.on ? Colors.white : (lit ? const Color(0xFFAAAAAA) : const Color(0xFF555555)),
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          widget.label,
          style: TextStyle(
            fontSize: widget.fontSize,
            color: widget.on ? Colors.white : const Color(0xFFDDDDDD),
          ),
        ),
      ),
    );
  }
}

/// 3×3 の十字ボタン。真ん中は「休む」（方向選択中は「取消」）。
class DPad extends StatelessWidget {
  const DPad({
    super.key,
    required this.onDir,
    required this.onDirHold,
    required this.onCenter,
    required this.onCenterHold,
    required this.aiming,
  });

  final void Function(int dx, int dy) onDir;
  final void Function(int dx, int dy) onDirHold;
  final VoidCallback onCenter;
  final VoidCallback onCenterHold;
  final bool aiming;

  static const _labels = ['↖', '↑', '↗', '←', '休', '→', '↙', '↓', '↘'];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 204,
      child: GridView.count(
        crossAxisCount: 3,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 6,
        crossAxisSpacing: 6,
        childAspectRatio: 64 / 58,
        children: [
          for (var i = 0; i < 9; i++)
            if (i == 4)
              PadButton(
                label: aiming ? '取消' : '休',
                fontSize: aiming ? 16 : 22,
                onDown: onCenter,
                onHold: aiming ? null : onCenterHold,
              )
            else
              PadButton(
                label: _labels[i],
                onDown: () => onDir(i % 3 - 1, i ~/ 3 - 1),
                onHold: aiming ? null : () => onDirHold(i % 3 - 1, i ~/ 3 - 1),
              ),
        ],
      ),
    );
  }
}
