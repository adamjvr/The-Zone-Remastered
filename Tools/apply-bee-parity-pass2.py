#!/usr/bin/env python3
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "ZoneCore/src/zone_core.c"
HEADER = ROOT / "ZoneCore/include/zone_core.h"
TESTS = ROOT / "ZoneCore/tests/test_zone_core.c"
MARKER = "Bee Parity Pass 2 donor +74 releases at Bee EXPL finalization"


def die(msg):
    raise SystemExit(f"ERROR: {msg}")


def once(text, old, new, label):
    n = text.count(old)
    if n != 1:
        die(f"{label}: expected exactly one anchor, found {n}")
    return text.replace(old, new, 1)


def patch(source, header, tests):
    if MARKER in source:
        print("Bee Parity Pass 2 marker already present; preserving source.")
        return source, header, tests

    source = once(
        source,
        "    int classic_slot;       /* transform preserves original 80-record identity */\n};\n",
        "    int classic_slot;       /* transform preserves original 80-record identity */\n"
        "    int parent_slot;        /* Bee +142 donor retained through EXPL finalization */\n};\n",
        "Explosion parent link field",
    )

    source = once(
        source,
        "                .sprite_base = base, .frame_count = frames, .side = side,\n"
        "                .classic_slot = classic_slot,\n",
        "                .sprite_base = base, .frame_count = frames, .side = side,\n"
        "                .classic_slot = classic_slot, .parent_slot = -1,\n",
        "Explosion parent link initialization",
    )

    source = once(
        source,
        "    const int side = o->side;\n"
        "    const int trace_bee_destroy = bee_trace_enabled() && destroyed_type == TZ_TYPE_BEE;\n",
        "    const int side = o->side;\n"
        "    const int bee_donor_slot = destroyed_type == TZ_TYPE_BEE ? o->parent_slot : -1;\n"
        "    const int trace_bee_destroy = bee_trace_enabled() && destroyed_type == TZ_TYPE_BEE;\n",
        "Bee donor capture",
    )

    source = once(
        source,
        "                if (destroyed_type == TZ_TYPE_BEE) {\n"
        "                    if (parent->bee_out_count > 0) --parent->bee_out_count;\n"
        "                } else if (destroyed_type == TZ_TYPE_ROTO) {\n",
        "                if (destroyed_type == TZ_TYPE_BEE) {\n"
        "                    /* Bee Parity Pass 2: PPC +142 survives BEE -> EXPL.\n"
        "                       Donor +74 remains occupied until EXPL finalization. */\n"
        "                } else if (destroyed_type == TZ_TYPE_ROTO) {\n",
        "immediate Bee donor release",
    )

    source = once(
        source,
        "    clear_world_contacts_for_slot(g, slot);\n"
        "    if (!transform_slot_to_explosion(g, classic_slot, x, y, side, destroyed_type)) {\n"
        "        /* The 80-entry explosion surrogate has at least one free typed entry\n"
        "           whenever this source occupies a Classic slot; keep a defensive\n"
        "           fallback rather than leaking allocator state. */\n"
        "        classic_free_slot(g, classic_slot);\n"
        "    }\n",
        "    clear_world_contacts_for_slot(g, slot);\n"
        "    const int transformed =\n"
        "        transform_slot_to_explosion(g, classic_slot, x, y, side, destroyed_type);\n"
        "    if (transformed) {\n"
        "        if (destroyed_type == TZ_TYPE_BEE && bee_donor_slot >= 0) {\n"
        "            for (int i = 0; i < ZONE_EXPLOSION_CAP; ++i) {\n"
        "                struct Explosion *e = &g->explosions[i];\n"
        "                if (!e->active || e->classic_slot != classic_slot ||\n"
        "                    e->previous_type != TZ_TYPE_BEE) continue;\n"
        "                e->parent_slot = bee_donor_slot;\n"
        "                break;\n"
        "            }\n"
        "        }\n"
        "    } else {\n"
        "        /* Defensive fallback: no EXPL means no later finalizer. */\n"
        "        if (destroyed_type == TZ_TYPE_BEE &&\n"
        "            bee_donor_slot >= 0 && bee_donor_slot < ZONE_WORLD_CAP) {\n"
        "            struct WorldObject *donor = &g->world[bee_donor_slot];\n"
        "            if (donor->active &&\n"
        "                (donor->type == TZ_TYPE_MOTH || donor->type == TZ_TYPE_BASE) &&\n"
        "                donor->bee_out_count > 0) {\n"
        "                --donor->bee_out_count;\n"
        "            }\n"
        "        }\n"
        "        classic_free_slot(g, classic_slot);\n"
        "    }\n",
        "Bee EXPL donor retention",
    )

    source = once(
        source,
        "            const uint32_t previous_type = e->previous_type;\n"
        "            const int classic_slot = e->classic_slot;\n"
        "            e->active = 0;\n"
        "            e->classic_slot = -1;\n\n"
        "            if (previous_type == TZ_TYPE_SHIP) {\n",
        "            const uint32_t previous_type = e->previous_type;\n"
        "            const int classic_slot = e->classic_slot;\n"
        "            const int parent_slot = e->parent_slot;\n"
        "            e->active = 0;\n"
        "            e->classic_slot = -1;\n"
        "            e->parent_slot = -1;\n\n"
        "            if (previous_type == TZ_TYPE_BEE &&\n"
        "                parent_slot >= 0 && parent_slot < ZONE_WORLD_CAP) {\n"
        "                struct WorldObject *donor = &g->world[parent_slot];\n"
        "                if (donor->active &&\n"
        "                    (donor->type == TZ_TYPE_MOTH || donor->type == TZ_TYPE_BASE) &&\n"
        "                    donor->bee_out_count > 0) {\n"
        "                    --donor->bee_out_count;\n"
        "                    if (bee_trace_enabled()) {\n"
        "                        fprintf(stderr,\n"
        "                                \"[BEE_TRACE] event=bee_donor_release wave=%d tick=%u \"\n"
        "                                \"donor=%d donor_out_after=%d\\n\",\n"
        "                                g->wave, g->behavior_tick, parent_slot,\n"
        "                                donor->bee_out_count);\n"
        "                    }\n"
        "                }\n"
        "            }\n\n"
        "            if (previous_type == TZ_TYPE_SHIP) {\n",
        "Bee donor finalization release",
    )

    header = once(
        header,
        "int32_t zone_game_debug_world_defender_count(const ZoneGame *game, int32_t index);\n",
        "int32_t zone_game_debug_world_defender_count(const ZoneGame *game, int32_t index);\n"
        "int32_t zone_game_debug_world_bee_out_count(const ZoneGame *game, int32_t index);\n"
        "int32_t zone_game_debug_world_bee_request_count(const ZoneGame *game, int32_t index);\n",
        "Bee debug accessor declarations",
    )

    source = once(
        source,
        "int32_t zone_game_debug_world_defender_count(const ZoneGame *g, int32_t index) {\n"
        "    if (!g || index < 0 || index >= ZONE_WORLD_CAP || !g->world[index].active) return 0;\n"
        "    return g->world[index].defender_count;\n"
        "}\n\n",
        "int32_t zone_game_debug_world_defender_count(const ZoneGame *g, int32_t index) {\n"
        "    if (!g || index < 0 || index >= ZONE_WORLD_CAP || !g->world[index].active) return 0;\n"
        "    return g->world[index].defender_count;\n"
        "}\n\n"
        "int32_t zone_game_debug_world_bee_out_count(const ZoneGame *g, int32_t index) {\n"
        "    if (!g || index < 0 || index >= ZONE_WORLD_CAP || !g->world[index].active) return -1;\n"
        "    return g->world[index].bee_out_count;\n"
        "}\n\n"
        "int32_t zone_game_debug_world_bee_request_count(const ZoneGame *g, int32_t index) {\n"
        "    if (!g || index < 0 || index >= ZONE_WORLD_CAP || !g->world[index].active) return -1;\n"
        "    return g->world[index].bee_request_count;\n"
        "}\n\n",
        "Bee debug accessor definitions",
    )

    pass1_test = (
        "    zone_game_debug_destroy_world(g, bee);\n"
        "    assert(zone_game_count_type(g, TZ_TYPE_BEE) == 0);\n"
        "    assert(zone_game_hud(g).enemies == 0);\n\n"
        "    /* Bee Parity Pass 1: destroying the Bee releases the donor in the\n"
        "       current portable lifecycle, but it must NOT refund the requesting\n"
        "       Mother's per-wave request quota. Wave-1 bee_limit is still one. */\n"
        "    assert(zone_game_debug_request_bee(g, requester) < 0);\n"
        "    assert(zone_game_count_type(g, TZ_TYPE_BEE) == 0);\n"
    )

    pass2_test = (
        "    assert(zone_game_debug_world_bee_out_count(g, donor) == 1);\n"
        "    assert(zone_game_debug_world_bee_request_count(g, requester) == 1);\n\n"
        "    zone_game_debug_destroy_world(g, bee);\n"
        "    assert(zone_game_count_type(g, TZ_TYPE_BEE) == 0);\n"
        "    assert(zone_game_hud(g).enemies == 0);\n"
        "    assert(zone_game_debug_active_explosions(g) == 1);\n\n"
        "    /* Pass 2: donor +74 remains occupied throughout the Bee-derived EXPL,\n"
        "       while Pass 1 requester +76 remains cumulatively consumed. */\n"
        "    assert(zone_game_debug_world_bee_out_count(g, donor) == 1);\n"
        "    assert(zone_game_debug_world_bee_request_count(g, requester) == 1);\n"
        "    assert(zone_game_debug_request_bee(g, requester) < 0);\n\n"
        "    advance_ticks(g, 11);\n"
        "    assert(zone_game_debug_active_explosions(g) == 1);\n"
        "    assert(zone_game_debug_world_bee_out_count(g, donor) == 1);\n"
        "    assert(zone_game_debug_world_bee_request_count(g, requester) == 1);\n\n"
        "    advance_ticks(g, 1);\n"
        "    assert(zone_game_debug_active_explosions(g) == 0);\n"
        "    assert(zone_game_debug_world_bee_out_count(g, donor) == 0);\n"
        "    assert(zone_game_debug_world_bee_request_count(g, requester) == 1);\n"
        "    assert(zone_game_debug_request_bee(g, requester) < 0);\n"
        "    assert(zone_game_count_type(g, TZ_TYPE_BEE) == 0);\n"
    )
    tests = once(tests, pass1_test, pass2_test, "Pass 1 Bee lifecycle regression")

    source += f"\n/* {MARKER} */\n"
    return source, header, tests


def validate(source, header, tests):
    if MARKER not in source:
        die("Pass 2 source marker missing")
    if "--requester->bee_request_count" in source:
        die("Pass 1 requester quota regression was lost")
    required = [
        "Bee +142 donor retained through EXPL finalization",
        "event=bee_donor_release",
        "zone_game_debug_world_bee_out_count",
        "zone_game_debug_world_bee_request_count",
    ]
    joined = source + header
    for token in required:
        if token not in joined:
            die(f"required Pass 2 token missing: {token}")
    if "advance_ticks(g, 11);" not in tests or "advance_ticks(g, 1);" not in tests:
        die("Pass 2 EXPL timing regression missing")


def self_test():
    assert "bee_donor_release" in "event=bee_donor_release"
    print("Bee Parity Pass 2 patcher self-test: PASS")


def main():
    if "--self-test" in sys.argv:
        self_test()
        return
    for p in (SOURCE, HEADER, TESTS):
        if not p.exists():
            die(f"missing {p.relative_to(ROOT)}")
    s0, h0, t0 = SOURCE.read_text(), HEADER.read_text(), TESTS.read_text()
    s1, h1, t1 = patch(s0, h0, t0)
    validate(s1, h1, t1)
    for path, old, new in ((SOURCE, s0, s1), (HEADER, h0, h1), (TESTS, t0, t1)):
        if old == new:
            continue
        tmp = Path(str(path) + ".bee-pass2.tmp")
        tmp.write_text(new)
        tmp.replace(path)
    print("Applied Bee Pass 2 donor-occupancy finalization timing.")


if __name__ == "__main__":
    main()
