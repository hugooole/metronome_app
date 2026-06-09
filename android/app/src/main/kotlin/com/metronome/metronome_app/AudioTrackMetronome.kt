package com.metronome.metronome_app

import android.content.Context
import android.media.*
import kotlinx.coroutines.*
import java.nio.ByteBuffer
import kotlin.math.min

/**
 * AudioTrack streaming metronome with sample-accurate beat placement.
 *
 * Each beat is positioned by writing silence up to the next beat boundary in the
 * PCM stream, then writing the click buffer. Integer sample arithmetic prevents drift.
 *
 * Uses a dedicated single-thread coroutine context — NOT Dispatchers.IO — because
 * WRITE_BLOCKING must not be preempted by other coroutines.
 */
class AudioTrackMetronome(private val context: Context) {

    companion object {
        private const val SAMPLE_RATE = 44100
    }

    private data class Config(
        val bpm: Int,
        val beatsPerBar: Int,
        val patternSlots: List<Int>,  // SlotType indices: 0=accent, 1=normal, 2=rest
    ) {
        val samplesPerBeat: Int get() = SAMPLE_RATE * 60 / bpm
        val slotsPerBeat: Int get() = patternSlots.size
    }

    @Volatile private var config = Config(120, 4, listOf(0, 1, 1, 1))
    @Volatile private var currentTimbreId = "click"

    private val accentBuffers = mutableMapOf<String, FloatArray>()
    private val normalBuffers = mutableMapOf<String, FloatArray>()

    private val audioDispatcher = newSingleThreadContext("MetronomeAudio")
    private var job: Job? = null
    private var audioTrack: AudioTrack? = null

    var onBeat: ((Map<String, Any>) -> Unit)? = null

    // MARK: - Start / Stop

    fun start() {
        loadBuffers()

        val minBuf = AudioTrack.getMinBufferSize(
            SAMPLE_RATE, AudioFormat.CHANNEL_OUT_MONO, AudioFormat.ENCODING_PCM_FLOAT)
        val bufSize = maxOf(minBuf * 2, 8192)

        audioTrack = AudioTrack.Builder()
            .setAudioAttributes(AudioAttributes.Builder()
                .setUsage(AudioAttributes.USAGE_MEDIA)
                .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC)
                .build())
            .setAudioFormat(AudioFormat.Builder()
                .setSampleRate(SAMPLE_RATE)
                .setEncoding(AudioFormat.ENCODING_PCM_FLOAT)
                .setChannelMask(AudioFormat.CHANNEL_OUT_MONO)
                .build())
            .setBufferSizeInBytes(bufSize)
            .setTransferMode(AudioTrack.MODE_STREAM)
            .build()
            .also { it.play() }

        job = CoroutineScope(audioDispatcher).launch { streamAudio() }
    }

    fun stop() {
        job?.cancel()
        job = null
        audioTrack?.stop()
        audioTrack?.release()
        audioTrack = null
    }

    fun updateConfig(bpm: Int, beatsPerBar: Int, patternSlots: List<Int>) {
        config = Config(bpm, beatsPerBar, patternSlots)
    }

    fun setTimbre(timbreId: String) {
        currentTimbreId = timbreId
    }

    // MARK: - Streaming loop

    private suspend fun streamAudio() = withContext(audioDispatcher) {
        var totalFramesWritten = 0L
        var totalBeats = 0L
        var nextBeatIndex = 0

        while (isActive) {
            val snap = config
            val timbreId = currentTimbreId

            val nextBeatFrame = (totalBeats + 1) * snap.samplesPerBeat

            // Write silence up to the next beat boundary (minus click lead-in).
            val accentBuf = accentBuffers[timbreId] ?: accentBuffers["click"] ?: FloatArray(0)
            val normalBuf = normalBuffers[timbreId] ?: normalBuffers["click"] ?: FloatArray(0)

            // Schedule each slot within this beat.
            for (slotIdx in 0 until snap.slotsPerBeat) {
                val slotFrame = nextBeatFrame + slotIdx.toLong() * snap.samplesPerBeat / snap.slotsPerBeat
                val raw = snap.patternSlots[slotIdx]
                val slotType = when {
                    nextBeatIndex == 0 && slotIdx == 0 -> if (raw == 2) 2 else 0
                    raw == 0 -> 1
                    else -> raw
                }

                val clickBuf: FloatArray = if (slotType == 0) accentBuf else if (slotType == 1) normalBuf else FloatArray(0)

                if (slotType != 2 && clickBuf.isNotEmpty()) {
                    // Write silence up to (slotFrame - clickBuf.size) so click lands at slotFrame.
                    val clickStart = slotFrame - clickBuf.size
                    val silenceCount = (clickStart - totalFramesWritten).toInt().coerceAtLeast(0)
                    if (silenceCount > 0) {
                        writeBlocking(FloatArray(silenceCount))
                        totalFramesWritten += silenceCount
                    }
                    writeBlocking(clickBuf)
                    totalFramesWritten += clickBuf.size
                }

                if (slotIdx == 0) {
                    val beatIdx = nextBeatIndex
                    val handler = android.os.Handler(android.os.Looper.getMainLooper())
                    handler.post {
                        onBeat?.invoke(mapOf("beatIndex" to beatIdx, "slotIndex" to 0, "slotType" to slotType))
                    }
                }
            }

            // Write silence to fill the rest of this beat.
            val endOfBeat = nextBeatFrame + snap.samplesPerBeat
            val tailSilence = (endOfBeat - totalFramesWritten).toInt().coerceAtLeast(0)
            if (tailSilence > 0) {
                writeBlocking(FloatArray(tailSilence))
                totalFramesWritten += tailSilence
            }

            nextBeatIndex = (nextBeatIndex + 1) % snap.beatsPerBar
            totalBeats++
        }
    }

    private fun writeBlocking(data: FloatArray) {
        var written = 0
        while (written < data.size) {
            val result = audioTrack?.write(data, written, data.size - written, AudioTrack.WRITE_BLOCKING) ?: break
            if (result <= 0) break
            written += result
        }
    }

    // MARK: - Buffer loading

    private fun loadBuffers() {
        data class TimbreDef(val id: String, val accentFile: String, val normalFile: String?)
        val timbres = listOf(
            TimbreDef("click", "flutter_assets/assets/sounds/click.flac", null),
            TimbreDef("drum", "flutter_assets/assets/sounds/drum_accent.flac",
                              "flutter_assets/assets/sounds/drum_normal.flac"),
        )
        for (t in timbres) {
            decodeFLAC(t.accentFile)?.let { pcm ->
                accentBuffers[t.id] = pcm
                if (t.normalFile == null) {
                    normalBuffers[t.id] = pcm.map { it * 0.6f }.toFloatArray()
                }
            }
            t.normalFile?.let { nf ->
                decodeFLAC(nf)?.let { normalBuffers[t.id] = it }
            }
        }
    }

    private fun decodeFLAC(assetPath: String): FloatArray? {
        return try {
            val afd = context.assets.openFd(assetPath)
            val extractor = MediaExtractor()
            extractor.setDataSource(afd.fileDescriptor, afd.startOffset, afd.length)
            afd.close()

            var trackIndex = -1
            for (i in 0 until extractor.trackCount) {
                val fmt = extractor.getTrackFormat(i)
                if (fmt.getString(MediaFormat.KEY_MIME)?.startsWith("audio/") == true) {
                    trackIndex = i; break
                }
            }
            if (trackIndex < 0) return null
            extractor.selectTrack(trackIndex)

            val srcFormat = extractor.getTrackFormat(trackIndex)
            val mime = srcFormat.getString(MediaFormat.KEY_MIME)!!
            val codec = MediaCodec.createDecoderByType(mime)
            codec.configure(srcFormat, null, null, 0)
            codec.start()

            val pcmChunks = mutableListOf<ByteArray>()
            val bufInfo = MediaCodec.BufferInfo()
            var sawEOS = false

            while (!sawEOS) {
                val inIdx = codec.dequeueInputBuffer(10_000)
                if (inIdx >= 0) {
                    val inBuf = codec.getInputBuffer(inIdx)!!
                    val sampleSize = extractor.readSampleData(inBuf, 0)
                    if (sampleSize < 0) {
                        codec.queueInputBuffer(inIdx, 0, 0, 0, MediaCodec.BUFFER_FLAG_END_OF_STREAM)
                        sawEOS = true
                    } else {
                        codec.queueInputBuffer(inIdx, 0, sampleSize, extractor.sampleTime, 0)
                        extractor.advance()
                    }
                }
                val outIdx = codec.dequeueOutputBuffer(bufInfo, 10_000)
                if (outIdx >= 0) {
                    val outBuf = codec.getOutputBuffer(outIdx)!!
                    val bytes = ByteArray(bufInfo.size)
                    outBuf.get(bytes)
                    pcmChunks.add(bytes)
                    codec.releaseOutputBuffer(outIdx, false)
                }
            }

            codec.stop(); codec.release(); extractor.release()

            // Convert raw PCM bytes to float. Assume 16-bit signed little-endian mono.
            val total = pcmChunks.sumOf { it.size }
            val floats = FloatArray(total / 2)
            var pos = 0
            for (chunk in pcmChunks) {
                var i = 0
                while (i + 1 < chunk.size) {
                    val sample = (chunk[i].toInt() and 0xFF) or (chunk[i + 1].toInt() shl 8)
                    floats[pos++] = sample.toShort() / 32768f
                    i += 2
                }
            }
            floats
        } catch (e: Exception) {
            null
        }
    }
}
