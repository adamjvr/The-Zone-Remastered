#!/usr/bin/env python3
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]
HEADER = ROOT / "ZoneCore/include/zone_core.h"
SOURCE = ROOT / "ZoneCore/src/zone_core.c"
TESTS = ROOT / "ZoneCore/tests/test_zone_core.c"
MARKER = "Milestone 1.11 recovered world/camera/radar spatial lifecycle"


def die(msg):
    raise SystemExit(f"ERROR: {msg}")


def replace_exact(text, old, new, label, count=None):
    n = text.count(old)
    if count is not None and n != count:
        die(f"{label}: expected {count} exact match(es), found {n}")
    if count is None and n == 0:
        die(f"{label}: source anchor not found")
    return text.replace(old, new)


def replace_once(text, old, new, label):
    n = text.count(old)
    if n != 1:
        die(f"{label}: expected one exact anchor, found {n}")
    return text.replace(old, new, 1)


h = HEADER.read_text()
s = SOURCE.read_text()
t = TESTS.read_text()

if MARKER in s:
    print("Milestone 1.11 source marker already present; nothing to patch.")
    sys.exit(0)

# Public recovered dimensions and spatial debug surface.
h = replace_once(h,
'''#define ZONE_LOGICAL_WIDTH 640
#define ZONE_LOGICAL_HEIGHT 480
#define ZONE_MAX_RENDER_ITEMS 160
''',
'''#define ZONE_LOGICAL_WIDTH 640
#define ZONE_LOGICAL_HEIGHT 480
/* Milestone 1.11: PPC 0x3E98..0x3F3C reserves 112 px at right,
 * then sets the square toroidal world to 2 * max(528, 480) = 1056. */
#define ZONE_CLASSIC_SIDEBAR_WIDTH 112
#define ZONE_PLAYFIELD_WIDTH (ZONE_LOGICAL_WIDTH - ZONE_CLASSIC_SIDEBAR_WIDTH)
#define ZONE_PLAYFIELD_HEIGHT ZONE_LOGICAL_HEIGHT
#define ZONE_RADAR_WIDTH 110
#define ZONE_WORLD_EXTENT 1056
#define ZONE_PLAYFIELD_CENTER_X (ZONE_PLAYFIELD_WIDTH / 2)
#define ZONE_PLAYFIELD_CENTER_Y (ZONE_PLAYFIELD_HEIGHT / 2)
#define ZONE_MAX_RENDER_ITEMS 160
''', "header dimensions")

h = replace_once(h,
'''typedef struct ZoneDebugProjectileState {
    uint8_t active;
    uint8_t hostile;
    uint8_t spatial_active;
    float x;
    float y;
    float vx;
    float vy;
    int32_t sprite;
    int32_t source_slot;
} ZoneDebugProjectileState;
''',
'''typedef struct ZoneDebugProjectileState {
    uint8_t active;
    uint8_t hostile;
    uint8_t spatial_active;
    float x;
    float y;
    float vx;
    float vy;
    int32_t sprite;
    int32_t source_slot;
} ZoneDebugProjectileState;

typedef struct ZoneDebugSpatialState {
    uint8_t active_128;       /* Classic byte +128: screen/action-active */
    uint8_t radar_129;        /* Classic byte +129: right-side radar registration */
    float screen_x;
    float screen_y;
    int32_t radar_x;
    int32_t radar_y;
} ZoneDebugSpatialState;
''', "header spatial struct")

h = replace_once(h,
'''uint32_t zone_game_debug_master_phase(const ZoneGame *game);

#ifdef __cplusplus
''',
'''uint32_t zone_game_debug_master_phase(const ZoneGame *game);
float zone_game_debug_camera_left(const ZoneGame *game);
float zone_game_debug_camera_top(const ZoneGame *game);
ZoneDebugSpatialState zone_game_debug_world_spatial_state(const ZoneGame *game, int32_t index);

#ifdef __cplusplus
''', "header spatial declarations")

# Internal +128/+129 state and camera origin.
s = replace_once(s,
'''struct WorldObject {
    uint8_t active;
    uint8_t player_contact;
''',
'''struct WorldObject {
    uint8_t active;
    uint8_t spatial_active;    /* PPC +128 */
    uint8_t radar_registered; /* PPC +129 */
    uint8_t player_contact;
''', "world spatial fields")

s = replace_once(s,
'''    int hostile_shots;
    int classic_slot;       /* recovered 80-record table identity */
};
''',
'''    int hostile_shots;
    int radar_x;            /* cached Classic +16 map X */
    int radar_y;            /* cached Classic +18 map Y */
    int classic_slot;       /* recovered 80-record table identity */
};
''', "world radar cache")

s = replace_once(s,
'''    float player_x, player_y;
    float player_vx, player_vy; /* portable screen X/Y */
''',
'''    float player_x, player_y;     /* toroidal world-space center */
    float camera_left, camera_top;   /* PPC globals +11108/+11110 */
    float player_vx, player_vy;     /* portable screen-axis velocity */
''', "camera fields")

old_spatial = '''/* PPC spatial maintenance around 0xED44..0xF168 keeps an object
 * action-active while byte +128 is nonzero.  When the object's top-left
 * screen coordinate leaves the strict live rectangle
 *   x > -side && x < width, y > -side && y < height
 * the pass clears +128.  `fire` is then finalized and `shot` is unlinked
 * from the shared object list; neither action owns a lifetime counter.
 *
 * ZoneCore stores sprite centers, not Classic top-left coordinates, so the
 * equivalent center bounds are [-side/2, width+side/2) and likewise for Y. */
static float projectile_half_side(const struct Projectile *p) {
    if (!p) return 8.0f;
    const ZoneSpritePixels *sprite = zone_sprite_pixels(p->sprite);
    return sprite ? (float)sprite->side * 0.5f : 8.0f;
}

static int projectile_outside_classic_live_region(const struct Projectile *p) {
    if (!p || !p->active) return 0;
    const float half = projectile_half_side(p);
    return p->x <= -half || p->x >= (float)ZONE_LOGICAL_WIDTH + half ||
           p->y <= -half || p->y >= (float)ZONE_LOGICAL_HEIGHT + half;
}

static float wrapf(float v, float max) {
    while (v < 0) v += max;
    while (v >= max) v -= max;
    return v;
}
'''
new_spatial = '''/* Milestone 1.11 recovered world/camera/radar spatial lifecycle. */
static float wrapf(float v, float max) {
    while (v < 0) v += max;
    while (v >= max) v -= max;
    return v;
}

static float wrapped_delta(float from, float to) {
    float d = to - from;
    const float half = (float)ZONE_WORLD_EXTENT * 0.5f;
    if (d > half) d -= (float)ZONE_WORLD_EXTENT;
    if (d < -half) d += (float)ZONE_WORLD_EXTENT;
    return d;
}

static void camera_follow_player(ZoneGame *g) {
    if (!g) return;
    g->camera_left = wrapf(g->player_x - (float)ZONE_PLAYFIELD_CENTER_X,
                           (float)ZONE_WORLD_EXTENT);
    g->camera_top = wrapf(g->player_y - (float)ZONE_PLAYFIELD_CENTER_Y,
                          (float)ZONE_WORLD_EXTENT);
}

static void world_to_screen(const ZoneGame *g, float wx, float wy, float *sx, float *sy) {
    if (sx) *sx = g ? wrapped_delta(g->camera_left, wx) : wx;
    if (sy) *sy = g ? wrapped_delta(g->camera_top, wy) : wy;
}

static void update_world_spatial_state(ZoneGame *g, struct WorldObject *o) {
    if (!g || !o || !o->active) return;
    float sx = 0.0f, sy = 0.0f;
    world_to_screen(g, o->x, o->y, &sx, &sy);
    const float half_side = (float)o->side * 0.5f;
    o->spatial_active = (uint8_t)(
        sx > -half_side && sx < (float)ZONE_PLAYFIELD_WIDTH + half_side &&
        sy > -half_side && sy < (float)ZONE_PLAYFIELD_HEIGHT + half_side);

    /* 0xE93C inflates the camera rectangle by world/4 before 0x145A0 tests
       radar eligibility. +129 persists while the object intersects that
       expanded toroidal region. */
    const float quarter = (float)ZONE_WORLD_EXTENT * 0.25f;
    o->radar_registered = (uint8_t)(
        sx > -quarter - half_side &&
        sx < (float)ZONE_PLAYFIELD_WIDTH + quarter + half_side &&
        sy > -quarter - half_side &&
        sy < (float)ZONE_PLAYFIELD_HEIGHT + quarter + half_side);

    if (o->radar_registered) {
        const int wx = (int)wrapf(o->x, (float)ZONE_WORLD_EXTENT);
        const int wy = (int)wrapf(o->y, (float)ZONE_WORLD_EXTENT);
        o->radar_x = ZONE_PLAYFIELD_WIDTH + 1 + (wx * ZONE_RADAR_WIDTH) / ZONE_WORLD_EXTENT;
        o->radar_y = 1 + (wy * ZONE_RADAR_WIDTH) / ZONE_WORLD_EXTENT;
    } else {
        o->radar_x = -1;
        o->radar_y = -1;
    }
}

static void refresh_world_spatial(ZoneGame *g) {
    if (!g) return;
    for (int i = 0; i < ZONE_WORLD_CAP; ++i) {
        if (g->world[i].active) update_world_spatial_state(g, &g->world[i]);
    }
}

/* PPC 0xED44..0xF168: SHOT/FIRE stay action-active while +128 is nonzero,
 * then retire when their sprite leaves the playfield. Positions are world
 * coordinates in 1.11; the live test is performed after toroidal camera
 * projection, once per Classic boundary in the 720-Hz path. */
static float projectile_half_side(const struct Projectile *p) {
    if (!p) return 8.0f;
    const ZoneSpritePixels *sprite = zone_sprite_pixels(p->sprite);
    return sprite ? (float)sprite->side * 0.5f : 8.0f;
}

static int projectile_outside_classic_live_region(const ZoneGame *g,
                                                   const struct Projectile *p) {
    if (!g || !p || !p->active) return 0;
    const float half = projectile_half_side(p);
    float sx = 0.0f, sy = 0.0f;
    world_to_screen(g, p->x, p->y, &sx, &sy);
    return sx <= -half || sx >= (float)ZONE_PLAYFIELD_WIDTH + half ||
           sy <= -half || sy >= (float)ZONE_PLAYFIELD_HEIGHT + half;
}
'''
s = replace_once(s, old_spatial, new_spatial, "spatial helper block")

# Toroidal collision across the 1056x1056 seam.
s = replace_once(s,
'''    const int atlx = (int)lrintf(ax - a->side * 0.5f);
    const int atly = (int)lrintf(ay - a->side * 0.5f);
    const int btlx = (int)lrintf(bx - b->side * 0.5f);
    const int btly = (int)lrintf(by - b->side * 0.5f);
''',
'''    const float local_bx = ax + wrapped_delta(ax, bx);
    const float local_by = ay + wrapped_delta(ay, by);
    const int atlx = (int)lrintf(ax - a->side * 0.5f);
    const int atly = (int)lrintf(ay - a->side * 0.5f);
    const int btlx = (int)lrintf(local_bx - b->side * 0.5f);
    const int btly = (int)lrintf(local_by - b->side * 0.5f);
''', "toroidal collision")

# World creation and targeting now use the recovered 1056 square.
s = replace_once(s,
'''    o->x = 64.0f + rng_unit(g) * (ZONE_LOGICAL_WIDTH - 128.0f);
    o->y = 64.0f + rng_unit(g) * (ZONE_LOGICAL_HEIGHT - 128.0f);
''',
'''    o->x = 64.0f + rng_unit(g) * (ZONE_WORLD_EXTENT - 128.0f);
    o->y = 64.0f + rng_unit(g) * (ZONE_WORLD_EXTENT - 128.0f);
''', "world random placement")

s = replace_once(s,
'''    o->x = wrapf(x, ZONE_LOGICAL_WIDTH);
    o->y = wrapf(y, ZONE_LOGICAL_HEIGHT);
''',
'''    o->x = wrapf(x, (float)ZONE_WORLD_EXTENT);
    o->y = wrapf(y, (float)ZONE_WORLD_EXTENT);
    update_world_spatial_state(g, o);
''', "spawn world wrapping")

s = replace_once(s,
'''    const float dx = shortest_wrapped_delta(from_x, to_x, ZONE_LOGICAL_WIDTH);
    const float dy = shortest_wrapped_delta(from_y, to_y, ZONE_LOGICAL_HEIGHT);
''',
'''    const float dx = shortest_wrapped_delta(from_x, to_x, (float)ZONE_WORLD_EXTENT);
    const float dy = shortest_wrapped_delta(from_y, to_y, (float)ZONE_WORLD_EXTENT);
''', "AI wrapped deltas")

# Respawn/reset to recovered world center. Camera then becomes exactly 264,288.
s = replace_once(s,
'''    /* 0x1663C rebuilds at half the playfield extents minus the 16-pixel
       top-left offset; ZoneCore stores centers, yielding exactly 320,240. */
    g->player_x = ZONE_LOGICAL_WIDTH * 0.5f;
    g->player_y = ZONE_LOGICAL_HEIGHT * 0.5f;
''',
'''    /* 0x1663C creates the ship at playfield center. With the recovered
       initial camera origin (264,288), the ship center is world (528,528). */
    g->player_x = ZONE_WORLD_EXTENT * 0.5f;
    g->player_y = ZONE_WORLD_EXTENT * 0.5f;
    camera_follow_player(g);
''', "respawn world center")

s = replace_once(s,
'''    g->player_x = ZONE_LOGICAL_WIDTH * 0.33f;
    g->player_y = ZONE_LOGICAL_HEIGHT * 0.5f;
''',
'''    g->player_x = ZONE_WORLD_EXTENT * 0.5f;
    g->player_y = ZONE_WORLD_EXTENT * 0.5f;
    camera_follow_player(g);
''', "reset world center")

s = replace_once(s,
'''    populate_fixed_wave(g, 1);
}
''',
'''    populate_fixed_wave(g, 1);
    refresh_world_spatial(g);
}
''', "reset spatial refresh")

# Player and object world integration: Classic API.
s = replace_once(s,
'''        g->player_x = wrapf(g->player_x + g->player_vx * ZONE_MOTION_X_SCALE,
                            ZONE_LOGICAL_WIDTH);
        g->player_y = wrapf(g->player_y + g->player_vy * ZONE_MOTION_Y_SCALE,
                            ZONE_LOGICAL_HEIGHT);
''',
'''        g->player_x = wrapf(g->player_x + g->player_vx * ZONE_MOTION_X_SCALE,
                            (float)ZONE_WORLD_EXTENT);
        g->player_y = wrapf(g->player_y + g->player_vy * ZONE_MOTION_Y_SCALE,
                            (float)ZONE_WORLD_EXTENT);
        camera_follow_player(g);
''', "classic player world integration")

s = replace_once(s,
'''            o->x = wrapf(o->x + o->vx * ZONE_MOTION_X_SCALE, ZONE_LOGICAL_WIDTH);
            o->y = wrapf(o->y + o->vy * ZONE_MOTION_Y_SCALE, ZONE_LOGICAL_HEIGHT);
''',
'''            o->x = wrapf(o->x + o->vx * ZONE_MOTION_X_SCALE, (float)ZONE_WORLD_EXTENT);
            o->y = wrapf(o->y + o->vy * ZONE_MOTION_Y_SCALE, (float)ZONE_WORLD_EXTENT);
''', "classic object world integration")

# Refresh +128/+129 before the Classic projectile/collision pass.
needle = '''    for (int i = 0; i < ZONE_PROJECTILE_CAP; ++i) {
        struct Projectile *p = &g->projectiles[i];
        if (!p->active) continue;
        p->x += p->vx * ZONE_MOTION_X_SCALE;
'''
replacement = '''    refresh_world_spatial(g);

    for (int i = 0; i < ZONE_PROJECTILE_CAP; ++i) {
        struct Projectile *p = &g->projectiles[i];
        if (!p->active) continue;
        p->x = wrapf(p->x + p->vx * ZONE_MOTION_X_SCALE, (float)ZONE_WORLD_EXTENT);
'''
s = replace_once(s, needle, replacement, "classic spatial boundary")
s = replace_once(s,
'''        p->y += p->vy * ZONE_MOTION_Y_SCALE;

        /* Recovered +128 spatial retirement replaces the provisional 90/120
''',
'''        p->y = wrapf(p->y + p->vy * ZONE_MOTION_Y_SCALE, (float)ZONE_WORLD_EXTENT);

        /* Recovered +128 spatial retirement replaces the provisional 90/120
''', "classic projectile world y")

# Both Classic and native paths now pass camera to the +128 live test.
s = replace_exact(s, "projectile_outside_classic_live_region(p)",
                  "projectile_outside_classic_live_region(g, p)",
                  "projectile spatial call sites", count=2)

# High-rate integration retains the accepted 720/60 split, only changing space.
s = replace_once(s,
'''            g->player_x = wrapf(
                g->player_x + g->player_vx * ZONE_MOTION_X_SCALE * motion_fraction,
                ZONE_LOGICAL_WIDTH);
            g->player_y = wrapf(
                g->player_y + g->player_vy * ZONE_MOTION_Y_SCALE * motion_fraction,
                ZONE_LOGICAL_HEIGHT);
''',
'''            g->player_x = wrapf(
                g->player_x + g->player_vx * ZONE_MOTION_X_SCALE * motion_fraction,
                (float)ZONE_WORLD_EXTENT);
            g->player_y = wrapf(
                g->player_y + g->player_vy * ZONE_MOTION_Y_SCALE * motion_fraction,
                (float)ZONE_WORLD_EXTENT);
            camera_follow_player(g);
''', "native player world integration")

s = replace_once(s,
'''                o->x = wrapf(
                    o->x + o->vx * ZONE_MOTION_X_SCALE * motion_fraction,
                    ZONE_LOGICAL_WIDTH);
                o->y = wrapf(
                    o->y + o->vy * ZONE_MOTION_Y_SCALE * motion_fraction,
                    ZONE_LOGICAL_HEIGHT);
''',
'''                o->x = wrapf(
                    o->x + o->vx * ZONE_MOTION_X_SCALE * motion_fraction,
                    (float)ZONE_WORLD_EXTENT);
                o->y = wrapf(
                    o->y + o->vy * ZONE_MOTION_Y_SCALE * motion_fraction,
                    (float)ZONE_WORLD_EXTENT);
''', "native object world integration")

s = replace_once(s,
'''            p->x += p->vx * ZONE_MOTION_X_SCALE * motion_fraction;
            p->y += p->vy * ZONE_MOTION_Y_SCALE * motion_fraction;
''',
'''            p->x = wrapf(p->x + p->vx * ZONE_MOTION_X_SCALE * motion_fraction,
                           (float)ZONE_WORLD_EXTENT);
            p->y = wrapf(p->y + p->vy * ZONE_MOTION_Y_SCALE * motion_fraction,
                           (float)ZONE_WORLD_EXTENT);
''', "native projectile world integration")

s = replace_once(s,
'''        if (classic_end) {
            for (int i = 0; i < ZONE_WORLD_CAP; ++i) {
''',
'''        if (classic_end) {
            refresh_world_spatial(g);
            for (int i = 0; i < ZONE_WORLD_CAP; ++i) {
''', "native spatial boundary")

# Muzzle starts in world coordinates and wraps at the torus seam.
s = replace_once(s,
'''            /* Classic SHOT positions remain in screen space. Do not wrap a
               muzzle that extends past an edge; +128 spatial retirement owns
               the off-region lifecycle. */
            p->x = g->player_x + (float)muzzle.x;
            p->y = g->player_y + (float)muzzle.y;
''',
'''            /* 1.11 promotes SHOT/FIRE positions to toroidal world space.
               +128 retirement still uses the projected playfield rectangle. */
            p->x = wrapf(g->player_x + (float)muzzle.x, (float)ZONE_WORLD_EXTENT);
            p->y = wrapf(g->player_y + (float)muzzle.y, (float)ZONE_WORLD_EXTENT);
''', "projectile world spawn")

# Rendering projects world coordinates through independent camera left/top.
old_render = '''int32_t zone_game_render_item_count(const ZoneGame *g) {
    if (!g) return 0;
    int n = g->player_alive ? 1 : 0;
    for (int i = 0; i < ZONE_WORLD_CAP; ++i) n += !!g->world[i].active;
    for (int i = 0; i < ZONE_PROJECTILE_CAP; ++i) n += !!g->projectiles[i].active;
    for (int i = 0; i < ZONE_EXPLOSION_CAP; ++i) n += !!g->explosions[i].active;
    return n;
}

ZoneRenderItem zone_game_render_item_at(const ZoneGame *g, int32_t index) {
    ZoneRenderItem z = {0, 0, 0, 0, 0, 0};
    if (!g || index < 0) return z;
    int n = 0;

    if (g->player_alive && index == n++) {
        return (ZoneRenderItem){current_ship_sprite(g), g->player_x, g->player_y, 32, 1,
                                g->player_hit_flash_ticks ? 1.0f : 0.0f};
    }
    for (int i = 0; i < ZONE_WORLD_CAP; ++i) {
        const struct WorldObject *o = &g->world[i];
        if (!o->active) continue;
        if (index == n++) {
            return (ZoneRenderItem){o->sprite_base + o->frame, o->x, o->y, (float)o->side, 1,
                                    o->hit_flash_ticks ? 1.0f : 0.0f};
        }
    }
    for (int i = 0; i < ZONE_PROJECTILE_CAP; ++i) {
        const struct Projectile *p = &g->projectiles[i];
        if (!p->active) continue;
        if (index == n++) return (ZoneRenderItem){p->sprite, p->x, p->y, 4, 1, 0};
    }
    for (int i = 0; i < ZONE_EXPLOSION_CAP; ++i) {
        const struct Explosion *e = &g->explosions[i];
        if (!e->active) continue;
        if (index == n++) {
            int frame = explosion_frame_at_age(e);
            if (frame >= e->frame_count) frame = e->frame_count - 1;
            return (ZoneRenderItem){e->sprite_base + frame, e->x, e->y, (float)e->side, 1, 0};
        }
    }
    return z;
}
'''
new_render = '''int32_t zone_game_render_item_count(const ZoneGame *g) {
    if (!g) return 0;
    int n = g->player_alive ? 1 : 0;
    for (int i = 0; i < ZONE_WORLD_CAP; ++i)
        n += !!(g->world[i].active && g->world[i].spatial_active);
    for (int i = 0; i < ZONE_PROJECTILE_CAP; ++i) n += !!g->projectiles[i].active;
    for (int i = 0; i < ZONE_EXPLOSION_CAP; ++i) n += !!g->explosions[i].active;
    return n;
}

ZoneRenderItem zone_game_render_item_at(const ZoneGame *g, int32_t index) {
    ZoneRenderItem z = {0, 0, 0, 0, 0, 0};
    if (!g || index < 0) return z;
    int n = 0;

    if (g->player_alive && index == n++) {
        return (ZoneRenderItem){current_ship_sprite(g),
                                (float)ZONE_PLAYFIELD_CENTER_X,
                                (float)ZONE_PLAYFIELD_CENTER_Y,
                                32, 1, g->player_hit_flash_ticks ? 1.0f : 0.0f};
    }
    for (int i = 0; i < ZONE_WORLD_CAP; ++i) {
        const struct WorldObject *o = &g->world[i];
        if (!o->active || !o->spatial_active) continue;
        if (index == n++) {
            float sx = 0.0f, sy = 0.0f;
            world_to_screen(g, o->x, o->y, &sx, &sy);
            return (ZoneRenderItem){o->sprite_base + o->frame, sx, sy, (float)o->side, 1,
                                    o->hit_flash_ticks ? 1.0f : 0.0f};
        }
    }
    for (int i = 0; i < ZONE_PROJECTILE_CAP; ++i) {
        const struct Projectile *p = &g->projectiles[i];
        if (!p->active) continue;
        if (index == n++) {
            float sx = 0.0f, sy = 0.0f;
            world_to_screen(g, p->x, p->y, &sx, &sy);
            return (ZoneRenderItem){p->sprite, sx, sy, 4, 1, 0};
        }
    }
    for (int i = 0; i < ZONE_EXPLOSION_CAP; ++i) {
        const struct Explosion *e = &g->explosions[i];
        if (!e->active) continue;
        if (index == n++) {
            int frame = explosion_frame_at_age(e);
            float sx = 0.0f, sy = 0.0f;
            if (frame >= e->frame_count) frame = e->frame_count - 1;
            world_to_screen(g, e->x, e->y, &sx, &sy);
            return (ZoneRenderItem){e->sprite_base + frame, sx, sy, (float)e->side, 1, 0};
        }
    }
    return z;
}
'''
s = replace_once(s, old_render, new_render, "world-to-screen renderer")

# Debug state setters now accept world coordinates and keep camera/spatial state coherent.
s = replace_once(s,
'''    g->player_x = wrapf(x, ZONE_LOGICAL_WIDTH);
    g->player_y = wrapf(y, ZONE_LOGICAL_HEIGHT);
    g->player_vx = vx;
    g->player_vy = vy;
''',
'''    g->player_x = wrapf(x, (float)ZONE_WORLD_EXTENT);
    g->player_y = wrapf(y, (float)ZONE_WORLD_EXTENT);
    g->player_vx = vx;
    g->player_vy = vy;
    camera_follow_player(g);
    refresh_world_spatial(g);
''', "debug player world setter")

# This is the remaining debug-world setter occurrence (spawn_world_object_at was patched above).
s = replace_once(s,
'''    o->x = wrapf(x, ZONE_LOGICAL_WIDTH);
    o->y = wrapf(y, ZONE_LOGICAL_HEIGHT);
    o->vx = vx;
''',
'''    o->x = wrapf(x, (float)ZONE_WORLD_EXTENT);
    o->y = wrapf(y, (float)ZONE_WORLD_EXTENT);
    o->vx = vx;
''', "debug world wrapping")

s = replace_once(s,
'''    o->player_contact = 0;
    clear_world_contacts_for_slot(g, index);
}
''',
'''    o->player_contact = 0;
    clear_world_contacts_for_slot(g, index);
    update_world_spatial_state(g, o);
}
''', "debug world spatial refresh")

# Ensure wave reloads recompute camera-dependent +128/+129 state.
s = replace_once(s,
'''    g->wave = wave;
    populate_fixed_wave(g, (unsigned)wave);
}
''',
'''    g->wave = wave;
    populate_fixed_wave(g, (unsigned)wave);
    refresh_world_spatial(g);
}
''', "debug wave spatial refresh")

# New debug accessors; append after the existing final helper.
s += '''\n\n/* ''' + MARKER + ''' */
float zone_game_debug_camera_left(const ZoneGame *g) {
    return g ? g->camera_left : 0.0f;
}

float zone_game_debug_camera_top(const ZoneGame *g) {
    return g ? g->camera_top : 0.0f;
}

ZoneDebugSpatialState zone_game_debug_world_spatial_state(const ZoneGame *g, int32_t index) {
    ZoneDebugSpatialState out = {0, 0, 0.0f, 0.0f, -1, -1};
    if (!g || index < 0 || index >= ZONE_WORLD_CAP) return out;
    const struct WorldObject *o = &g->world[index];
    if (!o->active) return out;
    out.active_128 = o->spatial_active;
    out.radar_129 = o->radar_registered;
    world_to_screen(g, o->x, o->y, &out.screen_x, &out.screen_y);
    out.radar_x = o->radar_x;
    out.radar_y = o->radar_y;
    return out;
}
'''

# Existing regression suite: recovered respawn world center replaces the old
# temporary 320,240 storage assumption. Only these exact assertions move.
t = t.replace('assert(nearly(zone_game_player_x(g), 320.0f));',
              'assert(nearly(zone_game_player_x(g), ZONE_WORLD_EXTENT * 0.5f));')
t = t.replace('assert(nearly(zone_game_player_y(g), 240.0f));',
              'assert(nearly(zone_game_player_y(g), ZONE_WORLD_EXTENT * 0.5f));')

# Transactional write after all anchors have validated.
for path, text in ((HEADER, h), (SOURCE, s), (TESTS, t)):
    tmp = path.with_suffix(path.suffix + '.m111.tmp')
    tmp.write_text(text)
    tmp.replace(path)

print("Patched Milestone 1.11 source/header/regression expectations.")
