#include "thezone_decomp.h"

/* Modern Game resource format reconstructed from PPC 0x00B604 loader and
 * 0x00C68C writer. */
size_t tz_save_expected_size(size_t object_count) {
    return sizeof(TzSaveHeaderPPC32) + object_count * sizeof(TzZoneObjectPPC32);
}

static uint16_t be16(const uint8_t *p) {
    return (uint16_t)(((uint16_t)p[0] << 8) | p[1]);
}

static uint32_t be32(const uint8_t *p) {
    return ((uint32_t)p[0] << 24) | ((uint32_t)p[1] << 16) | ((uint32_t)p[2] << 8) | p[3];
}

bool tz_save_validate_v151(const void *bytes, size_t size, int16_t *object_count_out) {
    if (!bytes || size < sizeof(TzSaveHeaderPPC32)) return false;
    const uint8_t *p = (const uint8_t *)bytes;
    if (be32(p) != TZ_SAVE_MAGIC) return false;
    const int16_t count = (int16_t)be16(p + 64);
    if (count < 0 || count > 80) return false;
    if (size != tz_save_expected_size((size_t)count)) return false;
    if (object_count_out) *object_count_out = count;
    return true;
}

/* Header fields are stored big-endian in the resource. These accessors avoid
 * depending on host endianness. */
static int16_t table_index_be(const int16_t *table, size_t i) {
    const uint8_t *p = (const uint8_t *)&table[i];
    return (int16_t)be16(p);
}

int16_t tz_save_link1_index(const TzSaveHeaderPPC32 *h, size_t object_index) {
    if (!h || object_index >= 80) return -1;
    return table_index_be(h->link1_object_index, object_index);
}

int16_t tz_save_link2_index(const TzSaveHeaderPPC32 *h, size_t object_index) {
    if (!h || object_index >= 80) return -1;
    return table_index_be(h->link2_object_index, object_index);
}
