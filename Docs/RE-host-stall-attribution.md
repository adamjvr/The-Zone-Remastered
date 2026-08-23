# Reverse-Engineering / Performance Note — Host Stall Attribution

## Accepted baseline

Milestone 1.1 established an important separation between game behavior and native real-time implementation:

- ZoneCore remained on the accepted Milestone 1.0 stepping contract;
- all recovered sprite textures were prepared before active presentation;
- no bundle lookup, PNG decode, or Metal texture allocation remained in `texture(_:)`;
- mapped sounds were prepared as 16-voice banks before gameplay;
- no WAV read or `AVAudioPlayer` construction remained in `play(_:)`.

The first extended diagnostic run completed Zone 1 and reported all 651 sprite textures loaded successfully. It produced no actual texture-miss or voice-steal events. The remaining visible issue therefore needs finer attribution rather than another global timing change.

## Why `host.step()` was too coarse

At Milestone 1.1 the renderer measured this entire call:

```text
host.step()
```

but the host itself performs:

```text
input.sample()
zone_game_step()
zone_game_drain_audio()
ZoneAudioEngine.play()  [0..N events]
zone_game_hud() + DispatchQueue.main.async HUD publication [every sixth step]
```

A slow outer measurement proves only that one of those operations blocked. It cannot identify the responsible subsystem.

## 1.2 structured record

A representative diagnostic record has this shape:

```text
[ZonePerf][host-detail] frame=844 total=75.000 input=0.050 core=0.600 drain=0.010 audio=74.200 audioMax=74.100 audioType=2 hud=0.020 hudPub=0 events=1 dominantMS=74.200 wave=1 bases=0 enemies=0 world=3 shots=0 hostile=0 tick=844 dominant=audio
```

The state probes are intentionally performed **after** the measured total is captured. They therefore do not inflate the stage timing being diagnosed.

The record is emitted only when total host time exceeds 4 ms and only when diagnostics are enabled.

## Audio trigger split

`ZoneAudioEngine.play()` now distinguishes the rewind and start operations:

```text
player.currentTime = 0
player.play()
```

If their combined diagnostic duration exceeds 2 ms, a record such as this is emitted:

```text
[ZonePerf][audio] slow-trigger sid=130 event=2 voice=0 total=73.500 reset=0.010 play=73.490 started=1
```

This is specifically designed to test the hypothesis that a prepared `AVAudioPlayer` can still block while starting or waking its underlying audio path.

No audio behavior is changed by this measurement.

## Automatic summary

`Tools/summarize-macos-perf.command` parses the structured records and reports:

- frame-gap count and worst gap;
- slow host-step count;
- counts over 16.7, 20, and 50 ms;
- worst host step and dominant stage;
- maximum time observed for each host stage;
- dominant-stage histogram;
- slow audio trigger count and worst resource/event/voice;
- texture misses and voice steals.

`Tools/test-perf-summary.command` feeds a synthetic known log through the parser so changes to the diagnostic format cannot silently break the summary tool.

## Fidelity boundary

This milestone is diagnostic infrastructure, not recovered gameplay behavior. It deliberately does not reinterpret the Classic TickCount gate, alter enemy behavior divisors, modify projectile integration, or introduce interpolation/extrapolation.

Once one native subsystem is proven responsible for the stall, that subsystem can be repaired independently and regression-tested against this accepted gameplay baseline.
