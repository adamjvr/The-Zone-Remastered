# Bee Parity Pass 0r1 — Trace String Compile Repair

Pass 0 correctly limited itself to diagnostics, but its generator contained two
non-raw Python triple-quoted replacement strings.  In those two replacements,
`\n` was interpreted by Python while generating `zone_core.c`, producing a real
line break inside a C string constant.

Affected trace records:

- `mother_hit_trigger`
- `bee_destroy`

This revision changes only those two generated string escapes from a literal
newline to C `\n`, and repairs `Tools/apply-bee-parity-pass0.py` so rerunning it
cannot reproduce the compile failure.

No gameplay state, Bee rule, RNG call, counter, motion, collision, wave,
renderer, or audio behavior is changed.

The accidental `Tools/__pycache__` directory from the original package is also
removed.
