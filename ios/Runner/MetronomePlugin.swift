import Flutter
import UIKit

/// Flutter plugin registering MethodChannel + EventChannel for sample-accurate metronome.
///
/// MethodChannel 'com.metronome.app/metronome':
///   start(bpm, beatsPerBar, patternSlots, timbreId)
///   stop()
///   updateConfig(bpm, beatsPerBar, patternSlots)
///   setTimbre(timbreId)
///
/// EventChannel 'com.metronome.app/metronome/beats':
///   emits {beatIndex: Int, slotIndex: Int, slotType: Int} on each slot
class MetronomePlugin: NSObject, FlutterPlugin, FlutterStreamHandler {

    private var metronome: SampleAccurateMetronome?
    private var eventSink: FlutterEventSink?

    // MARK: - Registration via FlutterPlugin protocol (used by FlutterPluginRegistry)

    static func register(with registrar: FlutterPluginRegistrar) {
        let plugin = MetronomePlugin()
        plugin.setupChannels(messenger: registrar.messenger())
        registrar.publish(plugin)
    }

    // MARK: - Registration via direct messenger (used by applicationRegistrar)

    static func register(messenger: FlutterBinaryMessenger) {
        let plugin = MetronomePlugin()
        plugin.setupChannels(messenger: messenger)
    }

    // MARK: - Channel setup

    private func setupChannels(messenger: FlutterBinaryMessenger) {
        let methodChannel = FlutterMethodChannel(
            name: "com.metronome.app/metronome",
            binaryMessenger: messenger)
        let eventChannel = FlutterEventChannel(
            name: "com.metronome.app/metronome/beats",
            binaryMessenger: messenger)

        methodChannel.setMethodCallHandler(handle)
        eventChannel.setStreamHandler(self)
    }

    // MARK: - MethodChannel handler

    func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "start":
            guard let args = call.arguments as? [String: Any],
                  let bpm = args["bpm"] as? Int,
                  let beatsPerBar = args["beatsPerBar"] as? Int,
                  let patternSlots = args["patternSlots"] as? [Int] else {
                result(FlutterError(code: "BAD_ARGS", message: "start requires bpm/beatsPerBar/patternSlots", details: nil))
                return
            }
            let timbreId = args["timbreId"] as? String ?? "click"
            let m = SampleAccurateMetronome(bpm: bpm, beatsPerBar: beatsPerBar, patternSlots: patternSlots)
            m.onBeat = { [weak self] payload in self?.eventSink?(payload) }
            m.setTimbre(timbreId)
            metronome = m
            do {
                try m.start()
                result(nil)
            } catch {
                result(FlutterError(code: "START_FAILED", message: error.localizedDescription, details: nil))
            }

        case "stop":
            metronome?.stop()
            metronome = nil
            result(nil)

        case "updateConfig":
            guard let args = call.arguments as? [String: Any],
                  let bpm = args["bpm"] as? Int,
                  let beatsPerBar = args["beatsPerBar"] as? Int,
                  let patternSlots = args["patternSlots"] as? [Int] else {
                result(FlutterError(code: "BAD_ARGS", message: "updateConfig requires bpm/beatsPerBar/patternSlots", details: nil))
                return
            }
            metronome?.updateConfig(bpm: bpm, beatsPerBar: beatsPerBar, patternSlots: patternSlots)
            result(nil)

        case "setTimbre":
            guard let args = call.arguments as? [String: Any],
                  let timbreId = args["timbreId"] as? String else {
                result(FlutterError(code: "BAD_ARGS", message: "setTimbre requires timbreId", details: nil))
                return
            }
            metronome?.setTimbre(timbreId)
            result(nil)

        default:
            result(FlutterMethodNotImplemented)
        }
    }

    // MARK: - FlutterStreamHandler

    func onListen(withArguments arguments: Any?,
                  eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        self.eventSink = events
        return nil
    }

    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        self.eventSink = nil
        return nil
    }
}
