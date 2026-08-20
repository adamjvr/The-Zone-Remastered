#include "thezone_decomp.h"

/* PPC 0x13328. Waves 1..18 use two fixed case tables selected by the
 * Preferences "normal_play" byte.  Later waves are procedurally generated.
 * The fields below retain the behavior visible in the spawn loops:
 *  - moth/base/raid/seek are direct initial spawn counts.
 *  - rotor_link_count: first N mothers receive a linked Rotor.
 *  - bloo_subtype_quota: first N qualifying base/mother subtype assignments
 *    are 'bloo'; remaining mother/base subtype tags become 'swar'/'moto'.
 *  - mobile_moth_quota: first N mothers receive object state_84 = 1; the
 *    behavior routine strongly suggests this enables the rare mobile/hunting
 *    Mother Base behavior described by the manual.
 *  - bee_limit: global TOC+12382.  0x16504 compares a base/mother's counter_76
 *    against this value before allowing it to request/spawn another Bee.
 */
static const TzWavePreset kProfessional[18] = {
    {1,0,0,0,0,0,0,1},{2,0,0,0,0,0,0,1},{3,0,0,0,0,0,0,1},
    {2,1,0,0,0,0,0,1},{2,2,1,0,1,1,0,1},{4,0,1,1,1,1,0,2},
    {0,3,1,1,0,0,0,0},{4,2,2,1,2,1,0,2},{6,0,2,1,3,2,0,2},
    {5,1,2,1,2,0,1,2},{3,3,2,1,1,1,1,2},{3,3,3,2,3,1,2,2},
    {8,0,3,2,3,2,2,3},{3,3,3,2,3,3,2,3},{0,6,4,2,0,1,0,0},
    {0,7,4,3,0,2,0,0},{7,1,4,4,4,3,2,4},{1,7,5,4,1,2,1,6},
};

static const TzWavePreset kBeginner[18] = {
    {1,0,0,0,0,0,0,1},{2,0,0,0,0,0,0,1},{3,0,0,0,0,0,0,1},
    {4,0,0,0,0,0,0,1},{5,0,1,0,0,1,0,1},{4,1,1,0,1,1,0,2},
    {4,1,1,1,0,0,0,2},{4,1,2,1,2,1,0,2},{5,0,1,1,2,1,0,2},
    {5,1,2,1,2,0,0,2},{4,2,2,1,1,1,0,2},{4,2,2,2,2,1,0,2},
    {6,0,2,2,2,2,0,2},{6,1,2,2,3,2,0,2},{5,2,3,2,0,1,1,3},
    {7,0,3,2,0,2,1,3},{7,1,3,3,2,3,1,3},{5,3,4,4,1,2,1,4},
};

const TzWavePreset *tz_wave_preset(bool professional, unsigned wave) {
    if (wave < 1 || wave > 18) return 0;
    return professional ? &kProfessional[wave - 1] : &kBeginner[wave - 1];
}

unsigned tz_initial_asteroid_count(unsigned wave) {
    unsigned count = wave + 2;
    return count > 14 ? 14 : count;
}
