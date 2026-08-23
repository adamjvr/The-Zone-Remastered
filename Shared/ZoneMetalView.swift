import Foundation
import MetalKit
import SwiftUI

private func zonePresentationTargetFPS(maximum: Int) -> Int {
  let maxFPS = max(1, maximum)
  if let raw = ProcessInfo.processInfo.environment["ZONE_PRESENTATION_HZ"],
     let requested = Int(raw), requested > 0 {
    return min(maxFPS, requested)
  }
  return maxFPS
}

#if os(macOS)
  import AppKit

  /// Shared by the Metal gameplay view and the pause-menu key-capture view so
  /// remapping never creates a second interpretation of macOS keyboard input.
  enum ZoneMacKeyboardEventRouter {
    static func modifierPressed(keyCode: UInt16, flags: NSEvent.ModifierFlags) -> Bool {
      switch keyCode {
      case 54, 55: return flags.contains(.command)
      case 56, 60: return flags.contains(.shift)
      case 58, 61: return flags.contains(.option)
      case 59, 62: return flags.contains(.control)
      case 57: return flags.contains(.capsLock)
      default: return false
      }
    }

    static func keyDown(_ event: NSEvent, router: ZoneInputRouter) {
      if event.isARepeat { return }
      if router.captureRebindKey(event.keyCode) { return }
      router.setKeyboardKey(event.keyCode, pressed: true)
    }

    static func keyUp(_ event: NSEvent, router: ZoneInputRouter) {
      if router.isRebinding { return }
      router.setKeyboardKey(event.keyCode, pressed: false)
    }

    static func flagsChanged(_ event: NSEvent, router: ZoneInputRouter) {
      let pressed = modifierPressed(keyCode: event.keyCode, flags: event.modifierFlags)
      if pressed && router.captureRebindKey(event.keyCode) { return }
      if !router.isRebinding { router.setKeyboardKey(event.keyCode, pressed: pressed) }
    }
  }

  final class ZoneMTKView: MTKView {
    weak var inputRouter: ZoneInputRouter?
    private var screenObserver: NSObjectProtocol?
    override var acceptsFirstResponder: Bool { true }

    deinit {
      if let screenObserver { NotificationCenter.default.removeObserver(screenObserver) }
    }

    func refreshPreferredFrameRate() {
      guard let screen = window?.screen else { return }
      preferredFramesPerSecond = zonePresentationTargetFPS(maximum: screen.maximumFramesPerSecond)
    }

    override func viewDidMoveToWindow() {
      super.viewDidMoveToWindow()
      if let screenObserver { NotificationCenter.default.removeObserver(screenObserver) }
      screenObserver = nil
      if let window {
        screenObserver = NotificationCenter.default.addObserver(
          forName: NSWindow.didChangeScreenNotification,
          object: window,
          queue: .main
        ) { [weak self] _ in self?.refreshPreferredFrameRate() }
      }
      refreshPreferredFrameRate()
      window?.makeFirstResponder(self)
    }

    override func resignFirstResponder() -> Bool {
      inputRouter?.clearKeyboard()
      return super.resignFirstResponder()
    }

    override func keyDown(with event: NSEvent) {
      guard let inputRouter else { return }
      ZoneMacKeyboardEventRouter.keyDown(event, router: inputRouter)
    }

    override func keyUp(with event: NSEvent) {
      guard let inputRouter else { return }
      ZoneMacKeyboardEventRouter.keyUp(event, router: inputRouter)
    }

    override func flagsChanged(with event: NSEvent) {
      guard let inputRouter else { return }
      ZoneMacKeyboardEventRouter.flagsChanged(event, router: inputRouter)
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

    func updateNSView(_ nsView: ZoneMTKView, context: Context) {
      nsView.refreshPreferredFrameRate()
      // The pause menu temporarily owns first responder for key capture. Give
      // keyboard control back to gameplay as soon as the game resumes.
      if !host.hud.paused && nsView.window?.firstResponder !== nsView {
        DispatchQueue.main.async { nsView.window?.makeFirstResponder(nsView) }
      }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }
    final class Coordinator { var renderer: ZoneRenderer? }
  }
#else
  import UIKit

  final class ZoneMTKView: MTKView {
    func refreshPreferredFrameRate() {
      guard let screen = window?.screen else { return }
      preferredFramesPerSecond = zonePresentationTargetFPS(maximum: screen.maximumFramesPerSecond)
    }

    override func didMoveToWindow() {
      super.didMoveToWindow()
      refreshPreferredFrameRate()
    }
  }

  struct ZoneMetalView: UIViewRepresentable {
    @ObservedObject var host: ZoneGameHost
    func makeUIView(context: Context) -> ZoneMTKView {
      let v = ZoneMTKView()
      context.coordinator.renderer = ZoneRenderer(view: v, host: host)
      return v
    }
    func updateUIView(_ uiView: ZoneMTKView, context: Context) {
      uiView.refreshPreferredFrameRate()
    }
    func makeCoordinator() -> Coordinator { Coordinator() }
    final class Coordinator { var renderer: ZoneRenderer? }
  }
#endif
