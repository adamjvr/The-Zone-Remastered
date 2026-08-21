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

/* Math resource #2 is copied to the PPC global at TOC+11320 during startup.
 * It is exactly 192 bytes: 48 pairs of signed 16-bit muzzle offsets. 0x12224
 * indexes this table by the ship's visible orientation before constructing a
 * 'shot' object. These values are the shipping v1.5.1 bytes decoded as BE i16.
 */
static const TzMuzzleOffset kShipMuzzleOffsets48[48] = {
    { 16,  0}, { 15, -2}, { 15, -4}, { 14, -6}, { 13, -7}, { 12, -9},
    { 11,-11}, {  9,-12}, {  8,-13}, {  6,-14}, {  4,-15}, {  2,-15},
    {  0,-16}, { -2,-15}, { -4,-15}, { -6,-14}, { -7,-13}, { -9,-12},
    {-11,-11}, {-12, -9}, {-13, -8}, {-14, -6}, {-15, -4}, {-15, -2},
    {-16,  0}, {-15,  2}, {-15,  4}, {-14,  6}, {-13,  7}, {-12,  9},
    {-11, 11}, { -9, 12}, { -8, 13}, { -6, 14}, { -4, 15}, { -2, 15},
    {  0, 16}, {  2, 15}, {  4, 15}, {  6, 14}, {  7, 13}, {  9, 12},
    { 11, 11}, { 12,  9}, { 13,  8}, { 14,  6}, { 15,  4}, { 15,  2},
};

TzMuzzleOffset tz_ship_muzzle_offset_frame48(int16_t frame) {
    int f = frame % 48;
    if (f < 0) f += 48;
    return kShipMuzzleOffsets48[f];
}

/* Classic Macintosh geometry convention matters here. The original movement
 * vector is stored/used as vertical then horizontal: Math0=-sin is the
 * vertical screen component and Math1=cos is the horizontal screen component.
 * Portable ZoneCore exposes conventional screen X/Y, therefore:
 *
 *     screen_x = horizontal = cos(angle)
 *     screen_y = vertical   = -sin(angle)
 *
 * This is the 90-degree mapping error that the first remaster scaffold exposed.
 */
void tz_screen_direction_from_heading(float heading_degrees,
                                      const float neg_sin_360[360],
                                      const float cos_360[360],
                                      float *screen_dx, float *screen_dy) {
    const int angle = (int)tz_wrap_heading(heading_degrees);
    if (screen_dx) *screen_dx = cos_360[angle];
    if (screen_dy) *screen_dy = neg_sin_360[angle];
}

/* Exact semantic lift of the thrust-vector acceptance rule at 0x11C70.
 * IMPORTANT: the two velocity pointers are in original Mac vertical/horizontal
 * component order. Math resource #0 is -sin(deg), #1 is cos(deg).
 */
bool tz_apply_player_thrust(float *velocity_vertical, float *velocity_horizontal,
                            float heading_degrees, float maximum_speed,
                            const float neg_sin_360[360], const float cos_360[360]) {
    const int angle = (int)tz_wrap_heading(heading_degrees);
    const float old_speed = sqrtf((*velocity_vertical * *velocity_vertical) +
                                  (*velocity_horizontal * *velocity_horizontal));
    const float new_vertical = *velocity_vertical + neg_sin_360[angle];
    const float new_horizontal = *velocity_horizontal + cos_360[angle];
    const float new_speed = sqrtf((new_vertical * new_vertical) +
                                  (new_horizontal * new_horizontal));

    if (new_speed <= maximum_speed || new_speed < old_speed) {
        *velocity_vertical = new_vertical;
        *velocity_horizontal = new_horizontal;
        return true;
    }
    return false;
}
