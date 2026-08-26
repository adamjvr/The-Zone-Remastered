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

## Phase 1 — Gameplay decompilation — ~90%

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

- remaining Mother Base/HQ collision/state edge semantics;
- original camera/world-to-screen transform plus remaining Bee/Seeker `+128/+129` spatial-mode behavior;
- remaining Seeker edge states around the now-live 200-unit speed switch;
- remaining hostile projectile collision special cases beyond recovered spatial retirement and base damage;
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

The display-independent 720-Hz/native-refresh path is now live. Remaining platform work is product/UI polish, save/persistence integration, final iPad validation, and distribution work.

## Phase 3 — Live Classic gameplay reconstruction — ~84%

**Current gameplay checkpoint: Milestone 1.10. Native product checkpoint 1.8.1 is accepted in parallel.**

Milestone 1.3 completes the recovered Bee/Seeker timed hit-state behavior currently supported by the portable object model. Bee and Seeker now honor their 60-TickCount `+66/+92` coast gates; Seeker player collision applies the recovered 30-tick timestamp backdate; and Professional Wave 2 regression-tests a real other-Mother Bee donor. The earlier "Bee return" roadmap wording is corrected because PPC `0x154A8` contains no parent-return state.

Milestone 1.2 is an instrumentation-only attribution phase on the accepted 1.1 build. It keeps ZoneCore and ZoneRenderer unchanged while measuring input, core simulation, audio drain, individual audio start, and HUD work independently so the remaining intermittent native stall can be repaired without another global timing change.

Milestone 1.1 is a narrow real-time hot-path repair on the committed 1.0 gameplay baseline. It keeps ZoneCore and the 60-Hz host stepping contract unchanged while removing first-use PNG/Metal texture construction and per-event WAV/player construction from active gameplay. Opt-in hitch telemetry is included before any further timing-model changes.

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

Milestone 0.8 starts with the known 0.7 base-damage play-test issue and keeps the same priorities:

- confirms cumulative Mother Base damage continues through the recovered Professional threshold of **40** even after defender launch has reached its active cap;
- restores the recovered nonlethal Mother/HQ damage-draw flag and hit-event semantics so later valid hits no longer look like misses;
- promotes Headquarters `0x16390` defender deployment with the recovered active cap of **4 Professional / 2 Beginner** and four corner launch positions;
- adds long-run damage and HQ-replenishment regression tests before further state-machine promotion.

Milestone 0.9 promotes the next recovered base-state behavior without inventing unresolved rules:

- fixed-wave `mobile_moth_quota` now becomes live Mother Base state `+84`;
- PPC `0x14C70` Mother states **0/1/2** are live: preserve motion, accelerative chase, and direct near/far pursuit;
- a player-shot destruction now executes the recovered `0x19C38..0x19C98` activation path and writes selector state **1 or 2** to the first eligible mobile Mother;
- the `RandomRange(1,3)` callsite is modeled with the recovered upper-exclusive range semantics;
- Headquarters use their independent `0x14B18` base handler and fire an aimed `fire` projectile every **15 behavior ticks**;
- all 0.8 damage feedback, defender caps, Bee separation, and fixed base-frame behavior remain regression-covered.

Milestone 1.0 promotes the linked Rotor guard state machine:

- PPC `0x15BC8..0x16124` Rotor states **0/1/2** are live as orbit, attack and return;
- linked Rotors hold the recovered **40-unit** orbit and wake at **100 units** from the player;
- attack uses recovered speed **10**, transitions to return at the **160-unit** parent leash, and return uses recovered speed **20** until the Rotor re-enters the 40-unit guard radius;
- Mother Base nonlethal hits and Rotor hits wake the linked Rotor exactly through the recovered `+131 = 1` semantics;
- Rotor hostile fire uses the strict `(10000,15000)` signed-Random window and shared 3-shot cap;
- Rotor destruction clears the parent link2 without corrupting the launched-defender counter.

### Milestone 1.4 — High-refresh engine/timebase foundation

Milestone 1.4 establishes the display-independent timebase foundation without reintroducing interpolation/extrapolation. The live architecture now:

- provides a monotonic integer **720-Hz master scheduling grid**;
- schedules the unchanged authoritative Classic game step every **12 master ticks = 60 Hz**;
- requests the active macOS/iPadOS screen's native maximum presentation rate, with a diagnostic Hz override;
- proves 60/120/144/165/240-Hz presentation cannot change Classic game speed;
- adds an optimized headless ZoneCore benchmark for 240/480/720/960/1440-Hz candidate dynamics rates;
- preserves Classic TickCount-derived durations independently of monitor refresh;
- keeps interpolation/extrapolation out of the foundational path.

### Milestone 1.5 — Native high-rate dynamics

Milestone 1.5 promotes continuous motion onto the already-proven 720-Hz master grid while preserving the 60-Hz Classic rule boundary:

- player, world-object and projectile positions receive real 1/720-second integration updates;
- each master displacement is exactly 1/12 of the recovered per-Classic-step displacement;
- input/thrust decisions, AI, RNG/fire gates, object ticks and animation decisions remain once per Classic interval;
- exact-pixel collision, projectile lifetime, pickups, impact damage, wave lifecycle and explosion aging remain on the Classic end boundary;
- `zone_game_step()` remains unchanged as the deterministic Classic reference API;
- new regressions compare one Classic interval against twelve master ticks and run a 180-interval changing-input parity trace;
- the host retains an explicit Classic/high dynamics A/B switch; interpolation and extrapolation remain absent.

This completes the first genuine high-refresh dynamics promotion. High-rate collision remains a separate Remastered-policy question because changing collision sampling frequency can change observable Classic outcomes.

### Milestone 1.6 — Shared 80-slot object admission and base-impact parity

The portable typed stores now obey the recovered global 80-object admission budget, and dedicated Mother/HQ ship-impact state/feedback consequences are regression-covered without altering the accepted high-rate presentation architecture.

### Milestone 1.7 — Recovered lifecycle timing

Death and wave progression now follow recovered explosion-finalization causality rather than provisional countdowns: the 20-frame ship-origin EXPL drives respawn, and the final Mother/HQ-origin EXPL drives objective-zero wave advancement. Projectile 90/120 lifetime guards remain explicitly temporary pending spatial/list parity.

### Milestone 1.8 — Native Front-End & Title Screen

The Apple products now boot through a shared native title shell instead of directly into gameplay. New Game, Controls, persistent presentation Preferences, Credits, macOS Quit, and Return-to-Title pause flow are live; the recovered 48-frame ship bank supplies the title emblem. `ZONE_BOOT_DIRECT=1` retains direct engineering boot, and ZoneCore/high-refresh/audio behavior is deliberately unchanged.

### Milestone 1.8.1 — Front-End Polish & Navigation

The native shell now has explicit controller/keyboard selection semantics instead of depending on pointer/touch or incidental platform focus behavior. D-pad/left stick navigates, primary activates, secondary/Menu backs out, Preferences can be changed from a controller, and iPad Pause can be fully operated from a controller. Hardware-key arrows/Return/Escape share the same selection model. Safe-area layout, screen transitions, title selection treatment, and pause styling are polished while ZoneCore and all accepted gameplay/runtime paths remain frozen.

### Milestone 1.9 — Recovered projectile spatial retirement

The portable projectile model now follows the recovered `+128` live-region lifecycle instead of provisional 90/120-step counters. `shot` and `fire` no longer wrap across the 640x480 boundary; they remain action-active while their sprite overlaps the Classic live rectangle and are retired after leaving it. Continuous projectile position still advances on the 720-Hz master grid, while the spatial-state consequence stays on the 60-Hz Classic boundary. Off-region hostile fire releases the shooter's active-shot cap. Exact shared `+138` traversal/slot-reuse ordering and non-projectile `+128/+129` semantics remain separate work.

### Milestone 1.10 — Shared Object Slots & +138 List Fidelity

The portable core now tracks the recovered 80-record allocator identity and global `+138` object chain in addition to typed portable stores. The player remains persistent head/slot 0; low mode scans 0→79 and inserts after the head; high mode scans 79→0 and appends at the tail; unlink frees the exact record for directional reuse. Player shots/HQ fire and fixed/moving-object paths now use their recovered modes. Ship and world destruction transform the same Classic record into `EXPL`, preserving slot/list identity, and Bee-donor/mobile-Mother first-match scans follow recovered list order. `+129` is decoded as coarse spatial-cell registration, but live world `+128/+129` is intentionally deferred until the original camera/world-to-screen transform is restored.

Next priorities:

1. Milestone 1.11 — recover the original camera/world-to-screen transform, then promote non-projectile `+128/+129` live-region and coarse spatial-cell state including Bee/Seeker edges;
2. Milestone 2.0 — finish remaining Classic collision/destruction/equipment behavior on the recovered object/spatial foundation;
3. Milestone 2.1 — recover procedural Waves 19+;
4. Milestone 2.2+ — Classic Mac RNG compatibility, save/load + Hall of Fame, then continuous Classic Mode closure.

## Phase 4 — Full Classic Mode — ~32%

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

## Phase 5 — Native product/UI layer — ~48%

**Status: active in parallel with Classic gameplay reconstruction.**

Completed foundations:

- SwiftUI/AppKit/UIKit shells;
- Metal game view;
- controller abstraction;
- macOS app branding/icon;
- macOS pause menu with persistent keyboard remapping and Classic-default reset;
- shared native title/menu shell on macOS and iPadOS;
- functional New Game / Controls / Preferences / Credits flows;
- persistent HUD/control-overlay presentation preferences;
- Return-to-Title pause flow on macOS and iPadOS;
- direct developer boot retained through `ZONE_BOOT_DIRECT=1`.

Remaining:

- Continue/save-slot UI and ZoneCore save restoration;
- Hall of Fame UI;
- full recovered Classic preferences;
- game-over/wave-transition presentation;
- controller-remapping UI;
- final iPad touch layout/polish;
- fullscreen/window/display controls;
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
