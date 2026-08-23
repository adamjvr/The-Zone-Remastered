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


/* Recovered enemy / Mother Base behavior semantics. */
int16_t tz_enemy_chase_interval(uint32_t type);
int16_t tz_enemy_axis_cap(uint32_t type);
bool tz_enemy_should_fire(uint32_t type, int16_t random_word);
int16_t tz_enemy_fire_active_cap(uint32_t type);
float tz_enemy_projectile_speed(void);
bool tz_mother_should_launch_defenders(int16_t random_word);
int16_t tz_mother_defender_active_cap(bool professional);
int16_t tz_mother_defender_batch_count(bool professional, uint16_t random_word);
/* HQ hit-response routine at PPC 0x16390: active linked-defender cap is
 * four in Professional mode and two in Beginner mode. */
int16_t tz_hq_defender_active_cap(bool professional);

/* Mother Base movement selector and Headquarters base-fire behavior.
 * PPC 0x14C70, 0x19C38..0x19C98 and 0x14B18. */
int16_t tz_mother_motion_state_from_random_word(uint16_t random_word);
float tz_mother_direct_speed(float distance_squared, float maximum_speed);
int16_t tz_hq_fire_interval(void);

/* Rotor guard state machine, PPC 0x15BC8..0x16124. */
float tz_rotor_orbit_radius(void);
float tz_rotor_attack_radius_squared(void);
float tz_rotor_leash_radius(float zone_extent);
float tz_rotor_attack_speed(void);
float tz_rotor_return_speed(void);
int16_t tz_rotor_orbit_heading_step(void);

/* Recovered collision semantics. */
void tz_swap_fixed_velocity(TzZoneObjectPPC32 *a, TzZoneObjectPPC32 *b);
void tz_swap_float_velocity(TzZoneObjectPPC32 *a, TzZoneObjectPPC32 *b);
void tz_swap_screen_velocity(float *a_vx, float *a_vy, float *b_vx, float *b_vy);
int16_t tz_player_impact_damage(uint32_t collider_type,
                                float ship_speed_before,
                                float ship_speed_after,
                                float shield_strength);
int16_t tz_player_base_impact_damage(float ship_speed_before, float shield_strength);

/* Recovered progression / pickup semantics. */
float tz_initial_player_max_speed(void);
float tz_velocity_module_apply(float maximum_speed);
int16_t tz_ammo_loader_apply(int16_t ammo_capacity);
int16_t tz_oscilloscope_apply(int16_t shields);
uint32_t tz_select_barrel_type(unsigned wave, int16_t upgrade_a, int16_t upgrade_b,
                               uint16_t random_0_100, bool rock_special,
                               uint16_t random_bit);

#endif
