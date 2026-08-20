#ifndef THEZONE_TYPES_H
#define THEZONE_TYPES_H

#include <stddef.h>
#include <stdint.h>

#define TZ_FOURCC(a,b,c,d) \
    ((((uint32_t)(uint8_t)(a)) << 24) | (((uint32_t)(uint8_t)(b)) << 16) | \
     (((uint32_t)(uint8_t)(c)) << 8) | ((uint32_t)(uint8_t)(d)))

#define TZ_TYPE_SHIP TZ_FOURCC('s','h','i','p')
#define TZ_TYPE_MINE TZ_FOURCC('m','i','n','e')
#define TZ_TYPE_MOTH TZ_FOURCC('m','o','t','h')
#define TZ_TYPE_BASE TZ_FOURCC('b','a','s','e')
#define TZ_TYPE_BEE  TZ_FOURCC('b','e','e','!')
#define TZ_TYPE_RAID TZ_FOURCC('r','a','i','d')
#define TZ_TYPE_SEEK TZ_FOURCC('s','e','e','k')
#define TZ_TYPE_ROTO TZ_FOURCC('r','o','t','o')
#define TZ_TYPE_SWAR TZ_FOURCC('s','w','a','r')
#define TZ_TYPE_MOTO TZ_FOURCC('m','o','t','o')
#define TZ_TYPE_BLOO TZ_FOURCC('b','l','o','o')
#define TZ_TYPE_ROCK TZ_FOURCC('r','o','c','k')
#define TZ_TYPE_ASTE TZ_FOURCC('a','s','t','e')
#define TZ_TYPE_STON TZ_FOURCC('s','t','o','n')
#define TZ_TYPE_OSCI TZ_FOURCC('o','s','c','i')
#define TZ_TYPE_VELO TZ_FOURCC('v','e','l','o')
#define TZ_TYPE_AMMO TZ_FOURCC('a','m','m','o')
#define TZ_TYPE_BONU TZ_FOURCC('b','o','n','u')
#define TZ_TYPE_EQUI TZ_FOURCC('e','q','u','i')
#define TZ_TYPE_GADG TZ_FOURCC('g','a','d','g')
#define TZ_TYPE_FIRE TZ_FOURCC('f','i','r','e')
#define TZ_TYPE_FAKE TZ_FOURCC('f','a','k','e')
#define TZ_TYPE_EXPL TZ_FOURCC('e','x','p','l')
#define TZ_TYPE_SHOT TZ_FOURCC('s','h','o','t')
#define TZ_SAVE_MAGIC TZ_FOURCC('D','A','P','P')

/*
 * The shipping PPC binary is 32-bit and the original structures use classic
 * 2-byte alignment.  Pointer-valued fields are represented as uint32_t here
 * so the offsets remain identical when this header is compiled on a 64-bit
 * host.  These are layout/reverse-engineering structures, not host pointers.
 */
typedef uint32_t TzPtr32;

#pragma pack(push, 2)
typedef struct TzZoneObjectPPC32 {
    uint32_t type;                  /* +0x00 confirmed FOURCC */
    uint32_t previous_type;         /* +0x04 confirmed by 0x107B4 */
    uint32_t subtype;               /* +0x08 type/child state; semantics partial */
    int16_t screen_x;               /* +0x0C */
    int16_t screen_y;               /* +0x0E */
    int16_t draw_x;                 /* +0x10 */
    int16_t draw_y;                 /* +0x12 */
    int16_t world_x;                /* +0x14 high confidence */
    int16_t world_y;                /* +0x16 high confidence */
    int16_t position_copy_x;        /* +0x18 */
    int16_t position_copy_y;        /* +0x1A */
    int16_t previous_x;             /* +0x1C */
    int16_t previous_y;             /* +0x1E */
    uint8_t unknown_32[4];          /* +0x20 */
    int16_t collision_dx;           /* +0x24 */
    int16_t collision_dy;           /* +0x26 */
    int16_t velocity_x;             /* +0x28 confirmed integration/collision */
    int16_t velocity_y;             /* +0x2A confirmed integration/collision */
    int16_t state_44;               /* +0x2C */
    int16_t state_46;               /* +0x2E */
    int16_t cached_dx;              /* +0x30 */
    int16_t cached_dy;              /* +0x32 */
    int16_t side;                   /* +0x34 confirmed sprite/object extent */
    int16_t orientation;            /* +0x36 heading->frame selector */
    int16_t sprite_frame;           /* +0x38 confirmed renderer index */
    int16_t sprite_frame_count;     /* +0x3A */
    int16_t animation_counter;      /* +0x3C */
    uint8_t unknown_62[4];          /* +0x3E */
    int16_t hit_state;              /* +0x42 used by collision paths */
    int16_t state_68;               /* +0x44 */
    int16_t type_state;             /* +0x46 per-type initial value */
    int16_t counter_72;             /* +0x48 */
    int16_t counter_74;             /* +0x4A */
    int16_t counter_76;             /* +0x4C */
    int16_t counter_78;             /* +0x4E */
    uint8_t unknown_80[4];          /* +0x50 */
    int16_t state_84;               /* +0x54 */
    uint8_t unknown_86[2];          /* +0x56 */
    uint32_t tick_88;               /* +0x58 */
    uint32_t tick_92;               /* +0x5C */
    uint32_t tick_96;               /* +0x60 */
    float velocity_fx;              /* +0x64 continuous motion vector X */
    float velocity_fy;              /* +0x68 continuous motion vector Y */
    float scaled_velocity_fx;       /* +0x6C written by 0xE6F4 */
    float scaled_velocity_fy;       /* +0x70 written by 0xE6F4 */
    float predicted_position_fx;    /* +0x74 written by 0xE6F4 */
    float predicted_position_fy;    /* +0x78 written by 0xE6F4 */
    float heading;                  /* +0x7C confirmed player heading */
    uint8_t active_128;             /* +0x80 active/spatial mode */
    uint8_t flag_129;               /* +0x81 */
    uint8_t flag_130;               /* +0x82 hit/damage state */
    uint8_t flag_131;               /* +0x83 rotor/collision special flag */
    uint8_t thrust_132;             /* +0x84 confirmed player thrust state */
    uint8_t dirty_133;              /* +0x85 render/spatial state */
    TzPtr32 sprite_table;            /* +0x86 (134) */
    TzPtr32 next;                    /* +0x8A (138) */
    TzPtr32 link1;                   /* +0x8E (142), serialized via index table */
    TzPtr32 link2;                   /* +0x92 (146), serialized via index table */
} TzZoneObjectPPC32;

/* Modern v1.5.1 Game resource header.  Unknown regions are deliberately raw. */
typedef struct TzSaveHeaderPPC32 {
    uint32_t magic;                  /* +0x000 'DAPP' */
    uint32_t mac_timestamp;          /* +0x004 */
    uint8_t state_008_063[56];       /* +0x008 */
    int16_t object_count;            /* +0x040 (64) */
    uint8_t state_066_175[110];      /* +0x042 */
    int16_t link1_object_index[80];  /* +0x0B0 (176) */
    int16_t link2_object_index[80];  /* +0x150 (336) */
} TzSaveHeaderPPC32;

/* Resource format used by TheZone Sprites. All integer fields are big-endian on disk. */
typedef struct TzSpriHeaderDisk {
    uint16_t side_be;
    uint16_t area_be;
    uint8_t mask_type;
    uint8_t unused;
} TzSpriHeaderDisk;
#pragma pack(pop)

_Static_assert(sizeof(TzZoneObjectPPC32) == 150, "TheZone object layout must be 150 bytes");
_Static_assert(offsetof(TzZoneObjectPPC32, velocity_x) == 40, "velocity_x offset");
_Static_assert(offsetof(TzZoneObjectPPC32, side) == 52, "side offset");
_Static_assert(offsetof(TzZoneObjectPPC32, sprite_frame) == 56, "sprite frame offset");
_Static_assert(offsetof(TzZoneObjectPPC32, heading) == 124, "heading offset");
_Static_assert(offsetof(TzZoneObjectPPC32, sprite_table) == 134, "sprite table offset");
_Static_assert(offsetof(TzZoneObjectPPC32, link1) == 142, "link1 offset");
_Static_assert(offsetof(TzZoneObjectPPC32, link2) == 146, "link2 offset");
_Static_assert(sizeof(TzSaveHeaderPPC32) == 496, "TheZone save header must be 496 bytes");
_Static_assert(offsetof(TzSaveHeaderPPC32, object_count) == 64, "save object_count offset");
_Static_assert(offsetof(TzSaveHeaderPPC32, link1_object_index) == 176, "save link1 table offset");
_Static_assert(offsetof(TzSaveHeaderPPC32, link2_object_index) == 336, "save link2 table offset");

#endif
