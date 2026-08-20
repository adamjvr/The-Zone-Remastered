#include "thezone_decomp.h"

/* Static portions of PPC 0x107B4 (reconfigure/transform object).
 * sprite_table_toc_offset identifies the original r2-relative global that
 * holds the sprite-table pointer.  Dynamic types (expl/fake) are intentionally
 * excluded from this table and are documented below.
 */
static const TzObjectInitSpec kObjectInitSpecs[] = {
    {TZ_TYPE_SHIP, 10912, 48, 32, 0,   0, false},
    {TZ_TYPE_SHOT, 10964,  1,  4, 0,   0, false},
    {TZ_TYPE_FIRE, 10964,  1,  4, 0,   0, false},
    {TZ_TYPE_OSCI, 10940, 30, 24, 0,   0, false},
    {TZ_TYPE_VELO, 10948, 24, 24, 0,   0, false},
    {TZ_TYPE_AMMO, 10944, 32, 24, 0,   0, false},
    {TZ_TYPE_BONU, 10952, 30, 16, 1,  23, true},
    {TZ_TYPE_EQUI, 10956, 30, 16, 1, 228, true},
    {TZ_TYPE_GADG, 10960, 30, 16, 1,  31, true},
    {TZ_TYPE_ASTE, 10992, 24, 32, 1,   0, false},
    {TZ_TYPE_STON, 11000, 16, 24, 1, 251, true},
    {TZ_TYPE_ROCK, 10996, 30, 48, 1,   0, false},
    {TZ_TYPE_SWAR, 11004, 24, 16, 1, 204, true},
    {TZ_TYPE_BLOO, 11012, 24, 16, 1, 204, true},
    {TZ_TYPE_MOTO, 11008, 24, 16, 1, 218, true},
    {TZ_TYPE_BEE,  11016, 24, 32, 1, 180, true},
    {TZ_TYPE_RAID, 11020, 24, 32, 1,   0, false},
    {TZ_TYPE_SEEK, 11024, 24, 32, 1, 192, true},
    {TZ_TYPE_ROTO, 11028, 24, 32, 1, 156, true},
    {TZ_TYPE_MOTH, 10976,  8, 48, 0,   0, false},
    {TZ_TYPE_BASE, 10980,  8, 48, 0,   0, false},
};

const TzObjectInitSpec *tz_object_init_spec(uint32_t type) {
    for (size_t i = 0; i < sizeof(kObjectInitSpecs) / sizeof(kObjectInitSpecs[0]); ++i) {
        if (kObjectInitSpecs[i].type == type) return &kObjectInitSpecs[i];
    }
    return 0;
}

/* Special cases in 0x107B4:
 *
 * ship: frame=orientation and heading=orientation*7.5 degrees.
 * shot: shared projectile sprites at TOC+10964, side 4. Initial cached vector
 *       is 15.0 * (-sin, cos) at the orientation angle.
 * fire: same projectile sprite table/side, but frame 4 and cached vector is
 *       11.25 * (-sin, cos).
 * expl: chooses an explosion bank from the object's PREVIOUS side/type.  A
 *       destroyed ship and destroyed mine use the 20-frame bank at +10920;
 *       other 32/16/48/24-pixel objects use 11-frame banks +10924/+10928/
 *       +10932/+10936 respectively.  Old collision_dx/dy are preserved into
 *       state_44/state_46.
 * fake: has no sprite table; frame is copied from orientation.
 */
