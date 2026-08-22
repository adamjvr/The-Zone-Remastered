#include <math.h>
#include "thezone_decomp.h"

/* Shared semantic pattern seen in swar/bloo/moto/raid handlers. */
int16_t tz_chase_axis_step(int16_t position, int16_t target, int16_t velocity, int16_t cap) {
    if (target < position) {
        if (velocity > -cap) velocity--;
    } else if (target > position) {
        if (velocity < cap) velocity++;
    } else {
        velocity = 0;
    }
    return velocity;
}

/* PPC 0xE6F4. Fields +100/+104 are a continuous motion vector. The routine
 * applies independent X/Y scale factors, forms predicted float positions from
 * the current integer world position, then truncates the resulting displacement
 * to object velocity fields +40/+42.
 *
 * Runtime defaults initialized by app startup are X scale ~= 0.325 and
 * Y scale = 0.25.
 */
void tz_convert_motion_vector(TzZoneObjectPPC32 *obj, float x_scale, float y_scale) {
    const float scaled_x = obj->velocity_fx * x_scale;
    const float scaled_y = obj->velocity_fy * y_scale;
    const float predicted_x = (float)obj->world_x + scaled_x;
    const float predicted_y = (float)obj->world_y + scaled_y;

    obj->velocity_x = (int16_t)(predicted_x - (float)obj->world_x);
    obj->velocity_y = (int16_t)(predicted_y - (float)obj->world_y);
}

/* Seek handler 0x15944. Once the caller has determined the wrapped target
 * position and angle, speed switches at squared distance 40000 (200 units).
 * Near: use current maximum speed. Far: use the cruise-speed global.
 */
void tz_seek_direct_velocity(TzZoneObjectPPC32 *obj, int16_t target_x, int16_t target_y,
                             int16_t heading_degrees, float maximum_speed, float cruise_speed,
                             float x_scale, float y_scale,
                             const float neg_sin_360[360], const float cos_360[360]) {
    const float dx = (float)target_x - (float)(obj->world_x + 16);
    const float dy = (float)target_y - (float)(obj->world_y + 16);
    const float dist_sq = dx * dx + dy * dy;
    const float speed = dist_sq <= 40000.0f ? maximum_speed : cruise_speed;
    int angle = heading_degrees % 360;
    if (angle < 0) angle += 360;

    obj->velocity_x = (int16_t)(speed * x_scale * neg_sin_360[angle]);
    obj->velocity_y = (int16_t)(speed * y_scale * cos_360[angle]);
}

bool tz_signed_random_strict_window(int16_t random_word, int16_t low, int16_t high) {
    return random_word > low && random_word < high;
}


/* Enemy update cadences and per-axis velocity caps from the native PPC
 * behavior dispatcher:
 *   swar: every 4 updates, cap 8
 *   bloo: every 3 updates, cap 9
 *   moto: every update, cap 10
 *   raid: every 2 updates, cap 9
 */
int16_t tz_enemy_chase_interval(uint32_t type) {
    switch (type) {
        case TZ_TYPE_SWAR: return 4;
        case TZ_TYPE_BLOO: return 3;
        case TZ_TYPE_MOTO: return 1;
        case TZ_TYPE_RAID: return 2;
        default: return 0;
    }
}

int16_t tz_enemy_axis_cap(uint32_t type) {
    switch (type) {
        case TZ_TYPE_SWAR: return 8;
        case TZ_TYPE_BLOO: return 9;
        case TZ_TYPE_MOTO: return 10;
        case TZ_TYPE_RAID: return 9;
        default: return 0;
    }
}

/* Hostile-fire gates recovered from the PPC type handlers. These use the
 * original signed Random() word and strict inequalities. The shared fire tail
 * refuses a new shot once the shooter's +72 active-fire counter reaches 3.
 *
 *   bloo: (10000,13500)
 *   bee!: (10000,15000)
 *   raid: (10000,20000)
 *   seek: (10000,11000)
 *
 * The `fire` object constructor at 0x107B4 uses vector magnitude 11.25.
 */
bool tz_enemy_should_fire(uint32_t type, int16_t random_word) {
    switch (type) {
        case TZ_TYPE_BLOO: return tz_signed_random_strict_window(random_word, 10000, 13500);
        case TZ_TYPE_BEE:  return tz_signed_random_strict_window(random_word, 10000, 15000);
        case TZ_TYPE_RAID: return tz_signed_random_strict_window(random_word, 10000, 20000);
        case TZ_TYPE_SEEK: return tz_signed_random_strict_window(random_word, 10000, 11000);
        default: return false;
    }
}

int16_t tz_enemy_fire_active_cap(uint32_t type) {
    switch (type) {
        case TZ_TYPE_BLOO:
        case TZ_TYPE_BEE:
        case TZ_TYPE_RAID:
        case TZ_TYPE_SEEK:
            return 3;
        default:
            return 0;
    }
}

float tz_enemy_projectile_speed(void) {
    return 11.25f;
}

/* Mother Base hit-reaction routine at PPC 0x161D0. The cached signed Random
 * value must lie strictly inside (10000,30000). Professional mode allows five
 * simultaneously linked defenders and launches 2..5 per successful request;
 * Beginner uses a cap of three and launches 1..3.
 */
bool tz_mother_should_launch_defenders(int16_t random_word) {
    return tz_signed_random_strict_window(random_word, 10000, 30000);
}

int16_t tz_mother_defender_active_cap(bool professional) {
    return professional ? 5 : 3;
}

int16_t tz_mother_defender_batch_count(bool professional, uint16_t random_word) {
    const uint16_t span = professional ? 4u : 3u;
    const int16_t base = professional ? 2 : 1;
    return (int16_t)(base + (random_word % span));
}


/* Headquarters hit-response routine at PPC 0x16390. Unlike the Mother Base
 * routine, HQ defender deployment has no signed-Random gate: each invocation
 * tries the four corner positions and stops once the mode-specific active cap
 * is reached. */
int16_t tz_hq_defender_active_cap(bool professional) {
    return professional ? 4 : 2;
}
