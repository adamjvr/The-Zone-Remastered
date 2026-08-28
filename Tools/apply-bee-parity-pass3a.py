#!/usr/bin/env python3
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "ZoneCore/src/zone_core.c"
MARKER = "Bee Parity Pass 3A firing forensics only"


def die(msg):
    raise SystemExit(f"ERROR: {msg}")


def once(text, old, new, label):
    n = text.count(old)
    if n != 1:
        die(f"{label}: expected exactly one anchor, found {n}")
    return text.replace(old, new, 1)


OLD_HELPER = r'''static int bee_trace_enabled(void) {
    const char *value = getenv("ZONE_BEE_TRACE");
    return value && value[0] != '\0' && strcmp(value, "0") != 0;
}
'''

NEW_HELPER = r'''static int bee_trace_enabled(void) {
    const char *value = getenv("ZONE_BEE_TRACE");
    return value && value[0] != '\0' && strcmp(value, "0") != 0;
}

/* Pass 3A is deliberately observational. Keep the high-volume Bee fire trace
 * on its own switch so ordinary Bee request tracing remains compact. */
static int bee_fire_trace_enabled(void) {
    const char *value = getenv("ZONE_BEE_FIRE_TRACE");
    return value && value[0] != '\0' && strcmp(value, "0") != 0;
}
'''

OLD_FIRE = r'''static void update_enemy_fire(ZoneGame *g, int slot) {
    if (!g->player_alive || slot < 0 || slot >= ZONE_WORLD_CAP) return;
    struct WorldObject *o = &g->world[slot];
    const int cap = o->active ? tz_enemy_fire_active_cap(o->type) : 0;
    if (cap <= 0 || o->hostile_shots >= cap) return;

    /* Bee 0x154A8 and Seeker 0x15944 branch to their common return before
       Random() while +66 is in its timed state. Preserve RNG call ordering by
       suppressing the fire test itself rather than merely refusing the shot. */
    if ((o->type == TZ_TYPE_BEE || o->type == TZ_TYPE_SEEK) &&
        enemy_hit_state_active(g, o)) return;

    const int16_t random_word = (int16_t)(rng_next(g) & 0xFFFFu);
    if (tz_enemy_should_fire(o->type, random_word)) {
        (void)spawn_hostile_projectile(g, slot);
    }
}
'''

NEW_FIRE = r'''static void update_enemy_fire(ZoneGame *g, int slot) {
    if (!g->player_alive || slot < 0 || slot >= ZONE_WORLD_CAP) return;
    struct WorldObject *o = &g->world[slot];
    const int trace_bee_fire = bee_fire_trace_enabled() && o->active && o->type == TZ_TYPE_BEE;
    const int cap = o->active ? tz_enemy_fire_active_cap(o->type) : 0;
    if (cap <= 0 || o->hostile_shots >= cap) {
        if (trace_bee_fire) {
            fprintf(stderr,
                    "[BEE_FIRE_TRACE] event=blocked wave=%d tick=%u bee=%d "
                    "reason=shot_cap hostile_shots=%d cap=%d x=%.3f y=%.3f\n",
                    g->wave, g->behavior_tick, slot, o->hostile_shots, cap,
                    o->x, o->y);
        }
        return;
    }

    /* Bee 0x154A8 and Seeker 0x15944 branch to their common return before
       Random() while +66 is in its timed state. Preserve RNG call ordering by
       suppressing the fire test itself rather than merely refusing the shot. */
    if ((o->type == TZ_TYPE_BEE || o->type == TZ_TYPE_SEEK) &&
        enemy_hit_state_active(g, o)) {
        if (trace_bee_fire) {
            fprintf(stderr,
                    "[BEE_FIRE_TRACE] event=blocked wave=%d tick=%u bee=%d "
                    "reason=hit_state hostile_shots=%d cap=%d x=%.3f y=%.3f\n",
                    g->wave, g->behavior_tick, slot, o->hostile_shots, cap,
                    o->x, o->y);
        }
        return;
    }

    /* IMPORTANT: the trace consumes no RNG. It observes the exact same word
       already consumed by the pre-Pass-3A firing path. */
    const int16_t random_word = (int16_t)(rng_next(g) & 0xFFFFu);
    const int fire_gate = tz_enemy_should_fire(o->type, random_word);
    int fired = 0;
    if (fire_gate) {
        fired = spawn_hostile_projectile(g, slot);
    }

    if (trace_bee_fire) {
        fprintf(stderr,
                "[BEE_FIRE_TRACE] event=decision wave=%d tick=%u bee=%d "
                "random_word=%d gate=%d fired=%d hostile_shots=%d cap=%d "
                "x=%.3f y=%.3f vx=%.3f vy=%.3f player_x=%.3f player_y=%.3f\n",
                g->wave, g->behavior_tick, slot, (int)random_word,
                fire_gate, fired, o->hostile_shots, cap,
                o->x, o->y, o->vx, o->vy, g->player_x, g->player_y);
    }
}
'''


def patch(s):
    if MARKER in s:
        print("Bee Parity Pass 3A marker already present; preserving source.")
        return s
    if "Bee Parity Pass 2 donor +74 releases at Bee EXPL finalization" not in s:
        die("Pass 2 prerequisite missing")
    s = once(s, OLD_HELPER, NEW_HELPER, "Bee fire trace helper")
    s = once(s, OLD_FIRE, NEW_FIRE, "update_enemy_fire forensic instrumentation")
    s += f"\n/* {MARKER} */\n"
    return s


def validate(s):
    for token in [MARKER, "ZONE_BEE_FIRE_TRACE", "[BEE_FIRE_TRACE]", "const int fire_gate"]:
        if token not in s:
            die(f"missing token: {token}")
    if "--requester->bee_request_count" in s:
        die("Pass 1 requester quota regression was lost")
    if "event=bee_donor_release" not in s:
        die("Pass 2 donor-finalization logic was lost")


def self_test():
    sample = OLD_HELPER + "\n" + OLD_FIRE + "\n/* Bee Parity Pass 2 donor +74 releases at Bee EXPL finalization */\n"
    sample += "\n/* event=bee_donor_release */\n/* Bee Parity Pass 1 requester quota is cumulative for the wave */\n"
    out = patch(sample)
    validate(out)
    print("Bee Parity Pass 3A patcher self-test: PASS")


def main():
    if "--self-test" in sys.argv:
        self_test(); return
    if not SOURCE.exists():
        die("ZoneCore/src/zone_core.c not found")
    old = SOURCE.read_text()
    new = patch(old)
    validate(new)
    if new != old:
        tmp = SOURCE.with_suffix(".c.bee-pass3a.tmp")
        tmp.write_text(new)
        tmp.replace(SOURCE)
        print("Applied Bee Pass 3A firing instrumentation (no gameplay rule changes).")
    else:
        print("Pass 3A already applied.")

if __name__ == "__main__":
    main()
