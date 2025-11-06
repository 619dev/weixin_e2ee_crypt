package com.wxcrypt.app

import android.app.Service
import android.content.Intent
import android.graphics.PixelFormat
import android.os.Build
import android.os.IBinder
import android.view.Gravity
import android.view.LayoutInflater
import android.view.MotionEvent
import android.view.View
import android.view.WindowManager
import android.widget.ImageView
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat

class FloatingWindowService : Service() {

    private var windowManager: WindowManager? = null
    private var floatingButton: View? = null
    private var isServiceRunning = false

    override fun onCreate() {
        super.onCreate()
        windowManager = getSystemService(WINDOW_SERVICE) as WindowManager
        createFloatingButton()
        startForegroundService()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        try {
            when (intent?.action) {
                ACTION_START -> {
                    if (!isServiceRunning) {
                        showFloatingButton()
                        isServiceRunning = true
                    }
                }
                ACTION_STOP -> {
                    hideFloatingButton()
                    stopSelf()
                }
            }
        } catch (e: Exception) {
            android.util.Log.e("FloatingWindowService", "Error in onStartCommand: ${e.message}", e)
        }
        return START_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? {
        return null
    }

    override fun onDestroy() {
        super.onDestroy()
        hideFloatingButton()
        isServiceRunning = false
    }

    private fun createFloatingButton() {
        floatingButton = LayoutInflater.from(this).inflate(R.layout.floating_button, null)
        
        val params = WindowManager.LayoutParams(
            WindowManager.LayoutParams.WRAP_CONTENT,
            WindowManager.LayoutParams.WRAP_CONTENT,
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
            } else {
                @Suppress("DEPRECATION")
                WindowManager.LayoutParams.TYPE_PHONE
            },
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE,
            PixelFormat.TRANSLUCENT
        )

        params.gravity = Gravity.TOP or Gravity.START
        params.x = 0
        params.y = 100

        floatingButton?.let { button ->
            val imageView = button.findViewById<ImageView>(R.id.floating_button_icon)
            
            // 点击事件
            button.setOnClickListener { view ->
                android.util.Log.d("FloatingWindowService", "Floating button clicked")
                try {
                    // 通过MethodChannel通知Flutter显示加密界面
                    notifyFlutterShowEncryptScreen()
                } catch (e: Exception) {
                    android.util.Log.e("FloatingWindowService", "Error handling click: ${e.message}", e)
                }
            }
            
            // 确保按钮可点击
            button.isClickable = true
            button.isFocusable = true

            // 拖动功能
            var initialX = 0
            var initialY = 0
            var initialTouchX = 0f
            var initialTouchY = 0f

            button.setOnTouchListener { _, event ->
                when (event.action) {
                    MotionEvent.ACTION_DOWN -> {
                        initialX = params.x
                        initialY = params.y
                        initialTouchX = event.rawX
                        initialTouchY = event.rawY
                        true
                    }
                    MotionEvent.ACTION_MOVE -> {
                        params.x = initialX + (event.rawX - initialTouchX).toInt()
                        params.y = initialY + (event.rawY - initialTouchY).toInt()
                        windowManager?.updateViewLayout(button, params)
                        true
                    }
                    else -> false
                }
            }
        }
    }

    private fun showFloatingButton() {
        floatingButton?.let { button ->
            try {
                // 检查悬浮窗权限
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                    if (!android.provider.Settings.canDrawOverlays(this)) {
                        android.util.Log.e("FloatingWindowService", "No overlay permission")
                        return
                    }
                }
                
                val params = WindowManager.LayoutParams(
                    WindowManager.LayoutParams.WRAP_CONTENT,
                    WindowManager.LayoutParams.WRAP_CONTENT,
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
                    } else {
                        @Suppress("DEPRECATION")
                        WindowManager.LayoutParams.TYPE_PHONE
                    },
                    WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE,
                    PixelFormat.TRANSLUCENT
                )
                params.gravity = Gravity.TOP or Gravity.START
                params.x = 0
                params.y = 100
                windowManager?.addView(button, params)
            } catch (e: Exception) {
                android.util.Log.e("FloatingWindowService", "Error showing floating button: ${e.message}", e)
                e.printStackTrace()
            }
        }
    }

    private fun hideFloatingButton() {
        floatingButton?.let { button ->
            try {
                windowManager?.removeView(button)
            } catch (e: Exception) {
                e.printStackTrace()
            }
        }
    }

    private fun startForegroundService() {
        val notification = NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("微信PGP加密助手")
            .setContentText("悬浮窗服务运行中")
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .build()

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = android.app.NotificationChannel(
                CHANNEL_ID,
                "悬浮窗服务",
                android.app.NotificationManager.IMPORTANCE_LOW
            )
            val notificationManager = getSystemService(android.app.NotificationManager::class.java)
            notificationManager.createNotificationChannel(channel)
        }

        startForeground(NOTIFICATION_ID, notification)
    }

    private fun notifyFlutterShowEncryptScreen() {
        try {
            // 通过Intent启动MainActivity并传递参数
            val intent = Intent(this, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
                putExtra("action", "show_encrypt")
            }
            startActivity(intent)
        } catch (e: Exception) {
            android.util.Log.e("FloatingWindowService", "Error notifying Flutter: ${e.message}", e)
        }
    }

    companion object {
        const val ACTION_START = "com.wxcrypt.app.START_FLOATING"
        const val ACTION_STOP = "com.wxcrypt.app.STOP_FLOATING"
        private const val CHANNEL_ID = "floating_window_channel"
        private const val NOTIFICATION_ID = 1
    }
}

