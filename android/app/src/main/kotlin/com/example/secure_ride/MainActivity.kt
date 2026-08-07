package com.example.secure_ride

import android.content.Intent
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    // Bridge between the SOS Quick Settings tile (native) and the SOS
    // screen in Flutter.
    private val quickTileChannel = "com.example.secure_ride/quick_tile"
    private var methodChannel: MethodChannel? = null

    // True if this Activity was (re)launched by a tap on the SOS tile,
    // before the Dart side has had a chance to register its handler.
    private var pendingOpenSos = false

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        pendingOpenSos = intent?.getBooleanExtra(SosTileService.EXTRA_OPEN_SOS, false) ?: false
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, quickTileChannel)
        methodChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                // Dart calls this once at startup (cold start / app was
                // launched fresh by the tile).
                "getInitialAction" -> {
                    if (pendingOpenSos) {
                        pendingOpenSos = false
                        result.success("open_sos")
                    } else {
                        result.success(null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    // App was already running in the background and the tile was tapped
    // again — singleTop launchMode routes it here instead of onCreate.
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        if (intent.getBooleanExtra(SosTileService.EXTRA_OPEN_SOS, false)) {
            methodChannel?.invokeMethod("onQuickTileAction", "open_sos")
        }
    }
}