package com.cloudstream.cloudstream_app

import android.app.PictureInPictureParams
import android.content.res.Configuration
import android.os.Build
import android.util.Rational
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.io.BufferedReader
import java.io.InputStreamReader

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.cloudstream.cloudstream_app/pip"
    private val LOG_CHANNEL = "com.cloudstream.cloudstream_app/logs"
    private var isInPipMode = false
    private var logStreamHandler: LogStreamHandler? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "enterPictureInPicture" -> {
                    // enterPictureInPictureMode is available from API 26 (Oreo)
                    // enterPictureInPicture(instance, params) was removed in API 33 (S)
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        val rational = Rational(16, 9)
                        val params = PictureInPictureParams.Builder()
                            .setAspectRatio(rational)
                            .build()
                        enterPictureInPictureMode(params)
                        result.success(true)
                    } else {
                        result.success(false)
                    }
                }
                "isInPictureInPictureMode" -> {
                    result.success(isInPipMode)
                }
                else -> result.notImplemented()
            }
        }

        // EventChannel: streaming logcat lines to Flutter.
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, LOG_CHANNEL).setStreamHandler(
            LogStreamHandler().also { logStreamHandler = it }
        )
    }

    override fun onUserLeaveHint() {
        super.onUserLeaveHint()
    }

    override fun onPictureInPictureModeChanged(
        isInPictureInPictureMode: Boolean,
        newConfig: Configuration
    ) {
        super.onPictureInPictureModeChanged(isInPictureInPictureMode, newConfig)
        isInPipMode = isInPictureInPictureMode
        flutterEngine?.dartExecutor?.binaryMessenger?.let { messenger ->
            MethodChannel(messenger, CHANNEL)
                .invokeMethod("onPictureInPictureModeChanged", isInPictureInPictureMode)
        }
    }

    override fun onDestroy() {
        logStreamHandler?.cancel()
        super.onDestroy()
    }
}

/** Streams logcat output for this app's tag to Flutter via EventChannel. */
class LogStreamHandler : EventChannel.StreamHandler {
    private var reader: BufferedReader? = null
    private var process: Process? = null
    private var isStreaming = false

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        if (isStreaming) return
        isStreaming = true

        try {
            // Filter to this app's process + Flutter tags only.
            // Excludes noisy system tags; targets this app's package.
            process = Runtime.getRuntime().exec(arrayOf(
                "logcat", "--pid=0", "-s",
                "flutter", "cloudstream_app", "D/CloudStream", "E/CloudStream", "W/CloudStream"
            ))
            reader = BufferedReader(InputStreamReader(process!!.inputStream), 8192)

            Thread {
                try {
                    var line: String?
                    while (reader!!.readLine().also { line = it } != null) {
                        events?.success(line)
                    }
                } catch (e: Exception) {
                    events?.error("LOG_ERROR", e.message, null)
                } finally {
                    events?.endOfStream()
                }
            }.start()
        } catch (e: Exception) {
            events?.error("LOG_ERROR", e.message, null)
        }
    }

    override fun onCancel(arguments: Any?) {
        isStreaming = false
        try { reader?.close() } catch (_: Exception) {}
        process?.destroy()
        process = null
        reader = null
    }
}
