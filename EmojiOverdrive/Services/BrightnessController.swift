import UIKit

@MainActor
final class BrightnessController {
    private var screen: UIScreen?
    private var originalBrightness: CGFloat?

    @discardableResult
    func activate(on windowScene: UIWindowScene?, target: CGFloat) -> Bool {
        guard let targetScreen = windowScene?.screen else { return false }

        if originalBrightness == nil {
            originalBrightness = targetScreen.brightness
            screen = targetScreen
        }

        targetScreen.brightness = target.clamped(to: 0...1)
        return true
    }

    func restore() {
        guard let originalBrightness else { return }
        screen?.brightness = originalBrightness
        self.originalBrightness = nil
        screen = nil
    }
}
