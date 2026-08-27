#!/usr/bin/env python3
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "ZoneCore/src/zone_core.c"
PATCHER = ROOT / "Tools/apply-bee-parity-pass0.py"
MARKER = "Bee Parity Pass 0r1 trace-string repair"


def die(msg):
    raise SystemExit(f"ERROR: {msg}")


def repair_text(source_text, patcher_text):
    # The original package emitted two literal newlines inside C string
    # constants.  They must be escaped as backslash-n.
    bad_c = [
        '"damage=%d request_count=%d limit=%d active_bees=%d\n",',
        '"active_bees_before_remove=%d\n",',
    ]
    good_c = [
        '"damage=%d request_count=%d limit=%d active_bees=%d\\n",',
        '"active_bees_before_remove=%d\\n",',
    ]

    for bad, good in zip(bad_c, good_c):
        count = source_text.count(bad)
        if count > 1:
            die(f"unexpected duplicate malformed C trace anchor: {bad!r}")
        if count == 1:
            source_text = source_text.replace(bad, good, 1)

    # Repair the Pass-0 generator itself.  Its Python source currently contains
    # one backslash-n in non-raw triple-quoted replacement strings; executing
    # that script converts the escape to a real newline in generated C.
    patcher_pairs = [
        (
            '"damage=%d request_count=%d limit=%d active_bees=%d\\n",',
            '"damage=%d request_count=%d limit=%d active_bees=%d\\\\n",',
        ),
        (
            '"active_bees_before_remove=%d\\n",',
            '"active_bees_before_remove=%d\\\\n",',
        ),
    ]
    for old, new in patcher_pairs:
        count = patcher_text.count(old)
        if count > 1:
            die(f"unexpected duplicate Pass-0 generator anchor: {old!r}")
        if count == 1:
            patcher_text = patcher_text.replace(old, new, 1)

    if MARKER not in source_text:
        source_text += f"\n/* {MARKER} */\n"

    return source_text, patcher_text


def validate(source_text, patcher_text):
    malformed = [
        '"damage=%d request_count=%d limit=%d active_bees=%d\n",',
        '"active_bees_before_remove=%d\n",',
    ]
    for bad in malformed:
        if bad in source_text:
            die(f"malformed C trace string remains: {bad!r}")

    required_c = [
        '"damage=%d request_count=%d limit=%d active_bees=%d\\n",',
        '"active_bees_before_remove=%d\\n",',
        MARKER,
    ]
    for item in required_c:
        if item not in source_text:
            die(f"required repaired source marker missing: {item!r}")

    required_patcher = [
        '"damage=%d request_count=%d limit=%d active_bees=%d\\\\n",',
        '"active_bees_before_remove=%d\\\\n",',
    ]
    for item in required_patcher:
        if item not in patcher_text:
            die(f"Pass-0 generator is not repaired: {item!r}")


def self_test():
    sample_source = (
        'fprintf(stderr, "damage=%d request_count=%d limit=%d active_bees=%d\n", x);\n'
        'fprintf(stderr, "active_bees_before_remove=%d\n", y);\n'
    )
    sample_patcher = (
        '"damage=%d request_count=%d limit=%d active_bees=%d\\n",\n'
        '"active_bees_before_remove=%d\\n",\n'
    )
    s, p = repair_text(sample_source, sample_patcher)
    validate(s, p)
    print("Bee Parity Pass 0r1 repair self-test: PASS")


def main():
    if "--self-test" in sys.argv:
        self_test()
        return

    if not SOURCE.exists():
        die("ZoneCore/src/zone_core.c not found")
    if not PATCHER.exists():
        die("Tools/apply-bee-parity-pass0.py not found")

    source_old = SOURCE.read_text()
    patcher_old = PATCHER.read_text()
    source_new, patcher_new = repair_text(source_old, patcher_old)
    validate(source_new, patcher_new)

    if source_new != source_old:
        tmp = SOURCE.with_suffix(".c.bee-pass0r1.tmp")
        tmp.write_text(source_new)
        tmp.replace(SOURCE)
        print("Repaired the two malformed C Bee-trace strings.")
    else:
        print("C Bee-trace strings already repaired.")

    if patcher_new != patcher_old:
        tmp = PATCHER.with_suffix(".py.bee-pass0r1.tmp")
        tmp.write_text(patcher_new)
        tmp.replace(PATCHER)
        print("Repaired the Pass-0 generator so it cannot recreate the bug.")
    else:
        print("Pass-0 generator already repaired.")


if __name__ == "__main__":
    main()
