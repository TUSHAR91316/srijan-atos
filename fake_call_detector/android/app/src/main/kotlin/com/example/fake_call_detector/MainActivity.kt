package com.example.fake_call_detector

import android.Manifest
import android.app.role.RoleManager
import android.content.pm.PackageManager
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.util.Log
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val methodChannelName = "com.example.fake_call_detector/methods"
    private val eventChannelName = "com.example.fake_call_detector/events"

    private var audioCaptureService: AudioCaptureService? = null
    private var eventSink: EventChannel.EventSink? = null

    companion object {
        private const val TAG = "MainActivity"
        private var instance: MainActivity? = null

        fun triggerCallEvent(phoneNumber: String) {
            Handler(Looper.getMainLooper()).post {
                if (instance != null) {
                    instance?.eventSink?.success(mapOf("event" to "incoming_call", "phoneNumber" to phoneNumber))
                } else {
                    Log.d(TAG, "MainActivity is null, cannot relay call event.")
                }
            }
        }
    }

    private fun canStartAudioCapture(): Boolean {
        val hasMicPermission = ContextCompat.checkSelfPermission(
            this,
            Manifest.permission.RECORD_AUDIO
        ) == PackageManager.PERMISSION_GRANTED

        if (!hasMicPermission) {
            Log.w(TAG, "Audio capture blocked: RECORD_AUDIO permission not granted.")
            return false
        }

        val roleManager = getSystemService(RoleManager::class.java)
        val holdsScreeningRole = roleManager?.isRoleHeld(RoleManager.ROLE_CALL_SCREENING) == true
        if (!holdsScreeningRole) {
            Log.w(TAG, "Audio capture blocked: app is not default call screening role holder.")
            return false
        }

        return true
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        instance = this
        audioCaptureService = AudioCaptureService(this)
    }

    override fun onDestroy() {
        super.onDestroy()
        instance = null
        audioCaptureService?.stopCapture()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, methodChannelName).setMethodCallHandler { call, result ->
            when (call.method) {
                "startAudioCapture" -> {
                    if (!canStartAudioCapture()) {
                        result.success(false)
                        return@setMethodCallHandler
                    }

                    val started = audioCaptureService?.startCapture() ?: false
                    result.success(started)
                }
                "stopAudioCapture" -> {
                    audioCaptureService?.stopCapture()
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, eventChannelName).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    eventSink = events
                }

                override fun onCancel(arguments: Any?) {
                    eventSink = null
                }
            }
        )
    }
}
