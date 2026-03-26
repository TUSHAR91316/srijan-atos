package com.example.fake_call_detector

import android.Manifest
import android.app.role.RoleManager
import android.content.Intent
import android.provider.ContactsContract
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.view.WindowManager
import androidx.core.content.ContextCompat
import com.google.i18n.phonenumbers.NumberParseException
import com.google.i18n.phonenumbers.PhoneNumberUtil
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val methodChannelName = "com.example.fake_call_detector/methods"
    private val eventChannelName = "com.example.fake_call_detector/events"
    private val REQUEST_ID_CALL_SCREENING = 1001

    private var audioCaptureService: AudioCaptureService? = null
    private var eventSink: EventChannel.EventSink? = null

    companion object {
        private var instance: MainActivity? = null

        fun triggerCallEvent(phoneNumber: String) {
            Handler(Looper.getMainLooper()).post {
                if (instance != null) {
                    val voiceSimilarity = instance?.audioCaptureService?.latestVoiceSimilarity
                    val voiceEmbedding = instance?.audioCaptureService?.latestVoiceEmbedding?.map { it.toDouble() }
                    val antiSpoofScore = instance?.audioCaptureService?.latestAntiSpoofScore
                    val snrDb = instance?.audioCaptureService?.latestSnrDb
                    val voiceUsable = instance?.audioCaptureService?.latestVoiceUsable
                    instance?.eventSink?.success(
                        mapOf(
                            "event" to "incoming_call",
                            "phoneNumber" to phoneNumber,
                            "voiceSimilarity" to voiceSimilarity,
                            "voiceEmbedding" to voiceEmbedding,
                            "antiSpoofScore" to antiSpoofScore,
                            "snrDb" to snrDb,
                            "voiceUsable" to voiceUsable,
                        )
                    )
                }
            }
        }
    }

    private fun requestCallScreeningRole() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val roleManager = getSystemService(RoleManager::class.java)
            if (roleManager != null && roleManager.isRoleAvailable(RoleManager.ROLE_CALL_SCREENING)) {
                if (!roleManager.isRoleHeld(RoleManager.ROLE_CALL_SCREENING)) {
                    val intent = roleManager.createRequestRoleIntent(RoleManager.ROLE_CALL_SCREENING)
                    startActivityForResult(intent, REQUEST_ID_CALL_SCREENING)
                }
            }
        }
    }

    private fun canStartAudioCapture(): Boolean {
        return ContextCompat.checkSelfPermission(
            this,
            Manifest.permission.RECORD_AUDIO
        ) == PackageManager.PERMISSION_GRANTED
    }

    private fun getTrustedNumbers(): List<String> {
        val hasContactsPermission = ContextCompat.checkSelfPermission(
            this,
            Manifest.permission.READ_CONTACTS
        ) == PackageManager.PERMISSION_GRANTED

        if (!hasContactsPermission) {
            return emptyList()
        }

        val uniqueNumbers = linkedSetOf<String>()
        val projection = arrayOf(ContactsContract.CommonDataKinds.Phone.NUMBER)
        val phoneUtil = PhoneNumberUtil.getInstance()
        val defaultRegion = resources.configuration.locales[0]?.country?.takeIf { it.isNotBlank() } ?: "US"

        contentResolver.query(
            ContactsContract.CommonDataKinds.Phone.CONTENT_URI,
            projection,
            null,
            null,
            null
        )?.use { cursor ->
            val numberIndex = cursor.getColumnIndex(ContactsContract.CommonDataKinds.Phone.NUMBER)
            while (cursor.moveToNext()) {
                val rawNumber = cursor.getString(numberIndex) ?: continue
                val normalized = try {
                    val parsed = phoneUtil.parse(rawNumber, defaultRegion)
                    if (phoneUtil.isValidNumber(parsed)) {
                        phoneUtil.format(parsed, PhoneNumberUtil.PhoneNumberFormat.E164)
                    } else {
                        null
                    }
                } catch (_: NumberParseException) {
                    null
                }

                if (!normalized.isNullOrBlank()) {
                    uniqueNumbers.add(normalized)
                }
            }
        }

        return uniqueNumbers.take(1000)
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
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
                        result.error("PERMISSION_DENIED", "Microphone permission required", null)
                        return@setMethodCallHandler
                    }

                    val started = audioCaptureService?.startCapture() ?: false
                    result.success(started)
                }
                "stopAudioCapture" -> {
                    audioCaptureService?.stopCapture()
                    result.success(true)
                }
                "getLatestVoiceEmbedding" -> {
                    val embedding = audioCaptureService?.latestVoiceEmbedding
                    result.success(embedding?.map { it.toDouble() })
                }
                "getTrustedNumbers" -> {
                    result.success(getTrustedNumbers())
                }
                "requestScreeningRole" -> {
                    requestCallScreeningRole()
                    result.success(true)
                }
                "getLatestAudioSignals" -> {
                    val audioSvc = audioCaptureService ?: return@setMethodCallHandler result.success(null)
                    result.success(
                        mapOf(
                            "voiceSimilarity" to audioSvc.latestVoiceSimilarity,
                            "antiSpoofScore" to audioSvc.latestAntiSpoofScore,
                            "snrDb" to audioSvc.latestSnrDb,
                            "voiceUsable" to audioSvc.latestVoiceUsable
                        )
                    )
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
