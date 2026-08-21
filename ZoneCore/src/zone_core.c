#include "zone_core.h"
#include "zone_sprite_data.h"
#include "thezone_decomp.h"

#include <math.h>
#include <stdlib.h>
#include <string.h>

#define ZONE_PI 3.14159265358979323846f
#define ZONE_SHIP_BASE 1000
#define ZONE_SHOT_BASE 148
#define ZONE_PROJECTILE_CAP 16
#define ZONE_EXPLOSION_CAP 12
#define ZONE_WORLD_CAP 64

/* Recovered gameplay constants currently promoted into the playable core. */
#define ZONE_CLASSIC_TURN_DEG 4.5f
#define ZONE_CLASSIC_MAX_SPEED 12.0f
#define ZONE_MOTION_X_SCALE 0.325f
#define ZONE_MOTION_Y_SCALE 0.25f
#define ZONE_PROJECTILE_SPEED 15.0f
#define ZONE_FIRE_COOLDOWN_TICKS 8

struct Projectile {
    uint8_t active;
    float x, y, vx, vy;
    int life;
    int sprite;
};

struct Explosion {
    uint8_t active;
    float x, y;
    int age;
    int sprite_base;
    int frame_count;
    int side;
};

struct WorldObject {
    uint8_t active;
    uint32_t type;
    float x, y, vx, vy;
    int sprite_base;
    int frame_count;
    int frame;
    int side;
    int damage;
    int tick;
};

struct ZoneGame {
    uint32_t rng;
    float player_x, player_y;
    float player_vx, player_vy; /* portable screen X/Y */
    float heading;
    int fire_cooldown;
    uint8_t fire_latch;
    uint8_t pause_latch;

    struct WorldObject world[ZONE_WORLD_CAP];
    struct Projectile projectiles[ZONE_PROJECTILE_CAP];
    struct Explosion explosions[ZONE_EXPLOSION_CAP];

    int score, shields, wave, ammo;
    int bases_remaining, enemies_remaining;
    uint8_t professional;
    uint8_t paused;

    ZoneAudioEvent audio[ZONE_MAX_AUDIO_EVENTS];
    int audio_count;
};

static float g_neg_sin_360[360];
static float g_cos_360[360];
static uint8_t g_trig_ready;

static void ensure_trig_tables(void) {
    if (g_trig_ready) return;
    for (int i = 0; i < 360; ++i) {
        const float radians = (float)i * ZONE_PI / 180.0f;
        g_neg_sin_360[i] = -sinf(radians);
        g_cos_360[i] = cosf(radians);
    }
    g_trig_ready = 1;
}

static uint32_t rng_next(ZoneGame *g) {
    /* Deterministic placeholder. Exact classic Mac Random() remains a later
       compatibility item; keeping it isolated prevents it leaking into rules. */
    uint32_t x = g->rng ? g->rng : 0x6D2B79F5u;
    x ^= x << 13;
    x ^= x >> 17;
    x ^= x << 5;
    g->rng = x;
    return x;
}

static float rng_unit(ZoneGame *g) {
    return (rng_next(g) & 0xFFFFFFu) / (float)0x1000000u;
}

static float wrapf(float v, float max) {
    while (v < 0) v += max;
    while (v >= max) v -= max;
    return v;
}

static void audio_push(ZoneGame *g, int type, float x, float y) {
    if (g->audio_count >= ZONE_MAX_AUDIO_EVENTS) return;
    g->audio[g->audio_count++] = (ZoneAudioEvent){type, x, y};
}

static int exact_overlap_ids(int a_id, float ax, float ay,
                             int b_id, float bx, float by) {
    const ZoneSpritePixels *a = zone_sprite_pixels(a_id);
    const ZoneSpritePixels *b = zone_sprite_pixels(b_id);
    if (!a || !b) return 0;

    TzSpriteView av = {a->side, a->pixels};
    TzSpriteView bv = {b->side, b->pixels};
    const int atlx = (int)lrintf(ax - a->side * 0.5f);
    const int atly = (int)lrintf(ay - a->side * 0.5f);
    const int btlx = (int)lrintf(bx - b->side * 0.5f);
    const int btly = (int)lrintf(by - b->side * 0.5f);
    return tz_sprite_overlap_exact(&av, atlx, atly, &bv, btlx, btly);
}

static int current_ship_frame(const ZoneGame *g) {
    return tz_heading_to_frame48(g->heading);
}

static int current_ship_sprite(const ZoneGame *g) {
    return ZONE_SHIP_BASE + current_ship_frame(g);
}

static int object_visual_spec(uint32_t type, int *base, int *frames, int *side) {
    switch (type) {
        case TZ_TYPE_ASTE: *base = 400;   *frames = 24; *side = 32; return 1;
        case TZ_TYPE_ROCK: *base = 900;   *frames = 30; *side = 48; return 1;
        case TZ_TYPE_STON: *base = 1200;  *frames = 16; *side = 24; return 1;
        case TZ_TYPE_MOTH: *base = 9000;  *frames = 8;  *side = 48; return 1;
        case TZ_TYPE_BASE: *base = 10100; *frames = 8;  *side = 48; return 1;
        case TZ_TYPE_SWAR: *base = 11000; *frames = 24; *side = 16; return 1;
        case TZ_TYPE_MOTO: *base = 11100; *frames = 24; *side = 16; return 1;
        case TZ_TYPE_BLOO: *base = 12000; *frames = 24; *side = 16; return 1;
        case TZ_TYPE_BEE:  *base = 4000;  *frames = 24; *side = 32; return 1;
        case TZ_TYPE_RAID: *base = 4100;  *frames = 24; *side = 32; return 1;
        case TZ_TYPE_SEEK: *base = 7000;  *frames = 24; *side = 32; return 1;
        case TZ_TYPE_ROTO: *base = 6000;  *frames = 24; *side = 32; return 1;
        default: return 0;
    }
}

static int destruction_threshold(const ZoneGame *g, uint32_t type) {
    const TzDamageThresholds t = tz_damage_thresholds(g->professional != 0);
    return tz_damage_threshold_for_type(type, &t);
}

static int allocate_world_slot(ZoneGame *g) {
    for (int i = 0; i < ZONE_WORLD_CAP; ++i) {
        if (!g->world[i].active) return i;
    }
    return -1;
}

static struct WorldObject *spawn_world_object(ZoneGame *g, uint32_t type) {
    const int slot = allocate_world_slot(g);
    if (slot < 0) return NULL;

    int base = 0, frames = 0, side = 0;
    if (!object_visual_spec(type, &base, &frames, &side)) return NULL;

    struct WorldObject *o = &g->world[slot];
    memset(o, 0, sizeof(*o));
    o->active = 1;
    o->type = type;
    o->sprite_base = base;
    o->frame_count = frames;
    o->side = side;
    o->frame = (int)(rng_next(g) % (uint32_t)frames);

    /* Spawn placement remains isolated/provisional until 0x13D5C is fully
       lifted. The population counts and object classes are already exact. */
    o->x = 64.0f + rng_unit(g) * (ZONE_LOGICAL_WIDTH - 128.0f);
    o->y = 64.0f + rng_unit(g) * (ZONE_LOGICAL_HEIGHT - 128.0f);

    if (type == TZ_TYPE_ASTE) {
        o->vx = -3.0f + rng_unit(g) * 6.0f;
        o->vy = -3.0f + rng_unit(g) * 6.0f;
        if (fabsf(o->vx) < 0.7f) o->vx = o->vx < 0.0f ? -0.7f : 0.7f;
        if (fabsf(o->vy) < 0.7f) o->vy = o->vy < 0.0f ? -0.7f : 0.7f;
    }
    return o;
}

static void populate_wave_1(ZoneGame *g) {
    memset(g->world, 0, sizeof(g->world));
    const TzWavePreset *preset = tz_wave_preset(g->professional != 0, 1);
    const unsigned asteroids = tz_initial_asteroid_count(1);

    for (unsigned i = 0; i < asteroids; ++i) (void)spawn_world_object(g, TZ_TYPE_ASTE);
    if (preset) {
        for (int i = 0; i < preset->moth_count; ++i) (void)spawn_world_object(g, TZ_TYPE_MOTH);
        for (int i = 0; i < preset->base_count; ++i) (void)spawn_world_object(g, TZ_TYPE_BASE);
        g->bases_remaining = preset->moth_count + preset->base_count;
        g->enemies_remaining = preset->raid_count + preset->seek_count;
    }
}

static void spawn_explosion(ZoneGame *g, float x, float y, int destroyed_side) {
    int base = 1500, frames = 20, side = 32;
    switch (destroyed_side) {
        case 16: base = 700;   frames = 11; side = 16; break;
        case 24: base = 3000;  frames = 11; side = 24; break;
        case 32: base = 600;   frames = 11; side = 32; break;
        case 48: base = 20000; frames = 11; side = 48; break;
        default: break;
    }

    for (int i = 0; i < ZONE_EXPLOSION_CAP; ++i) {
        if (!g->explosions[i].active) {
            g->explosions[i] = (struct Explosion){1, x, y, 0, base, frames, side};
            audio_push(g, ZONE_AUDIO_EXPLOSION, x, y);
            return;
        }
    }
}

static void destroy_world_object(ZoneGame *g, struct WorldObject *o) {
    if (!o || !o->active) return;
    const TzKillAward *award = tz_kill_award_for_type(o->type);
    if (award) g->score += award->score;
    if (o->type == TZ_TYPE_MOTH || o->type == TZ_TYPE_BASE) {
        if (g->bases_remaining > 0) --g->bases_remaining;
    } else if (o->type == TZ_TYPE_RAID || o->type == TZ_TYPE_SEEK ||
               o->type == TZ_TYPE_BEE || o->type == TZ_TYPE_ROTO ||
               o->type == TZ_TYPE_SWAR || o->type == TZ_TYPE_MOTO ||
               o->type == TZ_TYPE_BLOO) {
        if (g->enemies_remaining > 0) --g->enemies_remaining;
    }
    spawn_explosion(g, o->x, o->y, o->side);
    o->active = 0;
}

static void spawn_projectile(ZoneGame *g) {
    ensure_trig_tables();
    for (int i = 0; i < ZONE_PROJECTILE_CAP; ++i) {
        if (!g->projectiles[i].active) {
            const int frame = current_ship_frame(g);
            const TzMuzzleOffset muzzle = tz_ship_muzzle_offset_frame48((int16_t)frame);
            float dx = 0.0f, dy = 0.0f;
            tz_screen_direction_from_heading(g->heading, g_neg_sin_360, g_cos_360, &dx, &dy);

            struct Projectile *p = &g->projectiles[i];
            p->active = 1;
            p->x = wrapf(g->player_x + (float)muzzle.x, ZONE_LOGICAL_WIDTH);
            p->y = wrapf(g->player_y + (float)muzzle.y, ZONE_LOGICAL_HEIGHT);
            p->vx = dx * ZONE_PROJECTILE_SPEED;
            p->vy = dy * ZONE_PROJECTILE_SPEED;
            p->life = 90;
            p->sprite = ZONE_SHOT_BASE;
            audio_push(g, ZONE_AUDIO_FIRE, p->x, p->y);
            return;
        }
    }
}

void zone_game_reset(ZoneGame *g, uint32_t seed) {
    ensure_trig_tables();
    memset(g, 0, sizeof(*g));
    g->rng = seed ? seed : 0x19940811u;
    g->player_x = ZONE_LOGICAL_WIDTH * 0.33f;
    g->player_y = ZONE_LOGICAL_HEIGHT * 0.5f;
    g->heading = 0.0f;
    g->score = 0;
    g->shields = 100;
    g->wave = 1;
    g->ammo = 2;
    g->professional = 1;
    populate_wave_1(g);
}

ZoneGame *zone_game_create(uint32_t seed) {
    ZoneGame *g = calloc(1, sizeof(*g));
    if (g) zone_game_reset(g, seed);
    return g;
}

void zone_game_destroy(ZoneGame *g) {
    free(g);
}

void zone_game_step(ZoneGame *g, ZoneInput in) {
    if (!g) return;

    if (in.pause && !g->pause_latch) g->paused = !g->paused;
    g->pause_latch = in.pause;
    if (g->paused) return;

    const float turn = in.turn < -0.25f ? -1.0f : (in.turn > 0.25f ? 1.0f : 0.0f);
    g->heading = tz_wrap_heading(g->heading + turn * ZONE_CLASSIC_TURN_DEG);

    if (in.thrust > 0.5f) {
        /* Recovered PPC uses classic Mac vertical/horizontal component order.
           ZoneCore exposes modern screen X/Y, so swap at the boundary. */
        float vertical = g->player_vy;
        float horizontal = g->player_vx;
        if (tz_apply_player_thrust(&vertical, &horizontal,
                                   g->heading, ZONE_CLASSIC_MAX_SPEED,
                                   g_neg_sin_360, g_cos_360)) {
            g->player_vx = horizontal;
            g->player_vy = vertical;
        }
    }

    g->player_x = wrapf(g->player_x + g->player_vx * ZONE_MOTION_X_SCALE,
                        ZONE_LOGICAL_WIDTH);
    g->player_y = wrapf(g->player_y + g->player_vy * ZONE_MOTION_Y_SCALE,
                        ZONE_LOGICAL_HEIGHT);

    if (g->fire_cooldown > 0) --g->fire_cooldown;
    if (in.fire && g->fire_cooldown == 0) {
        spawn_projectile(g);
        g->fire_cooldown = ZONE_FIRE_COOLDOWN_TICKS;
    }
    g->fire_latch = in.fire;

    for (int i = 0; i < ZONE_WORLD_CAP; ++i) {
        struct WorldObject *o = &g->world[i];
        if (!o->active) continue;
        ++o->tick;
        if (o->type == TZ_TYPE_ASTE) {
            o->x = wrapf(o->x + o->vx * ZONE_MOTION_X_SCALE, ZONE_LOGICAL_WIDTH);
            o->y = wrapf(o->y + o->vy * ZONE_MOTION_Y_SCALE, ZONE_LOGICAL_HEIGHT);
            if ((o->tick & 7) == 0) o->frame = (o->frame + 1) % o->frame_count;
        } else if (o->type == TZ_TYPE_MOTH || o->type == TZ_TYPE_BASE) {
            /* Sprite animation is active; full movement/state machine lands in
               the following gameplay milestone. */
            if ((o->tick & 7) == 0) o->frame = (o->frame + 1) % o->frame_count;
        }
    }

    for (int i = 0; i < ZONE_PROJECTILE_CAP; ++i) {
        struct Projectile *p = &g->projectiles[i];
        if (!p->active) continue;
        p->x = wrapf(p->x + p->vx * ZONE_MOTION_X_SCALE, ZONE_LOGICAL_WIDTH);
        p->y = wrapf(p->y + p->vy * ZONE_MOTION_Y_SCALE, ZONE_LOGICAL_HEIGHT);
        if (--p->life <= 0) {
            p->active = 0;
            continue;
        }

        for (int j = 0; j < ZONE_WORLD_CAP && p->active; ++j) {
            struct WorldObject *o = &g->world[j];
            if (!o->active) continue;
            if (!exact_overlap_ids(p->sprite, p->x, p->y,
                                   o->sprite_base + o->frame, o->x, o->y)) continue;

            p->active = 0;
            o->damage += tz_shot_damage_from_upgrade(0);
            const int threshold = destruction_threshold(g, o->type);
            if (threshold > 0 && o->damage >= threshold) destroy_world_object(g, o);
        }
    }

    for (int i = 0; i < ZONE_WORLD_CAP; ++i) {
        struct WorldObject *o = &g->world[i];
        if (!o->active || o->type != TZ_TYPE_ASTE) continue;
        if (exact_overlap_ids(current_ship_sprite(g), g->player_x, g->player_y,
                              o->sprite_base + o->frame, o->x, o->y)) {
            --g->shields;
            if (g->shields < 0) g->shields = 0;
            audio_push(g, ZONE_AUDIO_COLLISION, g->player_x, g->player_y);
        }
    }

    for (int i = 0; i < ZONE_EXPLOSION_CAP; ++i) {
        struct Explosion *e = &g->explosions[i];
        if (!e->active) continue;
        ++e->age;
        if ((e->age / 2) >= e->frame_count) e->active = 0;
    }
}

int32_t zone_game_render_item_count(const ZoneGame *g) {
    if (!g) return 0;
    int n = 1;
    for (int i = 0; i < ZONE_WORLD_CAP; ++i) n += !!g->world[i].active;
    for (int i = 0; i < ZONE_PROJECTILE_CAP; ++i) n += !!g->projectiles[i].active;
    for (int i = 0; i < ZONE_EXPLOSION_CAP; ++i) n += !!g->explosions[i].active;
    return n;
}

ZoneRenderItem zone_game_render_item_at(const ZoneGame *g, int32_t index) {
    ZoneRenderItem z = {0, 0, 0, 0, 0};
    if (!g || index < 0) return z;
    int n = 0;

    if (index == n++) {
        return (ZoneRenderItem){current_ship_sprite(g), g->player_x, g->player_y, 32, 1};
    }
    for (int i = 0; i < ZONE_WORLD_CAP; ++i) {
        const struct WorldObject *o = &g->world[i];
        if (!o->active) continue;
        if (index == n++) {
            return (ZoneRenderItem){o->sprite_base + o->frame, o->x, o->y, (float)o->side, 1};
        }
    }
    for (int i = 0; i < ZONE_PROJECTILE_CAP; ++i) {
        const struct Projectile *p = &g->projectiles[i];
        if (!p->active) continue;
        if (index == n++) return (ZoneRenderItem){p->sprite, p->x, p->y, 4, 1};
    }
    for (int i = 0; i < ZONE_EXPLOSION_CAP; ++i) {
        const struct Explosion *e = &g->explosions[i];
        if (!e->active) continue;
        if (index == n++) {
            int frame = e->age / 2;
            if (frame >= e->frame_count) frame = e->frame_count - 1;
            return (ZoneRenderItem){e->sprite_base + frame, e->x, e->y, (float)e->side, 1};
        }
    }
    return z;
}

ZoneHUDState zone_game_hud(const ZoneGame *g) {
    if (!g) return (ZoneHUDState){0};
    return (ZoneHUDState){
        g->score, g->shields, g->wave, g->ammo,
        g->bases_remaining, g->enemies_remaining, g->paused
    };
}

int32_t zone_game_drain_audio(ZoneGame *g, ZoneAudioEvent *events, int32_t cap) {
    if (!g || !events || cap <= 0) return 0;
    const int n = g->audio_count < cap ? g->audio_count : cap;
    memcpy(events, g->audio, (size_t)n * sizeof(*events));
    if (n < g->audio_count) {
        memmove(g->audio, g->audio + n,
                (size_t)(g->audio_count - n) * sizeof(*g->audio));
    }
    g->audio_count -= n;
    return n;
}

float zone_game_player_x(const ZoneGame *g) { return g ? g->player_x : 0; }
float zone_game_player_y(const ZoneGame *g) { return g ? g->player_y : 0; }
float zone_game_player_heading(const ZoneGame *g) { return g ? g->heading : 0; }

int32_t zone_game_world_object_count(const ZoneGame *g) {
    if (!g) return 0;
    int n = 0;
    for (int i = 0; i < ZONE_WORLD_CAP; ++i) n += !!g->world[i].active;
    return n;
}

int32_t zone_game_count_type(const ZoneGame *g, uint32_t fourcc) {
    if (!g) return 0;
    int n = 0;
    for (int i = 0; i < ZONE_WORLD_CAP; ++i) {
        if (g->world[i].active && g->world[i].type == fourcc) ++n;
    }
    return n;
}

void zone_game_debug_set_heading(ZoneGame *g, float heading_degrees) {
    if (g) g->heading = tz_wrap_heading(heading_degrees);
}
