# Bee Parity Pass 3A — Firing Forensics Only

Pass 2 was accepted in play testing. The next recovered Bee detail is the original Bee firing eligibility path, but the accepted playable branch lacks a critical prerequisite: original world-object byte +128 and the 1056x1056 camera/world model are not live in this branch.

The accepted branch instead stores world objects directly in wrapped 640x480 coordinates. Adding an alleged "+128" firing gate here would therefore either do nothing or require reintroducing the broad spatial rewrite that previously broke gameplay.

Pass 3A makes **no firing-rule change**. It records every Bee pre-RNG block from timed hit state or the active hostile-shot cap, the exact signed RNG word already consumed by the existing path, whether the word passed the recovered Bee fire predicate, whether a hostile projectile was actually allocated, and Bee/player coordinates and Bee velocity at the decision.

The trace does not consume an additional RNG word.

Run:

`./Tools/run-macos-bee-fire-trace.command`

The summary/CSV are written under `build/bee-parity/`.

True +128/off-screen firing parity is deferred until spatial behavior can be reconstructed and tested as its own forensic project.
