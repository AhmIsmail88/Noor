package com.noor.player.noor

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    private var mediaAccess: MediaAccess? = null
    companion object {
        private var retainedEngine: FlutterEngine? = null
        private var online: OnlineMediaBridge? = null
    }
    // Keep the one application engine alive across Activity recreation. The
    // playback service and its video texture must not outlive a destroyed JNI.
    override fun provideFlutterEngine(context: android.content.Context): FlutterEngine? = retainedEngine
    override fun shouldDestroyEngineWithHost(): Boolean = false
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        retainedEngine = flutterEngine
        mediaAccess = MediaAccess(this, flutterEngine.dartExecutor.binaryMessenger)
        val appContext = applicationContext
        val playback = io.flutter.plugin.common.MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "noor/playback")
        PlaybackService.channel = playback
        playback.setMethodCallHandler { call, result ->
            when (call.method) {
                "update" -> {
                    if (android.os.Build.VERSION.SDK_INT >= 26) {
                        val intent = android.content.Intent(appContext, PlaybackService::class.java)
                            .putExtra("title", call.argument<String>("title") ?: "Noor")
                            .putExtra("playing", call.argument<Boolean>("playing") ?: false)
                            .putExtra("position", (call.argument<Number>("position") ?: 0).toLong())
                            .putExtra("duration", (call.argument<Number>("duration") ?: 0).toLong())
                        appContext.startForegroundService(intent)
                    }
                    result.success(null)
                }
                "stop" -> { appContext.stopService(android.content.Intent(appContext, PlaybackService::class.java)); result.success(null) }
                else -> result.notImplemented()
            }
        }
        if (android.os.Build.VERSION.SDK_INT >= 33 && checkSelfPermission(android.Manifest.permission.POST_NOTIFICATIONS) != android.content.pm.PackageManager.PERMISSION_GRANTED) {
            requestPermissions(arrayOf(android.Manifest.permission.POST_NOTIFICATIONS), 41)
        }
        if (online == null) online = OnlineMediaBridge(applicationContext, flutterEngine.dartExecutor.binaryMessenger)
    }
    override fun onCreate(savedInstanceState: android.os.Bundle?) {
        super.onCreate(savedInstanceState)
        if (savedInstanceState == null) mediaAccess?.incoming(intent)
    }
    override fun onNewIntent(intent: android.content.Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        mediaAccess?.incoming(intent)
    }
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: android.content.Intent?) {
        if (mediaAccess?.result(requestCode, resultCode, data) != true)
            super.onActivityResult(requestCode, resultCode, data)
    }
    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        // Engine belongs to the application, not to this Activity.
        super.cleanUpFlutterEngine(flutterEngine)
    }
}
