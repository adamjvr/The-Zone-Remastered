#include "thezone_decomp.h"

/* PPC 0x307C initializes these thresholds from the Preferences normal_play
 * byte.  PPC 0x192FC accumulates damage in object->state_68 and compares
 * against the per-type threshold.  Shot collision at 0x172DC uses
 * (weapon_damage_level + 1), i.e. ordinary projectile damage 1..4.
 */
TzDamageThresholds tz_damage_thresholds(bool professional) {
    if (professional) {
        return (TzDamageThresholds){
            .moth=40, .base=25, .raid=8, .bee=5,
            .roto=20, .seek=15, .bloo=5,
        };
    }
    return (TzDamageThresholds){
        .moth=20, .base=14, .raid=5, .bee=4,
        .roto=10, .seek=8, .bloo=4,
    };
}

int16_t tz_damage_threshold_for_type(uint32_t type, const TzDamageThresholds *t) {
    switch (type) {
        case TZ_TYPE_MOTH: return t->moth;
        case TZ_TYPE_BASE: return t->base;
        case TZ_TYPE_RAID: return t->raid;
        case TZ_TYPE_BEE:  return t->bee;
        case TZ_TYPE_ROTO: return t->roto;
        case TZ_TYPE_SEEK: return t->seek;
        case TZ_TYPE_BLOO: return t->bloo;
        case TZ_TYPE_ROCK: return 4; /* literal in 0x192FC */
        case TZ_TYPE_ASTE:
        case TZ_TYPE_STON:
        case TZ_TYPE_SWAR:
        case TZ_TYPE_MOTO: return 1;
        default: return 0;
    }
}

int16_t tz_shot_damage_from_upgrade(int16_t weapon_damage_level) {
    return (int16_t)(weapon_damage_level + 1); /* 0..3 -> 1..4 */
}
