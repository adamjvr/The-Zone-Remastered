#!/bin/zsh
set -euo pipefail
cd "${0:A:h}/.."
PROJECT="TheZoneRemastered.xcodeproj"

# The installed SDK version and the app deployment target are intentionally
# different concepts. Xcode 26 may report SDKROOT=macosx26.x even when the app
# is built to run natively on macOS 15 Sequoia.

die() { print -u2 "ERROR: $*"; exit 1; }
value() {
  local scheme="$1" sdk="$2" key="$3"
  xcodebuild -project "$PROJECT" -scheme "$scheme" -sdk "$sdk" -showBuildSettings 2>/dev/null \
    | awk -F ' = ' -v k="$key" '$1 ~ "^[[:space:]]*" k "$" {print $2; exit}'
}

print "=== Native macOS target ==="
mac_sdk=$(value "The Zone macOS" macosx SDKROOT)
mac_platform=$(value "The Zone macOS" macosx PLATFORM_NAME)
mac_plats=$(value "The Zone macOS" macosx SUPPORTED_PLATFORMS)
mac_deploy=$(value "The Zone macOS" macosx MACOSX_DEPLOYMENT_TARGET)
mac_catalyst=$(value "The Zone macOS" macosx SUPPORTS_MACCATALYST)
mac_designed=$(value "The Zone macOS" macosx SUPPORTS_MAC_DESIGNED_FOR_IPHONE_IPAD)

[[ "$mac_sdk" == macosx* || "$mac_sdk" == */MacOSX*.sdk ]] || die "Mac target is not using a macOS SDK: $mac_sdk"
[[ "$mac_platform" == "macosx" ]] || die "Mac target PLATFORM_NAME is wrong: $mac_platform"
[[ "$mac_plats" == "macosx" ]] || die "Mac target supports unexpected platforms: $mac_plats"
[[ "$mac_deploy" == 15.* ]] || die "Mac target is not pinned to macOS 15 Sequoia: MACOSX_DEPLOYMENT_TARGET=$mac_deploy"
[[ "$mac_catalyst" == "NO" ]] || die "Mac target unexpectedly enables Catalyst: $mac_catalyst"
[[ "$mac_designed" == "NO" ]] || die "Mac target unexpectedly enables Designed-for-iPad-on-Mac: $mac_designed"
print "PASS: The Zone macOS => native macOS; deployment target macOS $mac_deploy (Sequoia); build SDK $mac_sdk"

print "=== Native iPadOS target ==="
pad_sdk=$(value "The Zone iPadOS" iphoneos SDKROOT)
pad_platform=$(value "The Zone iPadOS" iphoneos PLATFORM_NAME)
pad_plats=$(value "The Zone iPadOS" iphoneos SUPPORTED_PLATFORMS)
pad_family=$(value "The Zone iPadOS" iphoneos TARGETED_DEVICE_FAMILY)
pad_deploy=$(value "The Zone iPadOS" iphoneos IPHONEOS_DEPLOYMENT_TARGET)
pad_catalyst=$(value "The Zone iPadOS" iphoneos SUPPORTS_MACCATALYST)
pad_designed=$(value "The Zone iPadOS" iphoneos SUPPORTS_MAC_DESIGNED_FOR_IPHONE_IPAD)

[[ "$pad_sdk" == iphoneos* || "$pad_sdk" == */iPhoneOS*.sdk ]] || die "iPad target is not using an iPadOS/iOS device SDK: $pad_sdk"
[[ "$pad_platform" == "iphoneos" ]] || die "iPad target PLATFORM_NAME is wrong: $pad_platform"
[[ "$pad_plats" == *iphoneos* && "$pad_plats" == *iphonesimulator* && "$pad_plats" != *macosx* ]] || die "iPad target platforms are wrong: $pad_plats"
[[ "$pad_family" == "2" ]] || die "iPad target is not iPad-only: TARGETED_DEVICE_FAMILY=$pad_family"
[[ "$pad_catalyst" == "NO" ]] || die "Mac Catalyst is enabled for iPad target: $pad_catalyst"
[[ "$pad_designed" == "NO" ]] || die "Mac (Designed for iPad) destination is enabled: $pad_designed"
print "PASS: The Zone iPadOS => native iPadOS/iPad Simulator only; deployment target iPadOS $pad_deploy; build SDK $pad_sdk"

print "Native target separation: PASS"
