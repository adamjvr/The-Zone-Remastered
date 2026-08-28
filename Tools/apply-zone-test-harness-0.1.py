#!/usr/bin/env python3
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "ZoneCore/src/zone_core.c"
MARKER = "Zone Test Harness 0.1 environment-gated fixed-Zone startup"
PASS2 = "Bee Parity Pass 2 donor +74 releases at Bee EXPL finalization"


def die(msg):
    raise SystemExit(f"ERROR: {msg}")


def patch(source):
    if MARKER in source:
        print("Zone Test Harness 0.1 source marker already present; preserving source.")
        return source
    if PASS2 not in source:
        die("accepted Bee Parity Pass 2 prerequisite missing")

    reset_start = source.find("void zone_game_reset(ZoneGame *g, uint32_t seed) {")
    reset_end = source.find("\nZoneGame *zone_game_create(uint32_t seed) {", reset_start)
    if reset_start < 0 or reset_end < 0:
        die("could not isolate zone_game_reset()")

    helper = r'''/* Test harness only. Normal gameplay does not consult a requested Zone
 * unless ZONE_TEST_MODE is explicitly enabled. Keeping this in ZoneCore lets
 * every host use the same forensic startup path without UI-specific hacks. */
static int test_start_zone_from_environment(void) {
    const char *mode = getenv("ZONE_TEST_MODE");
    if (!mode || mode[0] == '\0' || strcmp(mode, "0") == 0) return 0;

    const char *value = getenv("ZONE_TEST_START_ZONE");
    if (!value || value[0] == '\0') return 0;

    char *end = NULL;
    const long zone = strtol(value, &end, 10);
    if (!end || end == value || *end != '\0' || zone < 1 || zone > 18) return 0;
    return (int)zone;
}

'''
    source = source[:reset_start] + helper + source[reset_start:]

    reset_start = source.find("void zone_game_reset(ZoneGame *g, uint32_t seed) {")
    reset_end = source.find("\nZoneGame *zone_game_create(uint32_t seed) {", reset_start)
    reset = source[reset_start:reset_end]
    anchor = "    populate_fixed_wave(g, 1);\n"
    if reset.count(anchor) != 1:
        die(f"zone_game_reset fixed-wave anchor: expected exactly one, found {reset.count(anchor)}")

    replacement = anchor + r'''

    /* Testing-only direct Zone startup. This intentionally uses the same
       fixed-wave population path as zone_game_debug_load_fixed_wave(). */
    const int test_start_zone = test_start_zone_from_environment();
    if (test_start_zone > 1) {
        g->wave = test_start_zone;
        populate_fixed_wave(g, (unsigned)test_start_zone);
    }
'''
    reset = reset.replace(anchor, replacement, 1)
    source = source[:reset_start] + reset + source[reset_end:]
    source += f"\n/* {MARKER} */\n"
    return source


def validate(source):
    for token in [
        MARKER,
        'getenv("ZONE_TEST_MODE")',
        'getenv("ZONE_TEST_START_ZONE")',
        'strtol(value, &end, 10)',
        'populate_fixed_wave(g, (unsigned)test_start_zone);',
    ]:
        if token not in source:
            die(f"missing harness token: {token}")
    if "--requester->bee_request_count" in source:
        die("Pass 1 requester-quota fix was lost")
    if "event=bee_donor_release" not in source:
        die("Pass 2 donor-finalization fix was lost")


def self_test():
    sample = r'''/* Bee Parity Pass 2 donor +74 releases at Bee EXPL finalization */
/* event=bee_donor_release */
void zone_game_reset(ZoneGame *g, uint32_t seed) {
    g->wave = 1;
    populate_fixed_wave(g, 1);
}
ZoneGame *zone_game_create(uint32_t seed) {
    return 0;
}
'''
    out = patch(sample)
    validate(out)
    assert out.count("test_start_zone_from_environment") >= 2
    print("Zone Test Harness 0.1 patcher self-test: PASS")


def main():
    if "--self-test" in sys.argv:
        self_test()
        return
    if not SOURCE.exists():
        die("ZoneCore/src/zone_core.c not found")
    old = SOURCE.read_text()
    new = patch(old)
    validate(new)
    if new != old:
        tmp = SOURCE.with_suffix(".c.zone-test-harness.tmp")
        tmp.write_text(new)
        tmp.replace(SOURCE)
        print("Applied environment-gated direct Zone startup harness.")
    else:
        print("Zone Test Harness 0.1 already applied.")


if __name__ == "__main__":
    main()
