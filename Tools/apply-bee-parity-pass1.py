#!/usr/bin/env python3
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "ZoneCore/src/zone_core.c"
TESTS = ROOT / "ZoneCore/tests/test_zone_core.c"
MARKER = "Bee Parity Pass 1 requester quota is cumulative for the wave"

SOURCE_OLD = """        if (destroyed_type == TZ_TYPE_BEE &&
            o->requester_slot >= 0 && o->requester_slot < ZONE_WORLD_CAP) {
            struct WorldObject *requester = &g->world[o->requester_slot];
            if (requester->active && requester->bee_request_count > 0) {
                --requester->bee_request_count;
            }
        }
"""
SOURCE_NEW = """        /* Bee Parity Pass 1 / PPC requester +76:
         * Bee destruction does NOT refund the Mother's request quota.
         * +76 is cumulative requests consumed by that requester for the
         * current wave. Donor +74 cleanup remains unchanged in this pass. */
"""
TEST_OLD = """    /* Destroying the linked Bee repairs both recovered counters. */
    assert(zone_game_debug_request_bee(g, requester) >= 0);
"""
TEST_NEW = """    /* Bee Parity Pass 1: destroying the Bee releases the donor in the
       current portable lifecycle, but it must NOT refund the requesting
       Mother's per-wave request quota. Wave-1 bee_limit is still one. */
    assert(zone_game_debug_request_bee(g, requester) < 0);
    assert(zone_game_count_type(g, TZ_TYPE_BEE) == 0);
"""
DONOR_CLEANUP = """if (destroyed_type == TZ_TYPE_BEE) {
                    if (parent->bee_out_count > 0) --parent->bee_out_count;
                }"""

def die(msg):
    raise SystemExit(f"ERROR: {msg}")

def replace_once(text, old, new, label):
    n = text.count(old)
    if n != 1:
        die(f"{label}: expected exactly one anchor, found {n}")
    return text.replace(old, new, 1)

def validate(source, tests):
    if "--requester->bee_request_count" in source:
        die("requester Bee quota decrement still exists")
    if MARKER not in source:
        die("Pass 1 source marker missing")
    if TEST_NEW not in tests:
        die("Pass 1 regression expectation missing")
    if DONOR_CLEANUP not in source:
        die("donor +74 cleanup changed unexpectedly")

def patch(source, tests):
    if MARKER in source:
        validate(source, tests)
        print("Bee Parity Pass 1 already applied; preserving source.")
        return source, tests
    source = replace_once(source, SOURCE_OLD, SOURCE_NEW, "requester quota refund block")
    tests = replace_once(tests, TEST_OLD, TEST_NEW, "two-base Bee quota regression")
    source += f"\n/* {MARKER} */\n"
    validate(source, tests)
    return source, tests

def self_test():
    s = "x\n" + SOURCE_OLD + "\n" + DONOR_CLEANUP + "\ny"
    t = "a\n" + TEST_OLD + "\nb"
    s, t = patch(s, t)
    validate(s, t)
    print("Bee Parity Pass 1 patcher self-test: PASS")

def main():
    if "--self-test" in sys.argv:
        self_test()
        return
    if not SOURCE.exists() or not TESTS.exists():
        die("ZoneCore source/tests not found")
    source_old = SOURCE.read_text()
    tests_old = TESTS.read_text()
    source_new, tests_new = patch(source_old, tests_old)
    if source_new != source_old:
        tmp = SOURCE.with_suffix(".c.bee-pass1.tmp")
        tmp.write_text(source_new)
        tmp.replace(SOURCE)
        print("Removed Bee requester-quota refund on Bee destruction.")
    else:
        print("Pass 1 source already applied.")
    if tests_new != tests_old:
        tmp = TESTS.with_suffix(".c.bee-pass1.tmp")
        tmp.write_text(tests_new)
        tmp.replace(TESTS)
        print("Updated Bee lifetime-quota regression.")
    else:
        print("Pass 1 regression already applied.")

if __name__ == "__main__":
    main()
