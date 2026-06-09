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

        job = CoroutineScope(audioDispatcher).launch {
            loadBuffers()
            audioTrack?.play()
            streamAudio()
        }
    }

    fun stop() {
        job?.cancel()
        job = null
        val track = audioTrack
        audioTrack = null
        track?.stop()
        track?.release()
    }

    fun updateConfig(bpm: Int, beatsPerBar: Int, patternSlots: List<Int>) {
        config = Config(bpm, beatsPerBar, patternSlots)
    }

    fun setTimbre(timbreId: String) {
        currentTimbreId = timbreId
    }

    // MARK: - Streaming loop

    private data class ActiveClip(val buf: FloatArray, var offset: Int)

    private suspend fun streamAudio() = withContext(audioDispatcher) {
        val chunkSize = 512
        val chunk = FloatArray(chunkSize)
        var cursor = 0L          // next frame to render
        var nextBeatFrame = 0L
        var nextBeatIndex = 0
        var nextSlotIndex = 0
        val activeClips = mutableListOf<ActiveClip>()

        while (isActive) {
            val snap = config
            val timbreId = currentTimbreId
            val accentBuf = accentBuffers[timbreId] ?: accentBuffers["click"] ?: FloatArray(0)
            val normalBuf = normalBuffers[timbreId] ?: normalBuffers["click"] ?: FloatArray(0)

            // Queue all slots that start within this chunk.
            val chunkEnd = cursor + chunkSize
            while (true) {
                val slotFrame = nextBeatFrame + nextSlotIndex.toLong() * snap.samplesPerBeat / snap.slotsPerBeat
                if (slotFrame >= chunkEnd) break
                val raw = snap.patternSlots[nextSlotIndex]
                val slotType = when {
                    nextBeatIndex == 0 && nextSlotIndex == 0 -> if (raw == 2) 2 else 0
                    raw == 0 -> 1
                    else -> raw
                }
                if (slotType != 2) {
                    val buf = if (slotType == 0) accentBuf else normalBuf
                    if (buf.isNotEmpty()) {
                        // offset accounts for frames already past before this chunk started
                        val skipFrames = (cursor - slotFrame).toInt().coerceAtLeast(0)
                        activeClips.add(ActiveClip(buf, skipFrames))
                    }
                }
                if (nextSlotIndex == 0) {
                    val beatIdx = nextBeatIndex
                    val capturedType = slotType
                    val markerFrame = (slotFrame - cursor).toInt().coerceAtLeast(0)
                    val markerPos = (cursor + markerFrame).toInt()
                    audioTrack?.setNotificationMarkerPosition(markerPos)
                    audioTrack?.setPlaybackPositionUpdateListener(object : AudioTrack.OnPlaybackPositionUpdateListener {
                        override fun onMarkerReached(track: AudioTrack) {
                            android.os.Handler(android.os.Looper.getMainLooper()).post {
                                onBeat?.invoke(mapOf("beatIndex" to beatIdx, "slotIndex" to 0, "slotType" to capturedType))
                            }
                            track.setPlaybackPositionUpdateListener(null)
                        }
                        override fun onPeriodicNotification(track: AudioTrack) {}
                    })
                }
                nextSlotIndex++
                if (nextSlotIndex >= snap.slotsPerBeat) {
                    nextSlotIndex = 0
                    nextBeatFrame += snap.samplesPerBeat
                    nextBeatIndex = (nextBeatIndex + 1) % snap.beatsPerBar
                }
            }

            // Mix active clips into chunk.
            chunk.fill(0f)
            val toRemove = mutableListOf<ActiveClip>()
            for (clip in activeClips) {
                val frames = minOf(chunkSize, clip.buf.size - clip.offset)
                for (i in 0 until frames) chunk[i] += clip.buf[clip.offset + i]
                clip.offset += frames
                if (clip.offset >= clip.buf.size) toRemove.add(clip)
            }
            activeClips.removeAll(toRemove)

            writeBlocking(chunk)
            cursor += chunkSize
        }
    }

    private fun writeBlocking(data: FloatArray) {
        var written = 0
        try {
            while (written < data.size) {
                val result = audioTrack?.write(data, written, data.size - written, AudioTrack.WRITE_BLOCKING) ?: break
                if (result <= 0) break
                written += result
            }
        } catch (_: IllegalStateException) {
            // AudioTrack was released while writing — normal during stop()
        }
    }

    // MARK: - Buffer loading

    private suspend fun loadBuffers() {
        data class TimbreDef(val id: String, val accentFile: String, val normalFile: String?)
        val timbres = listOf(
            TimbreDef("click", "flutter_assets/assets/sounds/click.flac", null),
            TimbreDef("drum", "flutter_assets/assets/sounds/drum_accent.flac",
                              "flutter_assets/assets/sounds/drum_normal.flac"),
        )
        for (t in timbres) {
            decodeFLAC(t.accentFile)?.let { pcm ->
                accentBuffers[t.id] = pcm
                android.util.Log.d("AudioTrackMetronome", "loaded accent[${t.id}]: ${pcm.size} samples")
                if (t.normalFile == null) {
                    normalBuffers[t.id] = pcm.map { it * 0.6f }.toFloatArray()
                }
            } ?: android.util.Log.e("AudioTrackMetronome", "FAILED accent[${t.id}]: ${t.accentFile}")
            t.normalFile?.let { nf ->
                decodeFLAC(nf)?.let { normalBuffers[t.id] = it
                    android.util.Log.d("AudioTrackMetronome", "loaded normal[${t.id}]: ${it.size} samples")
                } ?: android.util.Log.e("AudioTrackMetronome", "FAILED normal[${t.id}]: $nf")
            }
        }
        android.util.Log.d("AudioTrackMetronome", "buffers ready — accent:${accentBuffers.keys} normal:${normalBuffers.keys}")
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
            var inputDone = false
            var outputDone = false
            var outputFormat = codec.outputFormat

            while (!outputDone) {
                if (!inputDone) {
                    val inIdx = codec.dequeueInputBuffer(10_000)
                    if (inIdx >= 0) {
                        val inBuf = codec.getInputBuffer(inIdx)!!
                        val sampleSize = extractor.readSampleData(inBuf, 0)
                        if (sampleSize < 0) {
                            codec.queueInputBuffer(inIdx, 0, 0, 0, MediaCodec.BUFFER_FLAG_END_OF_STREAM)
                            inputDone = true
                        } else {
                            codec.queueInputBuffer(inIdx, 0, sampleSize, extractor.sampleTime, 0)
                            extractor.advance()
                        }
                    }
                }
                val outIdx = codec.dequeueOutputBuffer(bufInfo, 10_000)
                when {
                    outIdx == MediaCodec.INFO_OUTPUT_FORMAT_CHANGED -> outputFormat = codec.outputFormat
                    outIdx >= 0 -> {
                        val outBuf = codec.getOutputBuffer(outIdx)!!
                        val bytes = ByteArray(bufInfo.size)
                        outBuf.get(bytes)
                        pcmChunks.add(bytes)
                        codec.releaseOutputBuffer(outIdx, false)
                        if (bufInfo.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM != 0) outputDone = true
                    }
                }
            }
            codec.stop(); codec.release(); extractor.release()

            val pcmEncoding = if (outputFormat.containsKey(MediaFormat.KEY_PCM_ENCODING))
                outputFormat.getInteger(MediaFormat.KEY_PCM_ENCODING)
            else
                AudioFormat.ENCODING_PCM_16BIT

            val total = pcmChunks.sumOf { it.size }
            val bytesPerSample = if (pcmEncoding == AudioFormat.ENCODING_PCM_FLOAT) 4 else 2
            val floats = FloatArray(total / bytesPerSample)
            var pos = 0
            for (chunk in pcmChunks) {
                val buf = ByteBuffer.wrap(chunk).order(java.nio.ByteOrder.LITTLE_ENDIAN)
                if (pcmEncoding == AudioFormat.ENCODING_PCM_FLOAT) {
                    while (buf.remaining() >= 4) floats[pos++] = buf.float
                } else {
                    while (buf.remaining() >= 2) floats[pos++] = buf.short / 32768f
                }
            }
            floats
        } catch (e: Exception) {
            android.util.Log.e("AudioTrackMetronome", "decodeFLAC failed: $assetPath", e)
            null
        }
    }
}
