#ifndef ZONE_CORE_H
#define ZONE_CORE_H

#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

#define ZONE_LOGICAL_WIDTH 640
#define ZONE_LOGICAL_HEIGHT 480
#define ZONE_MAX_RENDER_ITEMS 64
#define ZONE_MAX_AUDIO_EVENTS 16

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
} ZoneRenderItem;

typedef enum ZoneAudioEventType {
    ZONE_AUDIO_NONE = 0,
    ZONE_AUDIO_FIRE = 1,
    ZONE_AUDIO_EXPLOSION = 2,
    ZONE_AUDIO_COLLISION = 3
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
    uint8_t paused;
} ZoneHUDState;

ZoneGame *zone_game_create(uint32_t seed);
void zone_game_destroy(ZoneGame *game);
void zone_game_reset(ZoneGame *game, uint32_t seed);
void zone_game_step(ZoneGame *game, ZoneInput input);

int32_t zone_game_render_item_count(const ZoneGame *game);
ZoneRenderItem zone_game_render_item_at(const ZoneGame *game, int32_t index);
ZoneHUDState zone_game_hud(const ZoneGame *game);
int32_t zone_game_drain_audio(ZoneGame *game, ZoneAudioEvent *events, int32_t capacity);

/* Engineering/debug accessors used by deterministic regression tests. */
float zone_game_player_x(const ZoneGame *game);
float zone_game_player_y(const ZoneGame *game);
float zone_game_player_heading(const ZoneGame *game);

#ifdef __cplusplus
}
#endif
#endif
