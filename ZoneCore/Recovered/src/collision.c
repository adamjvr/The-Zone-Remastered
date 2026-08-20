#include "thezone_decomp.h"

/* Exact small helpers identified at the tail of the collision module. */
void tz_swap_fixed_velocity(TzZoneObjectPPC32 *a, TzZoneObjectPPC32 *b) { /* PPC 0x019D1C */
    int16_t t = a->velocity_x; a->velocity_x = b->velocity_x; b->velocity_x = t;
    t = a->velocity_y; a->velocity_y = b->velocity_y; b->velocity_y = t;
}

void tz_swap_float_velocity(TzZoneObjectPPC32 *a, TzZoneObjectPPC32 *b) { /* PPC 0x019DD8 */
    float t = a->velocity_fx; a->velocity_fx = b->velocity_fx; b->velocity_fx = t;
    t = a->velocity_fy; a->velocity_fy = b->velocity_fy; b->velocity_fy = t;
}

/* The full response dispatcher is PPC 0x0181A4..0x0192FC.  Its primary
 * type-B dispatch has been extracted mechanically to
 * tables/collision-primary-dispatch.csv. Nested pair cases remain represented
 * by their original addresses in the table/notes until lifted one-by-one. */
