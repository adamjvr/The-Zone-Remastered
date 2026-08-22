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


/* Progression constants and pickup effects recovered from the native PPC
 * collision/pickup dispatcher:
 *   new game 0x128F0: maximum speed = 25.0, ammo capacity = 2
 *   velo     0x17908: +5.0 maximum speed while below 50.0
 *   ammo     0x178E0: +1 simultaneous shot capacity while below 10
 *   osci     0x178B8: restore shields to 100 if below 100
 */
float tz_initial_player_max_speed(void) {
    return 25.0f;
}

float tz_velocity_module_apply(float maximum_speed) {
    if (maximum_speed < 50.0f) {
        maximum_speed += 5.0f;
        if (maximum_speed > 50.0f) maximum_speed = 50.0f;
    }
    return maximum_speed;
}

int16_t tz_ammo_loader_apply(int16_t ammo_capacity) {
    if (ammo_capacity < 10) ++ammo_capacity;
    return ammo_capacity;
}

int16_t tz_oscilloscope_apply(int16_t shields) {
    return shields < 100 ? 100 : shields;
}

/* Barrel selector at PPC 0x1A3D8.  The two counters are the upgrade-state
 * values tested by the original routine.  rock_special models the Big Rock
 * callsite: if the selector chooses a gadget there, one additional random bit
 * converts that result to a bonus/equipment barrel.
 */
uint32_t tz_select_barrel_type(unsigned wave, int16_t upgrade_a, int16_t upgrade_b,
                               uint16_t random_0_100, bool rock_special,
                               uint16_t random_bit) {
    const bool low_upgrades = upgrade_a < 2 && upgrade_b < 2;
    uint32_t selected = TZ_TYPE_BONU;

    if (wave < 10) {
        if (low_upgrades) {
            selected = random_0_100 < 70 ? TZ_TYPE_EQUI : TZ_TYPE_BONU;
        } else {
            selected = random_0_100 < 60 ? TZ_TYPE_BONU : TZ_TYPE_EQUI;
        }
    } else {
        if (low_upgrades) {
            if (random_0_100 < 50) selected = TZ_TYPE_EQUI;
            else if (random_0_100 < 80) selected = TZ_TYPE_GADG;
            else selected = TZ_TYPE_BONU;
        } else {
            if (random_0_100 < 35) selected = TZ_TYPE_EQUI;
            else if (random_0_100 < 70) selected = TZ_TYPE_BONU;
            else selected = TZ_TYPE_GADG;
        }
    }

    if (rock_special && selected == TZ_TYPE_GADG) {
        selected = (random_bit & 1u) ? TZ_TYPE_BONU : TZ_TYPE_EQUI;
    }
    return selected;
}
