# Emoji Overdrive

一款原生 SwiftUI + Metal 的 iOS 抽象派 Emoji 视觉合成器：最高 300 BPM 的连续缩放与轨道运动、确定性“无规则”震动、全屏宽色域渐变、Emoji 环绕、Core Haptics 节拍、可选最高屏幕亮度，以及后置手电筒低功率常亮。

> 这不是已签名 IPA。这个交付环境是 Windows，没有 Xcode 和 Apple SDK，无法编译、签名或验证可安装 IPA。压缩包是完整的 XcodeGen 源项目；最终 IPA 必须在 macOS + Xcode 上用你自己的 Apple Developer Team 生成。

## 视觉与硬件能力

- Metal `rgba16Float` 渲染、extended-linear Display P3 与 EDR layer
- SwiftUI `Canvas` Emoji 轨道、故障切片、中心节拍缩放与平滑种子噪声
- 180–300 BPM，默认 296 BPM；300 BPM 对应 5 Hz 的运动节拍
- Core Haptics 四拍循环；模拟器自动无效果
- 可选 `UIScreen.brightness = 1.0`，停止/失焦/后台时恢复原值
- 可选后置手电筒 8% 低功率常亮，上限硬编码为 12%；不做频闪
- 45 秒自动停止，始终可见的“立即停止”按钮

## 安全边界

原始概念强调高频闪烁、强制最大亮度与手电筒。5 Hz 全屏明暗翻转会带来光敏癫痫、偏头痛、眩晕与眼部不适风险，因此本项目保留 300 BPM 的缩放、位移、旋转与色相流动，但不实现 5 Hz 全屏黑白闪烁或手电筒频闪。

- 首次启动为静态警告页；强刺激不会自动开始。
- 最高亮度和手电筒各自需要明确开启。
- “调暗闪烁灯光”开启时，HDR 强光、亮度提升、手电筒和高频运动均关闭。
- “减少动态效果”开启时，抖动、缩放、轨道和背景运动全部冻结。
- 应用变为 inactive/background 时立即恢复亮度并停止触觉与手电筒。
- 设备进入 serious/critical 热状态时，本次体验会全部停止。
- 手电筒仅直接配置 torch，不创建捕获输入、相机会话，不拍摄或保存数据。

## 在 Mac 上生成工程

要求：

- macOS
- Xcode 15.4 或更高版本（CI 固定 Xcode 16.4；iOS 17 SDK 或更新）
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) 2.45.0 或更高版本

```bash
brew install xcodegen
cd EmojiOverdrive
xcodegen generate
open EmojiOverdrive.xcodeproj
```

在 Xcode 中选择 `EmojiOverdrive` target → Signing & Capabilities → 选择你的 Team，然后选真机运行。真机是验证 HDR、亮度、Core Haptics 和手电筒的必需条件；模拟器不能证明这些能力。

## 命令行构建

无签名模拟器构建：

```bash
bash scripts/build_on_macos.sh simulator
```

模拟器单元测试（示例使用已安装的最新 iPhone 16 Pro runtime）：

```bash
bash scripts/build_on_macos.sh test
```

无签名 device SDK 编译检查：

```bash
bash scripts/build_on_macos.sh device-check
```

用 Apple Development 证书导出 Debugging IPA：

```bash
DEVELOPMENT_TEAM=你的10位TeamID \
BUNDLE_ID=com.你的域名.EmojiOverdrive \
bash scripts/build_on_macos.sh ipa
```

成功后 IPA 在 `build/export/`。Debugging IPA 只能安装到你的 provisioning profile 覆盖的已注册设备。TestFlight/App Store 或 Ad Hoc 分发需要在 Xcode Organizer 中选择相应分发方式，或用 Xcode 生成匹配的 `ExportOptions.plist`。

## Windows 静态验证

```powershell
python -m pip install -r requirements.txt
python scripts/validate_project.py
```

它会检查 XcodeGen YAML、plist、asset catalog、图标尺寸及安全清理路径，但不能替代 Xcode 的 Swift 编译、链接和真机测试。

## 签名与分发说明

`BUNDLE_ID` 必须是你的 Apple Developer 账号能够注册/签署的唯一标识；示例默认值只用于本地工程占位。`ipa` 动作使用 automatic signing 与当前 Xcode 的 Debugging 导出方法，并会确认导出目录中确实存在 IPA、再运行 ZIP 完整性检查。Ad Hoc、TestFlight 或 App Store 需要对应证书、provisioning profile 和分发用 ExportOptions。

## GitHub Actions IPA

仓库内的 `Build IPA` 工作流会在每次 push、pull request 或手动触发时运行静态验证、模拟器测试和真机 SDK 编译，然后上传 `EmojiOverdrive-unsigned-ipa` 构件。该 IPA 没有 Apple 签名，适合进一步重签或验证包结构，不能直接安装到普通未越狱 iPhone。可直接安装的 IPA 仍需 Apple Development/Distribution 证书及匹配的 provisioning profile；不要把证书密码或 `.p12` 文件提交到仓库。

## 真机验收清单

1. 在 60 Hz 与 120 Hz iPhone 上运行 45 秒，观察帧率与发热。
2. 运行中拉出控制中心、锁屏、切后台：亮度必须恢复，torch/haptics 必须停止。
3. 在系统设置中打开“减少动态效果”和“调暗闪烁灯光”，再运行并在运行中切换。
4. 测试无 torch 的 iPad 与模拟器；应用必须继续运行且显示状态提示。
5. 测试 serious/critical thermal state 或长时间重复运行；torch 必须被系统/应用关闭。
6. 用 PEAT 或等效光敏分析工具复核发布版本；本实现不包含全屏明暗闪烁，但仍应以最终二进制为准。

## 图标

App 图标由 OpenAI ImageGen 生成，原始提示要求“抽象 Emoji 狂欢漩涡、霓虹 magenta/cyan/acid yellow、无文字/品牌/水印”，并以一张 1024×1024 不透明 PNG 交给 Xcode 自动生成 iPhone/iPad 变体。应用不会联网，也不收集数据。
