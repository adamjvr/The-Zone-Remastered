# Milestone 1.4.1 — Raider Fire-Cap Regression Hotfix

Base working state: uncommitted Milestone 1.4 overlay on committed Milestone 1.3 (`92f4e1912310162992f067c70edb7133412b48ec`).

The first full Milestone 1.4 verification correctly stopped in the pre-existing ZoneCore regression suite:

```text
assert(tz_enemy_fire_active_cap(TZ_TYPE_RAID) == 3)
```

The recovered AI documentation and PPC Raider handler establish that `raid` uses the same `object+72 < 3` active hostile-shot gate as `bloo`, `bee!`, and `seek`. The helper already exposed Raider's recovered strict Random window `(10000,20000)` but accidentally omitted Raider from `tz_enemy_fire_active_cap()`, effectively preventing Raider hostile shots.

This hotfix adds exactly `TZ_TYPE_RAID` to that shared cap helper. No timing, motion, timebase, renderer, audio, Bee, Seeker, Mother, HQ, Rotor, wave, or collision rule is changed.

The Milestone 1.4 verifier is tightened so ZoneCore may differ from committed 1.3 only by this exact audited one-line semantic correction.
