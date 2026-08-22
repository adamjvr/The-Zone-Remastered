# The Zone Remastered — Roadmap

This roadmap tracks two separate goals:

1. **Classic fidelity** — reproduce the observable behavior of *TheZone* 1.5.1 from the recovered PowerPC/68K program and resources.
2. **Native remaster** — ship that verified engine as first-class native macOS and iPadOS applications, then add optional modern presentation features without changing Classic rules.

Percentages below are engineering estimates, not source-line metrics.

## Phase 0 — Forensics and asset archaeology — ~95%

**Status: substantially complete.**

Completed:

- canonical v1.5.1 StuffIt archive identified and reproducibly extracted;
- native PPC PEF and 68K `CODE` architecture mapped;
- all 651 proprietary `Spri` resources extracted and decoded;
- all 36 sound resources decoded;
- PPC sprite loader/renderer and transparent-pixel rule recovered;
- object FOURCC taxonomy recovered;
- 150-byte PPC object layout and v1.5.1 save layout recovered;
- fixed wave tables 1–18 recovered;
- sprite banks, damage thresholds, scores, preferences, high scores and help data recovered;
- exact 48-frame ship muzzle-offset table recovered.

Remaining forensic work is mostly in service of behavioral parity: historical version binary diffs, exact classic RNG, and unresolved state-machine constants.

## Phase 1 — Gameplay decompilation — ~78%

**Status: active.**

Recovered or substantially mapped:

- player heading/thrust and speed-cap rule;
- projectile direction and muzzle geometry;
- exact pixel collision test;
- collision-response dispatcher architecture;
- player impact damage and momentum exchange;
- object constructors/transforms and score accounting;
- fixed wave population logic;
- progression pickups and asteroid payload selection;
- Big Rock destruction structure;
- player death routine location and partial semantics;
- simple enemy AI cadences/caps;
- Mother Base defender-launch path;
- inter-base Bee request path;
- save/load object graph.

Major remaining lifts:

- complete Mother Base/HQ movement state machines;
- Bee stun/return edge states around the now-live continuous-vector chase;
- remaining Seeker edge states around the now-live 200-unit speed switch;
- Rotor parent/orbit/attack/return state machine;
- complete hostile projectile lifetime/collision special cases beyond the recovered base damage path;
- full special-case collision matrix;
- exact Big Rock child geometry;
- exact `bonu` / `equi` / `gadg` effects;
- exact `0x1663C` death/respawn timing and placement;
- procedural waves after 18;
- exact classic Mac `Random()` compatibility.

## Phase 2 — Native Apple foundation — ~85%

**Status: working.**

Completed:

- separate **native macOS** application target;
- macOS deployment pinned to **macOS 15 Sequoia**;
- separate **native iPadOS** application target;
- Catalyst disabled;
- “Mac (Designed for iPad)” disabled;
- shared platform-independent C `ZoneCore`;
- Metal presentation layer;
- AVFoundation audio layer;
- Apple `GameController.framework` integration on both platforms;
- canonical keyboard input on macOS;
- touch-controller infrastructure on iPadOS;
- 640×480 canonical logical game canvas with Retina scaling;
- native macOS build verified running on hardware.

Remaining platform work is primarily product/UI polish and iPad device validation, not architectural restructuring.

## Phase 3 — Live Classic gameplay reconstruction — ~50%

**Current phase: Milestone 0.7.**

Delivered through 0.5:

- real Wave-1 population shell;
- ship/projectile geometry;
- exact sprite collision;
- recovered player/object collision physics;
- destruction/explosions;
- asteroid pickups;
- velocity/ammo/shield progression;
- Big Rock fragmentation skeleton;
- player death/respawn skeleton.

Milestone 0.6 adds:

- Professional Wave-1 Mother Base defender class = `swar`;
- recovered Mother Base defender-launch random gate, batch size and active cap;
- linked defender spawn positions and parent counters;
- live Empire Fighter pursuit AI;
- recovered Bee donor/requester relationship infrastructure;
- proof that the sole Wave-1 Mother Base cannot request a Bee from itself.

Milestone 0.7 keeps that roadmap intact and advances the next listed items:

- hostile `fire` projectiles use the recovered **11.25** vector magnitude;
- recovered signed firing windows and the **3 active shots/shooter** cap are live for Bloody, Bee, Raider and Seeker;
- Bee pursuit and Seeker's **200-unit** near/far speed switch are live;
- direct fixed-wave population data is connected for waves 1–18;
- the combat-objective clear condition now advances Wave 1 into Wave 2 and continues through the fixed-wave range;
- macOS gains persistent keyboard remapping inside the pause menu as a product-layer addition, without changing ZoneCore's semantic input API.

Next priorities remain substantially unchanged:

1. complete Mother Base/HQ state machines;
2. complete Bee/Seeker edge states and Rotor orbit/attack/return AI;
3. finish hostile-projectile lifetime and special collision consequences;
4. complete wave-transition presentation and procedural waves 19+;
5. remaining collision/destruction/equipment special cases.

## Phase 4 — Full Classic Mode — ~28%

**Goal:** play continuously from Wave 1 onward with original rules and data.

Required for completion:

- complete enemy roster and AI;
- all projectile/damage paths;
- all equipment/bonus effects;
- full wave lifecycle and procedural late waves;
- exact player death/respawn;
- save/load integration;
- Hall of Fame;
- preferences;
- original sound-event mapping;
- deterministic compatibility tests against original behavior.

## Phase 5 — Native product/UI layer — ~35%

Completed foundations:

- SwiftUI/AppKit/UIKit shells;
- Metal game view;
- controller abstraction;
- macOS app branding/icon;
- macOS pause menu with persistent keyboard remapping and Classic-default reset.

Remaining:

- title/menu experience;
- preferences UI;
- save-slot UI;
- Hall of Fame UI;
- game-over/wave-transition presentation;
- controller-remapping UI;
- final iPad touch layout;
- fullscreen/window presentation;
- distribution/signing/notarization/App Store work.

## Phase 6 — Remaster layer — ~5%

This intentionally follows Classic fidelity.

Planned optional improvements include:

- Retina-native remastered art;
- enhanced particles/glow/lighting;
- remastered audio;
- widescreen presentation options;
- controller haptics;
- accessibility options;
- iCloud saves;
- Game Center;
- Classic/Remastered presentation toggle.

## Fidelity rule

A modern enhancement does not replace an unknown original behavior. We first reproduce and regression-test the Classic behavior, then make any remastered alternative explicit and optional.
