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
  private let fallback: MTLTexture
  private var stars: [(Float, Float, Float)] = []

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

  private func texture(_ id: Int32) -> MTLTexture {
    if let texture = textures[id] { return texture }
    let name = String(format: "Spri_%05d", id)
    if let url = Bundle.main.url(forResource: name, withExtension: "png", subdirectory: "Sprites"),
      let texture = try? loader.newTexture(
        URL: url,
        options: [.SRGB: false, .generateMipmaps: false]
      )
    {
      textures[id] = texture
      return texture
    }
    return fallback
  }

  private func vertices(x: Float, y: Float, side: Float) -> [Vertex] {
    let left = (x - side / 2) / 640 * 2 - 1
    let right = (x + side / 2) / 640 * 2 - 1
    let top = 1 - (y - side / 2) / 480 * 2
    let bottom = 1 - (y + side / 2) / 480 * 2
    return [
      Vertex(position: [left, top], uv: [0, 0]),
      Vertex(position: [left, bottom], uv: [0, 1]),
      Vertex(position: [right, top], uv: [1, 0]),
      Vertex(position: [right, top], uv: [1, 0]),
      Vertex(position: [left, bottom], uv: [0, 1]),
      Vertex(position: [right, bottom], uv: [1, 1]),
    ]
  }

  private func drawQuad(
    _ encoder: MTLRenderCommandEncoder,
    x: Float,
    y: Float,
    side: Float,
    texture: MTLTexture
  ) {
    let vertices = vertices(x: x, y: y, side: side)
    encoder.setFragmentTexture(texture, index: 0)
    vertices.withUnsafeBufferPointer { pointer in
      encoder.setVertexBytes(
        pointer.baseAddress!,
        length: pointer.count * MemoryLayout<Vertex>.stride,
        index: 0
      )
    }
    encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)
  }

  func draw(in view: MTKView) {
    host.step()

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
            texture: texture(item.sprite_id)
          )
        }
      }
    }

    encoder.endEncoding()
    commandBuffer.present(drawable)
    commandBuffer.commit()
  }
}
