#include <math.h>
#include "thezone_decomp.h"

/* PPC ship branch 0x115F8. Heading is maintained in [0,360) and converted to
 * one of 48 ship orientations using 7.5 degrees/frame. */
float tz_wrap_heading(float h) {
    while (h < 0.0f) h += 360.0f;
    while (h >= 360.0f) h -= 360.0f;
    return h;
}

int16_t tz_heading_to_frame48(float heading_degrees) {
    const float h = tz_wrap_heading(heading_degrees);
    return (int16_t)(h / 7.5f); /* PPC uses fctiwz: truncate toward zero */
}

/* Exact semantic lift of the thrust-vector acceptance rule at 0x11C70.
 * Math resource #0 is -sin(deg), #1 is cos(deg).
 *
 * The game tentatively adds one lookup vector to velocity. It accepts the new
 * vector if it is at/below maximum speed OR if it reduces speed. This permits
 * thrusting opposite motion while already above a changed cap, but refuses
 * further acceleration away from the cap.
 */
bool tz_apply_player_thrust(float *vx, float *vy,
                            float heading_degrees, float maximum_speed,
                            const float neg_sin_360[360], const float cos_360[360]) {
    const int angle = (int)tz_wrap_heading(heading_degrees);
    const float old_speed = sqrtf((*vx * *vx) + (*vy * *vy));
    const float new_vx = *vx + neg_sin_360[angle];
    const float new_vy = *vy + cos_360[angle];
    const float new_speed = sqrtf((new_vx * new_vx) + (new_vy * new_vy));

    if (new_speed <= maximum_speed || new_speed < old_speed) {
        *vx = new_vx;
        *vy = new_vy;
        return true;
    }
    return false;
}
