#include "zone_core.h"
#include "zone_sprite_data.h"
#include "thezone_decomp.h"

#include <math.h>
#include <stdlib.h>
#include <string.h>

#define ZONE_PI 3.14159265358979323846f
#define ZONE_SHIP_BASE 1000
#define ZONE_ASTEROID_BASE 400
#define ZONE_SHOT_BASE 148
#define ZONE_EXPLOSION_BASE 1500
#define ZONE_PROJECTILE_CAP 12
#define ZONE_EXPLOSION_CAP 4

/* Recovered behavior constants currently used by the playable core.
 * - original viewport minimum: 640x480
 * - 48 ship frames => 7.5 degrees/frame
 * - continuous motion conversion: X ~= .325, Y = .25
 * - player/projectile directional basis: X = -sin(angle), Y = cos(angle)
 * - player projectile vector magnitude: 15
 *
 * The turn rate/default max speed remain isolated here until the remaining
 * preference/speed setup paths are completely lifted.
 */
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
};

struct ZoneGame {
    uint32_t rng;
    float player_x, player_y;
    float player_vx, player_vy;
    float heading;
    int fire_cooldown;
    uint8_t fire_latch;
    uint8_t pause_latch;

    float asteroid_x, asteroid_y;
    float asteroid_vx, asteroid_vy;
    int asteroid_frame;
    uint8_t asteroid_active;
    int asteroid_respawn;

    struct Projectile projectiles[ZONE_PROJECTILE_CAP];
    struct Explosion explosions[ZONE_EXPLOSION_CAP];

    int score, shields, wave, ammo;
    uint8_t paused;

    ZoneAudioEvent audio[ZONE_MAX_AUDIO_EVENTS];
    int audio_count;
};

/* The original ships/projectiles use two 360-entry math resources: -sin and
 * cos.  Until the extracted binary float tables are promoted into ZoneCore as
 * canonical data, build equivalent tables once and pass them through the
 * recovered player routine.  This keeps the recovered coordinate convention
 * centralized and prevents another accidental +cos/-sin rotation.
 */
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
    /* Deterministic placeholder. Replace with exact classic Mac Random() state
       transition once the RNG compatibility test is added. */
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

static void spawn_asteroid(ZoneGame *g) {
    g->asteroid_active = 1;
    g->asteroid_respawn = 0;
    g->asteroid_x = 430.0f + rng_unit(g) * 150.0f;
    g->asteroid_y = 80.0f + rng_unit(g) * 300.0f;
    g->asteroid_vx = -2.1f - rng_unit(g) * 1.7f;
    g->asteroid_vy = -1.2f + rng_unit(g) * 2.4f;
    g->asteroid_frame = (int)(rng_next(g) % 24u);
}

static void spawn_explosion(ZoneGame *g, float x, float y) {
    for (int i = 0; i < ZONE_EXPLOSION_CAP; ++i) {
        if (!g->explosions[i].active) {
            g->explosions[i] = (struct Explosion){1, x, y, 0};
            audio_push(g, ZONE_AUDIO_EXPLOSION, x, y);
            return;
        }
    }
}

static void spawn_projectile(ZoneGame *g) {
    ensure_trig_tables();
    for (int i = 0; i < ZONE_PROJECTILE_CAP; ++i) {
        if (!g->projectiles[i].active) {
            const int angle = (int)tz_wrap_heading(g->heading);
            const float dx = g_neg_sin_360[angle];
            const float dy = g_cos_360[angle];
            struct Projectile *p = &g->projectiles[i];
            p->active = 1;
            p->x = wrapf(g->player_x + dx * 18.0f, ZONE_LOGICAL_WIDTH);
            p->y = wrapf(g->player_y + dy * 18.0f, ZONE_LOGICAL_HEIGHT);
            p->vx = dx * ZONE_PROJECTILE_SPEED;
            p->vy = dy * ZONE_PROJECTILE_SPEED;
            p->life = 90;
            p->sprite = ZONE_SHOT_BASE;
            audio_push(g, ZONE_AUDIO_FIRE, p->x, p->y);
            return;
        }
    }
}

static int current_ship_sprite(const ZoneGame *g) {
    return ZONE_SHIP_BASE + tz_heading_to_frame48(g->heading);
}

static int exact_overlap_ids(int a_id, float ax, float ay,
                             int b_id, float bx, float by) {
    const ZoneSpritePixels *a = zone_sprite_pixels(a_id);
    const ZoneSpritePixels *b = zone_sprite_pixels(b_id);
    if (!a || !b) return 0;

    TzSpriteView av = {a->side, a->pixels};
    TzSpriteView bv = {b->side, b->pixels};
    int atlx = (int)lrintf(ax - a->side * 0.5f);
    int atly = (int)lrintf(ay - a->side * 0.5f);
    int btlx = (int)lrintf(bx - b->side * 0.5f);
    int btly = (int)lrintf(by - b->side * 0.5f);
    return tz_sprite_overlap_exact(&av, atlx, atly, &bv, btlx, btly);
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
    spawn_asteroid(g);
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
        (void)tz_apply_player_thrust(&g->player_vx, &g->player_vy,
                                     g->heading, ZONE_CLASSIC_MAX_SPEED,
                                     g_neg_sin_360, g_cos_360);
    }

    g->player_x = wrapf(g->player_x + g->player_vx * ZONE_MOTION_X_SCALE,
                        ZONE_LOGICAL_WIDTH);
    g->player_y = wrapf(g->player_y + g->player_vy * ZONE_MOTION_Y_SCALE,
                        ZONE_LOGICAL_HEIGHT);

    if (g->fire_cooldown > 0) g->fire_cooldown--;
    if (in.fire && g->fire_cooldown == 0) {
        spawn_projectile(g);
        g->fire_cooldown = ZONE_FIRE_COOLDOWN_TICKS;
    }
    g->fire_latch = in.fire;

    if (g->asteroid_active) {
        g->asteroid_x = wrapf(g->asteroid_x + g->asteroid_vx * ZONE_MOTION_X_SCALE,
                              ZONE_LOGICAL_WIDTH);
        g->asteroid_y = wrapf(g->asteroid_y + g->asteroid_vy * ZONE_MOTION_Y_SCALE,
                              ZONE_LOGICAL_HEIGHT);
        if ((rng_next(g) & 15u) == 0) g->asteroid_frame = (g->asteroid_frame + 1) % 24;
    } else if (--g->asteroid_respawn <= 0) {
        spawn_asteroid(g);
    }

    for (int i = 0; i < ZONE_PROJECTILE_CAP; ++i) {
        if (g->projectiles[i].active) {
            struct Projectile *p = &g->projectiles[i];
            p->x = wrapf(p->x + p->vx * ZONE_MOTION_X_SCALE, ZONE_LOGICAL_WIDTH);
            p->y = wrapf(p->y + p->vy * ZONE_MOTION_Y_SCALE, ZONE_LOGICAL_HEIGHT);
            if (--p->life <= 0) {
                p->active = 0;
                continue;
            }
            if (g->asteroid_active &&
                exact_overlap_ids(p->sprite, p->x, p->y,
                                  ZONE_ASTEROID_BASE + g->asteroid_frame,
                                  g->asteroid_x, g->asteroid_y)) {
                p->active = 0;
                g->asteroid_active = 0;
                g->asteroid_respawn = 120;
                g->score += 100;
                spawn_explosion(g, g->asteroid_x, g->asteroid_y);
            }
        }
    }

    if (g->asteroid_active &&
        exact_overlap_ids(current_ship_sprite(g), g->player_x, g->player_y,
                          ZONE_ASTEROID_BASE + g->asteroid_frame,
                          g->asteroid_x, g->asteroid_y)) {
        g->shields -= 1;
        if (g->shields < 0) g->shields = 0;
        audio_push(g, ZONE_AUDIO_COLLISION, g->player_x, g->player_y);
    }

    for (int i = 0; i < ZONE_EXPLOSION_CAP; ++i) {
        if (g->explosions[i].active && ++g->explosions[i].age >= 40) {
            g->explosions[i].active = 0;
        }
    }
}

int32_t zone_game_render_item_count(const ZoneGame *g) {
    if (!g) return 0;
    int n = 1 + (g->asteroid_active ? 1 : 0);
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
    if (g->asteroid_active) {
        if (index == n++) {
            return (ZoneRenderItem){ZONE_ASTEROID_BASE + g->asteroid_frame,
                                    g->asteroid_x, g->asteroid_y, 32, 1};
        }
    }
    for (int i = 0; i < ZONE_PROJECTILE_CAP; ++i) {
        if (g->projectiles[i].active && index == n++) {
            return (ZoneRenderItem){g->projectiles[i].sprite,
                                    g->projectiles[i].x, g->projectiles[i].y, 4, 1};
        }
    }
    for (int i = 0; i < ZONE_EXPLOSION_CAP; ++i) {
        if (g->explosions[i].active && index == n++) {
            int frame = g->explosions[i].age / 2;
            if (frame > 19) frame = 19;
            return (ZoneRenderItem){ZONE_EXPLOSION_BASE + frame,
                                    g->explosions[i].x, g->explosions[i].y, 32, 1};
        }
    }
    return z;
}

ZoneHUDState zone_game_hud(const ZoneGame *g) {
    if (!g) return (ZoneHUDState){0};
    return (ZoneHUDState){g->score, g->shields, g->wave, g->ammo, g->paused};
}

int32_t zone_game_drain_audio(ZoneGame *g, ZoneAudioEvent *events, int32_t cap) {
    if (!g || !events || cap <= 0) return 0;
    int n = g->audio_count < cap ? g->audio_count : cap;
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
