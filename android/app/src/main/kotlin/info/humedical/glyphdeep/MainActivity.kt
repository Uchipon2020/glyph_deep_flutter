package info.humedical.glyphdeep

import android.os.Bundle
import android.view.WindowManager
import androidx.core.view.WindowCompat
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        // エッジ ツー エッジ表示（Android 14 以前でも 15 と同じ見た目にする）。
        // FlutterActivity は ComponentActivity ではないので enableEdgeToEdge() の代わりにこれを使う。
        // 余白は Flutter 側の SafeArea が付けるので、ここでは padding を付けない（付けると二重になる）
        WindowCompat.setDecorFitsSystemWindows(window, false)
        super.onCreate(savedInstanceState)
        // 考えている間に画面が消えないようにする
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
    }
}
