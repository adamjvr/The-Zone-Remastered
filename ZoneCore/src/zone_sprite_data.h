#ifndef ZONE_SPRITE_DATA_H
#define ZONE_SPRITE_DATA_H
#include <stddef.h>
#include <stdint.h>
typedef struct ZoneSpritePixels {
    int32_t sprite_id;
    uint16_t side;
    const uint8_t *pixels;
} ZoneSpritePixels;
const ZoneSpritePixels *zone_sprite_pixels(int32_t sprite_id);
size_t zone_sprite_count(void);
#endif
