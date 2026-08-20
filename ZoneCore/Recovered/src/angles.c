#include "thezone_decomp.h"

/* App initialization builds the table behind TOC+10908 by starting at 90 and
 * subtracting one for each QuickDraw PtToAngle result, wrapping at zero.
 * Therefore 0xE7DC's final operation is exactly this transform.
 */
int16_t tz_map_quickdraw_angle(int16_t quickdraw_angle) {
    int a = (90 - quickdraw_angle) % 360;
    if (a < 0) a += 360;
    return (int16_t)a;
}
