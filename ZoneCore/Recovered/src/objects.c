#include "thezone_decomp.h"

/* PPC 0x016128 common tail of update_object_behavior() (0x014914).
 * The original uses signed 16-bit world coordinates and wraps them to the
 * current zone dimensions after adding fixed-point-ish integer velocity.
 */
static int16_t wrap16(int value, int extent) {
    if (extent <= 0) return (int16_t)value;
    while (value < 0) value += extent;
    while (value >= extent) value -= extent;
    return (int16_t)value;
}

void tz_integrate_wrapped(TzZoneObjectPPC32 *obj, int16_t world_width, int16_t world_height) {
    obj->world_x = wrap16((int)obj->world_x + obj->velocity_x, world_width);
    obj->world_y = wrap16((int)obj->world_y + obj->velocity_y, world_height);
}

/* PPC 0x0107B4 when new_type == 'expl'. The counter order matches the
 * shipping record-stat resources.  Score addition is performed centrally
 * before the object is reconfigured as an explosion.
 */
static const TzKillAward kKillAwards[] = {
    { TZ_TYPE_BEE,  0,  250 },
    { TZ_TYPE_RAID, 1,  200 },
    { TZ_TYPE_SEEK, 2,  300 },
    { TZ_TYPE_ROTO, 3,  250 },
    { TZ_TYPE_SWAR, 4,   30 },
    { TZ_TYPE_MOTO, 5,   50 },
    { TZ_TYPE_BLOO, 6,  150 },
    { TZ_TYPE_ASTE, 7,   20 },
    { TZ_TYPE_STON, 8,   20 },
    { TZ_TYPE_ROCK, 9,   50 },
    { TZ_TYPE_BASE,10, 1500 },
    { TZ_TYPE_MOTH,11,  750 },
};

const TzKillAward *tz_kill_award_for_type(uint32_t type) {
    for (size_t i = 0; i < sizeof(kKillAwards) / sizeof(kKillAwards[0]); i++) {
        if (kKillAwards[i].type == type) return &kKillAwards[i];
    }
    return 0;
}
