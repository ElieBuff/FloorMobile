//
//  AudioFeed.swift
//  FloorMobile
//

import AVFoundation
import Speech

/// The microphone, as `SpeechAnalyzer` wants it: every buffer converted to the
/// analyzer's format and handed to `onInput`, with the voice's level beside
/// it for the sheet's bars.
///
/// Nonisolated on purpose: the tap runs on the audio thread, and a closure
/// built on the main actor would assert there. Started and stopped by
/// `SpeechTranscription`, on the main actor.
nonisolated final class AudioFeed {
    private let engine = AVAudioEngine()
    private let converter: Converter
    private let onInput: @Sendable (AnalyzerInput) -> Void
    private let onLevel: @Sendable (Float) -> Void

    /// - Parameters:
    ///   - format: the analyzer's format (`SpeechAnalyzer.bestAvailableAudioFormat`).
    ///   - onInput: each converted buffer, on the audio thread.
    ///   - onLevel: the voice's level, 0…1, on the audio thread.
    init(
        format: AVAudioFormat,
        onInput: @escaping @Sendable (AnalyzerInput) -> Void,
        onLevel: @escaping @Sendable (Float) -> Void
    ) throws {
        let input = engine.inputNode.outputFormat(forBus: 0)
        guard let converter = Converter(from: input, to: format) else {
            throw Failure.unsupportedFormat
        }
        self.converter = converter
        self.onInput = onInput
        self.onLevel = onLevel
    }

    /// Opens the microphone and starts feeding.
    func start() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.record, mode: .measurement, options: .duckOthers)
        try session.setActive(true, options: .notifyOthersOnDeactivation)

        let input = engine.inputNode
        let converter = converter
        let onInput = onInput
        let onLevel = onLevel
        input.installTap(onBus: 0, bufferSize: 4096, format: input.outputFormat(forBus: 0)) { buffer, _ in
            onLevel(Self.level(of: buffer))
            if let converted = converter.convert(buffer) {
                onInput(AnalyzerInput(buffer: converted))
            }
        }
        engine.prepare()
        try engine.start()
    }

    /// Closes the microphone and hands the audio session back.
    func stop() {
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    /// The buffer's loudness, 0…1: its RMS in decibels, from -50 dB (silence)
    /// to 0 dB.
    private static func level(of buffer: AVAudioPCMBuffer) -> Float {
        guard let samples = buffer.floatChannelData?[0], buffer.frameLength > 0 else { return 0 }
        let count = Int(buffer.frameLength)
        var sum: Float = 0
        for index in 0..<count {
            sum += samples[index] * samples[index]
        }
        let rms = (sum / Float(count)).squareRoot()
        let decibels = 20 * log10(max(rms, 0.000_001))
        return min(max((decibels + 50) / 50, 0), 1)
    }
}

nonisolated extension AudioFeed {
    /// Why the microphone could not be fed to the analyzer.
    enum Failure: Error {
        /// The microphone's format cannot be converted to the analyzer's.
        case unsupportedFormat
    }

    /// Converts the microphone's buffers to the analyzer's format.
    ///
    /// `@unchecked Sendable`: `AVAudioConverter` is not `Sendable`, but this one
    /// is only ever used from the tap, one buffer after the other on the audio
    /// thread.
    final class Converter: @unchecked Sendable {
        private let converter: AVAudioConverter?
        private let target: AVAudioFormat

        init?(from source: AVAudioFormat, to target: AVAudioFormat) {
            self.target = target
            if source == target {
                converter = nil
            } else {
                guard let converter = AVAudioConverter(from: source, to: target) else { return nil }
                self.converter = converter
            }
        }

        /// `buffer` in the target format, or `nil` if the conversion failed —
        /// a dropped buffer, not a stopped feed.
        func convert(_ buffer: AVAudioPCMBuffer) -> AVAudioPCMBuffer? {
            guard let converter else { return buffer }
            let ratio = target.sampleRate / buffer.format.sampleRate
            let capacity = AVAudioFrameCount((Double(buffer.frameLength) * ratio).rounded(.up))
            guard let output = AVAudioPCMBuffer(pcmFormat: target, frameCapacity: capacity) else { return nil }

            let consumed = Consumed()
            var error: NSError?
            converter.convert(to: output, error: &error) { _, status in
                guard !consumed.value else {
                    status.pointee = .noDataNow
                    return nil
                }
                consumed.value = true
                status.pointee = .haveData
                return buffer
            }
            return error == nil ? output : nil
        }

        /// Whether the one input buffer was handed to the converter already.
        private final class Consumed: @unchecked Sendable {
            var value = false
        }
    }
}
