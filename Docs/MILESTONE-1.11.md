# Milestone 1.11 — Recovered world/camera/radar spatial lifecycle

Base: `d0aea36c484ceffd796717ded325d660f8243ed5` (Milestone 1.10)

This milestone replaces the temporary 640×480-as-world assumption with the Classic PPC spatial model recovered from the annotated executable.

## Promoted behavior

- full display: 640×480
- right-side instrument/radar reservation: 112 px
- playable viewport: 528×480
- right-side radar drawable width: 110 px
- toroidal world: 1056×1056
- initial ship world center: 528,528
- initial camera left/top: 264,288
- ship presentation remains fixed at playfield center 264,240
- world bodies and projectiles use toroidal world coordinates
- rendering uses wrapped world→screen projection through independent camera left/top
- exact-pixel collision uses shortest toroidal separation across world seams
- object byte `+128` is modeled as screen/action-active state
- object byte `+129` is modeled as right-side radar/map registration, not a collision cell
- cached radar coordinates follow the recovered `world * 110 / 1056` mapping
- Bee/Seeker and other non-projectile bodies can remain radar-registered while off-screen
- SHOT/FIRE retirement remains a 60-Hz Classic-boundary consequence inside the accepted 720-Hz master loop
- shared Classic object capacity remains 80 records

## PPC evidence promoted

- `0x3E98..0x3F3C`: display/playfield sizing and square world extent
- `0x12C48..0x12CF0`: initial camera left/top from `(world - viewport) / 2`
- `0xE8F0..0xE9D0`: camera rectangle and quarter-world expanded spatial rectangle
- `0x145A0..0x14868`: `+128` activation and `+129` radar register/update/remove
- `0x419C`: byte write into row-pointer radar/map buffer
- `0xED08..0xED34`: processing-list inclusion when either `+129` or `+128` is set
- `0xED44..0xF168`: screen/action clipping and SHOT/FIRE retirement
- `0x16128..0x161AC`: toroidal world-coordinate integration

See `Docs/RE-world-camera-radar-spatial.md` for the field-level reconstruction.
