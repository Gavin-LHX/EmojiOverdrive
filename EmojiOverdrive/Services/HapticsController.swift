import CoreHaptics
import Foundation

@MainActor
final class HapticsController {
    private struct Configuration {
        let bpm: Double
        let intensity: Double
    }

    private var engine: CHHapticEngine?
    private var player: (any CHHapticAdvancedPatternPlayer)?
    private var configuration: Configuration?

    private var supportsHaptics: Bool {
        CHHapticEngine.capabilitiesForHardware().supportsHaptics
    }

    func start(bpm: Double, intensity: Double) {
        stop()
        configuration = Configuration(bpm: bpm, intensity: intensity)
        rebuildPlayer()
    }

    func stop() {
        configuration = nil
        stopHardware()
    }

    private func rebuildPlayer() {
        stopHardware()
        guard supportsHaptics, let configuration else { return }

        do {
            let engine = try CHHapticEngine()
            engine.isAutoShutdownEnabled = false
            engine.stoppedHandler = { _ in }
            engine.resetHandler = { [weak self] in
                Task { @MainActor [weak self] in
                    guard self?.configuration != nil else { return }
                    self?.rebuildPlayer()
                }
            }

            let beatDuration = 60.0 / configuration.bpm.clamped(
                to: SafetyPolicy.minimumBPM...SafetyPolicy.maximumBPM
            )
            let cappedIntensity = Float(
                configuration.intensity.clamped(to: 0.15...SafetyPolicy.maximumHapticIntensity)
            )
            var events: [CHHapticEvent] = []

            // Four-beat loop. Strong and weak taps alternate; no continuous vibration.
            for beat in 0..<4 {
                let strength = beat.isMultiple(of: 2) ? cappedIntensity : cappedIntensity * 0.54
                events.append(
                    CHHapticEvent(
                        eventType: .hapticTransient,
                        parameters: [
                            CHHapticEventParameter(parameterID: .hapticIntensity, value: strength),
                            CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.72)
                        ],
                        relativeTime: beatDuration * Double(beat)
                    )
                )
            }

            let pattern = try CHHapticPattern(events: events, parameters: [])
            let player = try engine.makeAdvancedPlayer(with: pattern)
            player.loopEnabled = true
            player.loopEnd = beatDuration * 4

            self.engine = engine
            self.player = player
            try engine.start()
            try player.start(atTime: CHHapticTimeImmediate)
        } catch {
            configuration = nil
            stopHardware()
        }
    }

    private func stopHardware() {
        try? player?.stop(atTime: CHHapticTimeImmediate)
        player = nil
        engine?.stop(completionHandler: nil)
        engine = nil
    }
}
