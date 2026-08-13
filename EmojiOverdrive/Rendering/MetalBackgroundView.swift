import CoreGraphics
import MetalKit
import QuartzCore
import SwiftUI

struct MetalBackgroundView: UIViewRepresentable {
    let snapshot: RenderSnapshot

    func makeCoordinator() -> Coordinator {
        Coordinator(snapshot: snapshot)
    }

    func makeUIView(context: Context) -> MTKView {
        guard let device = MTLCreateSystemDefaultDevice() else {
            let view = MTKView(frame: .zero, device: nil)
            view.isPaused = true
            view.backgroundColor = .black
            return view
        }

        let shouldRun = snapshot.isRunning
            && snapshot.elapsedAtSnapshot < snapshot.sessionDuration
        let shouldAnimate = shouldRun
            && !snapshot.reduceMotion
            && !snapshot.dimFlashingLights
        let view = MTKView(frame: .zero, device: device)
        view.colorPixelFormat = .rgba16Float
        view.clearColor = MTLClearColorMake(0, 0, 0, 1)
        view.framebufferOnly = true
        view.preferredFramesPerSecond = 60
        view.enableSetNeedsDisplay = false
        view.isPaused = !shouldAnimate
        view.isOpaque = true

        if let layer = view.layer as? CAMetalLayer {
            layer.colorspace = CGColorSpace(name: CGColorSpace.extendedLinearDisplayP3)
            layer.wantsExtendedDynamicRangeContent = shouldRun && !snapshot.dimFlashingLights
        }

        context.coordinator.attach(to: view)
        if shouldRun && !shouldAnimate {
            view.draw()
        }
        return view
    }

    func updateUIView(_ uiView: MTKView, context: Context) {
        context.coordinator.update(snapshot: snapshot)
        let shouldRun = snapshot.isRunning
            && snapshot.elapsedAtSnapshot < snapshot.sessionDuration
        let shouldAnimate = shouldRun
            && !snapshot.reduceMotion
            && !snapshot.dimFlashingLights
        uiView.isPaused = !shouldAnimate
        if let layer = uiView.layer as? CAMetalLayer {
            layer.wantsExtendedDynamicRangeContent = shouldRun && !snapshot.dimFlashingLights
        }
        if !shouldAnimate {
            if !shouldRun {
                uiView.clearColor = MTLClearColorMake(0.006, 0.002, 0.01, 1)
            }
            uiView.draw()
        }
    }

    @MainActor
    final class Coordinator: NSObject, MTKViewDelegate {
        private struct Uniforms {
            var resolution: SIMD2<Float>
            var time: Float
            var intensity: Float
            var motion: Float
            var dimFlashing: Float
        }

        private var device: (any MTLDevice)?
        private var commandQueue: (any MTLCommandQueue)?
        private var pipelineState: (any MTLRenderPipelineState)?
        private var snapshot: RenderSnapshot

        init(snapshot: RenderSnapshot) {
            self.snapshot = snapshot
            super.init()
        }

        func attach(to view: MTKView) {
            guard let device = view.device ?? MTLCreateSystemDefaultDevice(),
                  let commandQueue = device.makeCommandQueue() else {
                view.isPaused = true
                return
            }

            self.device = device
            self.commandQueue = commandQueue

            do {
                let library = try device.makeLibrary(source: Self.shaderSource, options: nil)
                guard let vertex = library.makeFunction(name: "fullscreenVertex"),
                      let fragment = library.makeFunction(name: "pollutionFragment") else {
                    preconditionFailure("Metal shader functions are missing")
                }

                let descriptor = MTLRenderPipelineDescriptor()
                descriptor.label = "Emoji Overdrive HDR Pipeline"
                descriptor.vertexFunction = vertex
                descriptor.fragmentFunction = fragment
                descriptor.colorAttachments[0].pixelFormat = .rgba16Float
                pipelineState = try device.makeRenderPipelineState(descriptor: descriptor)
            } catch {
                view.isPaused = true
                pipelineState = nil
                return
            }
            view.device = device
            view.delegate = self
        }

        func update(snapshot: RenderSnapshot) {
            self.snapshot = snapshot
        }

        func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}

        func draw(in view: MTKView) {
            guard let drawable = view.currentDrawable,
                  let pass = view.currentRenderPassDescriptor,
                  let commandBuffer = commandQueue?.makeCommandBuffer() else { return }

            let liveElapsed = snapshot.elapsedAtSnapshot
                + max(0, Date().timeIntervalSince(snapshot.capturedAt))
            guard snapshot.isRunning, liveElapsed < snapshot.sessionDuration else {
                pass.colorAttachments[0].loadAction = .clear
                pass.colorAttachments[0].clearColor = MTLClearColorMake(0.006, 0.002, 0.01, 1)
                guard let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: pass) else { return }
                encoder.endEncoding()
                commandBuffer.present(drawable)
                commandBuffer.commit()
                return
            }

            guard let pipelineState,
                  let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: pass) else { return }

            let elapsed = min(liveElapsed, snapshot.sessionDuration)

            var uniforms = Uniforms(
                resolution: SIMD2(Float(view.drawableSize.width), Float(view.drawableSize.height)),
                time: Float(elapsed),
                intensity: Float(snapshot.intensity),
                motion: snapshot.reduceMotion || snapshot.dimFlashingLights ? 0 : 1,
                dimFlashing: snapshot.dimFlashingLights ? 1 : 0
            )

            encoder.setRenderPipelineState(pipelineState)
            encoder.setFragmentBytes(&uniforms, length: MemoryLayout<Uniforms>.stride, index: 0)
            encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
            encoder.endEncoding()
            commandBuffer.present(drawable)
            commandBuffer.commit()
        }

        private static let shaderSource = #"""
        #include <metal_stdlib>
        using namespace metal;

        struct VertexOut {
            float4 position [[position]];
            float2 uv;
        };

        struct Uniforms {
            float2 resolution;
            float time;
            float intensity;
            float motion;
            float dimFlashing;
        };

        vertex VertexOut fullscreenVertex(uint vertexID [[vertex_id]]) {
            constexpr float2 positions[4] = {
                float2(-1.0, -1.0), float2(1.0, -1.0),
                float2(-1.0, 1.0), float2(1.0, 1.0)
            };
            VertexOut out;
            out.position = float4(positions[vertexID], 0.0, 1.0);
            out.uv = positions[vertexID] * 0.5 + 0.5;
            return out;
        }

        float3 palette(float t) {
            float3 a = float3(0.48, 0.34, 0.58);
            float3 b = float3(0.52, 0.46, 0.42);
            float3 c = float3(1.0, 1.0, 1.0);
            float3 d = float3(0.04, 0.27, 0.57);
            return a + b * cos(6.2831853 * (c * t + d));
        }

        fragment half4 pollutionFragment(VertexOut in [[stage_in]], constant Uniforms &u [[buffer(0)]]) {
            float aspect = max(u.resolution.x / max(u.resolution.y, 1.0), 0.01);
            float2 p = (in.uv - 0.5) * float2(aspect, 1.0);
            float r = length(p);
            float angle = atan2(p.y, p.x);
            float t = u.time * u.motion;

            float spiral = sin(angle * 7.0 - r * 28.0 + t * 3.7);
            float rings = sin(r * 54.0 - t * 5.1 + sin(angle * 5.0));
            float lattice = sin((p.x + p.y) * 38.0 + t * 2.2) *
                            cos((p.x - p.y) * 31.0 - t * 1.9);
            float field = 0.48 + 0.18 * spiral + 0.13 * rings + 0.08 * lattice;

            float3 color = palette(field + t * 0.055 + angle * 0.035);
            float core = exp(-r * 5.5);
            float halo = exp(-abs(r - 0.31) * 19.0);
            float highlight = (core * 0.85 + halo * 0.34) * u.intensity;

            // EDR values above 1 are intentional on compatible displays. They move
            // smoothly rather than producing full-frame black/white flashes.
            float headroom = mix(1.0, 1.72, u.intensity) * mix(1.0, 0.56, u.dimFlashing);
            color = color * (0.55 + u.intensity * 0.62) + highlight * float3(1.1, 0.34, 1.32);
            color = max(color, float3(0.012, 0.006, 0.018));
            color *= headroom;
            if (u.dimFlashing > 0.5) {
                color = min(color, float3(1.0));
            }
            return half4(half3(color), half(1.0));
        }
        """#
    }
}
