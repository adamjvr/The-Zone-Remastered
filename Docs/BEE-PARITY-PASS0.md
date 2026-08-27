# Bee Parity Pass 0 — Known-Good Instrumentation

This package adds diagnostics only to the known-good 1.11.4 gameplay baseline.
Tracing is disabled unless `ZONE_BEE_TRACE` is nonzero.

Captured events:
- `mother_hit_trigger`
- `request_begin`
- `request_result`
- `bee_destroy`

The trace records wave/tick, requester quota, Bee limit, donor selection,
active Bee count, shared Classic live-object count, player-shot use/ammo, and
before/after donor/requester counters when a Bee dies.

Run:
`./Tools/run-macos-bee-trace.command`

The existing perf runner captures the trace in `build/perf-logs/`. After the app
quits, the wrapper writes a human summary and CSV under `build/bee-parity/`.

Pass 0 is not a fix. It tells us exactly why the known-good build produces the
Bee population observed during normal play.
