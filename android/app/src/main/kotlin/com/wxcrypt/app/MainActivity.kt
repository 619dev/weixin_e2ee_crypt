package com.wxcrypt.app

import android.content.Intent
import android.os.Build
import android.provider.Settings
import android.view.WindowManager
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val FLOATING_WINDOW_CHANNEL = "com.wxcrypt.floating_window"
    private val PGP_CHANNEL = "com.wxcrypt.pgp"

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // 悬浮窗MethodChannel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, FLOATING_WINDOW_CHANNEL).setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "startFloatingWindow" -> {
                        if (checkOverlayPermission()) {
                            try {
                                startFloatingWindow()
                                result.success(true)
                            } catch (e: Exception) {
                                android.util.Log.e("MainActivity", "Error starting floating window: ${e.message}", e)
                                result.error("SERVICE_ERROR", "启动悬浮窗服务失败: ${e.message}", null)
                            }
                        } else {
                            // 尝试打开设置页面
                            try {
                                openOverlaySettings()
                                result.error("PERMISSION_DENIED", "需要悬浮窗权限，已打开设置页面", null)
                            } catch (e: Exception) {
                                android.util.Log.e("MainActivity", "Error opening settings: ${e.message}", e)
                                result.error("PERMISSION_DENIED", "需要悬浮窗权限", null)
                            }
                        }
                    }
                    "stopFloatingWindow" -> {
                        try {
                            stopFloatingWindow()
                            result.success(true)
                        } catch (e: Exception) {
                            android.util.Log.e("MainActivity", "Error stopping floating window: ${e.message}", e)
                            result.error("SERVICE_ERROR", "停止悬浮窗服务失败: ${e.message}", null)
                        }
                    }
                    "showEncryptScreen" -> {
                        // 这个会在悬浮窗点击时由服务调用
                        result.success(true)
                    }
                    else -> {
                        result.notImplemented()
                    }
                }
            } catch (e: Exception) {
                android.util.Log.e("MainActivity", "Error in method call handler: ${e.message}", e)
                result.error("UNKNOWN_ERROR", "未知错误: ${e.message}", null)
            }
        }

        // PGP加密MethodChannel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, PGP_CHANNEL).setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "encryptMessage" -> {
                        val message = call.argument<String>("message")
                        val publicKey = call.argument<String>("publicKey")
                        if (message != null && publicKey != null) {
                            try {
                                val encrypted = PGPEncryptionHelper.encrypt(message, publicKey)
                                result.success(encrypted)
                            } catch (e: Exception) {
                                android.util.Log.e("MainActivity", "Encrypt error: ${e.message}", e)
                                result.error("ENCRYPT_ERROR", e.message ?: "加密失败", null)
                            }
                        } else {
                            result.error("INVALID_ARGUMENT", "消息或公钥为空", null)
                        }
                    }
                    "decryptMessage" -> {
                        val encryptedMessage = call.argument<String>("encryptedMessage")
                        val privateKey = call.argument<String>("privateKey")
                        val password = call.argument<String>("password") // 可选的私钥密码
                        if (encryptedMessage != null && privateKey != null) {
                            try {
                                val decrypted = PGPEncryptionHelper.decrypt(encryptedMessage, privateKey, password)
                                result.success(decrypted)
                            } catch (e: Exception) {
                                android.util.Log.e("MainActivity", "Decrypt error: ${e.message}", e)
                                result.error("DECRYPT_ERROR", e.message ?: "解密失败", null)
                            }
                        } else {
                            result.error("INVALID_ARGUMENT", "加密消息或私钥为空", null)
                        }
                    }
                    else -> {
                        result.notImplemented()
                    }
                }
            } catch (e: Exception) {
                android.util.Log.e("MainActivity", "Error in PGP method call handler: ${e.message}", e)
                result.error("UNKNOWN_ERROR", "未知错误: ${e.message}", null)
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        // 处理从悬浮窗启动的Intent
        handleIntent(intent)
    }

    override fun onStart() {
        super.onStart()
        // 延迟处理Intent，确保Flutter Engine已初始化
        android.os.Handler(android.os.Looper.getMainLooper()).postDelayed({
            intent?.let { handleIntent(it) }
        }, 300)
    }

    private fun handleIntent(intent: Intent) {
        try {
            if (intent.getStringExtra("action") == "show_encrypt") {
                android.util.Log.d("MainActivity", "Handling show_encrypt intent")
                // 通过MethodChannel通知Flutter显示加密界面
                // 使用Handler延迟执行，确保Flutter Engine已初始化
                android.os.Handler(android.os.Looper.getMainLooper()).postDelayed({
                    try {
                        flutterEngine?.let { engine ->
                            android.util.Log.d("MainActivity", "Invoking showEncryptScreen method")
                            MethodChannel(engine.dartExecutor.binaryMessenger, FLOATING_WINDOW_CHANNEL)
                                .invokeMethod("showEncryptScreen", null, object : MethodChannel.Result {
                                    override fun success(result: Any?) {
                                        android.util.Log.d("MainActivity", "showEncryptScreen success")
                                    }
                                    override fun error(errorCode: String, errorMessage: String?, errorDetails: Any?) {
                                        android.util.Log.e("MainActivity", "MethodChannel error: $errorCode - $errorMessage")
                                    }
                                    override fun notImplemented() {
                                        android.util.Log.e("MainActivity", "MethodChannel notImplemented")
                                    }
                                })
                        } ?: run {
                            android.util.Log.e("MainActivity", "FlutterEngine is null, retrying...")
                            // 如果Flutter Engine还未初始化，再延迟一点重试
                            android.os.Handler(android.os.Looper.getMainLooper()).postDelayed({
                                flutterEngine?.let { engine ->
                                    MethodChannel(engine.dartExecutor.binaryMessenger, FLOATING_WINDOW_CHANNEL)
                                        .invokeMethod("showEncryptScreen", null)
                                }
                            }, 1000)
                        }
                    } catch (e: Exception) {
                        android.util.Log.e("MainActivity", "Error invoking method: ${e.message}", e)
                    }
                }, 500)
            }
        } catch (e: Exception) {
            android.util.Log.e("MainActivity", "Error handling intent: ${e.message}", e)
        }
    }

    private fun checkOverlayPermission(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            Settings.canDrawOverlays(this)
        } else {
            true
        }
    }

    private fun openOverlaySettings() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val intent = Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION).apply {
                data = android.net.Uri.parse("package:$packageName")
                flags = Intent.FLAG_ACTIVITY_NEW_TASK
            }
            startActivity(intent)
        }
    }

    private fun startFloatingWindow() {
        val intent = Intent(this, FloatingWindowService::class.java).apply {
            action = FloatingWindowService.ACTION_START
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            startForegroundService(intent)
        } else {
            startService(intent)
        }
    }

    private fun stopFloatingWindow() {
        val intent = Intent(this, FloatingWindowService::class.java).apply {
            action = FloatingWindowService.ACTION_STOP
        }
        stopService(intent)
    }
}

