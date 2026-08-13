import SwiftUI

struct WarningView: View {
    let acknowledge: () -> Void

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [.black, Color(red: 0.2, green: 0, blue: 0.32), .black],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 22) {
                    Image("IconArtwork")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 132, height: 132)
                        .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
                        .shadow(color: .pink.opacity(0.7), radius: 28)
                        .accessibilityHidden(true)

                    Text("⚠️ 视觉刺激警告")
                        .font(.system(size: 31, weight: .black, design: .rounded))
                        .multilineTextAlignment(.center)

                    Text("包含快速运动、强烈色彩、高亮 HDR、缩放与震动反馈。300 BPM 只用于运动节奏，不会执行 5 Hz 全屏黑白闪烁或手电筒频闪。")
                        .font(.body.weight(.semibold))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.white.opacity(0.88))

                    VStack(alignment: .leading, spacing: 12) {
                        WarningLine(icon: "eye.slash.fill", text: "光敏癫痫、偏头痛或眩晕风险人群请勿使用。")
                        WarningLine(icon: "hand.raised.fill", text: "启动不会自动提升亮度或打开手电筒；必须由你单独启用。")
                        WarningLine(icon: "timer", text: "每次体验最多 45 秒；切后台或失焦会立即停止。")
                        WarningLine(icon: "accessibility", text: "系统“减少动态效果/调暗闪烁”设置始终优先。")
                    }
                    .padding(18)
                    .background(.black.opacity(0.5), in: RoundedRectangle(cornerRadius: 22))

                    Button(action: acknowledge) {
                        Text("我已了解，进入控制台")
                            .font(.headline.weight(.black))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.pink)
                    .accessibilityHint("进入后仍需再次点击开始")
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 36)
                .frame(maxWidth: 600)
                .frame(maxWidth: .infinity)
            }
        }
    }
}

private struct WarningLine: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(.yellow)
                .frame(width: 24)
            Text(text)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white.opacity(0.9))
            Spacer(minLength: 0)
        }
    }
}

