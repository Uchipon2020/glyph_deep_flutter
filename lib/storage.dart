// ベストスコアを端末内に保存する（通信はしない）。
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'game/game.dart';

class PrefsScoreBook implements ScoreBook {
  PrefsScoreBook._(this._prefs, this._best);

  static const _key = 'glyphdeep_best';

  final SharedPreferences _prefs;
  BestScore? _best;

  static Future<PrefsScoreBook> load() async {
    final prefs = await SharedPreferences.getInstance();
    BestScore? best;
    try {
      final raw = prefs.getString(_key);
      if (raw != null) {
        final j = jsonDecode(raw) as Map<String, dynamic>;
        best = BestScore(j['score'] as int, j['depth'] as int, j['gold'] as int);
      }
    } catch (_) {
      // 壊れたデータは無視して最初から
    }
    return PrefsScoreBook._(prefs, best);
  }

  @override
  BestScore? get best => _best;

  @override
  void submit(BestScore s) {
    if (_best != null && s.score <= _best!.score) return;
    _best = s;
    _prefs.setString(_key, jsonEncode({'score': s.score, 'depth': s.depth, 'gold': s.gold}));
  }
}
