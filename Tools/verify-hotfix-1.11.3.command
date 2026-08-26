#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
SOURCE="Shared/ZoneContentView.swift"

echo "[1/5] 1.11.2 prerequisite"
/usr/bin/grep -q 'Milestone 1.11.2 predecoded interpolated title ship' "$SOURCE"

echo "[2/5] macOS title no longer owns SwiftUI keyboard focus"
/usr/bin/grep -q 'Milestone 1.11.3 macOS key-window input isolation' "$SOURCE"
/usr/bin/grep -q 'private final class ZoneMacFrontEndKeyboardMonitor' "$SOURCE"
/usr/bin/grep -q 'keyboard.start(handleKeyboard)' "$SOURCE"
/usr/bin/grep -q 'NSEvent.addLocalMonitorForEvents' "$SOURCE"

echo "[3/5] wireless discovery gated off on macOS"
/usr/bin/grep -q '#if !os(macOS)' "$SOURCE"
/usr/bin/grep -q 'GCController.startWirelessControllerDiscovery' "$SOURCE"

echo "[4/5] patcher self-test"
/usr/bin/python3 Tools/apply-hotfix-1.11.3.py --self-test

echo "[5/5] prior title + gameplay regressions"
./Tools/verify-hotfix-1.11.2.command

echo "Hotfix 1.11.3r1 macOS key-window input isolation: PASS"
