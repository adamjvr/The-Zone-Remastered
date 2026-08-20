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
