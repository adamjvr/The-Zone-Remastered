# Wave generation (`0x13328`)

The PPC wave-populator contains two explicit 19-entry jump tables in packed data:

- TOC/data `+5808`: selected when Preferences `normal_play != 0` (professional/harder behavior).
- TOC/data `+5732`: selected when `normal_play == 0` (beginner/easier behavior).

Index 1..18 maps to fixed presets reconstructed in `tables/wave-presets.csv` and `src/waves.c`. Index 0 and waves above 18 enter procedural/random branches.

Before the enemy preset, the game creates `min(wave + 2, 14)` asteroid-class objects. Each is normally `aste`; depending on a random bit and a game-level condition it may be a `rock` instead.

Direct spawn loops after preset selection establish the following high-confidence meanings:

- `moth_count`: Mother Bases.
- `base_count`: Head Quarters.
- `raid_count`: Raiders.
- `seek_count`: Seekers.
- `rotor_link_count`: number of initial Mother Bases that receive a linked Rotor (`moth.link2 = roto`, `roto.link1 = moth`).
- `bloo_subtype_quota`: controls how many base/mother subtype tags are initialized to `bloo`; remaining tags use `swar` for mothers and `moto` for HQs.
- `mobile_moth_quota`: the first N Mother Bases get `state_84 = 1`. The exact flag name remains tentative, but its later behavior is consistent with the manual's rare hunting/mobile Mother Base state.
- `bee_limit`: global TOC+12382. `0x16504` checks a base/mother's `counter_76` against this before another `bee!` can be requested/spawned.

The routine also computes the initial HUD counters. `moth_count + base_count` is written to TOC+11282, strongly identifying that global as the remaining **Bases** count.
