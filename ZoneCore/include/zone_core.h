#ifndef ZONE_CORE_H
#define ZONE_CORE_H

#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

#define ZONE_LOGICAL_WIDTH 640
#define ZONE_LOGICAL_HEIGHT 480
#define ZONE_MAX_RENDER_ITEMS 160
#define ZONE_MAX_AUDIO_EVENTS 16

#define ZONE_MASTER_HZ 720u
#define ZONE_CLASSIC_HZ 60u
#define ZONE_MASTER_TICKS_PER_CLASSIC_STEP (ZONE_MASTER_HZ / ZONE_CLASSIC_HZ)

typedef struct ZoneGame ZoneGame;

typedef struct ZoneInput {
    float turn;          /* -1...+1; Classic mode quantizes to sign */
    float thrust;        /* 0...1; Classic mode is digital */
    uint8_t fire;
    uint8_t equipment_up;
    uint8_t equipment_down;
    uint8_t select;
    uint8_t pause;
    uint8_t save;
} ZoneInput;

typedef struct ZoneRenderItem {
    int32_t sprite_id;
    float x;             /* center, logical 640x480 coordinates */
    float y;
    float side;
    float alpha;
    float flash;          /* 0..1 one-frame impact emphasis */
} ZoneRenderItem;

typedef enum ZoneAudioEventType {
    ZONE_AUDIO_NONE = 0,
    ZONE_AUDIO_FIRE = 1,
    ZONE_AUDIO_EXPLOSION = 2,
    ZONE_AUDIO_COLLISION = 3,
    ZONE_AUDIO_HIT = 4
} ZoneAudioEventType;

typedef struct ZoneAudioEvent {
    int32_t type;
    float x;
    float y;
} ZoneAudioEvent;

typedef struct ZoneHUDState {
    int32_t score;
    int32_t shields;
    int32_t wave;
    int32_t ammo;
    int32_t bases;
    int32_t enemies;
    float speed;
    float maximum_speed;
    uint8_t player_alive;
    uint8_t paused;
} ZoneHUDState;

typedef struct ZoneDebugBodyState {
    uint8_t active;
    uint32_t type;
    float x;
    float y;
    float vx;
    float vy;
    int32_t frame;
} ZoneDebugBodyState;

ZoneGame *zone_game_create(uint32_t seed);
void zone_game_destroy(ZoneGame *game);
void zone_game_reset(ZoneGame *game, uint32_t seed);
void zone_game_step(ZoneGame *game, ZoneInput input);
int32_t zone_game_advance_master_ticks(ZoneGame *game, ZoneInput input, uint32_t master_ticks);

int32_t zone_game_render_item_count(const ZoneGame *game);
ZoneRenderItem zone_game_render_item_at(const ZoneGame *game, int32_t index);
ZoneHUDState zone_game_hud(const ZoneGame *game);
int32_t zone_game_drain_audio(ZoneGame *game, ZoneAudioEvent *events, int32_t capacity);

/* Engineering/debug accessors used by deterministic regression tests. */
float zone_game_player_x(const ZoneGame *game);
float zone_game_player_y(const ZoneGame *game);
float zone_game_player_heading(const ZoneGame *game);
int32_t zone_game_world_object_count(const ZoneGame *game);
int32_t zone_game_count_type(const ZoneGame *game, uint32_t fourcc);
void zone_game_debug_set_heading(ZoneGame *game, float heading_degrees);
ZoneDebugBodyState zone_game_debug_player_state(const ZoneGame *game);
void zone_game_debug_set_player_state(ZoneGame *game, float x, float y, float vx, float vy);
int32_t zone_game_debug_find_nth_type(const ZoneGame *game, uint32_t fourcc, int32_t nth);
ZoneDebugBodyState zone_game_debug_world_state(const ZoneGame *game, int32_t index);
void zone_game_debug_set_world_state(ZoneGame *game, int32_t index,
                                     float x, float y, float vx, float vy, int32_t frame);
float zone_game_player_max_speed(const ZoneGame *game);
int32_t zone_game_active_projectiles(const ZoneGame *game);
int32_t zone_game_active_hostile_projectiles(const ZoneGame *game);
int32_t zone_game_debug_classic_object_capacity(void);
int32_t zone_game_debug_classic_slots_used(const ZoneGame *game);
int32_t zone_game_debug_world_flash(const ZoneGame *game, int32_t index);
int32_t zone_game_debug_player_flash(const ZoneGame *game);
int32_t zone_game_debug_active_explosions(const ZoneGame *game);
int32_t zone_game_debug_explosion_frame(const ZoneGame *game, int32_t nth);
uint32_t zone_game_debug_explosion_previous_type(const ZoneGame *game, int32_t nth);
int32_t zone_game_debug_respawn_pending(const ZoneGame *game);
uint8_t zone_game_player_alive(const ZoneGame *game);
void zone_game_debug_set_progression(ZoneGame *game, int32_t shields, int32_t ammo,
                                     float maximum_speed, int32_t wave);
int32_t zone_game_debug_spawn_world(ZoneGame *game, uint32_t fourcc,
                                    float x, float y, float vx, float vy);
void zone_game_debug_destroy_world(ZoneGame *game, int32_t index);
uint32_t zone_game_debug_world_subtype(const ZoneGame *game, int32_t index);
int32_t zone_game_debug_world_parent(const ZoneGame *game, int32_t index);
int32_t zone_game_debug_world_hit_state(const ZoneGame *game, int32_t index);
void zone_game_debug_set_world_hit_state(ZoneGame *game, int32_t index,
                                         int32_t state, uint32_t elapsed_ticks);
int32_t zone_game_debug_world_defender_count(const ZoneGame *game, int32_t index);
int32_t zone_game_debug_trigger_mother_defense(ZoneGame *game, int32_t index,
                                               int16_t gate_word, uint16_t batch_word);
int32_t zone_game_debug_request_bee(ZoneGame *game, int32_t requester_index);
int32_t zone_game_debug_enemy_fire(ZoneGame *game, int32_t source_index);
int32_t zone_game_debug_spawn_hostile_unbounded(ZoneGame *game, int32_t source_index);
int32_t zone_game_debug_world_damage(const ZoneGame *game, int32_t index);
int32_t zone_game_debug_apply_player_shot(ZoneGame *game, int32_t index);
int32_t zone_game_debug_trigger_hq_defense(ZoneGame *game, int32_t index);
int32_t zone_game_debug_world_state84(const ZoneGame *game, int32_t index);
int32_t zone_game_debug_mother_motion_state(const ZoneGame *game, int32_t index);
void zone_game_debug_set_mother_state(ZoneGame *game, int32_t index,
                                      int32_t state84, int32_t motion_state);
int32_t zone_game_debug_rotor_state(const ZoneGame *game, int32_t index);
int32_t zone_game_debug_world_rotor_child(const ZoneGame *game, int32_t index);
void zone_game_debug_set_rotor_state(ZoneGame *game, int32_t index,
                                     int32_t rotor_state, int32_t heading_degrees);
void zone_game_debug_load_fixed_wave(ZoneGame *game, int32_t wave);
uint32_t zone_game_debug_behavior_tick(const ZoneGame *game);
uint32_t zone_game_debug_master_phase(const ZoneGame *game);

#ifdef __cplusplus
}
#endif
#endif
