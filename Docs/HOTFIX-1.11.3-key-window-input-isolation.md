# Hotfix 1.11.3r1 — macOS key-window input isolation

## Symptom

The animated title is noticeably smoother while another application (for example Terminal) is frontmost, then slows/judders after The Zone becomes the key application. Testing is keyboard-driven; no controller is required to reproduce it.

## Packaging revision

`1.11.3r1` fixes a prerequisite bug in the original 1.11.3 installer. Hotfix 1.11.2 replaces the 1.11.1 rotating-ship block, which removes the literal 1.11.1 marker from `Shared/ZoneContentView.swift`. The original 1.11.3 Python patcher incorrectly required both the obsolete 1.11.1 marker and the valid 1.11.2 marker, so it rejected a correctly patched 1.11.2 tree. Revision r1 requires only the authoritative 1.11.2 marker.

## Targeted changes

This hotfix isolates the two front-end subsystems that change when the Mac app becomes active:

1. The macOS title screen no longer becomes a SwiftUI `focusable()` node and no longer mutates `FocusState` simply to receive arrow/Return events. While the title is visible, a local AppKit `NSEvent` monitor handles arrows, Return/Enter, and Escape instead. This removes key-window focus bookkeeping from the same SwiftUI tree that continuously redraws the animated title.
2. `GCController.startWirelessControllerDiscovery()` is no longer started automatically on macOS. Already-connected controllers remain visible through GameController APIs and connect/disconnect notifications. Explicit wireless discovery remains enabled for non-macOS builds where controller-first use is expected.

No ZoneCore, gameplay, camera, collision, AI, 720/60 timing, Metal renderer, audio, or recovered sprite data changes are included.

## Acceptance test

Run the normal native/high macOS build. Observe at least two title-ship revolutions with Terminal frontmost, then click The Zone and observe another two revolutions without touching the keyboard. Next navigate repeatedly with arrows and Return. The active-window animation should retain the same pacing as the inactive-window view.

If active-only judder remains after this isolation, the next step is not another SwiftUI timing tweak: move the animated title presentation layer to a display-synchronized Metal view, matching gameplay's presentation path.
