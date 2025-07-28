package com.example.dashcam_viewer

import android.os.Build
import android.os.Bundle
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "flutter.dev/android_version"

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // 设置硬件加速和OpenGL配置
        window.setFlags(
            WindowManager.LayoutParams.FLAG_HARDWARE_ACCELERATED,
            WindowManager.LayoutParams.FLAG_HARDWARE_ACCELERATED
        )

        // 保持屏幕常亮（对视频播放有帮助）
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)

        // 设置方法通道
        flutterEngine?.dartExecutor?.binaryMessenger?.let {
            MethodChannel(it, CHANNEL).setMethodCallHandler { call, result ->
                when (call.method) {
                    "getAndroidVersion" -> {
                        result.success(Build.VERSION.SDK_INT)
                    }
                    else -> {
                        result.notImplemented()
                    }
                }
            }
        }
    }
}
