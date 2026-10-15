# ストア掲載メモ（Google Play / App Store 共通）

- カテゴリ: ゲーム > ロールプレイング
- アプリ名: 地下迷宮 @ / Glyph Deep
- 価格: 基本無料（深さ3まで無料）。アプリ内課金「深部解放」（非消耗型・買い切り）で深さ4以降と護符を解放。広告なし
- ID: Android `info.humedical.glyphdeep` / iOS バンドルID `info.humedical.glyphdeep`
- 対応: iPhone のみ・縦固定（iOS 15 以降） / Android 7.0 以降・縦固定

## 日本語

**サブタイトル（App Store, 30文字以内）**
記号だけで遊ぶ探索RPG

**短い説明（Google Play, 80文字以内）**
記号だけで遊ぶ探索RPG。基本無料で深さ3まで、その先は買い切りで解放。広告なし。

**詳しい説明**
「@」があなた。文字と記号だけで描かれた地下迷宮を、一歩ずつ降りていきます。

- 十字ボタンで移動、長押しで走る。マップをタップすると自動で移動
- A〜Z、26種類の怪物。眠らせる、凍らせる、盗む、鎧を錆びさせる、レベルを吸う、炎を吐く、アイテムに化ける…
- 隠し扉と、落とし穴・眠りガスなどの見えない罠
- 投げ矢や薬を投げる、杖を振る。未識別の薬・巻物・杖
- 満腹度の管理、装備の強化
- 潜るたびに姿を変える迷宮。倒れたら最初から
- 基本無料。深さ3までは無料で遊べます
- 全12階。深さ12の護符を手に入れたら、地上まで登って持ち帰る
- 深さ4〜12と迷宮の護符は、アプリ内課金「深部解放」（買い切り・1回のみ）で解放
- 広告なし。通信するのは購入・復元の処理だけ。ベストスコアと購入状態は端末内に保存

まずは深さ3まで無料で。気に入ったら「深部解放」で、深さ12の護符を地上へ持ち帰ってください。

**キーワード（App Store, 100文字以内・カンマ区切り）**
ローグライク,ダンジョン,RPG,ローグ,不思議のダンジョン,アスキー,テキスト,記号,オフライン,買い切り

## English

**Subtitle (App Store, 30 chars max)**
A roguelike drawn in symbols

**Short description (Google Play, 80 chars max)**
A roguelike in symbols. Free to depth 3; unlock the rest with a one-time purchase.

**Full description**
You are the "@". Descend a dungeon drawn entirely in characters and symbols, one step at a time.

- D-pad to move, long-press to run, tap the map to auto-travel
- 26 monsters from A to Z that put you to sleep, freeze you, steal, rust your armor, drain levels, breathe fire, pose as items...
- Secret doors and hidden traps: pits, sleeping gas, poison darts, teleporters
- Throw darts and potions, zap wands. Unidentified potions, scrolls and wands
- Hunger, gear upgrades
- A new dungeon every run. If you fall, you start over
- Free to play through depth 3
- 12 depths. Grab the amulet on depth 12, then climb all the way back to the surface
- Depths 4-12 and the amulet unlock with a one-time in-app purchase, "Deep Unlock"
- No ads. The app only goes online to process purchases and restores. Your best score and purchase status stay on your device

Try the first three depths for free, then unlock the deep and bring the amulet on depth 12 back to the surface.

**Keywords (App Store, 100 chars max)**
roguelike,dungeon,rpg,rogue,ascii,text,symbols,offline,retro,free,no ads

## アプリ内課金（App Store Connect / Play Console に登録）

どれも非消耗型（iOS: Non-Consumable / Google Play: 1回限りのアイテム）。Product ID は iOS・Android 共通。

| Product ID | 表示名 | 価格 | 説明（ストア表示用） |
|---|---|---|---|
| `info.humedical.glyphdeep.fullunlock` | 深部解放 | 未定（例: 480円） | 深さ4〜12と迷宮の護符を解放します。買い切りです。 |
| `info.humedical.glyphdeep.tip120` | 開発者を応援（120円） | 120円 | 開発者への応援です。ゲームの内容は変わりません。 |
| `info.humedical.glyphdeep.tip360` | 開発者を応援（360円） | 360円 | 開発者への応援です。ゲームの内容は変わりません。 |
| `info.humedical.glyphdeep.tip1000` | 開発者を応援（1000円） | 1000円 | 開発者への応援です。ゲームの内容は変わりません。 |

- App Store の審査用スクリーンショット（課金アイテムごとに1枚）: 深さ3の階段で出る「ここから先は製品版で」画面
- 審査メモ: 「深さ3の階段で購入画面が出ます。？ボタン →『深部解放・購入の復元・応援』からも開けます」
- 価格はアプリ内ではストアから取得して表示する（ハードコードしない）

## 画像素材

- アイコン: iOS は `ios/Runner/Assets.xcassets/AppIcon.appiconset/icon-1024.png`（透過なし）、Google Play は `docs/store/play-icon-512.png`
- Google Play のフィーチャーグラフィック（1024×500）: 未作成
- スクリーンショット: 未作成（iPhone 6.9インチ 1320×2868 か 6.5インチ 1284×2778 を最低1枚。Google Play は 2〜8枚）

## App Store（日本語）入力用

**サブタイトル（30文字以内）**
記号だけで遊ぶ探索RPG

**プロモーション用テキスト（170文字以内・審査なしでいつでも変更可）**
「@」があなた。記号だけの迷宮で、眠りを誘う蛾、金貨を盗むレプラコーン、炎を吐くドラゴンが待ち受ける。隠し扉と見えない罠をくぐり抜け、深さ12の護符を地上へ。基本無料・深さ3まで無料、その先は買い切りで解放。広告なし。

**概要**
「@」があなた。
文字と記号だけで描かれた地下迷宮を、一歩ずつ降りていく本格ローグライク。

■ 一手ごとに考える、ターン制の緊張感
あなたが1歩動けば、怪物も1歩動く。戦うか、逃げるか、薬を投げつけるか。判断ひとつで生死が分かれます。

■ A〜Z、26種類の怪物
眠らせる蛾、体を凍らせる怪物、金貨を盗んで消えるレプラコーン、鎧を錆びさせるアクエイター、レベルを吸うレイス、アイテムに化けるゼロック、そして炎を吐くドラゴン。

■ 隠し扉と見えない罠
出口のない部屋には隠し扉。床には落とし穴、眠りガス、毒矢、転移の罠。

■ 使ってみるまで正体不明
未識別の薬・巻物・杖。薬は飲むだけでなく、怪物に投げつけることもできます。

■ 全12階。潜って、持ち帰れ
護符を手にしたら、今度は地上を目指して登る番。登るたびに迷宮は姿を変えます。

■ 満腹度を管理しながら、深く潜れ
食料が尽きれば餓死。迷宮は潜るたびに姿を変え、倒れたら最初から。

■ シンプルな操作
十字ボタンで移動、長押しで走る。マップをタップすれば自動で移動。

■ 基本無料。深さ3まで無料、その先は買い切り
深さ1〜3は無料で、何度でも遊べます。
深さ4〜12と「迷宮の護符」は、アプリ内課金「深部解放」で解放。一度の購入でずっと遊べる買い切りです（月額課金ではありません）。
機種変更や再インストールのあとは「購入を復元」で戻せます。

■ 広告なし
広告は一切表示しません。通信するのは購入・復元の処理（App Store）だけ。保存するのは端末内のベストスコアと購入状態だけです。

■ 開発者を応援（任意）
気に入っていただけたら、応援の購入（120円／360円／1000円）もできます。応援の購入でゲームの内容は変わりません。

まずは深さ3まで、無料で潜ってみてください。
深さ12に眠る「迷宮の護符」を手に入れ、地上まで生きて持ち帰れるか。

**キーワード（100文字以内・カンマ区切り・スペースなし）**
ローグライク,ダンジョン,ローグ,ターン制,オフライン,基本無料,買い切り,広告なし,レトロ,アスキー,テキスト,文字,冒険,モンスター,罠,暇つぶし,roguelike

**サポートURL**
https://humedical.info/

**マーケティングURL（任意）**
https://humedical.info/

**著作権**
2026 H&UMedicalinformation

## コンテンツレーティング回答メモ (IARC / App Store)

- 暴力: ファンタジーの暴力（記号同士の戦闘。流血・写実表現なし）→ あり（軽度）
- 性的内容 / 冒涜的表現 / 薬物・アルコール・タバコの描写: なし
  （ゲーム内の「薬」は魔法の薬で、現実の薬物の描写ではない）
- 賭博: なし
- ユーザー生成コンテンツ / ユーザー間交流 / 位置情報共有: なし
- デジタル購入: あり（アプリ内課金。非消耗型のみ）
- 想定: 全年齢に近い区分（最終判定は IARC / Apple）

## Data safety（Google Play）/ App のプライバシー（App Store）

- 収集するデータ: なし / 「データを収集しない」
  （購入の処理は Apple / Google が行い、開発者のサーバーには何も送らない。
  アプリは購入履歴を端末外へ送らない。申告の要否は提出時に Play Console ヘルプで要確認）
- 共有するデータ: なし
- 通信時の暗号化: 課金処理の通信は OS / Play ストアが HTTPS で行う（アプリ独自の通信はなし）
- Android の権限: Play Billing Library が BILLING・INTERNET・ACCESS_NETWORK_STATE を追加する
- データ削除リクエスト: 該当なし（サーバー保存なし）
- 輸出コンプライアンス: 暗号化を使用しない（Info.plist に `ITSAppUsesNonExemptEncryption = NO` を設定済み）
- プライバシーポリシーURL: `docs/PRIVACY_POLICY.md` を公開したURLを入力（TODO）
