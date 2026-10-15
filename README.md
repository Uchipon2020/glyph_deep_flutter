# GlyphDeep（地下迷宮 @）Flutter 版

HTML 版（`../glyph_deep/docs/source/glyph-dungeon.html`）を Dart で書き直したもの。WebView は使わない。

    flutter run            # 実機・シミュレータで起動
    flutter test           # ルールのテスト（自動プレイで最深部まで）
    flutter build apk      # Android
    flutter build ios      # iOS

## 構成

    lib/main.dart            起動・縦固定・全画面
    lib/storage.dart         ベストスコアの保存（端末内のみ）
    lib/purchases.dart       アプリ内課金（深部解放・応援・復元）と購入フラグの保存
    lib/game/                ゲームのルール（Flutter の画面に依存しない）
      data.dart                怪物・薬・巻物・杖・罠の定義表（調整はここ）
      models.dart              地形・アイテム・怪物・プレイヤーのクラス
      dungeon.dart             階の自動生成（部屋・通路・隠し扉・罠・配置）
      game.dart                ターン進行・戦闘・持ち物・投げる/振る・走る
      util.dart                乱数・方向
    lib/ui/                  画面
      game_screen.dart         レイアウト・入力・持ち物などのパネル・説明文
      map_view.dart            マップ描画（CustomPainter）
      controls.dart            十字ボタンなど

## HTML 版から増えたもの

- 投げる（投げ矢・武器・薬）、杖（雷・眠り・転移）
- 満腹度の常時表示、同じ種類のアイテムをまとめて持つ
- 隠し扉（深さ2以降）と罠（落とし穴・眠りガス・毒矢・転移）、[休]で調べる
- 怪物 A〜Z の26種と特技（眠らせる・凍らせる・盗む・錆びさせる・吸う・射る・吐く・化ける・見えない など）
- 薬（千里眼・混乱）と巻物（識別・眠りの霧・大声）

## 依存

- shared_preferences（BSD-3-Clause, flutter.dev）: ベストスコアと購入フラグの保存
  （購入フラグは SharedPreferencesAsync = iOS: UserDefaults / Android: DataStore）
- in_app_purchase（BSD-3-Clause, flutter.dev）: アプリ内課金。iOS は StoreKit 2（既定）、
  Android は Google Play Billing Library 8

## 無料版と課金

- 深さ1〜3は無料（`Game.freeMaxDepth`）。深さ3の階段で「ここから先は製品版で」画面が出る
- 非消耗型の課金アイテム（ID は iOS・Android 共通、一覧は `docs/store-listing.md`）
  - `info.humedical.glyphdeep.fullunlock`「深部解放」: 深さ4〜12と護符を解放。深さ12で護符を拾い、深さ1の階段を登って地上に出ればクリア
  - `info.humedical.glyphdeep.tip120` / `tip360` / `tip1000`: 応援（機能は変わらない）
- 「購入を復元」は ？ → 「深部解放・購入の復元・応援」
- 通信は課金処理だけ。Android は Play Billing Library が INTERNET 権限を追加する

## リリース

バージョンは `pubspec.yaml` の `version: 1.0.0+1`（`+` の後ろがビルド番号）。
ストアに出すたびにビルド番号を必ず1つ上げる。掲載文などは `docs/store-listing.md`。

### Android（Google Play）

1. アップロード鍵を作る（一度だけ。リポジトリの外に置き、なくさない）

       mkdir -p ~/keys
       keytool -genkeypair -v -keystore ~/keys/glyphdeep-upload.jks \
         -alias upload -keyalg RSA -keysize 2048 -validity 10000

2. `android/key.properties` を作る（git には入らない）

       storeFile=/Users/<you>/keys/glyphdeep-upload.jks
       storePassword=<鍵ストアのパスワード>
       keyAlias=upload
       keyPassword=<鍵のパスワード>

3. `flutter build appbundle` → `build/app/outputs/bundle/release/app-release.aab` を Play Console へ
   （Play App Signing を使う。Google が配布用の鍵を持ち、上の鍵は「アップロード用」になる）

### iOS（App Store）

1. Xcode で `ios/Runner.xcworkspace` を開き、Runner > Signing & Capabilities で
   Team を確認（Automatically manage signing）
2. `flutter build ipa` → `build/ios/ipa/*.ipa` を Transporter アプリでアップロード
   （または Xcode の Product > Archive > Distribute App）
