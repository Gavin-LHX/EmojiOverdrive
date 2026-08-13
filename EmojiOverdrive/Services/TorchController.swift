import AVFoundation
import Foundation

@MainActor
final class TorchController {
    private var thermalObserver: NSObjectProtocol?
    var onForcedOff: (@MainActor (String) -> Void)?

    init() {
        let observer = NotificationCenter.default.addObserver(
            forName: ProcessInfo.thermalStateDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                let state = ProcessInfo.processInfo.thermalState
                if state == .serious || state == .critical {
                    self.turnOff()
                    self.onForcedOff?("设备温度过高，手电筒已自动关闭。")
                }
            }
        }
        thermalObserver = observer
    }

    deinit {
        if let thermalObserver {
            NotificationCenter.default.removeObserver(thermalObserver)
        }
    }

    /// Returns a user-facing error, or nil after successfully enabling the torch.
    /// Torch-only access does not create a capture input or session, so it avoids a camera prompt.
    func requestAndTurnOn(level: Float) async -> String? {
        let thermalState = ProcessInfo.processInfo.thermalState
        guard thermalState != .serious, thermalState != .critical else {
            let message = "设备温度过高，手电筒保持关闭。"
            onForcedOff?(message)
            return message
        }

        guard let device = backCamera,
              device.hasTorch,
              device.isTorchAvailable,
              device.isTorchModeSupported(.on) else {
            return "这台设备没有可用的后置手电筒（模拟器也不支持）。"
        }

        do {
            try device.lockForConfiguration()
            defer { device.unlockForConfiguration() }
            try device.setTorchModeOn(level: level.clamped(to: 0.01...SafetyPolicy.maximumTorchLevel))
            return nil
        } catch {
            return "手电筒启用失败：\(error.localizedDescription)"
        }
    }

    func turnOff() {
        guard let device = backCamera,
              device.hasTorch,
              device.isTorchModeSupported(.off) else { return }

        do {
            try device.lockForConfiguration()
            defer { device.unlockForConfiguration() }
            device.torchMode = .off
        } catch {
            // Best-effort cleanup; iOS also deactivates the torch when hardware is unavailable.
        }
    }

    private var backCamera: AVCaptureDevice? {
        AVCaptureDevice.default(
            .builtInWideAngleCamera,
            for: .video,
            position: .back
        )
    }
}
