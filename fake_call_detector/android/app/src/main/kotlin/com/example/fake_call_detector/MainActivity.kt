package com.example.fake_call_detector

import android.content.Intent
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val METHOD_CHANNEL = "com.example.fake_call_detector/methods"
    private val EVENT_CHANNEL = "com.example.fake_call_detector/events"

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

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, METHOD_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "startAudioCapture" -> {
                    audioCaptureService?.startCapture()
                    result.success(true)
                }
                "stopAudioCapture" -> {
                    audioCaptureService?.stopCapture()
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, EVENT_CHANNEL).setStreamHandler(
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
