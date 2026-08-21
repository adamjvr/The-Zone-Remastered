#ifndef THEZONE_DECOMP_H
#define THEZONE_DECOMP_H

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>
#include "thezone_types.h"

typedef struct TzSpriteView {
    uint16_t side;
    const uint8_t *pixels; /* side*side indexed-color bytes; 0 is transparent */
} TzSpriteView;

typedef struct TzRect16 {
    int16_t left, top, right, bottom;
} TzRect16;



typedef struct TzWavePreset {
    int16_t moth_count;
    int16_t base_count;
    int16_t raid_count;
    int16_t seek_count;
    int16_t rotor_link_count;
    int16_t bloo_subtype_quota;
    int16_t mobile_moth_quota;
    int16_t bee_limit;
} TzWavePreset;

typedef struct TzDamageThresholds {
    int16_t moth, base, raid, bee, roto, seek, bloo;
} TzDamageThresholds;

const TzWavePreset *tz_wave_preset(bool professional, unsigned wave);
unsigned tz_initial_asteroid_count(unsigned wave);
TzDamageThresholds tz_damage_thresholds(bool professional);
int16_t tz_damage_threshold_for_type(uint32_t type, const TzDamageThresholds *thresholds);
int16_t tz_shot_damage_from_upgrade(int16_t weapon_damage_level);
int16_t tz_map_quickdraw_angle(int16_t quickdraw_angle);

typedef struct TzObjectInitSpec {
    uint32_t type;
    uint16_t sprite_table_toc_offset; /* original PPC TOC-relative global */
    int16_t sprite_frame_count;
    int16_t side;
    uint8_t flag_130;
    int16_t type_state;
    bool has_type_state;
} TzObjectInitSpec;

const TzObjectInitSpec *tz_object_init_spec(uint32_t type);

typedef struct TzKillAward {
    uint32_t type;
    uint8_t counter_index;
    int16_t score;
} TzKillAward;

uint16_t tz_random_range_u16(uint16_t lower, uint16_t upper, uint16_t mac_random_word);
void tz_blit_sprite_transparent(const TzSpriteView *sprite, uint8_t *dst, size_t dst_row_bytes);
bool tz_sprite_overlap_exact(const TzSpriteView *a, int ax, int ay,
                             const TzSpriteView *b, int bx, int by);
void tz_integrate_wrapped(TzZoneObjectPPC32 *obj, int16_t world_width, int16_t world_height);
const TzKillAward *tz_kill_award_for_type(uint32_t type);
size_t tz_save_expected_size(size_t object_count);
bool tz_save_validate_v151(const void *bytes, size_t size, int16_t *object_count_out);
int16_t tz_save_link1_index(const TzSaveHeaderPPC32 *h, size_t object_index);
int16_t tz_save_link2_index(const TzSaveHeaderPPC32 *h, size_t object_index);

int16_t tz_heading_to_frame48(float heading_degrees);

typedef struct TzMuzzleOffset {
    int16_t x;
    int16_t y;
} TzMuzzleOffset;

TzMuzzleOffset tz_ship_muzzle_offset_frame48(int16_t frame);
void tz_screen_direction_from_heading(float heading_degrees,
                                      const float neg_sin_360[360],
                                      const float cos_360[360],
                                      float *screen_dx, float *screen_dy);
float tz_wrap_heading(float heading_degrees);
bool tz_apply_player_thrust(float *velocity_vertical, float *velocity_horizontal,
                            float heading_degrees, float maximum_speed,
                            const float neg_sin_360[360], const float cos_360[360]);

int16_t tz_chase_axis_step(int16_t position, int16_t target, int16_t velocity, int16_t cap);
void tz_convert_motion_vector(TzZoneObjectPPC32 *obj, float x_scale, float y_scale);
void tz_seek_direct_velocity(TzZoneObjectPPC32 *obj, int16_t target_x, int16_t target_y,
                             int16_t heading_degrees, float maximum_speed, float cruise_speed,
                             float x_scale, float y_scale,
                             const float neg_sin_360[360], const float cos_360[360]);
bool tz_signed_random_strict_window(int16_t random_word, int16_t low, int16_t high);

#endif
