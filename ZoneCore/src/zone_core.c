#include "zone_core.h"
#include "zone_sprite_data.h"
#include "thezone_decomp.h"

#include <math.h>
#include <stdlib.h>
#include <string.h>

#define ZONE_PI 3.14159265358979323846f
#define ZONE_SHIP_BASE 1000
#define ZONE_SHOT_BASE 148
#define ZONE_FIRE_SPRITE 152
#define ZONE_PROJECTILE_CAP 48
#define ZONE_EXPLOSION_CAP 12
#define ZONE_WORLD_CAP 64

/* Recovered gameplay constants currently promoted into the playable core. */
#define ZONE_CLASSIC_TURN_DEG 4.5f
#define ZONE_MOTION_X_SCALE 0.325f
#define ZONE_MOTION_Y_SCALE 0.25f
#define ZONE_PROJECTILE_SPEED 15.0f
#define ZONE_FIRE_COOLDOWN_TICKS 8
#define ZONE_RESPAWN_TICKS 120
#define ZONE_WAVE_CLEAR_TICKS 90

struct Projectile {
    uint8_t active;
    uint8_t hostile;
    float x, y, vx, vy;
    int life;
    int sprite;
    int source_slot;
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
    uint8_t hit_flash_ticks;
    uint32_t type;
    uint32_t subtype;
    float x, y, vx, vy;
    int sprite_base;
    int frame_count;
    int frame;
    int side;
    int damage;
    int tick;
    int hit_state;           /* PPC +66 timed enemy hit/stun state */
    uint32_t hit_tick;       /* PPC +92 TickCount timestamp for +66 */
    int state_84;            /* PPC +84: fixed-wave mobile-Mother eligibility flag */
    int mother_motion_state; /* PPC +86: Mother Base movement selector (0,1,2) */
    int rotor_state;         /* PPC +131: Rotor 0 orbit, 1 attack, 2 return */
    int rotor_heading;       /* PPC +54: Rotor orbit/aim heading in degrees */

    /* Portable equivalents of the recovered object-link/counter state.
       The shipping PPC object stores object links as pointers; ZoneCore uses
       stable world-slot indices so save/host pointer width never leaks in. */
    int parent_slot;
    int requester_slot;
    int rotor_slot;          /* PPC parent +146 / Rotor child link2 */
    int defender_count;
    int bee_out_count;
    int bee_request_count;
    int hostile_shots;
};

struct ZoneGame {
    uint32_t rng;
    uint32_t behavior_tick; /* deterministic equivalent of the shared PPC behavior cadence */
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
    int bee_limit;
    float shield_strength;
    float player_max_speed;
    int equipment_upgrade_a;
    int equipment_upgrade_b;
    int respawn_ticks;
    int wave_clear_ticks;
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
    for (int i = 0; i < ZONE_PROJECTILE_CAP; ++i) {
        n += g->projectiles[i].active && !g->projectiles[i].hostile;
    }
    return n;
}

static int active_hostile_projectile_count(const ZoneGame *g) {
    int n = 0;
    for (int i = 0; i < ZONE_PROJECTILE_CAP; ++i) {
        n += g->projectiles[i].active && g->projectiles[i].hostile;
    }
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
    o->parent_slot = -1;
    o->requester_slot = -1;
    o->rotor_slot = -1;
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

static void populate_fixed_wave(ZoneGame *g, unsigned wave) {
    memset(g->world, 0, sizeof(g->world));
    memset(g->world_contact_bits, 0, sizeof(g->world_contact_bits));
    memset(g->projectiles, 0, sizeof(g->projectiles));
    g->bases_remaining = 0;
    g->enemies_remaining = 0;
    g->bee_limit = 0;
    g->wave_clear_ticks = 0;

    const TzWavePreset *preset = tz_wave_preset(g->professional != 0, wave);
    if (!preset) return;

    const unsigned asteroids = tz_initial_asteroid_count(wave);
    for (unsigned i = 0; i < asteroids; ++i) {
        (void)spawn_world_object(g, TZ_TYPE_ASTE);
    }

    int bloo_left = preset->bloo_subtype_quota;
    int mobile_mothers_left = preset->mobile_moth_quota;
    int mother_slots[18];
    int mother_count = 0;

    for (int i = 0; i < preset->moth_count; ++i) {
        struct WorldObject *m = spawn_world_object(g, TZ_TYPE_MOTH);
        if (!m) continue;
        if (mother_count < (int)(sizeof(mother_slots) / sizeof(mother_slots[0]))) {
            mother_slots[mother_count++] = (int)(m - g->world);
        }

        /* PPC 0x13328 assigns the base's defender class while the wave is
           constructed.  The first quota entries become Bloody defenders;
           remaining Mother Bases use Empire Fighters. */
        if (bloo_left > 0) {
            m->subtype = TZ_TYPE_BLOO;
            --bloo_left;
        } else {
            m->subtype = TZ_TYPE_SWAR;
        }

        /* PPC 0x13B94..0x13BB0 marks the first mobile_moth_quota Mothers
           with state +84 = 1. This is an eligibility flag; motion remains
           dormant until the destruction path writes selector +86. */
        if (mobile_mothers_left > 0) {
            m->state_84 = 1;
            --mobile_mothers_left;
        }
        ++g->bases_remaining;
    }

    for (int i = 0; i < preset->base_count; ++i) {
        struct WorldObject *b = spawn_world_object(g, TZ_TYPE_BASE);
        if (!b) continue;
        if (bloo_left > 0) {
            b->subtype = TZ_TYPE_BLOO;
            --bloo_left;
        } else {
            b->subtype = TZ_TYPE_MOTO;
        }
        ++g->bases_remaining;
    }

    for (int i = 0; i < preset->raid_count; ++i) {
        if (spawn_world_object(g, TZ_TYPE_RAID)) ++g->enemies_remaining;
    }
    for (int i = 0; i < preset->seek_count; ++i) {
        if (spawn_world_object(g, TZ_TYPE_SEEK)) ++g->enemies_remaining;
    }

    /* PPC 0x13A58..0x13B5C creates the first N linked Rotors and stores both
       directions of the relationship: Rotor +142 -> Mother, Mother +146 -> Rotor.
       Rotor state +131 starts at zero (orbit). */
    const int rotor_count =
        preset->rotor_link_count < mother_count ? preset->rotor_link_count : mother_count;
    for (int i = 0; i < rotor_count; ++i) {
        const int parent_slot = mother_slots[i];
        struct WorldObject *parent = &g->world[parent_slot];
        struct WorldObject *rotor = spawn_world_object_at(
            g, TZ_TYPE_ROTO, parent->x + 40.0f, parent->y, 0.0f, 0.0f);
        if (rotor) {
            const int rotor_slot = (int)(rotor - g->world);
            rotor->parent_slot = parent_slot;
            rotor->rotor_state = 0;
            rotor->rotor_heading = 0;
            rotor->frame = 6; /* (0 + 90) / 15 at PPC 0x15DA8..0x15DCC */
            parent->rotor_slot = rotor_slot;
            ++g->enemies_remaining;
        }
    }

    g->bee_limit = preset->bee_limit;
}



static float shortest_wrapped_delta(float from, float to, float extent) {
    float d = to - from;
    if (d > extent * 0.5f) d -= extent;
    if (d < -extent * 0.5f) d += extent;
    return d;
}

static int frame24_toward(float from_x, float from_y, float to_x, float to_y) {
    const float dx = shortest_wrapped_delta(from_x, to_x, ZONE_LOGICAL_WIDTH);
    const float dy = shortest_wrapped_delta(from_y, to_y, ZONE_LOGICAL_HEIGHT);
    float degrees = atan2f(-dy, dx) * 180.0f / ZONE_PI;
    if (degrees < 0.0f) degrees += 360.0f;
    int frame = (int)(degrees / 15.0f);
    if (frame < 0) frame = 0;
    if (frame > 23) frame = 23;
    return frame;
}

static int spawn_linked_defender_at_offset(ZoneGame *g, int parent_slot,
                                           uint32_t type, float dx, float dy) {
    if (parent_slot < 0 || parent_slot >= ZONE_WORLD_CAP) return -1;
    struct WorldObject *parent = &g->world[parent_slot];
    if (!parent->active) return -1;

    struct WorldObject *child = spawn_world_object_at(
        g, type, parent->x + dx, parent->y + dy, 0.0f, 0.0f);
    if (!child) return -1;
    child->parent_slot = parent_slot;
    ++parent->defender_count;
    ++g->enemies_remaining;
    return (int)(child - g->world);
}

static int spawn_mother_defender(ZoneGame *g, int parent_slot,
                                 uint32_t type, int ordinal) {
    /* PPC 0x161D0 passes one of five top-left placements around the 48x48
       Mother Base: (0,0),(32,0),(0,32),(32,32),(16,16). Defenders are 16x16,
       so in ZoneCore's center-coordinate representation those become +/-16
       corners plus the center. */
    static const float offsets[5][2] = {
        {-16.0f, -16.0f}, {16.0f, -16.0f},
        {-16.0f,  16.0f}, {16.0f,  16.0f},
        {  0.0f,   0.0f},
    };
    const int oi = ordinal % 5;
    return spawn_linked_defender_at_offset(
        g, parent_slot, type, offsets[oi][0], offsets[oi][1]);
}

static int launch_mother_defenders_with_words(ZoneGame *g, int parent_slot,
                                               int16_t gate_word,
                                               uint16_t batch_word) {
    if (parent_slot < 0 || parent_slot >= ZONE_WORLD_CAP) return 0;
    struct WorldObject *parent = &g->world[parent_slot];
    if (!parent->active || parent->type != TZ_TYPE_MOTH) return 0;
    if (!tz_mother_should_launch_defenders(gate_word)) return 0;

    const int cap = tz_mother_defender_active_cap(g->professional != 0);
    if (parent->defender_count >= cap) return 0;

    const int requested = tz_mother_defender_batch_count(g->professional != 0, batch_word);
    const uint32_t defender_type = parent->subtype ? parent->subtype : TZ_TYPE_SWAR;
    int spawned = 0;
    for (int i = 0; i < requested && parent->defender_count < cap; ++i) {
        if (spawn_mother_defender(g, parent_slot, defender_type,
                                  parent->defender_count) < 0) break;
        ++spawned;
    }
    return spawned;
}

static int launch_mother_defenders(ZoneGame *g, int parent_slot) {
    const int16_t gate = (int16_t)(rng_next(g) & 0xFFFFu);
    const uint16_t batch = (uint16_t)(rng_next(g) & 0xFFFFu);
    return launch_mother_defenders_with_words(g, parent_slot, gate, batch);
}

static int launch_hq_defenders(ZoneGame *g, int parent_slot) {
    if (parent_slot < 0 || parent_slot >= ZONE_WORLD_CAP) return 0;
    struct WorldObject *parent = &g->world[parent_slot];
    if (!parent->active || parent->type != TZ_TYPE_BASE) return 0;

    /* PPC 0x16390 has no Random gate. It tries the four HQ corner launch
       positions and stops at the mode-specific active defender cap. */
    static const float offsets[4][2] = {
        {-16.0f, -16.0f}, {16.0f, -16.0f},
        {-16.0f,  16.0f}, {16.0f,  16.0f},
    };
    const int cap = tz_hq_defender_active_cap(g->professional != 0);
    const uint32_t defender_type = parent->subtype ? parent->subtype : TZ_TYPE_MOTO;
    int spawned = 0;
    for (int i = 0; i < 4 && parent->defender_count < cap; ++i) {
        const int oi = parent->defender_count % 4;
        if (spawn_linked_defender_at_offset(
                g, parent_slot, defender_type, offsets[oi][0], offsets[oi][1]) < 0) {
            break;
        }
        ++spawned;
    }
    return spawned;
}

static int request_bee(ZoneGame *g, int requester_slot) {
    if (requester_slot < 0 || requester_slot >= ZONE_WORLD_CAP) return -1;
    struct WorldObject *requester = &g->world[requester_slot];
    if (!requester->active ||
        (requester->type != TZ_TYPE_MOTH && requester->type != TZ_TYPE_BASE)) return -1;
    if (g->bee_limit <= 0 || requester->bee_request_count >= g->bee_limit) return -1;

    /* PPC 0x16504 explicitly searches for ANOTHER Mother Base/HQ and excludes
       the requester. That donor must not already have a Bee outstanding. */
    for (int donor_slot = 0; donor_slot < ZONE_WORLD_CAP; ++donor_slot) {
        if (donor_slot == requester_slot) continue;
        struct WorldObject *donor = &g->world[donor_slot];
        if (!donor->active) continue;
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

static void world_object_survived_player_shot(ZoneGame *g, int slot) {
    if (slot < 0 || slot >= ZONE_WORLD_CAP) return;
    struct WorldObject *o = &g->world[slot];
    if (!o->active) return;

    if (o->type == TZ_TYPE_MOTH) {
        /* Native consequence path after a nonlethal Mother Base hit:
           0x161D0 launch linked defenders, then 0x16504 request a Bee. */
        (void)launch_mother_defenders(g, slot);
        (void)request_bee(g, slot);

        /* PPC 0x19CB8..0x19CE8 wakes the linked Rotor after a valid
           nonlethal Mother hit by writing Rotor byte +131 = 1. */
        if (o->rotor_slot >= 0 && o->rotor_slot < ZONE_WORLD_CAP) {
            struct WorldObject *rotor = &g->world[o->rotor_slot];
            if (rotor->active && rotor->type == TZ_TYPE_ROTO &&
                rotor->parent_slot == slot && rotor->rotor_state != 1) {
                rotor->rotor_state = 1;
            }
        }
    } else if (o->type == TZ_TYPE_BASE) {
        /* Headquarters uses its separate non-random defender reaction
           routine at PPC 0x16390. */
        (void)launch_hq_defenders(g, slot);
    }
}

static void update_simple_enemy_ai(ZoneGame *g, struct WorldObject *o) {
    if (!g->player_alive || !o || !o->active) return;
    const int interval = tz_enemy_chase_interval(o->type);
    const int cap = tz_enemy_axis_cap(o->type);
    if (interval <= 0 || cap <= 0 || (o->tick % interval) != 0) return;

    const float dx = shortest_wrapped_delta(o->x, g->player_x, ZONE_LOGICAL_WIDTH);
    const float dy = shortest_wrapped_delta(o->y, g->player_y, ZONE_LOGICAL_HEIGHT);
    const int16_t px = (int16_t)lrintf(o->x);
    const int16_t py = (int16_t)lrintf(o->y);
    const int16_t tx = (int16_t)lrintf(o->x + dx);
    const int16_t ty = (int16_t)lrintf(o->y + dy);
    o->vx = (float)tz_chase_axis_step(px, tx, (int16_t)lrintf(o->vx), (int16_t)cap);
    o->vy = (float)tz_chase_axis_step(py, ty, (int16_t)lrintf(o->vy), (int16_t)cap);
    if (o->frame_count == 24) o->frame = frame24_toward(o->x, o->y,
                                                        g->player_x, g->player_y);
}


static void update_accelerative_chase_velocity(ZoneGame *g, struct WorldObject *o) {
    const float dx = shortest_wrapped_delta(o->x, g->player_x, ZONE_LOGICAL_WIDTH);
    const float dy = shortest_wrapped_delta(o->y, g->player_y, ZONE_LOGICAL_HEIGHT);
    const float mag = sqrtf(dx * dx + dy * dy);
    if (mag <= 0.0001f) return;

    const float ux = dx / mag;
    const float uy = dy / mag;
    const float old_speed = speed2d(o->vx, o->vy);
    const float candidate_vx = o->vx + ux;
    const float candidate_vy = o->vy + uy;
    const float candidate_speed = speed2d(candidate_vx, candidate_vy);
    if (candidate_speed <= g->player_max_speed || candidate_speed < old_speed) {
        o->vx = candidate_vx;
        o->vy = candidate_vy;
    } else {
        o->vx = ux * g->player_max_speed;
        o->vy = uy * g->player_max_speed;
    }
}

static int enemy_hit_state_active(ZoneGame *g, struct WorldObject *o) {
    if (!g || !o || o->hit_state != 1) return 0;
    const int duration = tz_enemy_hit_state_duration(o->type);
    if (duration <= 0) {
        o->hit_state = 0;
        return 0;
    }
    const uint32_t elapsed = g->behavior_tick - o->hit_tick;
    if (elapsed < (uint32_t)duration) return 1;
    o->hit_state = 0;
    return 0;
}

static void set_enemy_hit_state(ZoneGame *g, struct WorldObject *o,
                                int state, uint32_t elapsed_ticks) {
    if (!g || !o) return;
    o->hit_state = state;
    o->hit_tick = g->behavior_tick - elapsed_ticks;
}

static void update_bee_ai(ZoneGame *g, struct WorldObject *o) {
    if (!g->player_alive || !o || !o->active || o->type != TZ_TYPE_BEE) return;

    /* PPC 0x154A8: while +66 == 1 and less than 60 TickCount units have
       elapsed, Bee skips steering/facing/fire and only keeps its existing
       continuous motion. ZoneCore already integrates the retained velocity
       after this handler, so returning here reproduces the visible coast. */
    if (enemy_hit_state_active(g, o)) return;

    update_accelerative_chase_velocity(g, o);
    o->frame = frame24_toward(o->x, o->y, g->player_x, g->player_y);
}

static void update_mother_ai(ZoneGame *g, struct WorldObject *o) {
    if (!g->player_alive || !o || !o->active || o->type != TZ_TYPE_MOTH) return;

    /* PPC 0x14C70 dispatches on object +86.
       0: preserve existing motion
       1: accelerative chase, accepting over-cap changes only when slowing
       2: direct chase, max speed within radius 200 and cruise speed outside.
       The original routes nonzero states through 0xE6F4; ZoneCore keeps the
       continuous-vector abstraction already used by Bee/Seeker and applies
       recovered X/Y scale at integration. */
    if (o->mother_motion_state == 1) {
        update_accelerative_chase_velocity(g, o);
    } else if (o->mother_motion_state == 2) {
        const float dx = shortest_wrapped_delta(o->x, g->player_x, ZONE_LOGICAL_WIDTH);
        const float dy = shortest_wrapped_delta(o->y, g->player_y, ZONE_LOGICAL_HEIGHT);
        const float dist_sq = dx * dx + dy * dy;
        const float mag = sqrtf(dist_sq);
        if (mag <= 0.0001f) return;
        const float speed = tz_mother_direct_speed(dist_sq, g->player_max_speed);
        o->vx = (dx / mag) * speed;
        o->vy = (dy / mag) * speed;
    }
}

static void update_seeker_ai(ZoneGame *g, struct WorldObject *o) {
    if (!g->player_alive || !o || !o->active || o->type != TZ_TYPE_SEEK) return;

    /* PPC 0x15944: +66 == 1 blocks the Seeker handler until 60 TickCount
       units have elapsed from +92. Existing velocity remains authoritative
       during the gate, so the body coasts but does not retarget or refire. */
    if (enemy_hit_state_active(g, o)) return;

    const float dx = shortest_wrapped_delta(o->x, g->player_x, ZONE_LOGICAL_WIDTH);
    const float dy = shortest_wrapped_delta(o->y, g->player_y, ZONE_LOGICAL_HEIGHT);
    const float dist_sq = dx * dx + dy * dy;
    const float mag = sqrtf(dist_sq);
    if (mag <= 0.0001f) return;

    /* Recovered seek handler 0x15944 switches at radius 200. Fresh-game
       cruise speed is 10; inside the radius it uses the runtime maximum. */
    const float speed = tz_seeker_direct_speed(dist_sq, g->player_max_speed, 10.0f);
    o->vx = (dx / mag) * speed;
    o->vy = (dy / mag) * speed;
    o->frame = frame24_toward(o->x, o->y, g->player_x, g->player_y);
}

static void update_rotor_ai(ZoneGame *g, struct WorldObject *o) {
    if (!g->player_alive || !o || !o->active || o->type != TZ_TYPE_ROTO) return;

    struct WorldObject *parent = NULL;
    if (o->parent_slot >= 0 && o->parent_slot < ZONE_WORLD_CAP) {
        struct WorldObject *candidate = &g->world[o->parent_slot];
        if (candidate->active &&
            (candidate->type == TZ_TYPE_MOTH || candidate->type == TZ_TYPE_BASE)) {
            parent = candidate;
        }
    }

    /* PPC 0x15BC8 verifies link1 every update. If the parent is gone or no
       longer a Mother/HQ, execution falls into the Seeker-style direct chase
       path with the recovered 200-unit speed switch. */
    if (!parent) {
        const float dx = shortest_wrapped_delta(o->x, g->player_x, ZONE_LOGICAL_WIDTH);
        const float dy = shortest_wrapped_delta(o->y, g->player_y, ZONE_LOGICAL_HEIGHT);
        const float dist_sq = dx * dx + dy * dy;
        const float mag = sqrtf(dist_sq);
        if (mag > 0.0001f) {
            const float speed = tz_seeker_direct_speed(dist_sq, g->player_max_speed, 10.0f);
            o->vx = (dx / mag) * speed;
            o->vy = (dy / mag) * speed;
            o->rotor_heading = (frame24_toward(o->x, o->y, g->player_x, g->player_y) * 15) % 360;
            o->frame = o->rotor_heading / 15;
        }
        return;
    }

    const float player_dx = shortest_wrapped_delta(o->x, g->player_x, ZONE_LOGICAL_WIDTH);
    const float player_dy = shortest_wrapped_delta(o->y, g->player_y, ZONE_LOGICAL_HEIGHT);
    const float player_dist_sq = player_dx * player_dx + player_dy * player_dy;

    /* State 0 immediately wakes into state 1 when the player enters the
       recovered 100-unit radius, then runs the attack state in the same tick. */
    if (o->rotor_state == 0 && player_dist_sq <= tz_rotor_attack_radius_squared()) {
        o->rotor_state = 1;
    }

    if (o->rotor_state == 0) {
        ensure_trig_tables();
        o->rotor_heading = (o->rotor_heading + tz_rotor_orbit_heading_step()) % 360;
        const int tangent = (o->rotor_heading + 90) % 360;
        o->frame = tangent / 15;

        const float radius = tz_rotor_orbit_radius();
        const int a = o->rotor_heading;
        const float desired_x = wrapf(parent->x + radius * g_cos_360[a], ZONE_LOGICAL_WIDTH);
        const float desired_y = wrapf(parent->y + radius * g_neg_sin_360[a], ZONE_LOGICAL_HEIGHT);
        const float dx = shortest_wrapped_delta(o->x, desired_x, ZONE_LOGICAL_WIDTH);
        const float dy = shortest_wrapped_delta(o->y, desired_y, ZONE_LOGICAL_HEIGHT);

        /* Unlike the vector-speed states, PPC state 0 writes the full orbit
           correction directly to +40/+42 before common integration. Compensate
           for ZoneCore's screen-motion scale so the visible displacement is the
           recovered correction rather than a second scaling of it. */
        o->vx = dx / ZONE_MOTION_X_SCALE;
        o->vy = dy / ZONE_MOTION_Y_SCALE;
        return;
    }

    const float parent_dx = shortest_wrapped_delta(o->x, parent->x, ZONE_LOGICAL_WIDTH);
    const float parent_dy = shortest_wrapped_delta(o->y, parent->y, ZONE_LOGICAL_HEIGHT);
    const float parent_dist_sq = parent_dx * parent_dx + parent_dy * parent_dy;

    if (o->rotor_state == 1) {
        const float leash = tz_rotor_leash_radius((float)ZONE_LOGICAL_WIDTH);
        if (parent_dist_sq >= leash * leash) {
            o->rotor_state = 2;
            return; /* PPC changes state and reaches the common tail this tick. */
        }
        const float mag = sqrtf(player_dist_sq);
        if (mag > 0.0001f) {
            const float speed = tz_rotor_attack_speed();
            o->vx = (player_dx / mag) * speed;
            o->vy = (player_dy / mag) * speed;
            o->frame = frame24_toward(o->x, o->y, g->player_x, g->player_y);
            o->rotor_heading = o->frame * 15;
        }
        return;
    }

    if (o->rotor_state == 2) {
        const float radius = tz_rotor_orbit_radius();
        if (parent_dist_sq <= radius * radius) {
            o->rotor_state = 0;
            return;
        }
        const float mag = sqrtf(parent_dist_sq);
        if (mag > 0.0001f) {
            const float speed = tz_rotor_return_speed();
            o->vx = (parent_dx / mag) * speed;
            o->vy = (parent_dy / mag) * speed;
            o->frame = frame24_toward(o->x, o->y, parent->x, parent->y);
            o->rotor_heading = o->frame * 15;
        }
    }
}

static void update_complex_enemy_ai(ZoneGame *g, struct WorldObject *o) {
    if (!o || !o->active) return;
    if (o->type == TZ_TYPE_BEE) update_bee_ai(g, o);
    else if (o->type == TZ_TYPE_SEEK) update_seeker_ai(g, o);
    else if (o->type == TZ_TYPE_ROTO) update_rotor_ai(g, o);
    else if (o->type == TZ_TYPE_MOTH) update_mother_ai(g, o);
}

static void release_projectile_source(ZoneGame *g, struct Projectile *p) {
    if (!p || !p->hostile || p->source_slot < 0 || p->source_slot >= ZONE_WORLD_CAP) return;
    struct WorldObject *source = &g->world[p->source_slot];
    if (source->active && source->hostile_shots > 0) --source->hostile_shots;
    p->source_slot = -1;
}

static void deactivate_projectile(ZoneGame *g, struct Projectile *p) {
    if (!p || !p->active) return;
    release_projectile_source(g, p);
    p->active = 0;
}

static int spawn_hostile_projectile_with_cap(ZoneGame *g, int source_slot, int source_cap) {
    if (!g->player_alive || source_slot < 0 || source_slot >= ZONE_WORLD_CAP) return 0;
    struct WorldObject *source = &g->world[source_slot];
    if (!source->active) return 0;
    if (source_cap > 0 && source->hostile_shots >= source_cap) return 0;

    const float dx = shortest_wrapped_delta(source->x, g->player_x, ZONE_LOGICAL_WIDTH);
    const float dy = shortest_wrapped_delta(source->y, g->player_y, ZONE_LOGICAL_HEIGHT);
    const float mag = sqrtf(dx * dx + dy * dy);
    if (mag <= 0.0001f) return 0;

    for (int i = 0; i < ZONE_PROJECTILE_CAP; ++i) {
        struct Projectile *p = &g->projectiles[i];
        if (p->active) continue;
        p->active = 1;
        p->hostile = 1;
        p->source_slot = source_slot;
        p->x = source->x;
        p->y = source->y;
        const float fire_speed = tz_enemy_projectile_speed();
        p->vx = (dx / mag) * fire_speed;
        p->vy = (dy / mag) * fire_speed;
        p->life = 120; /* lifetime still isolated pending the action-routine lift */
        p->sprite = ZONE_FIRE_SPRITE;
        ++source->hostile_shots;
        audio_push(g, ZONE_AUDIO_FIRE, p->x, p->y);
        return 1;
    }
    return 0;
}

static int spawn_hostile_projectile(ZoneGame *g, int source_slot) {
    if (!g || source_slot < 0 || source_slot >= ZONE_WORLD_CAP) return 0;
    const struct WorldObject *source = &g->world[source_slot];
    const int cap = source->active ? tz_enemy_fire_active_cap(source->type) : 0;
    if (cap <= 0) return 0;
    return spawn_hostile_projectile_with_cap(g, source_slot, cap);
}

static void update_enemy_fire(ZoneGame *g, int slot) {
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

static void update_hq_fire(ZoneGame *g, int slot) {
    if (!g->player_alive || slot < 0 || slot >= ZONE_WORLD_CAP) return;
    struct WorldObject *o = &g->world[slot];
    if (!o->active || o->type != TZ_TYPE_BASE) return;
    if ((g->behavior_tick % (uint32_t)tz_hq_fire_interval()) != 0u) return;

    /* PPC base handler 0x14B18 has a shared 15-tick cadence and allocates a
       `fire` object aimed at the player. Unlike the Bloo/Bee/Raider/Seeker
       fire tail, this branch does not consult the per-shooter +72 cap of 3.
       ZoneCore still obeys its finite projectile pool. */
    (void)spawn_hostile_projectile_with_cap(g, slot, 0);
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

static void activate_mobile_mother_after_player_kill(ZoneGame *g) {
    /* PPC 0x19C38..0x19C98 walks the object list after a player-shot kill,
       selects the first live Mother Base with state +84 != 0, and writes the
       RandomRange(1,3) result to +86. The recovered helper's upper bound is
       exclusive, so the selector is exactly 1 or 2. */
    for (int i = 0; i < ZONE_WORLD_CAP; ++i) {
        struct WorldObject *m = &g->world[i];
        if (!m->active || m->type != TZ_TYPE_MOTH || m->state_84 == 0) continue;
        m->mother_motion_state =
            tz_mother_motion_state_from_random_word((uint16_t)(rng_next(g) & 0xFFFFu));
        return;
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

    /* Linked-child cleanup mirrors the recovered object counters used by
       0x161D0/0x16504. Defender and Bee counts live on their source bases. */
    if (is_enemy_type(destroyed_type)) {
        if (o->parent_slot >= 0 && o->parent_slot < ZONE_WORLD_CAP) {
            struct WorldObject *parent = &g->world[o->parent_slot];
            if (parent->active) {
                if (destroyed_type == TZ_TYPE_BEE) {
                    if (parent->bee_out_count > 0) --parent->bee_out_count;
                } else if (destroyed_type == TZ_TYPE_ROTO) {
                    /* Rotor is link2, not one of the +72 launched defenders. */
                    if (parent->rotor_slot == slot) parent->rotor_slot = -1;
                } else {
                    if (parent->defender_count > 0) --parent->defender_count;
                }
            }
        }
        if (destroyed_type == TZ_TYPE_BEE &&
            o->requester_slot >= 0 && o->requester_slot < ZONE_WORLD_CAP) {
            struct WorldObject *requester = &g->world[o->requester_slot];
            if (requester->active && requester->bee_request_count > 0) {
                --requester->bee_request_count;
            }
        }
    }

    /* Enemy fire remains alive if its shooter dies, but must no longer
       reference a world slot that can be recycled for a different object. */
    for (int i = 0; i < ZONE_PROJECTILE_CAP; ++i) {
        if (g->projectiles[i].active && g->projectiles[i].hostile &&
            g->projectiles[i].source_slot == slot) {
            g->projectiles[i].source_slot = -1;
        }
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

static int apply_player_shot_to_world(ZoneGame *g, int slot, int damage) {
    if (!g || slot < 0 || slot >= ZONE_WORLD_CAP || damage <= 0) return 0;
    struct WorldObject *o = &g->world[slot];
    if (!o->active) return 0;

    const int threshold = destruction_threshold(g, o->type);
    if (threshold <= 0) return 0;

    /* PPC 0x19AD4 writes Rotor +131 = 1 on every valid player-shot hit,
       before deciding whether that hit is lethal. */
    if (o->type == TZ_TYPE_ROTO) o->rotor_state = 1;
    o->damage += damage;

    if (o->damage >= threshold) {
        destroy_world_object(g, o);
        activate_mobile_mother_after_player_kill(g);
        return 1;
    }

    if (o->type == TZ_TYPE_MOTH || o->type == TZ_TYPE_BASE) {
        /* PPC 0x19C9C sets object byte +133 and plays SFX index 8 after every
           nonlethal Mother Base/HQ hit. The original renderer consumes and
           clears +133 on the next draw. ZoneCore exposes that semantic as one
           render-frame flash; exact legacy palette-effect reconstruction is
           still pending. */
        o->hit_flash_ticks = 1;
        audio_push(g, ZONE_AUDIO_HIT, o->x, o->y);
    }

    world_object_survived_player_shot(g, slot);
    return 0;
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
            p->hostile = 0;
            p->source_slot = -1;
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
    populate_fixed_wave(g, 1);
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

    ++g->behavior_tick;

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
        if (o->hit_flash_ticks > 0) --o->hit_flash_ticks;
        ++o->tick;

        update_simple_enemy_ai(g, o);
        update_complex_enemy_ai(g, o);
        update_enemy_fire(g, i);
        update_hq_fire(g, i);

        /* Collision-transferred motion plus live enemy motion. The simple
           swar/bloo/moto/raid families use recovered integer per-axis velocity
           caps; Bee/Seeker/Mother/Rotor use their recovered higher-level
           vector/state handlers without changing the world-object interface. */
        if (o->type == TZ_TYPE_ASTE || o->type == TZ_TYPE_ROCK ||
            o->type == TZ_TYPE_STON || o->type == TZ_TYPE_MOTH ||
            o->type == TZ_TYPE_BASE || is_enemy_type(o->type)) {
            o->x = wrapf(o->x + o->vx * ZONE_MOTION_X_SCALE, ZONE_LOGICAL_WIDTH);
            o->y = wrapf(o->y + o->vy * ZONE_MOTION_Y_SCALE, ZONE_LOGICAL_HEIGHT);
        }
        /* Do not generically cycle Mother Base/HQ sprite frames.  The recovered
           PPC moth/base behavior handlers maintain orientation/motion state but
           do not increment object sprite_frame (+56).  Cycling their 8-frame
           banks here produced a visible 7.5 Hz wobble/stutter that is not part
           of the original behavior.  Other passive banks remain on the
           milestone animation path until their exact frame rules are lifted. */
        if (!is_enemy_type(o->type) &&
            o->type != TZ_TYPE_MOTH && o->type != TZ_TYPE_BASE &&
            (o->tick & 7) == 0 && o->frame_count > 0) {
            o->frame = (o->frame + 1) % o->frame_count;
        }
    }

    for (int i = 0; i < ZONE_PROJECTILE_CAP; ++i) {
        struct Projectile *p = &g->projectiles[i];
        if (!p->active) continue;
        p->x = wrapf(p->x + p->vx * ZONE_MOTION_X_SCALE, ZONE_LOGICAL_WIDTH);
        p->y = wrapf(p->y + p->vy * ZONE_MOTION_Y_SCALE, ZONE_LOGICAL_HEIGHT);
        if (--p->life <= 0) {
            deactivate_projectile(g, p);
            continue;
        }

        if (p->hostile) {
            if (g->player_alive &&
                exact_overlap_ids(p->sprite, p->x, p->y,
                                  current_ship_sprite(g), g->player_x, g->player_y)) {
                deactivate_projectile(g, p);
                /* The recovered `fire` collision branch applies one damage
                   unit.  Shield-strength modifiers remain in the later
                   equipment lift; base hostile fire therefore costs 1 here. */
                if (g->shields > 0) --g->shields;
                if (g->shields <= 0) begin_player_death(g);
                audio_push(g, ZONE_AUDIO_COLLISION, g->player_x, g->player_y);
            }
            continue;
        }

        for (int j = 0; j < ZONE_WORLD_CAP && p->active; ++j) {
            struct WorldObject *o = &g->world[j];
            if (!o->active) continue;
            const int threshold = destruction_threshold(g, o->type);
            if (threshold <= 0) continue; /* collectible/non-combat object */
            if (!exact_overlap_ids(p->sprite, p->x, p->y,
                                   o->sprite_base + o->frame, o->x, o->y)) continue;

            deactivate_projectile(g, p);
            (void)apply_player_shot_to_world(
                g, j, tz_shot_damage_from_upgrade(0));
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

        /* PPC 0x1A0B4..0x1A0C8: player-body collision with a Seeker sets
           +66 = 1 and stores TickCount - 30 in +92. Because the handler
           clears at elapsed >= 60, this collision creates 30 ticks of the
           remaining coast/stun interval. */
        if (o->type == TZ_TYPE_SEEK) {
            set_enemy_hit_state(g, o, 1,
                (uint32_t)tz_seeker_player_collision_hit_backdate());
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

    /* Recovered fixed-wave population is now connected to a live lifecycle.
       Asteroids and pickups are not part of the clear condition: the tracked
       base/enemy counters are the combat objectives. */
    if (g->bases_remaining == 0 && g->enemies_remaining == 0) {
        if (g->wave < 18) {
            if (g->wave_clear_ticks == 0) g->wave_clear_ticks = ZONE_WAVE_CLEAR_TICKS;
            else if (--g->wave_clear_ticks == 0) {
                ++g->wave;
                populate_fixed_wave(g, (unsigned)g->wave);
            }
        } else {
            /* Procedural wave 19+ is intentionally still a roadmap item. */
            g->wave_clear_ticks = -1;
        }
    } else {
        g->wave_clear_ticks = 0;
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
    ZoneRenderItem z = {0, 0, 0, 0, 0, 0};
    if (!g || index < 0) return z;
    int n = 0;

    if (g->player_alive && index == n++) {
        return (ZoneRenderItem){current_ship_sprite(g), g->player_x, g->player_y, 32, 1, 0};
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
            int frame = e->age / 2;
            if (frame >= e->frame_count) frame = e->frame_count - 1;
            return (ZoneRenderItem){e->sprite_base + frame, e->x, e->y, (float)e->side, 1, 0};
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


uint32_t zone_game_debug_world_subtype(const ZoneGame *g, int32_t index) {
    if (!g || index < 0 || index >= ZONE_WORLD_CAP || !g->world[index].active) return 0;
    return g->world[index].subtype;
}

int32_t zone_game_debug_world_parent(const ZoneGame *g, int32_t index) {
    if (!g || index < 0 || index >= ZONE_WORLD_CAP || !g->world[index].active) return -1;
    return g->world[index].parent_slot;
}

int32_t zone_game_debug_world_hit_state(const ZoneGame *g, int32_t index) {
    if (!g || index < 0 || index >= ZONE_WORLD_CAP || !g->world[index].active) return -1;
    return g->world[index].hit_state;
}

void zone_game_debug_set_world_hit_state(ZoneGame *g, int32_t index,
                                         int32_t state, uint32_t elapsed_ticks) {
    if (!g || index < 0 || index >= ZONE_WORLD_CAP || !g->world[index].active) return;
    set_enemy_hit_state(g, &g->world[index], state, elapsed_ticks);
}

int32_t zone_game_debug_world_defender_count(const ZoneGame *g, int32_t index) {
    if (!g || index < 0 || index >= ZONE_WORLD_CAP || !g->world[index].active) return 0;
    return g->world[index].defender_count;
}

int32_t zone_game_debug_trigger_mother_defense(ZoneGame *g, int32_t index,
                                               int16_t gate_word, uint16_t batch_word) {
    if (!g) return 0;
    return launch_mother_defenders_with_words(g, (int)index, gate_word, batch_word);
}

int32_t zone_game_debug_request_bee(ZoneGame *g, int32_t requester_index) {
    if (!g) return -1;
    return request_bee(g, (int)requester_index);
}

int32_t zone_game_debug_world_damage(const ZoneGame *g, int32_t index) {
    if (!g || index < 0 || index >= ZONE_WORLD_CAP || !g->world[index].active) return -1;
    return g->world[index].damage;
}

int32_t zone_game_debug_apply_player_shot(ZoneGame *g, int32_t index) {
    if (!g) return 0;
    return apply_player_shot_to_world(g, (int)index, tz_shot_damage_from_upgrade(0));
}

int32_t zone_game_debug_trigger_hq_defense(ZoneGame *g, int32_t index) {
    if (!g) return 0;
    return launch_hq_defenders(g, (int)index);
}

int32_t zone_game_debug_world_state84(const ZoneGame *g, int32_t index) {
    if (!g || index < 0 || index >= ZONE_WORLD_CAP || !g->world[index].active) return -1;
    return g->world[index].state_84;
}

int32_t zone_game_debug_mother_motion_state(const ZoneGame *g, int32_t index) {
    if (!g || index < 0 || index >= ZONE_WORLD_CAP || !g->world[index].active) return -1;
    return g->world[index].mother_motion_state;
}

void zone_game_debug_set_mother_state(ZoneGame *g, int32_t index,
                                      int32_t state84, int32_t motion_state) {
    if (!g || index < 0 || index >= ZONE_WORLD_CAP) return;
    struct WorldObject *o = &g->world[index];
    if (!o->active || o->type != TZ_TYPE_MOTH) return;
    o->state_84 = state84 ? 1 : 0;
    o->mother_motion_state =
        motion_state < 0 ? 0 : (motion_state > 2 ? 2 : motion_state);
}

int32_t zone_game_debug_rotor_state(const ZoneGame *g, int32_t index) {
    if (!g || index < 0 || index >= ZONE_WORLD_CAP || !g->world[index].active ||
        g->world[index].type != TZ_TYPE_ROTO) return -1;
    return g->world[index].rotor_state;
}

int32_t zone_game_debug_world_rotor_child(const ZoneGame *g, int32_t index) {
    if (!g || index < 0 || index >= ZONE_WORLD_CAP || !g->world[index].active) return -1;
    return g->world[index].rotor_slot;
}

void zone_game_debug_set_rotor_state(ZoneGame *g, int32_t index,
                                     int32_t rotor_state, int32_t heading_degrees) {
    if (!g || index < 0 || index >= ZONE_WORLD_CAP) return;
    struct WorldObject *o = &g->world[index];
    if (!o->active || o->type != TZ_TYPE_ROTO) return;
    o->rotor_state = rotor_state < 0 ? 0 : (rotor_state > 2 ? 2 : rotor_state);
    heading_degrees %= 360;
    if (heading_degrees < 0) heading_degrees += 360;
    o->rotor_heading = heading_degrees;
}

void zone_game_debug_load_fixed_wave(ZoneGame *g, int32_t wave) {
    if (!g) return;
    if (wave < 1) wave = 1;
    if (wave > 18) wave = 18;
    g->wave = wave;
    populate_fixed_wave(g, (unsigned)wave);
}

uint32_t zone_game_debug_behavior_tick(const ZoneGame *g) {
    return g ? g->behavior_tick : 0u;
}

int32_t zone_game_active_hostile_projectiles(const ZoneGame *g) {
    return g ? active_hostile_projectile_count(g) : 0;
}

int32_t zone_game_debug_enemy_fire(ZoneGame *g, int32_t source_index) {
    if (!g) return 0;
    return spawn_hostile_projectile(g, (int)source_index);
}
