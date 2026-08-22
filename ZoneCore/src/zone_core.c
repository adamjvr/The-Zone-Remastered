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
#define ZONE_MOTION_X_SCALE 0.325f
#define ZONE_MOTION_Y_SCALE 0.25f
#define ZONE_PROJECTILE_SPEED 15.0f
#define ZONE_FIRE_COOLDOWN_TICKS 8
#define ZONE_RESPAWN_TICKS 120

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
    uint8_t player_contact;
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
    uint64_t world_contact_bits[ZONE_WORLD_CAP];
    struct Projectile projectiles[ZONE_PROJECTILE_CAP];
    struct Explosion explosions[ZONE_EXPLOSION_CAP];

    int score, shields, wave, ammo;
    int bases_remaining, enemies_remaining;
    float shield_strength;
    float player_max_speed;
    int equipment_upgrade_a;
    int equipment_upgrade_b;
    int respawn_ticks;
    uint8_t professional;
    uint8_t player_alive;
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

static uint16_t rng_0_100(ZoneGame *g) {
    return (uint16_t)(rng_next(g) % 101u);
}

static int active_projectile_count(const ZoneGame *g) {
    int n = 0;
    for (int i = 0; i < ZONE_PROJECTILE_CAP; ++i) n += !!g->projectiles[i].active;
    return n;
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

static float speed2d(float vx, float vy) {
    return sqrtf(vx * vx + vy * vy);
}

static int is_physical_world_type(uint32_t type) {
    switch (type) {
        case TZ_TYPE_MOTH:
        case TZ_TYPE_BASE:
        case TZ_TYPE_ASTE:
        case TZ_TYPE_ROCK:
        case TZ_TYPE_STON:
        case TZ_TYPE_SWAR:
        case TZ_TYPE_MOTO:
        case TZ_TYPE_BLOO:
        case TZ_TYPE_BEE:
        case TZ_TYPE_RAID:
        case TZ_TYPE_SEEK:
        case TZ_TYPE_ROTO:
            return 1;
        default:
            return 0;
    }
}

static int is_pickup_type(uint32_t type) {
    return type == TZ_TYPE_OSCI || type == TZ_TYPE_VELO || type == TZ_TYPE_AMMO ||
           type == TZ_TYPE_BONU || type == TZ_TYPE_EQUI || type == TZ_TYPE_GADG;
}

static int is_enemy_type(uint32_t type) {
    return type == TZ_TYPE_RAID || type == TZ_TYPE_SEEK || type == TZ_TYPE_BEE ||
           type == TZ_TYPE_ROTO || type == TZ_TYPE_SWAR || type == TZ_TYPE_MOTO ||
           type == TZ_TYPE_BLOO;
}

static int is_wave1_world_exchange_type(uint32_t type) {
    /* Keep world/world promotion deliberately narrow. These are the body
       families whose Wave-1 exchange paths have been traced through 0x181A4.
       Later enemy pair special cases are promoted only as they are lifted. */
    return type == TZ_TYPE_MOTH || type == TZ_TYPE_BASE || type == TZ_TYPE_ASTE;
}

static int world_pair_contact(const ZoneGame *g, int a, int b) {
    return (g->world_contact_bits[a] & (UINT64_C(1) << b)) != 0;
}

static void set_world_pair_contact(ZoneGame *g, int a, int b, int touching) {
    const uint64_t abit = UINT64_C(1) << b;
    const uint64_t bbit = UINT64_C(1) << a;
    if (touching) {
        g->world_contact_bits[a] |= abit;
        g->world_contact_bits[b] |= bbit;
    } else {
        g->world_contact_bits[a] &= ~abit;
        g->world_contact_bits[b] &= ~bbit;
    }
}

static void clear_world_contacts_for_slot(ZoneGame *g, int slot) {
    if (slot < 0 || slot >= ZONE_WORLD_CAP) return;
    g->world_contact_bits[slot] = 0;
    const uint64_t bit = ~(UINT64_C(1) << slot);
    for (int i = 0; i < ZONE_WORLD_CAP; ++i) g->world_contact_bits[i] &= bit;
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
        case TZ_TYPE_OSCI: *base = 800;    *frames = 30; *side = 24; return 1;
        case TZ_TYPE_VELO: *base = 2100;   *frames = 24; *side = 24; return 1;
        case TZ_TYPE_AMMO: *base = 2000;   *frames = 32; *side = 24; return 1;
        case TZ_TYPE_BONU: *base = 1300;   *frames = 30; *side = 16; return 1;
        case TZ_TYPE_EQUI: *base = 1400;   *frames = 30; *side = 16; return 1;
        case TZ_TYPE_GADG: *base = 18000;  *frames = 30; *side = 16; return 1;
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

    clear_world_contacts_for_slot(g, slot);
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

static struct WorldObject *spawn_world_object_at(ZoneGame *g, uint32_t type,
                                                  float x, float y,
                                                  float vx, float vy) {
    struct WorldObject *o = spawn_world_object(g, type);
    if (!o) return NULL;
    o->x = wrapf(x, ZONE_LOGICAL_WIDTH);
    o->y = wrapf(y, ZONE_LOGICAL_HEIGHT);
    o->vx = vx;
    o->vy = vy;
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

static void spawn_explosion_bank(ZoneGame *g, float x, float y,
                                 int base, int frames, int side) {
    for (int i = 0; i < ZONE_EXPLOSION_CAP; ++i) {
        if (!g->explosions[i].active) {
            g->explosions[i] = (struct Explosion){1, x, y, 0, base, frames, side};
            audio_push(g, ZONE_AUDIO_EXPLOSION, x, y);
            return;
        }
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
    spawn_explosion_bank(g, x, y, base, frames, side);
}

static void spawn_ship_explosion(ZoneGame *g, float x, float y) {
    /* The ship/mine special case in 0x107B4 uses the 20-frame 1500 bank,
       not the generic 32-pixel explosion bank. */
    spawn_explosion_bank(g, x, y, 1500, 20, 32);
}

static uint32_t select_asteroid_payload(ZoneGame *g) {
    /* PPC 0x195F4: one payload per destroyed medium asteroid. A low random
       bit chooses whether velocity or ammunition gets first priority. */
    const int prefer_velocity = (rng_next(g) & 1u) == 0u;
    if (prefer_velocity) {
        if (g->player_max_speed < 50.0f) return TZ_TYPE_VELO;
        if (g->ammo < 10) return TZ_TYPE_AMMO;
    } else {
        if (g->ammo < 10) return TZ_TYPE_AMMO;
        if (g->player_max_speed < 50.0f) return TZ_TYPE_VELO;
    }

    return tz_select_barrel_type((unsigned)g->wave,
                                 (int16_t)g->equipment_upgrade_a,
                                 (int16_t)g->equipment_upgrade_b,
                                 rng_0_100(g), false,
                                 (uint16_t)(rng_next(g) & 1u));
}

static void spawn_asteroid_payload(ZoneGame *g, const struct WorldObject *o) {
    const uint32_t type = select_asteroid_payload(g);
    (void)spawn_world_object_at(g, type, o->x + 4.0f, o->y + 4.0f, 0.0f, 0.0f);
}

static void fragment_big_rock(ZoneGame *g, const struct WorldObject *o) {
    /* PPC 0x19718 creates 2..4 children. The object-class consequence is
       recovered; exact per-child velocity/offset cases are still being lifted,
       so the angular spread below is isolated as the remaining approximation. */
    static const float headings[4] = {0.0f, 45.0f, 315.0f, 225.0f};
    const int count = 2 + (int)(rng_next(g) % 3u);
    ensure_trig_tables();

    for (int i = 0; i < count; ++i) {
        float dx = 0.0f, dy = 0.0f;
        tz_screen_direction_from_heading(headings[i], g_neg_sin_360, g_cos_360, &dx, &dy);
        const float speed = 4.0f + (float)(rng_next(g) % 9u); /* recovered 4..12 range */
        (void)spawn_world_object_at(g, TZ_TYPE_STON,
                                    o->x + dx * 24.0f, o->y + dy * 24.0f,
                                    dx * speed, dy * speed);
    }

    /* Hidden enemy path in 0x19718: signed raw Random >=22000, wave >2.
       At wave >=15, a second 0..100 draw <=40 selects Raider; otherwise Seeker. */
    const int16_t raw = (int16_t)(rng_next(g) & 0xFFFFu);
    if (g->wave > 2 && raw >= 22000) {
        uint32_t enemy = TZ_TYPE_SEEK;
        if (g->wave >= 15 && rng_0_100(g) <= 40) enemy = TZ_TYPE_RAID;
        struct WorldObject *child = spawn_world_object_at(g, enemy, o->x, o->y, 0.0f, 0.0f);
        if (child) ++g->enemies_remaining;
    }
}

static void destroy_world_object(ZoneGame *g, struct WorldObject *o) {
    if (!o || !o->active) return;
    const int slot = (int)(o - g->world);
    const uint32_t destroyed_type = o->type;
    const float x = o->x;
    const float y = o->y;
    const int side = o->side;

    /* Destruction consequences are generated before the source slot is freed,
       matching the original transform/spawn ordering closely enough that
       object-capacity behavior remains deterministic. */
    if (destroyed_type == TZ_TYPE_ASTE) {
        spawn_asteroid_payload(g, o);
    } else if (destroyed_type == TZ_TYPE_ROCK) {
        fragment_big_rock(g, o);
    }

    const TzKillAward *award = tz_kill_award_for_type(destroyed_type);
    if (award) g->score += award->score;
    if (destroyed_type == TZ_TYPE_MOTH || destroyed_type == TZ_TYPE_BASE) {
        if (g->bases_remaining > 0) --g->bases_remaining;
    } else if (is_enemy_type(destroyed_type)) {
        if (g->enemies_remaining > 0) --g->enemies_remaining;
    }

    spawn_explosion(g, x, y, side);
    o->active = 0;
    clear_world_contacts_for_slot(g, slot);
}

static void begin_player_death(ZoneGame *g) {
    if (!g->player_alive) return;
    g->player_alive = 0;
    g->shields = 0;
    g->respawn_ticks = ZONE_RESPAWN_TICKS;
    g->player_vx = 0.0f;
    g->player_vy = 0.0f;
    spawn_ship_explosion(g, g->player_x, g->player_y);
}

static void respawn_player(ZoneGame *g) {
    /* 0x1663C is only partially lifted. The reset semantics (ship object is
       reconfigured and shields restored) are known; exact historical spawn
       placement/timing remains a compatibility item. Keep those two values
       centralized here until the final lift replaces them. */
    g->player_x = ZONE_LOGICAL_WIDTH * 0.33f;
    g->player_y = ZONE_LOGICAL_HEIGHT * 0.5f;
    g->player_vx = 0.0f;
    g->player_vy = 0.0f;
    g->heading = 0.0f;
    g->shields = 100;
    g->player_alive = 1;
    g->respawn_ticks = 0;
    for (int i = 0; i < ZONE_WORLD_CAP; ++i) g->world[i].player_contact = 0;
}

static void collect_pickup(ZoneGame *g, struct WorldObject *o) {
    if (!o || !o->active || !is_pickup_type(o->type)) return;
    const int slot = (int)(o - g->world);
    switch (o->type) {
        case TZ_TYPE_OSCI:
            g->shields = tz_oscilloscope_apply((int16_t)g->shields);
            break;
        case TZ_TYPE_VELO:
            g->player_max_speed = tz_velocity_module_apply(g->player_max_speed);
            break;
        case TZ_TYPE_AMMO:
            g->ammo = tz_ammo_loader_apply((int16_t)g->ammo);
            break;
        case TZ_TYPE_BONU:
        case TZ_TYPE_EQUI:
        case TZ_TYPE_GADG:
            /* Collection/removal is exact. Their individual upgrade effects
               remain outside 0.5 until the corresponding 0x17xxx branches are
               fully lifted; no invented effect is applied here. */
            break;
        default:
            return;
    }
    o->active = 0;
    clear_world_contacts_for_slot(g, slot);
}

static int spawn_projectile(ZoneGame *g) {
    ensure_trig_tables();
    if (!g->player_alive || active_projectile_count(g) >= g->ammo) return 0;
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
            return 1;
        }
    }
    return 0;
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
    g->shield_strength = 1.0f;
    g->player_max_speed = tz_initial_player_max_speed();
    g->professional = 1;
    g->player_alive = 1;
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

    if (g->player_alive) {
        const float turn = in.turn < -0.25f ? -1.0f : (in.turn > 0.25f ? 1.0f : 0.0f);
        g->heading = tz_wrap_heading(g->heading + turn * ZONE_CLASSIC_TURN_DEG);

        if (in.thrust > 0.5f) {
            /* Recovered PPC uses classic Mac vertical/horizontal component order.
               ZoneCore exposes modern screen X/Y, so swap at the boundary. */
            float vertical = g->player_vy;
            float horizontal = g->player_vx;
            if (tz_apply_player_thrust(&vertical, &horizontal,
                                       g->heading, g->player_max_speed,
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
        if (in.fire && g->fire_cooldown == 0 && spawn_projectile(g)) {
            g->fire_cooldown = ZONE_FIRE_COOLDOWN_TICKS;
        }
        g->fire_latch = in.fire;
    } else {
        if (g->respawn_ticks > 0) --g->respawn_ticks;
        if (g->respawn_ticks == 0) respawn_player(g);
    }

    for (int i = 0; i < ZONE_WORLD_CAP; ++i) {
        struct WorldObject *o = &g->world[i];
        if (!o->active) continue;
        ++o->tick;

        /* 0.4 promotes collision-transferred motion into the live simulation.
           In particular, PPC 0x174E8 swaps the ship/base continuous vectors,
           so a stationary Mother Base can acquire the ship's incoming motion. */
        if (o->type == TZ_TYPE_ASTE || o->type == TZ_TYPE_ROCK ||
            o->type == TZ_TYPE_STON || o->type == TZ_TYPE_MOTH ||
            o->type == TZ_TYPE_BASE) {
            o->x = wrapf(o->x + o->vx * ZONE_MOTION_X_SCALE, ZONE_LOGICAL_WIDTH);
            o->y = wrapf(o->y + o->vy * ZONE_MOTION_Y_SCALE, ZONE_LOGICAL_HEIGHT);
        }
        if ((o->tick & 7) == 0 && o->frame_count > 0) {
            o->frame = (o->frame + 1) % o->frame_count;
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
            const int threshold = destruction_threshold(g, o->type);
            if (threshold <= 0) continue; /* collectible/non-combat object */
            if (!exact_overlap_ids(p->sprite, p->x, p->y,
                                   o->sprite_base + o->frame, o->x, o->y)) continue;

            p->active = 0;
            o->damage += tz_shot_damage_from_upgrade(0);
            if (o->damage >= threshold) destroy_world_object(g, o);
        }
    }

    /* Collectible collision branch (PPC 0x177A8). These objects do not
       participate in the physical momentum-exchange matrix. */
    if (g->player_alive) {
        for (int i = 0; i < ZONE_WORLD_CAP; ++i) {
            struct WorldObject *o = &g->world[i];
            if (!o->active || !is_pickup_type(o->type)) continue;
            if (exact_overlap_ids(current_ship_sprite(g), g->player_x, g->player_y,
                                  o->sprite_base + o->frame, o->x, o->y)) {
                collect_pickup(g, o);
            }
        }
    }

    /* Player/world collision response. PPC 0x19DFC handles ordinary bodies;
       PPC 0x174E8 is the dedicated Mother Base/HQ path.  Contact is latched
       until separation so a single physical impact cannot drain shields once
       per rendered frame or swap the same velocities back and forth. */
    for (int i = 0; g->player_alive && i < ZONE_WORLD_CAP; ++i) {
        struct WorldObject *o = &g->world[i];
        if (!o->active || !is_physical_world_type(o->type)) continue;

        const int touching = exact_overlap_ids(current_ship_sprite(g),
                                               g->player_x, g->player_y,
                                               o->sprite_base + o->frame,
                                               o->x, o->y);
        if (!touching) {
            o->player_contact = 0;
            continue;
        }
        if (o->player_contact) continue;
        o->player_contact = 1;

        const float speed_before = speed2d(g->player_vx, g->player_vy);
        int damage = 0;
        if (o->type == TZ_TYPE_MOTH || o->type == TZ_TYPE_BASE) {
            damage = tz_player_base_impact_damage(speed_before, g->shield_strength);
            tz_swap_screen_velocity(&g->player_vx, &g->player_vy, &o->vx, &o->vy);
        } else {
            tz_swap_screen_velocity(&g->player_vx, &g->player_vy, &o->vx, &o->vy);
            const float speed_after = speed2d(g->player_vx, g->player_vy);
            damage = tz_player_impact_damage(o->type, speed_before,
                                             speed_after, g->shield_strength);
        }

        if (damage > 0) {
            g->shields -= damage;
            if (g->shields <= 0) begin_player_death(g);
        }
        audio_push(g, ZONE_AUDIO_COLLISION, g->player_x, g->player_y);
    }

    /* World/world physical response, phase 1.  The recovered 0x181A4 pair
       dispatcher uses the fixed/float exchange helpers for the Wave-1 body
       combinations (asteroid/base/mother).  ZoneCore stores a single portable
       velocity representation, so the corresponding response is a direct
       exchange.  Pair latching prevents overlap ping-pong. */
    for (int i = 0; i < ZONE_WORLD_CAP; ++i) {
        struct WorldObject *a = &g->world[i];
        if (!a->active || !is_wave1_world_exchange_type(a->type)) continue;
        for (int j = i + 1; j < ZONE_WORLD_CAP; ++j) {
            struct WorldObject *b = &g->world[j];
            if (!b->active || !is_wave1_world_exchange_type(b->type)) {
                set_world_pair_contact(g, i, j, 0);
                continue;
            }
            const int touching = exact_overlap_ids(a->sprite_base + a->frame,
                                                   a->x, a->y,
                                                   b->sprite_base + b->frame,
                                                   b->x, b->y);
            if (!touching) {
                set_world_pair_contact(g, i, j, 0);
                continue;
            }
            if (!world_pair_contact(g, i, j)) {
                set_world_pair_contact(g, i, j, 1);
                tz_swap_screen_velocity(&a->vx, &a->vy, &b->vx, &b->vy);
            }
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
    int n = g->player_alive ? 1 : 0;
    for (int i = 0; i < ZONE_WORLD_CAP; ++i) n += !!g->world[i].active;
    for (int i = 0; i < ZONE_PROJECTILE_CAP; ++i) n += !!g->projectiles[i].active;
    for (int i = 0; i < ZONE_EXPLOSION_CAP; ++i) n += !!g->explosions[i].active;
    return n;
}

ZoneRenderItem zone_game_render_item_at(const ZoneGame *g, int32_t index) {
    ZoneRenderItem z = {0, 0, 0, 0, 0};
    if (!g || index < 0) return z;
    int n = 0;

    if (g->player_alive && index == n++) {
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
        g->bases_remaining, g->enemies_remaining,
        speed2d(g->player_vx, g->player_vy), g->player_max_speed,
        g->player_alive, g->paused
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

ZoneDebugBodyState zone_game_debug_player_state(const ZoneGame *g) {
    if (!g) return (ZoneDebugBodyState){0};
    return (ZoneDebugBodyState){g->player_alive, TZ_TYPE_SHIP, g->player_x, g->player_y,
                                g->player_vx, g->player_vy, current_ship_frame(g)};
}

void zone_game_debug_set_player_state(ZoneGame *g, float x, float y, float vx, float vy) {
    if (!g) return;
    g->player_x = wrapf(x, ZONE_LOGICAL_WIDTH);
    g->player_y = wrapf(y, ZONE_LOGICAL_HEIGHT);
    g->player_vx = vx;
    g->player_vy = vy;
}

int32_t zone_game_debug_find_nth_type(const ZoneGame *g, uint32_t fourcc, int32_t nth) {
    if (!g || nth < 0) return -1;
    int32_t seen = 0;
    for (int32_t i = 0; i < ZONE_WORLD_CAP; ++i) {
        if (!g->world[i].active || g->world[i].type != fourcc) continue;
        if (seen++ == nth) return i;
    }
    return -1;
}

ZoneDebugBodyState zone_game_debug_world_state(const ZoneGame *g, int32_t index) {
    if (!g || index < 0 || index >= ZONE_WORLD_CAP) return (ZoneDebugBodyState){0};
    const struct WorldObject *o = &g->world[index];
    return (ZoneDebugBodyState){o->active, o->type, o->x, o->y, o->vx, o->vy, o->frame};
}

void zone_game_debug_set_world_state(ZoneGame *g, int32_t index,
                                     float x, float y, float vx, float vy, int32_t frame) {
    if (!g || index < 0 || index >= ZONE_WORLD_CAP || !g->world[index].active) return;
    struct WorldObject *o = &g->world[index];
    o->x = wrapf(x, ZONE_LOGICAL_WIDTH);
    o->y = wrapf(y, ZONE_LOGICAL_HEIGHT);
    o->vx = vx;
    o->vy = vy;
    if (o->frame_count > 0) {
        frame %= o->frame_count;
        if (frame < 0) frame += o->frame_count;
        o->frame = frame;
    }
    o->player_contact = 0;
    clear_world_contacts_for_slot(g, index);
}


float zone_game_player_max_speed(const ZoneGame *g) {
    return g ? g->player_max_speed : 0.0f;
}

int32_t zone_game_active_projectiles(const ZoneGame *g) {
    return g ? active_projectile_count(g) : 0;
}

uint8_t zone_game_player_alive(const ZoneGame *g) {
    return g ? g->player_alive : 0;
}

void zone_game_debug_set_progression(ZoneGame *g, int32_t shields, int32_t ammo,
                                     float maximum_speed, int32_t wave) {
    if (!g) return;
    g->shields = shields;
    g->ammo = ammo < 0 ? 0 : (ammo > 10 ? 10 : ammo);
    g->player_max_speed = maximum_speed;
    g->wave = wave < 1 ? 1 : wave;
}

int32_t zone_game_debug_spawn_world(ZoneGame *g, uint32_t fourcc,
                                    float x, float y, float vx, float vy) {
    if (!g) return -1;
    struct WorldObject *o = spawn_world_object_at(g, fourcc, x, y, vx, vy);
    if (!o) return -1;
    if (fourcc == TZ_TYPE_MOTH || fourcc == TZ_TYPE_BASE) ++g->bases_remaining;
    else if (is_enemy_type(fourcc)) ++g->enemies_remaining;
    return (int32_t)(o - g->world);
}

void zone_game_debug_destroy_world(ZoneGame *g, int32_t index) {
    if (!g || index < 0 || index >= ZONE_WORLD_CAP || !g->world[index].active) return;
    destroy_world_object(g, &g->world[index]);
}
