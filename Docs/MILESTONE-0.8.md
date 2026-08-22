# Milestone 0.8 — Base Damage Feedback & Headquarters Defense

Milestone 0.8 is deliberately a stabilization-first continuation of the 0.7 roadmap.

## 1. Mother Base “stops taking damage” play-test report

The live 0.7 engine already kept the Mother Base's cumulative `damage` field increasing. A forced-hit reconstruction reaches the recovered Professional destruction threshold of **40** correctly.

The misleading behavior appeared after the Mother Base reached its linked-defender cap. At that point a valid nonlethal projectile hit could:

1. add one damage;
2. fail to launch another defender because the cap was full;
3. fail to request a Bee when no valid donor was available;
4. produce no separate visual hit state in the remaster.

The hit therefore became visually indistinguishable from a miss.

The original PPC path does have feedback. The base/mother damage branch around `0x19BD8` accumulates the projectile damage. For a nonlethal Mother Base/HQ hit, `0x19C9C` requests sound-effect index 8 and stores `1` to object byte **+133**. The renderer consumes that byte as a one-draw effect flag and clears it.

### 0.8 fix

ZoneCore now carries a one-frame `hit_flash_ticks` semantic for Mother Base/HQ objects. Every valid nonlethal hit:

- increments cumulative damage;
- raises the one-draw impact flag;
- emits a dedicated `ZONE_AUDIO_HIT` event;
- then runs the appropriate Mother/HQ hit reaction.

The Metal renderer renders that semantic as a short white impact flash. This is intentionally a modern representation of the recovered one-draw flag; the exact classic palette/effect operation used by the original draw helper remains a later fidelity item.

The exact mapping from original sound-dispatch index 8 to one of the extracted `snd ` resources is also not yet fully lifted. The current Apple audio layer uses the existing generic impact sample so the event is audible while preserving that uncertainty in documentation.

## 2. Long-run damage regression

A deterministic regression now:

- creates the Professional Wave-1 Mother Base;
- deliberately fills its recovered **5-defender** active cap first;
- applies valid player-shot damage repeatedly;
- verifies damage values 1 through 39 remain cumulative;
- verifies each nonlethal hit can produce the damage-feedback event;
- verifies hit 40 destroys the Mother Base;
- verifies the linked defenders remain alive after the parent is destroyed.

This specifically protects the play-test case that motivated 0.8.

## 3. Headquarters hit reaction

The separate Headquarters routine at PPC `0x16390` is now promoted into the live engine.

Unlike Mother Base `0x161D0`, the HQ routine has no signed-Random launch gate. A nonlethal HQ hit attempts defender deployment from the four corner positions around the 48×48 HQ and stops at its recovered active cap:

- **Professional: 4**
- **Beginner: 2**

The linked children use the HQ's assigned defender subtype. In the fixed-wave population code this remains the recovered allocation rule: Bloody quota first, otherwise Off-Shore (`moto`) for Headquarters.

Destroying a linked defender repairs the parent's active-defender count, and a later HQ hit can refill the newly available slot.

The Mother Base Bee-request path remains Mother-specific; Headquarters do not invoke it.

## 4. Regression coverage

The existing strict C suite remains enabled with `-Wall -Wextra -Werror` and 0.8 adds:

- Mother Base 40-hit damage continuity through saturated defender cap;
- render-item damage flag visibility;
- dedicated hit-event emission;
- Headquarters active-cap constants;
- Headquarters four-defender deployment and replenishment;
- production nonlethal HQ shot consequence.

## Still intentionally pending

Milestone 0.8 does not rearrange the roadmap. Major next items remain:

1. complete Mother Base/HQ movement state machines;
2. Bee/Seeker edge states and Rotor orbit/attack/return state machine;
3. hostile projectile special cases/lifetimes;
4. late wave presentation and procedural waves after 18;
5. remaining collision/destruction/equipment effects.

The fidelity rule remains: unknown original behavior stays isolated and documented rather than silently replaced with guessed “final” behavior.
