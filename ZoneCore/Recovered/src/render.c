#include "thezone_decomp.h"

/* PPC 0x0048F0, called by wrapper 0x00488C.
 * The original native PPC renderer increments the source for every pixel and
 * writes only non-zero palette indices to the destination framebuffer.
 */
void tz_blit_sprite_transparent(const TzSpriteView *sprite, uint8_t *dst, size_t dst_row_bytes) {
    const uint8_t *src = sprite->pixels;
    for (uint16_t y = 0; y < sprite->side; y++) {
        for (uint16_t x = 0; x < sprite->side; x++) {
            const uint8_t pixel = *src++;
            if (pixel != 0) {
                dst[x] = pixel;
            }
        }
        dst += dst_row_bytes;
    }
}

/* Semantic lift of PPC 0x0041E4 as used by 0x01708C.
 * 0x01708C first uses QuickDraw SectRect as broad phase, then obtains each
 * current Spri frame and performs this non-zero/non-zero pixel overlap test.
 */
bool tz_sprite_overlap_exact(const TzSpriteView *a, int ax, int ay,
                             const TzSpriteView *b, int bx, int by) {
    const int left   = ax > bx ? ax : bx;
    const int top    = ay > by ? ay : by;
    const int aright = ax + (int)a->side;
    const int bright = bx + (int)b->side;
    const int abot   = ay + (int)a->side;
    const int bbot   = by + (int)b->side;
    const int right  = aright < bright ? aright : bright;
    const int bottom = abot < bbot ? abot : bbot;

    if (left >= right || top >= bottom) {
        return false;
    }

    for (int y = top; y < bottom; y++) {
        const size_t arow = (size_t)(y - ay) * a->side;
        const size_t brow = (size_t)(y - by) * b->side;
        for (int x = left; x < right; x++) {
            const uint8_t ap = a->pixels[arow + (size_t)(x - ax)];
            const uint8_t bp = b->pixels[brow + (size_t)(x - bx)];
            if (ap != 0 && bp != 0) {
                return true;
            }
        }
    }
    return false;
}
