import AVFoundation
import Darwin  // mach_absolute_time

/// Sample-accurate metronome using AVAudioEngine + AVAudioPlayerNode.
///
/// Timing: integer AVAudioFramePosition accumulation — nextBeatSampleTime += samplesPerBeat.
/// A DispatchSourceTimer fires every 50ms and pre-schedules all slots within a 400ms window.
class SampleAccurateMetronome {

    // MARK: - Configuration

    private struct Config {
        var bpm: Int
        var beatsPerBar: Int
        var patternSlots: [Int]  // SlotType indices: 0=accent, 1=normal, 2=rest

        var samplesPerBeat: AVAudioFramePosition {
            AVAudioFramePosition(44100.0 * 60.0 / Double(bpm))
        }
        var slotsPerBeat: Int { patternSlots.count }
    }

    static let sampleRate: Double = 44100
    private static let lookaheadSamples: AVAudioFramePosition = AVAudioFramePosition(44100.0 * 0.4) // 400ms
    private static let schedulerIntervalMs: Int = 50

    // MARK: - State

    private let engine = AVAudioEngine()
    private let playerNode = AVAudioPlayerNode()
    private var config: Config
    private var accentBuffers: [String: AVAudioPCMBuffer] = [:]
    private var normalBuffers: [String: AVAudioPCMBuffer] = [:]
    private var currentTimbreId: String = "click"

    private var nextBeatSampleTime: AVAudioFramePosition = 0
    private var nextBeatIndex: Int = 0
    private var nextSlotIndex: Int = 0

    private var schedulerTimer: DispatchSourceTimer?
    private let audioQueue = DispatchQueue(label: "com.metronome.app.audio", qos: .userInteractive)

    var onBeat: (([String: Any]) -> Void)?

    // MARK: - Init

    init(bpm: Int, beatsPerBar: Int, patternSlots: [Int]) {
        config = Config(bpm: bpm, beatsPerBar: beatsPerBar, patternSlots: patternSlots)
    }

    // MARK: - Start / Stop

    func start() throws {
        try configureAudioSession()

        engine.attach(playerNode)
        // Use the engine's processing format so no conversion is needed for scheduling.
        let format = AVAudioFormat(standardFormatWithSampleRate: Self.sampleRate, channels: 1)!
        engine.connect(playerNode, to: engine.mainMixerNode, format: format)
        try engine.start()
        playerNode.play()

        try loadBuffers(format: format)

        // Anchor the first beat 200ms into the future from now to guarantee the
        // scheduler has time to pre-schedule it before it is due.
        let startSample = playerSampleNow() + AVAudioFramePosition(Self.sampleRate * 0.2)
        nextBeatSampleTime = startSample
        nextBeatIndex = 0
        nextSlotIndex = 0

        startSchedulerTimer()
    }

    func stop() {
        schedulerTimer?.cancel()
        schedulerTimer = nil
        playerNode.stop()
        engine.stop()
    }

    func updateConfig(bpm: Int, beatsPerBar: Int, patternSlots: [Int]) {
        audioQueue.async { [weak self] in
            guard let self else { return }
            self.config = Config(bpm: bpm, beatsPerBar: beatsPerBar, patternSlots: patternSlots)
            if self.nextBeatIndex >= beatsPerBar { self.nextBeatIndex = 0 }
        }
    }

    func setTimbre(_ timbreId: String) {
        audioQueue.async { [weak self] in self?.currentTimbreId = timbreId }
    }

    // MARK: - Scheduling

    private func startSchedulerTimer() {
        let timer = DispatchSource.makeTimerSource(queue: audioQueue)
        timer.schedule(deadline: .now(), repeating: .milliseconds(Self.schedulerIntervalMs))
        timer.setEventHandler { [weak self] in self?.scheduleAhead() }
        timer.resume()
        schedulerTimer = timer
    }

    private func scheduleAhead() {
        let now = playerSampleNow()
        let horizon = now + Self.lookaheadSamples

        while nextSlotAbsoluteSample() <= horizon {
            let beatIndex  = nextBeatIndex
            let slotIndex  = nextSlotIndex
            let sampleTime = nextSlotAbsoluteSample()
            let raw        = config.patternSlots[slotIndex]

            let slotType: Int
            if beatIndex == 0 && slotIndex == 0 {
                slotType = raw == 2 ? 2 : 0
            } else {
                slotType = raw == 0 ? 1 : raw
            }

            if slotType != 2 {
                scheduleSlot(sampleTime: sampleTime, slotType: slotType,
                             beatIndex: beatIndex, slotIndex: slotIndex)
            }

            nextSlotIndex += 1
            if nextSlotIndex >= config.slotsPerBeat {
                nextSlotIndex = 0
                nextBeatSampleTime += config.samplesPerBeat
                nextBeatIndex = (nextBeatIndex + 1) % config.beatsPerBar
            }
        }
    }

    /// Absolute sample position of the current pending slot.
    private func nextSlotAbsoluteSample() -> AVAudioFramePosition {
        let n = AVAudioFramePosition(config.slotsPerBeat)
        return nextBeatSampleTime + AVAudioFramePosition(nextSlotIndex) * config.samplesPerBeat / n
    }

    private func scheduleSlot(sampleTime: AVAudioFramePosition, slotType: Int,
                               beatIndex: Int, slotIndex: Int) {
        let buf: AVAudioPCMBuffer?
        if slotType == 0 {
            buf = accentBuffers[currentTimbreId] ?? accentBuffers["click"]
        } else {
            buf = normalBuffers[currentTimbreId] ?? normalBuffers["click"]
        }
        guard let buf else { return }

        let audioTime = AVAudioTime(sampleTime: sampleTime, atRate: Self.sampleRate)
        let capBeat = beatIndex, capSlot = slotIndex, capType = slotType

        playerNode.scheduleBuffer(buf, at: audioTime, options: [],
            completionCallbackType: .dataPlayedBack) { [weak self] _ in
            guard let self, capSlot == 0 else { return }
            DispatchQueue.main.async {
                self.onBeat?(["beatIndex": capBeat, "slotIndex": capSlot, "slotType": capType])
            }
        }
    }

    // MARK: - Current player sample position

    /// Returns the player node's current sample time. Returns a time based on
    /// the engine's output node when the player node hasn't rendered yet.
    private func playerSampleNow() -> AVAudioFramePosition {
        // Prefer player node's own timeline once it has started rendering.
        if let nodeTime = playerNode.lastRenderTime,
           nodeTime.isSampleTimeValid,
           let playerTime = playerNode.playerTime(forNodeTime: nodeTime),
           playerTime.isSampleTimeValid {
            return playerTime.sampleTime
        }

        // Fall back to engine output node — always valid once engine.start() returns.
        if let outputTime = engine.outputNode.lastRenderTime,
           outputTime.isSampleTimeValid {
            return outputTime.sampleTime
        }

        // Last resort: convert host time to sample time manually.
        let hostTime = mach_absolute_time()
        var tb = mach_timebase_info_data_t()
        mach_timebase_info(&tb)
        let nanos = Double(hostTime) * Double(tb.numer) / Double(tb.denom)
        return AVAudioFramePosition(nanos * Self.sampleRate / 1_000_000_000.0)
    }

    // MARK: - Audio session

    private func configureAudioSession() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
        try session.setActive(true)
    }

    // MARK: - Buffer loading

    private func loadBuffers(format: AVAudioFormat) throws {
        let base = Bundle.main.bundlePath + "/flutter_assets/assets/sounds/"
        let timbres: [(id: String, accent: String, normal: String?)] = [
            ("click", "click.flac",       nil),
            ("drum",  "drum_accent.flac", "drum_normal.flac"),
        ]
        for t in timbres {
            if let buf = loadFlac(path: base + t.accent, targetFormat: format) {
                accentBuffers[t.id] = buf
                if t.normal == nil {
                    normalBuffers[t.id] = scaledCopy(buf, volume: 0.6)
                }
            } else {
                print("[MetronomeAudio] failed to load accent: \(t.accent)")
            }
            if let nf = t.normal,
               let buf = loadFlac(path: base + nf, targetFormat: format) {
                normalBuffers[t.id] = buf
            }
        }
        print("[MetronomeAudio] buffers loaded — accent keys: \(accentBuffers.keys), normal keys: \(normalBuffers.keys)")
    }

    private func loadFlac(path: String, targetFormat: AVAudioFormat) -> AVAudioPCMBuffer? {
        let url = URL(fileURLWithPath: path)
        guard let file = try? AVAudioFile(forReading: url) else {
            print("[MetronomeAudio] AVAudioFile open failed: \(path)")
            return nil
        }

        // Read into the file's native format first.
        let nativeFrames = AVAudioFrameCount(file.length)
        guard let srcBuf = AVAudioPCMBuffer(pcmFormat: file.processingFormat,
                                             frameCapacity: nativeFrames) else { return nil }
        do { try file.read(into: srcBuf) } catch {
            print("[MetronomeAudio] read failed: \(error)")
            return nil
        }

        // If formats match, return directly.
        if file.processingFormat == targetFormat { return srcBuf }

        // Convert to engine's processing format.
        guard let converter = AVAudioConverter(from: file.processingFormat, to: targetFormat) else {
            print("[MetronomeAudio] converter nil: \(file.processingFormat) → \(targetFormat)")
            return nil
        }

        let targetFrames = AVAudioFrameCount(
            Double(nativeFrames) * targetFormat.sampleRate / file.processingFormat.sampleRate
        ) + 1
        guard let dstBuf = AVAudioPCMBuffer(pcmFormat: targetFormat,
                                             frameCapacity: targetFrames) else { return nil }

        var srcConsumed = false
        var convError: NSError?
        converter.convert(to: dstBuf, error: &convError) { _, outStatus in
            if srcConsumed {
                outStatus.pointee = .endOfStream
                return nil
            }
            srcConsumed = true
            outStatus.pointee = .haveData
            return srcBuf
        }
        if let e = convError {
            print("[MetronomeAudio] convert error: \(e)")
            return nil
        }
        return dstBuf
    }

    private func scaledCopy(_ src: AVAudioPCMBuffer, volume: Float) -> AVAudioPCMBuffer {
        let dst = AVAudioPCMBuffer(pcmFormat: src.format, frameCapacity: src.frameCapacity)!
        dst.frameLength = src.frameLength
        for ch in 0..<Int(src.format.channelCount) {
            guard let s = src.floatChannelData?[ch],
                  let d = dst.floatChannelData?[ch] else { continue }
            for i in 0..<Int(src.frameLength) { d[i] = s[i] * volume }
        }
        return dst
    }
}
