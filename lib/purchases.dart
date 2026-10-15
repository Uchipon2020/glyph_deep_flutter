// アプリ内課金（買い切りの「深部解放」と、機能の変わらない「応援」）。
//
// iOS は StoreKit 2、Android は Google Play Billing Library を in_app_purchase
// プラグイン経由で使う。通信するのは Apple / Google の課金処理だけ。
// 購入済みのフラグは端末内に保存する（iOS: UserDefaults / Android: DataStore）。
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ProductIds {
  static const fullUnlock = 'info.humedical.glyphdeep.fullunlock';
  static const tip120 = 'info.humedical.glyphdeep.tip120';
  static const tip360 = 'info.humedical.glyphdeep.tip360';
  static const tip1000 = 'info.humedical.glyphdeep.tip1000';

  static const tips = [tip120, tip360, tip1000];
  static const all = {fullUnlock, ...tips};
}

class Purchases extends ChangeNotifier {
  Purchases._(this._prefs, this._fullUnlocked, this._tipped);

  static const _unlockKey = 'glyphdeep_full_unlock';
  static const _tipKey = 'glyphdeep_tipped';

  final SharedPreferencesAsync _prefs;
  bool _fullUnlocked;
  bool _tipped;
  StreamSubscription<List<PurchaseDetails>>? _sub;

  final products = <String, ProductDetails>{};
  bool storeAvailable = true;
  bool busy = false;
  String? message; // 画面に出す結果（購入できた・キャンセルした など）

  bool _restoring = false;
  bool _restoredAny = false;

  bool get fullUnlocked => _fullUnlocked;
  bool get tipped => _tipped;

  /// 起動時に呼ぶ。保存済みのフラグを読み、未完了の購入を受け取れるよう待ち受ける。
  /// ここではストアへの問い合わせはしない（購入画面を開いたときだけ）。
  static Future<Purchases> load() async {
    final prefs = SharedPreferencesAsync();
    var unlocked = false, tipped = false;
    try {
      unlocked = await prefs.getBool(_unlockKey) ?? false;
      tipped = await prefs.getBool(_tipKey) ?? false;
    } catch (_) {
      // 読めなければ未購入扱い（「購入を復元」で戻せる）
    }
    final p = Purchases._(prefs, unlocked, tipped);
    p._sub = InAppPurchase.instance.purchaseStream.listen(
      p._onPurchases,
      onError: (Object _) => p._setMessage('購入処理でエラーが起きました'),
    );
    return p;
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  /// 価格などをストアから取得する（購入画面を開いたとき）。
  Future<void> loadProducts() async {
    if (products.length == ProductIds.all.length) return;
    storeAvailable = await InAppPurchase.instance.isAvailable();
    if (!storeAvailable) {
      notifyListeners();
      return;
    }
    final res = await InAppPurchase.instance.queryProductDetails(ProductIds.all);
    for (final d in res.productDetails) {
      products[d.id] = d;
    }
    notifyListeners();
  }

  Future<void> buy(String id) async {
    final d = products[id];
    if (d == null || busy) {
      _setMessage('ストアに接続できません。時間をおいて試してください');
      return;
    }
    busy = true;
    message = null;
    notifyListeners();
    try {
      // どれも非消耗型（一度買えば終わり）
      await InAppPurchase.instance.buyNonConsumable(purchaseParam: PurchaseParam(productDetails: d));
    } catch (_) {
      busy = false;
      _setMessage('購入を開始できませんでした');
    }
  }

  Future<void> restore() async {
    if (busy) return;
    busy = true;
    _restoring = true;
    _restoredAny = false;
    _setMessage('購入履歴を確認しています…');
    try {
      if (!await InAppPurchase.instance.isAvailable()) {
        _setMessage('ストアに接続できません。時間をおいて試してください');
        return;
      }
      await InAppPurchase.instance.restorePurchases();
      // 復元した購入は purchaseStream に少し遅れて届くことがある
      await Future<void>.delayed(const Duration(seconds: 2));
      if (!_restoredAny) _setMessage('復元できる購入は見つかりませんでした');
    } catch (_) {
      _setMessage('復元できませんでした。時間をおいて試してください');
    } finally {
      _restoring = false;
      busy = false;
      notifyListeners();
    }
  }

  Future<void> _onPurchases(List<PurchaseDetails> list) async {
    for (final pd in list) {
      switch (pd.status) {
        case PurchaseStatus.pending:
          _setMessage('購入の承認を待っています');
        case PurchaseStatus.purchased || PurchaseStatus.restored:
          await _grant(pd.productID, restored: pd.status == PurchaseStatus.restored);
        case PurchaseStatus.canceled:
          busy = false;
          _setMessage('購入をキャンセルしました');
        case PurchaseStatus.error:
          busy = false;
          _setMessage('購入できませんでした');
      }
      // 完了を通知しないと、Android では3日後に自動で返金される
      if (pd.pendingCompletePurchase) {
        try {
          await InAppPurchase.instance.completePurchase(pd);
        } catch (_) {
          // 次回起動時にもう一度届くので、そのとき完了させる
        }
      }
    }
  }

  Future<void> _grant(String id, {required bool restored}) async {
    if (_restoring) _restoredAny = true;
    if (!_restoring) busy = false;
    if (id == ProductIds.fullUnlock) {
      _fullUnlocked = true;
      await _save(_unlockKey);
      _setMessage(restored ? '「深部解放」を復元しました' : '「深部解放」を購入しました。深さ4より先へ進めます');
    } else if (ProductIds.tips.contains(id)) {
      _tipped = true;
      await _save(_tipKey);
      _setMessage(restored ? '応援の購入を復元しました' : '応援ありがとうございます！');
    }
  }

  Future<void> _save(String key) async {
    try {
      await _prefs.setBool(key, true);
    } catch (_) {
      // 保存に失敗しても、今回の起動中は解放されたまま（再起動後は「購入を復元」）
    }
  }

  void _setMessage(String m) {
    message = m;
    notifyListeners();
  }
}
