# Bee Parity — Pass-by-Pass Plan

Baseline: `4d5568949bd6d2844547789dc85c6d9ec332c9c2`

Rule: one observable Bee behavior per pass. No cumulative world/camera/timebase rewrites.

## Pass 0 — Observe known-good
No behavior changes. Instrument hit triggers, request results, requester quota,
donor occupancy, active Bees, shared object pressure, and Bee destruction.

## Pass 1 — Request quota only
Only if Pass 0 shows requester quota refunds are driving repeat Bee generation.
No donor timing, firing, movement, placement, or spatial changes.

## Pass 2 — Donor occupancy timing only
Test and, if justified, change only when donor +74 is released.

## Pass 3 — Bee firing eligibility only
Test +128/on-screen eligibility in isolation. No spawn-count change.

## Pass 4 — Placement/spatial interaction
Separate research pass. No guessed constants and no Bee hotfix bundled into it.

## Pass 5 — RNG fidelity if needed
Exact Classic Mac Random() compatibility only after Bee rules are isolated.

## Promotion rule
Each pass starts from the previous accepted pass, changes one behavior, passes
deterministic tests, receives a macOS play acceptance, and remains revertible as
one commit. Physical iPad Pro acceptance comes after the Bee passes that survive
macOS testing are combined into the final candidate.
