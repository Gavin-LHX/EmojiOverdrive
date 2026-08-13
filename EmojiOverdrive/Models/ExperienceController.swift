import Combine
import Foundation
import QuartzCore
import UIKit

@MainActor
final class ExperienceController: ObservableObject {
    enum Phase: Equatable {
        case warning
        case ready
        case running
    }

    @Published private(set) var phase: Phase = .warning
    @Published var settings = ExperienceSettings()
    @Published private(set) var safety = SafetyOverrides()
    @Published private(set) var secondsRemaining = SafetyPolicy.maximumSessionSeconds
    @Published private(set) var statusMessage: String?

    let brightnessController = BrightnessController()
    let torchController = TorchController()
    let hapticsController = HapticsController()

    private var startTime: TimeInterval = 0
    private var countdownTask: Task<Void, Never>?

    init() {
        torchController.onForcedOff = { [weak self] reason in
            guard let self else { return }
            self.settings.torchEnabled = false
            if self.isRunning {
                self.stop(reason: reason + " 为降低热负载，本次体验已全部停止。")
            } else {
                self.statusMessage = reason
            }
        }
    }

    var isRunning: Bool { phase == .running }

    var renderSnapshot: RenderSnapshot {
        RenderSnapshot(
            isRunning: isRunning,
            elapsedAtSnapshot: isRunning ? max(0, CACurrentMediaTime() - startTime) : 0,
            capturedAt: Date(),
            sessionDuration: TimeInterval(SafetyPolicy.maximumSessionSeconds),
            bpm: settings.clampedBPM,
            intensity: effectiveIntensity,
            orbitDensity: settings.clampedDensity,
            reduceMotion: effectiveReduceMotion,
            dimFlashingLights: safety.dimFlashingLights,
            reduceTransparency: safety.reduceTransparency,
            emoji: EmojiLibrary.all
        )
    }

    var effectiveReduceMotion: Bool {
        settings.reducedStimulus || safety.reduceMotion
    }

    var effectiveIntensity: Double {
        if safety.dimFlashingLights { return min(settings.clampedIntensity, SafetyPolicy.dimFlashingIntensityCap) }
        if settings.reducedStimulus { return min(settings.clampedIntensity, SafetyPolicy.reducedStimulusIntensityCap) }
        return settings.clampedIntensity
    }

    func acknowledgeWarning() {
        guard phase == .warning else { return }
        phase = .ready
        statusMessage = nil
    }

    func updateSafety(
        reduceMotion: Bool,
        dimFlashingLights: Bool,
        reduceTransparency: Bool
    ) {
        safety = SafetyOverrides(
            reduceMotion: reduceMotion || dimFlashingLights,
            dimFlashingLights: dimFlashingLights,
            reduceTransparency: reduceTransparency
        )

        if dimFlashingLights {
            settings.brightnessBoostEnabled = false
            settings.torchEnabled = false
            brightnessController.restore()
            torchController.turnOff()
            statusMessage = "已遵循系统“调暗闪烁”设置：HDR 强光、最高亮度与手电筒已关闭。"
        }
    }

    func start(windowScene: UIWindowScene?) async {
        guard phase == .ready else { return }

        statusMessage = nil
        startTime = CACurrentMediaTime()
        secondsRemaining = SafetyPolicy.maximumSessionSeconds
        phase = .running
        startCountdown()

        if settings.brightnessBoostEnabled && !safety.dimFlashingLights {
            if !brightnessController.activate(on: windowScene, target: 1.0) {
                settings.brightnessBoostEnabled = false
                statusMessage = "尚未取得当前窗口屏幕，未提升亮度。请稍后重试。"
            }
        }

        if settings.hapticsEnabled {
            hapticsController.start(bpm: settings.clampedBPM, intensity: effectiveIntensity)
        }

        if settings.torchEnabled && !safety.dimFlashingLights {
            let torchResult = await torchController.requestAndTurnOn(level: 0.08)
            guard phase == .running else {
                torchController.turnOff()
                return
            }
            if let torchResult {
                statusMessage = torchResult
                settings.torchEnabled = false
            }
        }

    }

    func stop(reason: String? = nil) {
        countdownTask?.cancel()
        countdownTask = nil
        hapticsController.stop()
        torchController.turnOff()
        brightnessController.restore()

        if phase != .warning {
            phase = .ready
        }
        secondsRemaining = SafetyPolicy.maximumSessionSeconds
        if let reason {
            statusMessage = reason
        }
    }

    func handleSceneInactive() {
        hapticsController.stop()
        torchController.turnOff()
        brightnessController.restore()
        if isRunning {
            stop(reason: "应用失去焦点，所有强刺激与硬件效果已自动停止。")
        }
    }

    func setBrightnessBoost(_ enabled: Bool) {
        settings.brightnessBoostEnabled = enabled && !safety.dimFlashingLights
        if !settings.brightnessBoostEnabled { brightnessController.restore() }
    }

    func setTorchEnabled(_ enabled: Bool) {
        settings.torchEnabled = enabled && !safety.dimFlashingLights
        if !settings.torchEnabled { torchController.turnOff() }
    }

    private func startCountdown() {
        countdownTask?.cancel()
        countdownTask = Task { [weak self] in
            guard let self else { return }
            while phase == .running {
                guard !Task.isCancelled else { return }
                let elapsed = CACurrentMediaTime() - startTime
                secondsRemaining = SafetyPolicy.remainingSeconds(atElapsed: elapsed)
                if SafetyPolicy.hasReachedSessionLimit(elapsed: elapsed) {
                    stop(reason: "\(SafetyPolicy.maximumSessionSeconds) 秒安全计时结束，已自动停止。")
                    return
                }
                try? await Task.sleep(for: .milliseconds(100))
            }
        }
    }
}
