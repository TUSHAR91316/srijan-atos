package com.example.fake_call_detector

import android.content.Context
import android.media.AudioManager
import android.media.AudioRecord
import android.media.MediaRecorder
import android.media.AudioFormat
import android.util.Log
import org.tensorflow.lite.Interpreter
import java.io.FileInputStream
import java.nio.MappedByteBuffer
import java.nio.channels.FileChannel
import kotlin.math.abs
import kotlin.math.cos
import kotlin.math.exp
import kotlin.math.max
import kotlin.math.sqrt
import kotlin.concurrent.thread

class AudioCaptureService(private val context: Context) {
    companion object {
        const val TAG = "AudioCaptureService"
    }

    private var audioRecord: AudioRecord? = null
    private var isRecording = false
    private var interpreter: Interpreter? = null
    @Volatile var latestVoiceEmbedding: FloatArray? = null
    @Volatile var latestVoiceSimilarity: Double? = null
    @Volatile var latestInferenceLatencyMs: Double = 0.0
    @Volatile var latestSnrDb: Double? = null
    @Volatile var latestAntiSpoofScore: Double? = null
    @Volatile var latestVoiceUsable: Boolean = false
    private val sampleRate = 16000
    private val modelInputSamples = 15600
    private val inferenceHopSamples = 1600
    private val ringBuffer = FloatArray(modelInputSamples)
    private var ringIndex = 0
    private var ringFilled = 0
    private var pendingSamples = 0
    private val bufferSize = AudioRecord.getMinBufferSize(
        sampleRate,
        AudioFormat.CHANNEL_IN_MONO,
        AudioFormat.ENCODING_PCM_16BIT
    )

    fun startCapture(): Boolean {
        if (isRecording) {
            return true
        }

        if (!ensureInterpreter()) {
            Log.e(TAG, "Audio capture unavailable: TFLite speaker model failed to load")
            return false
        }

        if (bufferSize <= 0) {
            Log.e(TAG, "Audio capture unavailable: invalid buffer size $bufferSize")
            return false
        }

        val audioManager = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
        
        // Emulate the workaround: Force speakerphone on so the MIC can pick up the remote caller's voice
        audioManager.isSpeakerphoneOn = true
        audioManager.mode = AudioManager.MODE_IN_CALL

        try {
            audioRecord = AudioRecord(
                MediaRecorder.AudioSource.MIC,
                sampleRate,
                AudioFormat.CHANNEL_IN_MONO,
                AudioFormat.ENCODING_PCM_16BIT,
                bufferSize
            )

            if (audioRecord?.state != AudioRecord.STATE_INITIALIZED) {
                Log.e(TAG, "AudioRecord initialization failed")
                return false
            }

            audioRecord?.startRecording()
            isRecording = true

            thread {
                val audioBuffer = ShortArray(bufferSize)
                while (isRecording) {
                    val readResult = audioRecord?.read(audioBuffer, 0, audioBuffer.size)
                    if (readResult != null && readResult > 0) {
                        appendToRingBuffer(audioBuffer, readResult)
                        pendingSamples += readResult

                        if (ringFilled >= modelInputSamples && pendingSamples >= inferenceHopSamples) {
                            pendingSamples = 0
                            val inferenceStart = System.nanoTime()
                            val waveform = snapshotWaveform()
                            val snrDb = estimateSnrDb(waveform)
                            latestSnrDb = snrDb
                            latestVoiceUsable = snrDb >= 8.0

                            if (!latestVoiceUsable) {
                                latestVoiceEmbedding = null
                                latestVoiceSimilarity = null
                                latestAntiSpoofScore = 1.0
                                continue
                            }

                            val antiSpoof = spectralAnomalyScore(waveform)
                            latestAntiSpoofScore = antiSpoof

                            val embedding = runEmbeddingModel(waveform)
                            if (embedding != null) {
                                val previous = latestVoiceEmbedding
                                latestVoiceEmbedding = embedding
                                if (previous != null) {
                                    latestVoiceSimilarity = cosineSimilarity(embedding, previous).coerceIn(0.0, 1.0)
                                }
                                val elapsedMs = (System.nanoTime() - inferenceStart) / 1_000_000.0
                                latestInferenceLatencyMs = elapsedMs
                            }
                        }
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
        try {
            audioRecord?.stop()
        } catch (_: IllegalStateException) {}
        audioRecord?.release()
        audioRecord = null
        latestVoiceEmbedding = null
        latestVoiceSimilarity = null
        latestInferenceLatencyMs = 0.0
        latestSnrDb = null
        latestAntiSpoofScore = null
        latestVoiceUsable = false
        ringIndex = 0
        ringFilled = 0
        pendingSamples = 0

        // Restore audio settings
        val audioManager = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
        audioManager.isSpeakerphoneOn = false
        audioManager.mode = AudioManager.MODE_NORMAL
    }

    private fun ensureInterpreter(): Boolean {
        if (interpreter != null) return true
        return try {
            val mapped = loadModelFile("speaker_embedding.tflite")
            val options = Interpreter.Options().apply {
                setNumThreads(2)
                setUseXNNPACK(true)
            }
            interpreter = Interpreter(mapped, options)

            val inputShape = interpreter?.getInputTensor(0)?.shape()
            val outputShape = interpreter?.getOutputTensor(0)?.shape()
            val shapeOk = inputShape?.contentEquals(intArrayOf(1, modelInputSamples)) == true &&
                outputShape?.size == 2 && outputShape[0] == 1 && outputShape[1] >= 128

            if (!shapeOk) {
                Log.e(TAG, "Unexpected model shape. input=${inputShape?.contentToString()} output=${outputShape?.contentToString()}")
                interpreter?.close()
                interpreter = null
                return false
            }
            true
        } catch (e: Exception) {
            Log.e(TAG, "Failed to initialize TFLite interpreter: ${e.message}")
            false
        }
    }

    private fun loadModelFile(assetName: String): MappedByteBuffer {
        val fileDescriptor = context.assets.openFd(assetName)
        FileInputStream(fileDescriptor.fileDescriptor).channel.use { channel ->
            return channel.map(
                FileChannel.MapMode.READ_ONLY,
                fileDescriptor.startOffset,
                fileDescriptor.declaredLength
            )
        }
    }

    private fun appendToRingBuffer(buffer: ShortArray, length: Int) {
        for (i in 0 until length) {
            val sample = (buffer[i] / 32768.0f).coerceIn(-1.0f, 1.0f)
            ringBuffer[ringIndex] = sample
            ringIndex = (ringIndex + 1) % modelInputSamples
            if (ringFilled < modelInputSamples) {
                ringFilled++
            }
        }
    }

    private fun snapshotWaveform(): FloatArray {
        val waveform = FloatArray(modelInputSamples)
        val start = ringIndex
        for (i in 0 until modelInputSamples) {
            waveform[i] = ringBuffer[(start + i) % modelInputSamples]
        }
        normalizeWaveform(waveform)
        return waveform
    }

    private fun normalizeWaveform(waveform: FloatArray) {
        var mean = 0.0f
        for (x in waveform) {
            mean += x
        }
        mean /= waveform.size

        var maxAbs = 1e-6f
        for (i in waveform.indices) {
            waveform[i] -= mean
            maxAbs = max(maxAbs, abs(waveform[i]))
        }

        val scale = if (maxAbs > 0f) 1.0f / maxAbs else 1.0f
        for (i in waveform.indices) {
            waveform[i] = (waveform[i] * scale).coerceIn(-1.0f, 1.0f)
        }
    }

    private fun runEmbeddingModel(waveform: FloatArray): FloatArray? {
        val outputShape = interpreter?.getOutputTensor(0)?.shape() ?: return null
        val embeddingDim = outputShape[1]
        val input = Array(1) { waveform }
        val output = Array(1) { FloatArray(embeddingDim) }
        interpreter?.run(input, output)
        normalizeL2(output[0])
        return output[0]
    }

    private fun estimateSnrDb(waveform: FloatArray): Double {
        var signalPower = 0.0
        var noisePower = 0.0
        var noiseCount = 0

        for (sample in waveform) {
            val p = sample * sample
            signalPower += p
            if (abs(sample) < 0.02f) {
                noisePower += p
                noiseCount++
            }
        }

        signalPower /= waveform.size
        val estimatedNoise = if (noiseCount > 32) noisePower / noiseCount else max(signalPower * 0.1, 1e-8)
        return 10.0 * kotlin.math.log10(max(signalPower, 1e-8) / max(estimatedNoise, 1e-8))
    }

    private fun spectralAnomalyScore(waveform: FloatArray): Double {
        val n = 1024
        if (waveform.size < n) return 1.0

        val real = FloatArray(n)
        val imag = FloatArray(n)
        for (i in 0 until n) {
            real[i] = waveform[i]
        }

        fft(real, imag)

        val bins = n / 2
        var geometricMeanLog = 0.0
        var arithmeticMean = 0.0
        var centroidNum = 0.0
        var total = 0.0
        var highBand = 0.0

        for (k in 1 until bins) {
            val mag2 = (real[k] * real[k] + imag[k] * imag[k]).toDouble() + 1e-9
            geometricMeanLog += kotlin.math.ln(mag2)
            arithmeticMean += mag2
            total += mag2
            centroidNum += k * mag2
            if (k > bins * 0.6) {
                highBand += mag2
            }
        }

        val count = (bins - 1).toDouble()
        val flatness = exp(geometricMeanLog / count) / (arithmeticMean / count)
        val centroidNorm = if (total > 0) (centroidNum / total) / bins else 0.0
        val highRatio = if (total > 0) highBand / total else 0.0

        val flatnessAnomaly = ((flatness - 0.35).let { if (it < 0) -it else it } / 0.35).coerceIn(0.0, 1.0)
        val centroidAnomaly = ((centroidNorm - 0.32).let { if (it < 0) -it else it } / 0.32).coerceIn(0.0, 1.0)
        val highBandAnomaly = ((highRatio - 0.2).let { if (it < 0) -it else it } / 0.2).coerceIn(0.0, 1.0)

        return (0.5 * flatnessAnomaly + 0.3 * centroidAnomaly + 0.2 * highBandAnomaly).coerceIn(0.0, 1.0)
    }

    private fun fft(real: FloatArray, imag: FloatArray) {
        val n = real.size
        var j = 0
        for (i in 0 until n) {
            if (i < j) {
                val tempR = real[i]
                real[i] = real[j]
                real[j] = tempR
                val tempI = imag[i]
                imag[i] = imag[j]
                imag[j] = tempI
            }
            var m = n shr 1
            while (j >= m && m >= 2) {
                j -= m
                m = m shr 1
            }
            j += m
        }

        var len = 2
        while (len <= n) {
            val angle = -2.0 * Math.PI / len
            val wLenR = cos(angle).toFloat()
            val wLenI = kotlin.math.sin(angle).toFloat()

            var i = 0
            while (i < n) {
                var wR = 1.0f
                var wI = 0.0f
                for (k in 0 until len / 2) {
                    val uR = real[i + k]
                    val uI = imag[i + k]
                    val vR = real[i + k + len / 2] * wR - imag[i + k + len / 2] * wI
                    val vI = real[i + k + len / 2] * wI + imag[i + k + len / 2] * wR

                    real[i + k] = uR + vR
                    imag[i + k] = uI + vI
                    real[i + k + len / 2] = uR - vR
                    imag[i + k + len / 2] = uI - vI

                    val nextWR = wR * wLenR - wI * wLenI
                    val nextWI = wR * wLenI + wI * wLenR
                    wR = nextWR
                    wI = nextWI
                }
                i += len
            }
            len = len shl 1
        }
    }

    private fun normalizeL2(vector: FloatArray) {
        var norm = 0.0f
        for (v in vector) {
            norm += v * v
        }
        norm = sqrt(norm)
        if (norm <= 0f) return
        for (i in vector.indices) {
            vector[i] /= norm
        }
    }

    private fun cosineSimilarity(a: FloatArray, b: FloatArray): Double {
        var dot = 0.0
        var normA = 0.0
        var normB = 0.0

        for (i in a.indices) {
            dot += a[i].toDouble() * b[i].toDouble()
            normA += a[i].toDouble() * a[i].toDouble()
            normB += b[i].toDouble() * b[i].toDouble()
        }

        if (normA == 0.0 || normB == 0.0) return 0.0
        return dot / (sqrt(normA) * sqrt(normB))
    }
}
