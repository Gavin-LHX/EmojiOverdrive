import SwiftUI
import UIKit

struct WindowSceneReader: UIViewRepresentable {
    let onResolve: @MainActor (UIWindowScene?) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onResolve: onResolve)
    }

    func makeUIView(context: Context) -> SceneProbeView {
        let view = SceneProbeView()
        let coordinator = context.coordinator
        view.onWindowSceneChange = { scene in
            coordinator.schedule(scene)
        }
        return view
    }

    func updateUIView(_ uiView: SceneProbeView, context: Context) {
        context.coordinator.onResolve = onResolve
        uiView.resolve()
    }

    @MainActor
    final class Coordinator {
        var onResolve: @MainActor (UIWindowScene?) -> Void
        private var lastSceneIdentifier: ObjectIdentifier?

        init(onResolve: @escaping @MainActor (UIWindowScene?) -> Void) {
            self.onResolve = onResolve
        }

        func schedule(_ scene: UIWindowScene?) {
            let identifier = scene.map(ObjectIdentifier.init)
            guard identifier != lastSceneIdentifier else { return }
            lastSceneIdentifier = identifier

            Task { @MainActor [weak self, weak scene] in
                self?.onResolve(scene)
            }
        }
    }

    final class SceneProbeView: UIView {
        var onWindowSceneChange: (@MainActor (UIWindowScene?) -> Void)?

        override func didMoveToWindow() {
            super.didMoveToWindow()
            resolve()
        }

        func resolve() {
            onWindowSceneChange?(window?.windowScene)
        }
    }
}
