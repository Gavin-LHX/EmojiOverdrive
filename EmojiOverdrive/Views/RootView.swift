import SwiftUI
import UIKit

struct RootView: View {
    @EnvironmentObject private var experience: ExperienceController
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityDimFlashingLights) private var dimFlashingLights
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    @State private var windowScene: UIWindowScene?
    @State private var isShowingStartConfirmation = false

    var body: some View {
        Group {
            if experience.phase == .warning {
                WarningView(acknowledge: experience.acknowledgeWarning)
            } else {
                experienceView
            }
        }
        .background(
            WindowSceneReader { scene in
                windowScene = scene
            }
            .frame(width: 0, height: 0)
        )
        .allowedDynamicRange(experience.isRunning && !dimFlashingLights ? .high : .standard)
        .persistentSystemOverlays(.hidden)
        .onAppear(perform: synchronizeAccessibility)
        .onChange(of: reduceMotion) { _, _ in synchronizeAccessibility() }
        .onChange(of: dimFlashingLights) { _, _ in synchronizeAccessibility() }
        .onChange(of: reduceTransparency) { _, _ in synchronizeAccessibility() }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase != .active {
                experience.handleSceneInactive()
            }
        }
        .onDisappear {
            experience.handleSceneInactive()
        }
        .confirmationDialog(
            "启动强刺激体验？",
            isPresented: $isShowingStartConfirmation,
            titleVisibility: .visible
        ) {
            Button("启动 \(SafetyPolicy.maximumSessionSeconds) 秒", role: .destructive) {
                Task {
                    await experience.start(windowScene: windowScene)
                }
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("请把设备远离眼睛。应用会应用控制台中已启用的亮度、触觉和手电筒选项。")
        }
    }

    private var experienceView: some View {
        ZStack(alignment: .bottom) {
            MetalBackgroundView(snapshot: experience.renderSnapshot)
                .ignoresSafeArea()

            EmojiOrbitCanvas(snapshot: experience.renderSnapshot)
                .ignoresSafeArea()

            LinearGradient(
                colors: [.clear, .black.opacity(0.07), .black.opacity(0.62)],
                startPoint: .center,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            .allowsHitTesting(false)

            ControlPanel {
                isShowingStartConfirmation = true
            }
        }
        .background(Color.black)
    }

    private func synchronizeAccessibility() {
        experience.updateSafety(
            reduceMotion: reduceMotion,
            dimFlashingLights: dimFlashingLights,
            reduceTransparency: reduceTransparency
        )
    }
}

#Preview {
    RootView()
        .environmentObject(ExperienceController())
}
