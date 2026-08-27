#!/usr/bin/env python3
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "ZoneCore/src/zone_core.c"
MARKER = "Bee Parity Pass 0 known-good instrumentation"

def die(msg):
    raise SystemExit(f"ERROR: {msg}")

def once(text, old, new, label):
    n = text.count(old)
    if n != 1:
        die(f"{label}: expected exactly one anchor, found {n}")
    return text.replace(old, new, 1)

def patch(s):
    if MARKER in s:
        print("Bee Parity Pass 0 marker already present; no source changes required.")
        return s

    s = once(
        s,
        "#include <math.h>\n#include <stdlib.h>\n#include <string.h>\n",
        "#include <math.h>\n#include <stdio.h>\n#include <stdlib.h>\n#include <string.h>\n",
        "stdio include",
    )

    helpers_old = "static uint8_t g_trig_ready;\n\nstatic void ensure_trig_tables(void) {\n"
    helpers_new = r'''static uint8_t g_trig_ready;

/* Bee Parity Pass 0 known-good instrumentation.
 * Enabled only when ZONE_BEE_TRACE is present and not "0".
 * Observational only: no RNG consumption and no ZoneGame mutation. */
static int bee_trace_enabled(void) {
    const char *value = getenv("ZONE_BEE_TRACE");
    return value && value[0] != '\0' && strcmp(value, "0") != 0;
}

static int bee_trace_active_bees(const ZoneGame *g) {
    if (!g) return 0;
    int count = 0;
    for (int i = 0; i < ZONE_WORLD_CAP; ++i) {
        count += g->world[i].active && g->world[i].type == TZ_TYPE_BEE;
    }
    return count;
}

static int bee_trace_request_count(const ZoneGame *g, int slot) {
    if (!g || slot < 0 || slot >= ZONE_WORLD_CAP || !g->world[slot].active) return -1;
    return g->world[slot].bee_request_count;
}

static int bee_trace_out_count(const ZoneGame *g, int slot) {
    if (!g || slot < 0 || slot >= ZONE_WORLD_CAP || !g->world[slot].active) return -1;
    return g->world[slot].bee_out_count;
}

static void ensure_trig_tables(void) {
'''
    s = once(s, helpers_old, helpers_new, "trace helpers")

    old_request = r'''static int request_bee(ZoneGame *g, int requester_slot) {
    if (requester_slot < 0 || requester_slot >= ZONE_WORLD_CAP) return -1;
    struct WorldObject *requester = &g->world[requester_slot];
    if (!requester->active ||
        (requester->type != TZ_TYPE_MOTH && requester->type != TZ_TYPE_BASE)) return -1;
    if (g->bee_limit <= 0 || requester->bee_request_count >= g->bee_limit) return -1;

    /* PPC 0x16568 starts at head->+138 and walks that exact chain looking
       for ANOTHER Mother/HQ with no Bee outstanding. */
    for (int classic_slot = g->classic_objects[g->classic_head_slot].next_slot;
         classic_slot >= 0;
         classic_slot = g->classic_objects[classic_slot].next_slot) {
        const int donor_slot = classic_world_index_for_slot(g, classic_slot);
        if (donor_slot < 0 || donor_slot == requester_slot) continue;
        struct WorldObject *donor = &g->world[donor_slot];
        if (donor->type != TZ_TYPE_MOTH && donor->type != TZ_TYPE_BASE) continue;
        if (donor->bee_out_count != 0) continue;

        /* Original top-left placement is donor +8,+8. A 32px Bee centered
           inside a 48px base therefore has the same center as its donor. */
        struct WorldObject *bee = spawn_world_object_at(
            g, TZ_TYPE_BEE, donor->x, donor->y, 0.0f, 0.0f);
        if (!bee) return -1;
        bee->parent_slot = donor_slot;
        bee->requester_slot = requester_slot;
        ++donor->bee_out_count;
        ++requester->bee_request_count;
        ++g->enemies_remaining;
        return (int)(bee - g->world);
    }
    return -1;
}
'''

    new_request = r'''static int request_bee(ZoneGame *g, int requester_slot) {
    const int trace = bee_trace_enabled();

    if (requester_slot < 0 || requester_slot >= ZONE_WORLD_CAP) {
        if (trace) {
            fprintf(stderr,
                    "[BEE_TRACE] event=request_result wave=%d tick=%u requester=%d "
                    "result=blocked reason=invalid_requester\n",
                    g ? g->wave : -1, g ? g->behavior_tick : 0u, requester_slot);
        }
        return -1;
    }

    struct WorldObject *requester = &g->world[requester_slot];
    if (!requester->active ||
        (requester->type != TZ_TYPE_MOTH && requester->type != TZ_TYPE_BASE)) {
        if (trace) {
            fprintf(stderr,
                    "[BEE_TRACE] event=request_result wave=%d tick=%u requester=%d "
                    "result=blocked reason=inactive_or_wrong_type active=%d type=%08x\n",
                    g->wave, g->behavior_tick, requester_slot,
                    requester->active != 0, requester->type);
        }
        return -1;
    }

    if (trace) {
        fprintf(stderr,
                "[BEE_TRACE] event=request_begin wave=%d tick=%u requester=%d "
                "request_count=%d limit=%d active_bees=%d live_objects=%d "
                "player_shots=%d ammo=%d\n",
                g->wave, g->behavior_tick, requester_slot,
                requester->bee_request_count, g->bee_limit,
                bee_trace_active_bees(g), g->classic_live_count,
                active_projectile_count(g), g->ammo);
    }

    if (g->bee_limit <= 0 || requester->bee_request_count >= g->bee_limit) {
        if (trace) {
            fprintf(stderr,
                    "[BEE_TRACE] event=request_result wave=%d tick=%u requester=%d "
                    "result=blocked reason=quota request_count=%d limit=%d "
                    "active_bees=%d live_objects=%d\n",
                    g->wave, g->behavior_tick, requester_slot,
                    requester->bee_request_count, g->bee_limit,
                    bee_trace_active_bees(g), g->classic_live_count);
        }
        return -1;
    }

    int donor_candidates = 0;
    int donor_busy = 0;

    for (int classic_slot = g->classic_objects[g->classic_head_slot].next_slot;
         classic_slot >= 0;
         classic_slot = g->classic_objects[classic_slot].next_slot) {
        const int donor_slot = classic_world_index_for_slot(g, classic_slot);
        if (donor_slot < 0 || donor_slot == requester_slot) continue;
        struct WorldObject *donor = &g->world[donor_slot];
        if (donor->type != TZ_TYPE_MOTH && donor->type != TZ_TYPE_BASE) continue;
        ++donor_candidates;
        if (donor->bee_out_count != 0) {
            ++donor_busy;
            continue;
        }

        struct WorldObject *bee = spawn_world_object_at(
            g, TZ_TYPE_BEE, donor->x, donor->y, 0.0f, 0.0f);
        if (!bee) {
            if (trace) {
                fprintf(stderr,
                        "[BEE_TRACE] event=request_result wave=%d tick=%u requester=%d "
                        "result=blocked reason=spawn_failed donor=%d request_count=%d "
                        "limit=%d active_bees=%d live_objects=%d player_shots=%d ammo=%d\n",
                        g->wave, g->behavior_tick, requester_slot, donor_slot,
                        requester->bee_request_count, g->bee_limit,
                        bee_trace_active_bees(g), g->classic_live_count,
                        active_projectile_count(g), g->ammo);
            }
            return -1;
        }

        bee->parent_slot = donor_slot;
        bee->requester_slot = requester_slot;
        ++donor->bee_out_count;
        ++requester->bee_request_count;
        ++g->enemies_remaining;

        if (trace) {
            fprintf(stderr,
                    "[BEE_TRACE] event=request_result wave=%d tick=%u requester=%d "
                    "result=spawned bee=%d donor=%d requester_count_after=%d "
                    "donor_out_after=%d limit=%d active_bees=%d live_objects=%d "
                    "player_shots=%d ammo=%d\n",
                    g->wave, g->behavior_tick, requester_slot,
                    (int)(bee - g->world), donor_slot,
                    requester->bee_request_count, donor->bee_out_count,
                    g->bee_limit, bee_trace_active_bees(g), g->classic_live_count,
                    active_projectile_count(g), g->ammo);
        }
        return (int)(bee - g->world);
    }

    if (trace) {
        fprintf(stderr,
                "[BEE_TRACE] event=request_result wave=%d tick=%u requester=%d "
                "result=blocked reason=no_donor donor_candidates=%d donor_busy=%d "
                "request_count=%d limit=%d active_bees=%d live_objects=%d\n",
                g->wave, g->behavior_tick, requester_slot,
                donor_candidates, donor_busy,
                requester->bee_request_count, g->bee_limit,
                bee_trace_active_bees(g), g->classic_live_count);
    }
    return -1;
}
'''
    s = once(s, old_request, new_request, "request_bee instrumentation")

    s = once(
        s,
        '''        (void)launch_mother_defenders(g, slot);
        (void)request_bee(g, slot);
''',
        '''        (void)launch_mother_defenders(g, slot);
        if (bee_trace_enabled()) {
            fprintf(stderr,
                    "[BEE_TRACE] event=mother_hit_trigger wave=%d tick=%u mother=%d "
                    "damage=%d request_count=%d limit=%d active_bees=%d\\n",
                    g->wave, g->behavior_tick, slot, o->damage,
                    o->bee_request_count, g->bee_limit, bee_trace_active_bees(g));
        }
        (void)request_bee(g, slot);
''',
        "Mother hit trigger instrumentation",
    )

    s = once(
        s,
        '''    const float y = o->y;
    const int side = o->side;

    /* Destruction consequences are generated before the source slot is freed,
''',
        '''    const float y = o->y;
    const int side = o->side;
    const int trace_bee_destroy = bee_trace_enabled() && destroyed_type == TZ_TYPE_BEE;
    const int trace_bee_donor_slot = trace_bee_destroy ? o->parent_slot : -1;
    const int trace_bee_requester_slot = trace_bee_destroy ? o->requester_slot : -1;
    const int trace_bee_donor_before =
        trace_bee_destroy ? bee_trace_out_count(g, trace_bee_donor_slot) : -1;
    const int trace_bee_requester_before =
        trace_bee_destroy ? bee_trace_request_count(g, trace_bee_requester_slot) : -1;

    /* Destruction consequences are generated before the source slot is freed,
''',
        "Bee destroy pre-state",
    )

    s = once(
        s,
        '''    /* Enemy fire remains alive if its shooter dies, but must no longer
       reference a world slot that can be recycled for a different object. */
''',
        '''    if (trace_bee_destroy) {
        fprintf(stderr,
                "[BEE_TRACE] event=bee_destroy wave=%d tick=%u bee=%d donor=%d "
                "requester=%d donor_out_before=%d donor_out_after=%d "
                "requester_count_before=%d requester_count_after=%d "
                "active_bees_before_remove=%d\\n",
                g->wave, g->behavior_tick, slot,
                trace_bee_donor_slot, trace_bee_requester_slot,
                trace_bee_donor_before,
                bee_trace_out_count(g, trace_bee_donor_slot),
                trace_bee_requester_before,
                bee_trace_request_count(g, trace_bee_requester_slot),
                bee_trace_active_bees(g));
    }

    /* Enemy fire remains alive if its shooter dies, but must no longer
       reference a world slot that can be recycled for a different object. */
''',
        "Bee destroy post-state trace",
    )

    s += f"\n/* {MARKER} */\n"
    return s

def self_test():
    sample = "#include <math.h>\n#include <stdlib.h>\n#include <string.h>\n"
    out = once(sample, sample,
               "#include <math.h>\n#include <stdio.h>\n#include <stdlib.h>\n#include <string.h>\n",
               "sample")
    assert "#include <stdio.h>" in out
    print("Bee Parity Pass 0 patcher self-test: PASS")

def main():
    if "--self-test" in sys.argv:
        self_test()
        return
    if not SOURCE.exists():
        die("ZoneCore/src/zone_core.c not found")
    old = SOURCE.read_text()
    new = patch(old)
    if new != old:
        tmp = SOURCE.with_suffix(".c.bee-pass0.tmp")
        tmp.write_text(new)
        tmp.replace(SOURCE)
        print("Patched Bee Pass 0 instrumentation into ZoneCore/src/zone_core.c")
    else:
        print("No source changes required.")

if __name__ == "__main__":
    main()
