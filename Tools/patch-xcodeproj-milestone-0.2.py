#!/usr/bin/env python3
"""Idempotently add the Milestone 0.2 macOS AppIcon asset catalog to the
existing Xcode project without regenerating the project or disturbing signing.
"""
from pathlib import Path
import re
import sys

PROJECT = Path("TheZoneRemastered.xcodeproj/project.pbxproj")
BUILD_ID = "0A2C00000000000000000001"
FILE_ID = "0A2C00000000000000000002"

if not PROJECT.exists():
    raise SystemExit(f"missing {PROJECT}")

text = PROJECT.read_text()

if FILE_ID in text and BUILD_ID in text:
    print("Xcode project already contains Milestone 0.2 AppIcon wiring")
    sys.exit(0)

def replace_once(old: str, new: str, label: str) -> None:
    global text
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"cannot patch {label}: expected 1 match, found {count}")
    text = text.replace(old, new, 1)

# PBXBuildFile
anchor = '\t\tE2F453E7BD6CEA68030CC5D3 /* TheZoneMacApp.swift in Sources */ = {isa = PBXBuildFile; fileRef = 918110C8D25F1E7885F46099 /* TheZoneMacApp.swift */; };\n'
replace_once(
    anchor,
    anchor + f'\t\t{BUILD_ID} /* Assets.xcassets in Resources */ = {{isa = PBXBuildFile; fileRef = {FILE_ID} /* Assets.xcassets */; }};\n',
    "PBXBuildFile",
)

# PBXFileReference
anchor = '\t\t918110C8D25F1E7885F46099 /* TheZoneMacApp.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = TheZoneMacApp.swift; sourceTree = "<group>"; };\n'
replace_once(
    anchor,
    anchor + f'\t\t{FILE_ID} /* Assets.xcassets */ = {{isa = PBXFileReference; lastKnownFileType = folder.assetcatalog; path = Assets.xcassets; sourceTree = "<group>"; }};\n',
    "PBXFileReference",
)

# macOS group
anchor = '\t\t\tchildren = (\n\t\t\t\t918110C8D25F1E7885F46099 /* TheZoneMacApp.swift */,\n\t\t\t);\n\t\t\tpath = macOS;\n'
replace_once(
    anchor,
    '\t\t\tchildren = (\n'
    '\t\t\t\t918110C8D25F1E7885F46099 /* TheZoneMacApp.swift */,\n'
    f'\t\t\t\t{FILE_ID} /* Assets.xcassets */,\n'
    '\t\t\t);\n\t\t\tpath = macOS;\n',
    "macOS PBXGroup",
)

# Native macOS Resources phase only.
anchor = '\t\t\t\t8F6D66D4D3063EC255390571 /* Sprites in Resources */,\n\t\t\t\tA5F1DA8098428207D6D949CE /* Sounds in Resources */,\n'
replace_once(
    anchor,
    anchor + f'\t\t\t\t{BUILD_ID} /* Assets.xcassets in Resources */,\n',
    "macOS resources phase",
)

def inject_build_settings(config_id: str) -> None:
    global text
    pattern = re.compile(
        rf'(\t\t{re.escape(config_id)} /\* (?:Debug|Release) \*/ = \{{\n'
        rf'\t\t\tisa = XCBuildConfiguration;\n'
        rf'\t\t\tbuildSettings = \{{\n)(.*?)(\t\t\t\}};\n\t\t\tname = (?:Debug|Release);\n\t\t\}};)',
        re.S,
    )
    m = pattern.search(text)
    if not m:
        raise SystemExit(f"cannot locate macOS build configuration {config_id}")
    body = m.group(2)
    additions = []
    if "ASSETCATALOG_COMPILER_APPICON_NAME" not in body:
        additions.append('\t\t\t\tASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;\n')
    if "CURRENT_PROJECT_VERSION" not in body:
        additions.append('\t\t\t\tCURRENT_PROJECT_VERSION = 2;\n')
    if "MARKETING_VERSION" not in body:
        additions.append('\t\t\t\tMARKETING_VERSION = 0.2.0;\n')
    if not additions:
        return
    new = m.group(1) + ''.join(additions) + body + m.group(3)
    text = text[:m.start()] + new + text[m.end():]

inject_build_settings("547D583F7C199D1AF41BE66E")
inject_build_settings("FE4F1C27BEBBD9ED1FB5F7F5")

PROJECT.write_text(text)
print("Patched Xcode project: macOS AppIcon asset catalog + version 0.2.0")
