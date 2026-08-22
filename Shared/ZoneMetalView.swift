import MetalKit
import SwiftUI

#if os(macOS)
  import AppKit
  final class ZoneMTKView: MTKView {
    weak var inputRouter: ZoneInputRouter?
    override var acceptsFirstResponder: Bool { true }

    override func viewDidMoveToWindow() {
      super.viewDidMoveToWindow()
      window?.makeFirstResponder(self)
    }

    override func resignFirstResponder() -> Bool {
      // A window/app focus transition can swallow keyUp events on macOS.
      // Clear held keyboard actions so no gameplay command remains stuck.
      inputRouter?.clearKeyboard()
      return super.resignFirstResponder()
    }

    private func key(_ code: UInt16, pressed: Bool) {
      guard let r = inputRouter else { return }
      switch code {
      case 123: r.setKeyboard(.left, pressed: pressed)
      case 124: r.setKeyboard(.right, pressed: pressed)
      case 49: r.setKeyboard(.thrust, pressed: pressed)
      case 126: r.setKeyboard(.equipmentUp, pressed: pressed)
      case 125: r.setKeyboard(.equipmentDown, pressed: pressed)
      case 53: r.setKeyboard(.pause, pressed: pressed)
      case 65: r.setKeyboard(.save, pressed: pressed)  // keypad decimal
      default: break
      }
    }

    override func keyDown(with event: NSEvent) {
      // The router edge-detects pause, but dropping repeated keyDown at the
      // view boundary avoids needless state churn for every canonical key.
      if !event.isARepeat { key(event.keyCode, pressed: true) }
    }
    override func keyUp(with event: NSEvent) { key(event.keyCode, pressed: false) }
    override func flagsChanged(with event: NSEvent) {
      inputRouter?.setKeyboard(.fire, pressed: event.modifierFlags.contains(.option))
      inputRouter?.setKeyboard(.select, pressed: event.modifierFlags.contains(.command))
    }
  }

  struct ZoneMetalView: NSViewRepresentable {
    @ObservedObject var host: ZoneGameHost
    func makeNSView(context: Context) -> ZoneMTKView {
      let v = ZoneMTKView()
      v.inputRouter = host.input
      context.coordinator.renderer = ZoneRenderer(view: v, host: host)
      return v
    }
    func updateNSView(_ nsView: ZoneMTKView, context: Context) {}
    func makeCoordinator() -> Coordinator { Coordinator() }
    final class Coordinator { var renderer: ZoneRenderer? }
  }
#else
  import UIKit
  final class ZoneMTKView: MTKView {}
  struct ZoneMetalView: UIViewRepresentable {
    @ObservedObject var host: ZoneGameHost
    func makeUIView(context: Context) -> ZoneMTKView {
      let v = ZoneMTKView()
      context.coordinator.renderer = ZoneRenderer(view: v, host: host)
      return v
    }
    func updateUIView(_ uiView: ZoneMTKView, context: Context) {}
    func makeCoordinator() -> Coordinator { Coordinator() }
  }
#endif
