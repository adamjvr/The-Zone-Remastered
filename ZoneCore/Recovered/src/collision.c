#include "thezone_decomp.h"

#include <math.h>

/* Exact small helpers identified at the tail of the collision module. */
void tz_swap_fixed_velocity(TzZoneObjectPPC32 *a, TzZoneObjectPPC32 *b) { /* PPC 0x019D1C */
    int16_t t = a->velocity_x; a->velocity_x = b->velocity_x; b->velocity_x = t;
    t = a->velocity_y; a->velocity_y = b->velocity_y; b->velocity_y = t;
}

void tz_swap_float_velocity(TzZoneObjectPPC32 *a, TzZoneObjectPPC32 *b) { /* PPC 0x019DD8 */
    float t = a->velocity_fx; a->velocity_fx = b->velocity_fx; b->velocity_fx = t;
    t = a->velocity_fy; a->velocity_fy = b->velocity_fy; b->velocity_fy = t;
}

/* Portable equivalent of the velocity exchange semantics used throughout
 * PPC 0x181A4 and by the ship/base collision path at 0x174E8.  The original
 * has separate fixed and float representations; ZoneCore stores both actors
 * in the same screen-space units, so the semantic operation is a direct swap.
 */
void tz_swap_screen_velocity(float *a_vx, float *a_vy, float *b_vx, float *b_vy) {
    float t = *a_vx; *a_vx = *b_vx; *b_vx = t;
    t = *a_vy; *a_vy = *b_vy; *b_vy = t;
}

/* PPC 0x19DFC player-vs-object impact damage.
 *
 * The original routine measures the ship speed before the velocity exchange
 * and again after it, sums those two magnitudes, then applies a type-specific
 * divisor.  Because most ordinary collisions exchange the ship's velocity
 * with the collider, this is equivalent to using the pre-impact speed of both
 * bodies in the portable model.  The integer result is capped by collider
 * type and finally divided by the current shield-strength multiplier.
 *
 * Types absent from this switch do not take shield damage through 0x19DFC;
 * some (notably moth/base) have dedicated collision paths.
 */
int16_t tz_player_impact_damage(uint32_t collider_type,
                                float ship_speed_before,
                                float ship_speed_after,
                                float shield_strength) {
    int divisor = 0;
    int cap = 8;

    switch (collider_type) {
        case TZ_TYPE_STON: divisor = 6; break;
        case TZ_TYPE_BLOO:
        case TZ_TYPE_ASTE:
        case TZ_TYPE_SWAR: divisor = 5; break;
        case TZ_TYPE_RAID:
        case TZ_TYPE_MOTO:
        case TZ_TYPE_SEEK: divisor = 4; break;
        case TZ_TYPE_BEE:
        case TZ_TYPE_ROTO:
        case TZ_TYPE_ROCK: divisor = 3; break;
        default: return 0;
    }

    if (collider_type == TZ_TYPE_ROCK) {
        cap = 30;
    } else if (collider_type == TZ_TYPE_RAID ||
               collider_type == TZ_TYPE_BEE ||
               collider_type == TZ_TYPE_SEEK) {
        cap = 20;
    }

    if (shield_strength <= 0.0f) shield_strength = 1.0f;
    const float speed_sum = fmaxf(0.0f, ship_speed_before) + fmaxf(0.0f, ship_speed_after);
    int damage = (int)(speed_sum / (float)divisor); /* PPC fctiwz: truncate */
    if (damage > cap) damage = cap;
    damage = (int)((float)damage / shield_strength); /* second PPC fctiwz */
    if (damage < 0) damage = 0;
    return (int16_t)damage;
}

/* PPC 0x174E8 dedicated ship-vs-Mother-Base/HQ collision damage.
 * The shipping constant at packed-data +3080 is exactly 0.75.  Damage is
 * trunc(shipSpeed * 0.75 / shieldStrength), capped at 30.  That routine then
 * exchanges the base's and ship's continuous velocity vectors, which is why
 * the manual warns players to keep bases still.
 */
int16_t tz_player_base_impact_damage(float ship_speed_before, float shield_strength) {
    if (shield_strength <= 0.0f) shield_strength = 1.0f;
    int damage = (int)((fmaxf(0.0f, ship_speed_before) * 0.75f) / shield_strength);
    if (damage > 30) damage = 30;
    if (damage < 0) damage = 0;
    return (int16_t)damage;
}
