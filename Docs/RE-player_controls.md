# Player control lift — `ship` branch at `0x115F8`

The branch is selected by the `ship` FOURCC in `0x113B8`.

## Heading

- `object+124` is a float heading in degrees.
- left subtracts the runtime rotation step; right adds it.
- heading wraps at 0/360.
- `object+54 = trunc(heading / 7.5)`, giving exactly 48 orientations.
- at the end of the player branch, `object+56 = object+54`, selecting the
  current ship sprite frame.

The literal 360.0 and 7.5 constants are present in the PEF packed data at TOC
constant offsets 2992 and 3016 respectively.

## Thrust

The thrust key is key-table entry +4. On first press `object+132` becomes 1
and the thrust sound is triggered. `object+60` drives alternating thrust sprite
banks.

The movement calculation uses the game's 360-entry tables:

```
candidate_vx = vx + Math0[trunc(heading)]   # Math0 = -sin(deg)
candidate_vy = vy + Math1[trunc(heading)]   # Math1 =  cos(deg)
```

It calculates both old and candidate magnitudes. Candidate velocity is committed
when:

```
candidate_speed <= maximum_speed
OR
candidate_speed < old_speed
```

This is an important piece of the original inertial feel: at the cap, thrust
that reduces speed is still accepted.

## Fire modes

The fire key is key-table entry +6. The routine checks the current object-count
limit and a firing-mode variable before calling projectile creator `0x12224`.
Observed mode structures include:

- center/single shot;
- two parallel offset shots using sprite orientations `frame-2` and `frame+2`;
- three-shot fan: center plus headings `heading-7.5` and `heading+7.5`;
- an additional mode gated by the runtime fire-mode/cadence state (machine-gun
  behavior is consistent with the shipping help text but the final cadence
  variable name is intentionally not asserted yet).

## Equipment

Key entries +8/+10 drive the selected equipment state (observed selection
values include 1, 3, and 5). The branches consume counters and create objects
or invoke `0x16BB4`; exact UI names are being assigned only where the help data
and resource state agree.
