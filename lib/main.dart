import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'purchases.dart';
import 'storage.dart';
import 'ui/game_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  // 画面いっぱいに使う（端からスワイプでバーが一時的に出る）
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  final scores = await PrefsScoreBook.load();
  final purchases = await Purchases.load();
  runApp(GlyphDeepApp(scores: scores, purchases: purchases));
}

class GlyphDeepApp extends StatelessWidget {
  const GlyphDeepApp({super.key, required this.scores, required this.purchases});

  final PrefsScoreBook scores;
  final Purchases purchases;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '地下迷宮 @',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: Colors.black,
        colorScheme: const ColorScheme.dark(surface: Colors.black, primary: Color(0xFFDDDDDD)),
      ),
      home: GameScreen(scores: scores, purchases: purchases),
    );
  }
}
