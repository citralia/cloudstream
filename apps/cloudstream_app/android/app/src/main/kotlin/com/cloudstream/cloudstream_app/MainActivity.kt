package com.cloudstream.cloudstream_app

import android.app.PictureInPictureParams
import android.content.res.Configuration
import android.os.Build
import android.util.Rational
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.cloudstream.cloudstream_app/pip"
    private var isInPipMode = false

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "enterPictureInPicture" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                        val rational = Rational(16, 9)
                        val params = PictureInPictureParams.Builder()
                            .setAspectRatio(rational)
                            .build()
                        enterPictureInPictureMode(params)
                        result.success(true)
                    } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        val rational = Rational(16, 9)
                        val params = PictureInPictureParams.Builder()
                            .setAspectRatio(rational)
                            .build()
                        @Suppress("DEPRECATION")
                        enterPictureInPicture(params)
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
}
