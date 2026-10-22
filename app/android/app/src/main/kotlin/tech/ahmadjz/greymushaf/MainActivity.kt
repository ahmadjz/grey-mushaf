package tech.ahmadjz.greymushaf

import androidx.core.view.ViewCompat
import androidx.core.view.WindowCompat
import androidx.core.view.WindowInsetsCompat
import androidx.core.view.WindowInsetsControllerCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var barsVisible = false

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "tech.ahmadjz.greymushaf/reader")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "setBarsVisible" -> {
                        barsVisible = call.arguments as Boolean
                        applyBars()
                        result.success(null)
                    }
                    "getInsets" -> {
                        val insets = ViewCompat.getRootWindowInsets(window.decorView)
                        val cutout = insets?.getInsets(WindowInsetsCompat.Type.displayCutout())
                        val density = resources.displayMetrics.density
                        result.success(mapOf(
                            "left" to (cutout?.left ?: 0) / density,
                            "top" to (cutout?.top ?: 0) / density,
                            "right" to (cutout?.right ?: 0) / density,
                            "bottom" to (cutout?.bottom ?: 0) / density,
                            "statusTop" to (insets?.getInsetsIgnoringVisibility(WindowInsetsCompat.Type.statusBars())?.top ?: 0) / density
                        ))
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun applyBars() {
        WindowCompat.setDecorFitsSystemWindows(window, false)
        val controller = WindowCompat.getInsetsController(window, window.decorView)
        controller.systemBarsBehavior = WindowInsetsControllerCompat.BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE
        if (barsVisible) controller.show(WindowInsetsCompat.Type.systemBars())
        else controller.hide(WindowInsetsCompat.Type.systemBars())
    }

    override fun onWindowFocusChanged(hasFocus: Boolean) {
        super.onWindowFocusChanged(hasFocus)
        if (hasFocus) applyBars()
    }
}
