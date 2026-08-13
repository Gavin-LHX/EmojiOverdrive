import SwiftUI

struct EmojiOrbitCanvas: View {
    let snapshot: RenderSnapshot

    var body: some View {
        Group {
            if snapshot.isRunning {
                TimelineView(
                    .animation(
                        minimumInterval: 1.0 / 60.0,
                        paused: snapshot.reduceMotion
                    )
                ) { timeline in
                    Canvas(opaque: false, colorMode: .extendedLinear, rendersAsynchronously: true) { context, size in
                        let liveElapsed = max(
                            0,
                            snapshot.elapsedAtSnapshot + timeline.date.timeIntervalSince(snapshot.capturedAt)
                        )
                        guard liveElapsed < snapshot.sessionDuration else { return }
                        EmojiOrbitRenderer.draw(
                            context: &context,
                            size: size,
                            elapsed: liveElapsed,
                            snapshot: snapshot
                        )
                    }
                }
            } else {
                Color.clear
            }
        }
        .accessibilityHidden(true)
        .allowsHitTesting(false)
    }
}

private enum EmojiOrbitRenderer {
    static func draw(
        context: inout GraphicsContext,
        size: CGSize,
        elapsed: TimeInterval,
        snapshot: RenderSnapshot
    ) {
        guard size.width > 1, size.height > 1 else { return }
        guard !snapshot.emoji.isEmpty else { return }

        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let minSide = min(size.width, size.height)
        let beat = elapsed * snapshot.bpm / 60
        let phase = beat - floor(beat)
        // Continuous at the beat boundary. The 300 BPM pulse changes only object
        // size/position; it never flips full-frame luminance or the torch.
        let kick = snapshot.reduceMotion ? 0 : 0.5 + 0.5 * cos(phase * .pi * 2)
        let motion = snapshot.reduceMotion ? 0 : 1.0
        let minimumCount = min(6, snapshot.emoji.count)
        let densityCount = Int((Double(snapshot.emoji.count) * snapshot.orbitDensity).rounded())
            .clamped(to: minimumCount...snapshot.emoji.count)

        drawOrbitTracks(
            context: &context,
            center: center,
            minSide: minSide,
            beat: snapshot.reduceMotion ? 0 : beat,
            intensity: snapshot.intensity
        )

        for index in 0..<densityCount {
            let seed = hash(UInt64(index + 1))
            let unitDouble = Double(seed & 0xffff) / Double(UInt16.max)
            let unit = CGFloat(unitDouble)
            let ring = index % 3
            let direction = index.isMultiple(of: 2) ? 1.0 : -1.0
            let baseAngle = unitDouble * .pi * 2
            let angularSpeed = (0.34 + Double(ring) * 0.11) * direction
            let angle = baseAngle + beat * angularSpeed * motion
            let radiusBase = minSide * (0.22 + CGFloat(ring) * 0.105)
            let wobble = CGFloat(sin(beat * (0.71 + unitDouble) + Double(index)))
                * minSide * 0.022 * CGFloat(motion)
            let radius = radiusBase + wobble

            let x = center.x + CGFloat(cos(angle)) * radius
            let y = center.y + CGFloat(sin(angle)) * radius * 0.82
            let fontSize = minSide * (0.072 + unit * 0.035)
            let localKick = 1 + CGFloat(kick * snapshot.intensity)
                * (0.08 + unit * 0.08) * CGFloat(motion)
            let rotation = Angle(
                radians: angle * direction + sin(beat + unitDouble * 7) * 0.25 * motion
            )

            var layer = context
            layer.translateBy(x: x, y: y)
            layer.rotate(by: rotation)
            layer.scaleBy(x: localKick, y: localKick)

            let text = Text(snapshot.emoji[index])
                .font(.system(size: fontSize))
            layer.draw(
                context.resolve(text),
                at: .zero,
                anchor: .center
            )
        }

        drawCenter(
            context: &context,
            center: center,
            minSide: minSide,
            beat: beat,
            kick: kick,
            snapshot: snapshot
        )

        if !snapshot.reduceMotion && !snapshot.dimFlashingLights {
            drawGlitchSlices(
                context: &context,
                size: size,
                beat: beat,
                intensity: snapshot.intensity
            )
        }
    }

    private static func drawOrbitTracks(
        context: inout GraphicsContext,
        center: CGPoint,
        minSide: CGFloat,
        beat: Double,
        intensity: Double
    ) {
        let colors: [Color] = [.cyan, .pink, .yellow]
        for ring in 0..<3 {
            let radius = minSide * (0.22 + CGFloat(ring) * 0.105)
            let rect = CGRect(
                x: center.x - radius,
                y: center.y - radius * 0.82,
                width: radius * 2,
                height: radius * 1.64
            )
            let path = Path(ellipseIn: rect)
            let dashPhase = CGFloat(beat * Double(ring + 1) * 9)
            context.stroke(
                path,
                with: .color(colors[ring].opacity(0.15 + intensity * 0.16)),
                style: StrokeStyle(
                    lineWidth: 1.2 + CGFloat(intensity),
                    dash: [5, 12, 2, 7],
                    dashPhase: dashPhase
                )
            )
        }
    }

    private static func drawCenter(
        context: inout GraphicsContext,
        center: CGPoint,
        minSide: CGFloat,
        beat: Double,
        kick: Double,
        snapshot: RenderSnapshot
    ) {
        let scale: CGFloat = snapshot.reduceMotion
            ? 1.0
            : 1 + CGFloat(kick * snapshot.intensity) * 0.24
        let jitterAmplitude: CGFloat = snapshot.reduceMotion
            ? 0
            : minSide * 0.018 * CGFloat(snapshot.intensity)
        let jitterX = CGFloat(smoothNoise(beat * 2.7, seed: 41)) * jitterAmplitude
        let jitterY = CGFloat(smoothNoise(beat * 3.1, seed: 97)) * jitterAmplitude

        var layer = context
        layer.translateBy(x: center.x + jitterX, y: center.y + jitterY)
        layer.rotate(by: .radians(sin(beat * 0.57) * 0.16 * (snapshot.reduceMotion ? 0 : 1)))
        layer.scaleBy(x: scale, y: scale)

        let emoji = snapshot.emoji[Int(floor(beat / 4)).positiveModulo(snapshot.emoji.count)]
        let resolved = layer.resolve(
            Text(emoji)
                .font(.system(size: minSide * 0.22))
        )
        layer.draw(resolved, at: .zero, anchor: .center)

        let label = layer.resolve(
            Text("\(Int(snapshot.bpm)) BPM")
                .font(.system(size: minSide * 0.034, weight: .black, design: .monospaced))
                .foregroundStyle(.white)
        )
        layer.draw(label, at: CGPoint(x: 0, y: minSide * 0.14), anchor: .center)
    }

    private static func drawGlitchSlices(
        context: inout GraphicsContext,
        size: CGSize,
        beat: Double,
        intensity: Double
    ) {
        for index in 0..<7 {
            let noise = smoothNoise(beat * (0.8 + Double(index) * 0.13), seed: UInt64(index + 400))
            let y = CGFloat((Double(index) + 0.5) / 7) * size.height + CGFloat(noise) * 18
            let width = size.width * (0.28 + CGFloat(abs(noise)) * 0.42)
            let x: CGFloat = noise > 0 ? 0 : size.width - width
            let rect = CGRect(
                x: x,
                y: y,
                width: width,
                height: 1.5 + CGFloat(intensity) * 3.5
            )
            let color: Color = index.isMultiple(of: 2) ? .cyan : .pink
            context.fill(Path(rect), with: .color(color.opacity(0.15 + intensity * 0.16)))
        }
    }

    private static func smoothNoise(_ value: Double, seed: UInt64) -> Double {
        let lower = floor(value)
        let fraction = value - lower
        let smooth = fraction * fraction * (3 - 2 * fraction)
        let a = randomSigned(UInt64(bitPattern: Int64(lower)), seed: seed)
        let b = randomSigned(UInt64(bitPattern: Int64(lower + 1)), seed: seed)
        return a + (b - a) * smooth
    }

    private static func randomSigned(_ value: UInt64, seed: UInt64) -> Double {
        let hashed = hash(value &+ seed &* 0x9E3779B97F4A7C15)
        let unit = Double(hashed >> 11) / Double(1 << 53)
        return unit * 2 - 1
    }

    private static func hash(_ value: UInt64) -> UInt64 {
        var z = value &+ 0x9E3779B97F4A7C15
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}

private extension Int {
    func positiveModulo(_ modulus: Int) -> Int {
        guard modulus > 0 else { return 0 }
        return (self % modulus + modulus) % modulus
    }
}
