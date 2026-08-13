import SwiftUI

struct ControlPanel: View {
    @EnvironmentObject private var experience: ExperienceController
    let start: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("EMOJI OVERDRIVE")
                        .font(.system(size: 17, weight: .black, design: .monospaced))
                    Text(experience.isRunning ? "污染进行中 · \(experience.secondsRemaining)s" : "就绪 · 二次确认后启动")
                        .font(.caption.monospacedDigit().weight(.bold))
                        .foregroundStyle(experience.isRunning ? .yellow : .white.opacity(0.64))
                }
                Spacer()
                Text("\(Int(experience.settings.bpm))")
                    .font(.system(size: 32, weight: .black, design: .rounded).monospacedDigit())
                    .foregroundStyle(.cyan)
                    .contentTransition(.numericText())
                Text("BPM")
                    .font(.caption2.weight(.black))
                    .foregroundStyle(.cyan.opacity(0.75))
            }

            if !experience.isRunning {
                VStack(spacing: 11) {
                    LabeledSlider(
                        title: "节拍",
                        value: $experience.settings.bpm,
                        range: 180...300,
                        format: { "\(Int($0)) BPM" }
                    )
                    LabeledSlider(
                        title: "精神污染",
                        value: $experience.settings.intensity,
                        range: 0.15...1,
                        format: { "\(Int($0 * 100))%" }
                    )
                    LabeledSlider(
                        title: "Emoji 密度",
                        value: $experience.settings.orbitDensity,
                        range: 0.25...1,
                        format: { "\(Int($0 * 100))%" }
                    )

                    Toggle("触觉节拍", isOn: $experience.settings.hapticsEnabled)
                    Toggle(
                        "主动提升至最高亮度",
                        isOn: Binding(
                            get: { experience.settings.brightnessBoostEnabled },
                            set: experience.setBrightnessBoost
                        )
                    )
                    .disabled(experience.safety.dimFlashingLights)

                    Toggle(
                        "后置手电筒低功率常亮",
                        isOn: Binding(
                            get: { experience.settings.torchEnabled },
                            set: experience.setTorchEnabled
                        )
                    )
                    .disabled(experience.safety.dimFlashingLights)

                    Toggle("低刺激模式", isOn: $experience.settings.reducedStimulus)
                }
                .font(.subheadline.weight(.semibold))
            }

            if let message = experience.statusMessage {
                Text(message)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.yellow)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityLabel("状态：\(message)")
            }

            Button(action: experience.isRunning ? { experience.stop() } : start) {
                Label(
                    experience.isRunning ? "立即停止" : "启动 45 秒污染",
                    systemImage: experience.isRunning ? "stop.fill" : "bolt.fill"
                )
                .font(.headline.weight(.black))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .tint(experience.isRunning ? .red : .pink)
            .keyboardShortcut(.escape, modifiers: [])
            .accessibilityHint(experience.isRunning ? "恢复亮度并停止手电筒与触觉" : "启动前会应用你选择的硬件效果")
        }
        .padding(18)
        .background(panelBackground)
        .padding(.horizontal, 14)
        .padding(.bottom, 10)
    }

    @ViewBuilder
    private var panelBackground: some View {
        if experience.safety.reduceTransparency {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(Color.black.opacity(0.94))
                .overlay(
                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .stroke(.white.opacity(0.18), lineWidth: 1)
                )
        } else {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .stroke(.white.opacity(0.22), lineWidth: 1)
                )
        }
    }
}

private struct LabeledSlider: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let format: (Double) -> String

    var body: some View {
        VStack(spacing: 2) {
            HStack {
                Text(title)
                Spacer()
                Text(format(value))
                    .monospacedDigit()
                    .foregroundStyle(.cyan)
            }
            Slider(value: $value, in: range)
                .tint(.pink)
                .accessibilityValue(format(value))
        }
    }
}

