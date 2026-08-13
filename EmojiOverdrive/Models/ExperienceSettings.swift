import Foundation

enum SafetyPolicy {
    static let minimumBPM = 180.0
    static let maximumBPM = 300.0
    static let maximumSessionSeconds = 45
    static let maximumTorchLevel: Float = 0.12
    static let maximumHapticIntensity = 0.72
    static let dimFlashingIntensityCap = 0.34
    static let reducedStimulusIntensityCap = 0.45

    static func remainingSeconds(atElapsed elapsed: TimeInterval) -> Int {
        max(0, maximumSessionSeconds - Int(floor(max(0, elapsed))))
    }

    static func hasReachedSessionLimit(elapsed: TimeInterval) -> Bool {
        elapsed >= TimeInterval(maximumSessionSeconds)
    }
}

struct ExperienceSettings: Equatable, Sendable {
    var bpm: Double = 296
    var intensity: Double = 0.82
    var orbitDensity: Double = 0.82
    var hapticsEnabled = true
    var brightnessBoostEnabled = false
    var torchEnabled = false
    var reducedStimulus = false

    var clampedBPM: Double { bpm.clamped(to: SafetyPolicy.minimumBPM...SafetyPolicy.maximumBPM) }
    var clampedIntensity: Double { intensity.clamped(to: 0.15...1) }
    var clampedDensity: Double { orbitDensity.clamped(to: 0.25...1) }
}

struct SafetyOverrides: Equatable, Sendable {
    var reduceMotion = false
    var dimFlashingLights = false
    var reduceTransparency = false

    var requiresReducedExperience: Bool {
        reduceMotion || dimFlashingLights
    }
}

struct RenderSnapshot: Equatable, Sendable {
    let isRunning: Bool
    let elapsedAtSnapshot: TimeInterval
    let capturedAt: Date
    let sessionDuration: TimeInterval
    let bpm: Double
    let intensity: Double
    let orbitDensity: Double
    let reduceMotion: Bool
    let dimFlashingLights: Bool
    let reduceTransparency: Bool
    let emoji: [String]

    static let idle = RenderSnapshot(
        isRunning: false,
        elapsedAtSnapshot: 0,
        capturedAt: .distantPast,
        sessionDuration: TimeInterval(SafetyPolicy.maximumSessionSeconds),
        bpm: 296,
        intensity: 0.5,
        orbitDensity: 0.6,
        reduceMotion: true,
        dimFlashingLights: true,
        reduceTransparency: false,
        emoji: EmojiLibrary.all
    )
}

enum EmojiLibrary {
    static let all: [String] = [
        "🤯", "🫠", "👁️", "🌀", "👹", "👽", "🤡", "💥",
        "⚡️", "🪩", "🧿", "🧠", "🦷", "🔥", "🌈", "💀",
        "🐸", "🍄", "🛸", "🫨", "💫", "🦄", "👾", "😵‍💫"
    ]
}

extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
