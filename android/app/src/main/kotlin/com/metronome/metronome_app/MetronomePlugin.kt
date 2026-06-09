package com.metronome.metronome_app

import android.content.Context
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

/**
 * Flutter plugin bridging MethodChannel + EventChannel to AudioTrackMetronome.
 *
 * MethodChannel  'com.metronome.app/metronome': start, stop, updateConfig, setTimbre
 * EventChannel   'com.metronome.app/metronome/beats': beat maps → Dart UI
 */
class MetronomePlugin(private val context: Context) {

    companion object {
        private const val METHOD_CHANNEL = "com.metronome.app/metronome"
        private const val EVENT_CHANNEL = "com.metronome.app/metronome/beats"

        fun registerWith(engine: FlutterEngine, context: Context) {
            val plugin = MetronomePlugin(context)
            plugin.setup(engine)
        }
    }

    private var metronome: AudioTrackMetronome? = null
    private var eventSink: EventChannel.EventSink? = null

    fun setup(engine: FlutterEngine) {
        val messenger = engine.dartExecutor.binaryMessenger

        MethodChannel(messenger, METHOD_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "start" -> {
                    val args = call.arguments as? Map<*, *>
                    val bpm = args?.get("bpm") as? Int ?: 120
                    val beatsPerBar = args?.get("beatsPerBar") as? Int ?: 4
                    @Suppress("UNCHECKED_CAST")
                    val patternSlots = (args?.get("patternSlots") as? List<*>)
                        ?.filterIsInstance<Int>() ?: listOf(0, 1, 1, 1)
                    val timbreId = args?.get("timbreId") as? String ?: "click"
                    val m = AudioTrackMetronome(context)
                    m.onBeat = { payload ->
                        eventSink?.success(payload)
                    }
                    m.updateConfig(bpm, beatsPerBar, patternSlots)
                    m.setTimbre(timbreId)
                    metronome = m
                    m.start()
                    result.success(null)
                }
                "stop" -> {
                    metronome?.onBeat = null
                    metronome?.stop()
                    metronome = null
                    result.success(null)
                }
                "updateConfig" -> {
                    val args = call.arguments as? Map<*, *>
                    val bpm = args?.get("bpm") as? Int ?: 120
                    val beatsPerBar = args?.get("beatsPerBar") as? Int ?: 4
                    @Suppress("UNCHECKED_CAST")
                    val patternSlots = (args?.get("patternSlots") as? List<*>)
                        ?.filterIsInstance<Int>() ?: listOf(0, 1, 1, 1)
                    metronome?.updateConfig(bpm, beatsPerBar, patternSlots)
                    result.success(null)
                }
                "setTimbre" -> {
                    val timbreId = (call.arguments as? Map<*, *>)?.get("timbreId") as? String ?: "click"
                    metronome?.setTimbre(timbreId)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }

        EventChannel(messenger, EVENT_CHANNEL).setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
                eventSink = events
            }
            override fun onCancel(arguments: Any?) {
                eventSink = null
            }
        })
    }
}
