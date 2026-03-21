package com.example.fake_call_detector

import android.content.Context
import android.media.AudioManager
import android.media.AudioRecord
import android.media.MediaRecorder
import android.media.AudioFormat
import android.util.Log
import kotlin.concurrent.thread

class AudioCaptureService(private val context: Context) {
    companion object {
        const val TAG = "AudioCaptureService"
    }

    private var audioRecord: AudioRecord? = null
    private var isRecording = false
    private val sampleRate = 16000
    private val bufferSize = AudioRecord.getMinBufferSize(
        sampleRate,
        AudioFormat.CHANNEL_IN_MONO,
        AudioFormat.ENCODING_PCM_16BIT
    )

    fun startCapture(): Boolean {
        if (isRecording) {
            return true
        }

        val audioManager = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
        
        // Emulate the workaround: Force speakerphone on so the MIC can pick up the remote caller's voice
        audioManager.isSpeakerphoneOn = true
        audioManager.mode = AudioManager.MODE_IN_CALL
        Log.d(TAG, "Speakerphone forced ON for audio capture workaround.")

        try {
            audioRecord = AudioRecord(
                MediaRecorder.AudioSource.MIC,
                sampleRate,
                AudioFormat.CHANNEL_IN_MONO,
                AudioFormat.ENCODING_PCM_16BIT,
                bufferSize
            )

            audioRecord?.startRecording()
            isRecording = true
            Log.d(TAG, "Audio recording started via MIC.")

            thread {
                val audioBuffer = ShortArray(bufferSize)
                while (isRecording) {
                    val readResult = audioRecord?.read(audioBuffer, 0, audioBuffer.size)
                    if (readResult != null && readResult > 0) {
                        // TODO: Pass the audioBuffer to TFLite model via JNI or Flutter Platform Channel
                        // For now we just pretend to process it.
                    }
                }
            }
            return true
        } catch (e: Exception) {
            Log.e(TAG, "Error initializing AudioRecord: ${e.message}")
            isRecording = false
            return false
        }
    }

    fun stopCapture() {
        isRecording = false
        audioRecord?.stop()
        audioRecord?.release()
        audioRecord = null

        // Restore audio settings
        val audioManager = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
        audioManager.isSpeakerphoneOn = false
        audioManager.mode = AudioManager.MODE_NORMAL
        Log.d(TAG, "Audio capture stopped and audio mode restored.")
    }
}
