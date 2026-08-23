import Foundation
import Metal
import MetalKit
import simd

final class ZoneRenderer: NSObject, MTKViewDelegate {
  struct Vertex {
    var position: SIMD2<Float>
    var uv: SIMD2<Float>
  }

  private let host: ZoneGameHost
  private let device: MTLDevice
  private let queue: MTLCommandQueue
  private let pipeline: MTLRenderPipelineState
  private let sampler: MTLSamplerState
  private let loader: MTKTextureLoader
  private var textures: [Int32: MTLTexture] = [:]
  private var missingTextureIDs: Set<Int32> = []
  private let fallback: MTLTexture
  private var stars: [(Float, Float, Float)] = []

  // Diagnostics are opt-in so normal gameplay does not spend time printing or
  // collecting per-frame telemetry. Use Tools/run-macos-perf.command.
  private let diagnosticsEnabled = ProcessInfo.processInfo.environment["ZONE_PERF_DIAGNOSTICS"] == "1"
  private var lastDrawTime: TimeInterval?
  private var frameNumber: UInt64 = 0

  init?(view: MTKView, host: ZoneGameHost) {
    guard
      let device = view.device ?? MTLCreateSystemDefaultDevice(),
      let queue = device.makeCommandQueue()
    else { return nil }

    self.host = host
    self.device = device
    self.queue = queue
    self.loader = MTKTextureLoader(device: device)

    view.device = device
    view.colorPixelFormat = .bgra8Unorm
    // Milestone 1.1 intentionally preserves the Milestone 1.0 host contract:
    // one ZoneCore step per normal 60 Hz Metal presentation callback.
    view.preferredFramesPerSecond = 60
    view.enableSetNeedsDisplay = false
    view.isPaused = false

    guard
      let library = device.makeDefaultLibrary(),
      let vertexFunction = library.makeFunction(name: "zone_vertex"),
      let fragmentFunction = library.makeFunction(name: "zone_fragment")
    else { return nil }

    let pipelineDescriptor = MTLRenderPipelineDescriptor()
    pipelineDescriptor.vertexFunction = vertexFunction
    pipelineDescriptor.fragmentFunction = fragmentFunction
    pipelineDescriptor.colorAttachments[0].pixelFormat = view.colorPixelFormat
    pipelineDescriptor.colorAttachments[0].isBlendingEnabled = true
    pipelineDescriptor.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
    pipelineDescriptor.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
    pipelineDescriptor.colorAttachments[0].sourceAlphaBlendFactor = .one
    pipelineDescriptor.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha

    guard let pipeline = try? device.makeRenderPipelineState(descriptor: pipelineDescriptor) else {
      return nil
    }
    self.pipeline = pipeline

    let samplerDescriptor = MTLSamplerDescriptor()
    samplerDescriptor.minFilter = .nearest
    samplerDescriptor.magFilter = .nearest
    samplerDescriptor.sAddressMode = .clampToEdge
    samplerDescriptor.tAddressMode = .clampToEdge
    guard let sampler = device.makeSamplerState(descriptor: samplerDescriptor) else { return nil }
    self.sampler = sampler

    let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(
      pixelFormat: .rgba8Unorm,
      width: 1,
      height: 1,
      mipmapped: false
    )
    textureDescriptor.usage = [.shaderRead]
    guard let fallback = device.makeTexture(descriptor: textureDescriptor) else { return nil }
    let white: [UInt8] = [255, 255, 255, 255]
    white.withUnsafeBytes {
      fallback.replace(
        region: MTLRegionMake2D(0, 0, 1, 1),
        mipmapLevel: 0,
        withBytes: $0.baseAddress!,
        bytesPerRow: 4
      )
    }
    self.fallback = fallback

    super.init()

    // The 1.0 renderer decoded PNGs and created Metal textures on first use
    // *inside draw(in:)*. Enemy orientation changes therefore had permission
    // to perform filesystem/PNG/GPU allocation work on the real-time render
    // path. Load the complete recovered sprite library once before the view is
    // allowed to start presenting frames.
    preloadSpriteTextures()

    view.delegate = self

    var state: UInt32 = 0x1234_5678
    for _ in 0..<72 {
      state = 1_664_525 &* state &+ 1_013_904_223
      let x = Float(state & 0xffff) / 65_535 * 640
      state = 1_664_525 &* state &+ 1_013_904_223
      let y = Float(state & 0xffff) / 65_535 * 480
      stars.append((x, y, (state & 3) == 0 ? 1.5 : 1.0))
    }
  }

  func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}

  private static func spriteID(from url: URL) -> Int32? {
    let stem = url.deletingPathExtension().lastPathComponent
    guard stem.hasPrefix("Spri_") else { return nil }
    return Int32(String(stem.dropFirst(5)))
  }

  private func preloadSpriteTextures() {
    let options: [MTKTextureLoader.Option: Any] = [
      .SRGB: false,
      .generateMipmaps: false,
    ]
    let urls = Bundle.main.urls(forResourcesWithExtension: "png", subdirectory: "Sprites") ?? []
    var loaded = 0
    var failed = 0

    for url in urls {
      guard let id = Self.spriteID(from: url) else { continue }
      if let texture = try? loader.newTexture(URL: url, options: options) {
        textures[id] = texture
        loaded += 1
      } else {
        missingTextureIDs.insert(id)
        failed += 1
      }
    }

    if diagnosticsEnabled {
      print("[ZonePerf][renderer] sprite-preload urls=\(urls.count) loaded=\(loaded) failed=\(failed)")
    }
  }

  private func texture(_ id: Int32) -> MTLTexture {
    if let texture = textures[id] { return texture }
    if diagnosticsEnabled, missingTextureIDs.insert(id).inserted {
      print("[ZonePerf][renderer] texture-miss sprite=\(id)")
    }
    // No filesystem access, PNG decode or Metal allocation is permitted here.
    return fallback
  }

  private func drawQuad(
    _ encoder: MTLRenderCommandEncoder,
    x: Float,
    y: Float,
    side: Float,
    texture: MTLTexture,
    flash: Float = 0
  ) {
    let left = (x - side / 2) / 640 * 2 - 1
    let right = (x + side / 2) / 640 * 2 - 1
    let top = 1 - (y - side / 2) / 480 * 2
    let bottom = 1 - (y + side / 2) / 480 * 2

    encoder.setFragmentTexture(texture, index: 0)
    var flashAmount = flash
    encoder.setFragmentBytes(&flashAmount, length: MemoryLayout<Float>.size, index: 0)

    // 1.0 built a fresh six-element Swift Array for every star and every
    // sprite every frame. Use temporary stack storage instead so the render
    // hot path has no per-quad heap allocation.
    withUnsafeTemporaryAllocation(of: Vertex.self, capacity: 6) { vertices in
      vertices[0] = Vertex(position: [left, top], uv: [0, 0])
      vertices[1] = Vertex(position: [left, bottom], uv: [0, 1])
      vertices[2] = Vertex(position: [right, top], uv: [1, 0])
      vertices[3] = Vertex(position: [right, top], uv: [1, 0])
      vertices[4] = Vertex(position: [left, bottom], uv: [0, 1])
      vertices[5] = Vertex(position: [right, bottom], uv: [1, 1])
      encoder.setVertexBytes(
        vertices.baseAddress!,
        length: 6 * MemoryLayout<Vertex>.stride,
        index: 0
      )
      encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)
    }
  }

  func draw(in view: MTKView) {
    let frameStart = ProcessInfo.processInfo.systemUptime
    frameNumber &+= 1
    if diagnosticsEnabled, let last = lastDrawTime {
      let gapMS = (frameStart - last) * 1000
      // A 60 Hz callback is ~16.67 ms. Log only conspicuous misses so the
      // diagnostic itself does not flood stdout and create more stutter.
      if gapMS > 24.0 {
        print(String(format: "[ZonePerf][renderer] frame-gap frame=%llu %.3fms", frameNumber, gapMS))
      }
    }
    lastDrawTime = frameStart

    let stepStart = diagnosticsEnabled ? ProcessInfo.processInfo.systemUptime : 0
    host.step()
    if diagnosticsEnabled {
      let stepMS = (ProcessInfo.processInfo.systemUptime - stepStart) * 1000
      if stepMS > 4.0 {
        print(String(format: "[ZonePerf][host] slow-step frame=%llu %.3fms", frameNumber, stepMS))
      }
    }

    guard
      let pass = view.currentRenderPassDescriptor,
      let drawable = view.currentDrawable,
      let commandBuffer = queue.makeCommandBuffer()
    else { return }

    pass.colorAttachments[0].clearColor = MTLClearColor(
      red: 0.005,
      green: 0.007,
      blue: 0.012,
      alpha: 1
    )
    pass.colorAttachments[0].loadAction = .clear

    guard let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: pass) else { return }

    let drawableWidth = Double(view.drawableSize.width)
    let drawableHeight = Double(view.drawableSize.height)
    let logicalAspect = 640.0 / 480.0
    var viewportX = 0.0
    var viewportY = 0.0
    var viewportWidth = drawableWidth
    var viewportHeight = drawableHeight
    if drawableWidth / drawableHeight > logicalAspect {
      viewportWidth = drawableHeight * logicalAspect
      viewportX = (drawableWidth - viewportWidth) / 2
    } else {
      viewportHeight = drawableWidth / logicalAspect
      viewportY = (drawableHeight - viewportHeight) / 2
    }

    encoder.setViewport(
      MTLViewport(
        originX: viewportX,
        originY: viewportY,
        width: viewportWidth,
        height: viewportHeight,
        znear: 0,
        zfar: 1
      )
    )
    encoder.setRenderPipelineState(pipeline)
    encoder.setFragmentSamplerState(sampler, index: 0)

    for star in stars {
      drawQuad(encoder, x: star.0, y: star.1, side: star.2, texture: fallback)
    }

    let count = zone_game_render_item_count(host.game)
    if count > 0 {
      for index in 0..<count {
        let item = zone_game_render_item_at(host.game, index)
        if item.sprite_id != 0 {
          drawQuad(
            encoder,
            x: item.x,
            y: item.y,
            side: item.side,
            texture: texture(item.sprite_id),
            flash: item.flash
          )
        }
      }
    }

    encoder.endEncoding()
    commandBuffer.present(drawable)
    commandBuffer.commit()

    if diagnosticsEnabled {
      let cpuMS = (ProcessInfo.processInfo.systemUptime - frameStart) * 1000
      if cpuMS > 8.0 {
        print(String(format: "[ZonePerf][renderer] slow-cpu-frame frame=%llu %.3fms items=%d", frameNumber, cpuMS, count))
      }
    }
  }
}
