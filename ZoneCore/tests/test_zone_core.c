#include "zone_core.h"
#include "thezone_decomp.h"
#include "thezone_types.h"

#include <assert.h>
#include <math.h>
#include <stdio.h>

static ZoneRenderItem find_sprite(const ZoneGame *g, int32_t sprite_id) {
    const int32_t count = zone_game_render_item_count(g);
    for (int32_t i = 0; i < count; ++i) {
        const ZoneRenderItem item = zone_game_render_item_at(g, i);
        if (item.sprite_id == sprite_id) return item;
    }
    return (ZoneRenderItem){0};
}

static void test_muzzle_table(void) {
    const TzMuzzleOffset f0 = tz_ship_muzzle_offset_frame48(0);
    const TzMuzzleOffset f12 = tz_ship_muzzle_offset_frame48(12);
    const TzMuzzleOffset f24 = tz_ship_muzzle_offset_frame48(24);
    const TzMuzzleOffset f36 = tz_ship_muzzle_offset_frame48(36);
    assert(f0.x == 16 && f0.y == 0);
    assert(f12.x == 0 && f12.y == -16);
    assert(f24.x == -16 && f24.y == 0);
    assert(f36.x == 0 && f36.y == 16);

    /* Every canonical 7.5-degree heading must launch generally outward from
       the exact muzzle position for that visible frame. */
    float neg_sin[360], cos_table[360];
    for (int i = 0; i < 360; ++i) {
        const float r = (float)i * 3.14159265358979323846f / 180.0f;
        neg_sin[i] = -sinf(r);
        cos_table[i] = cosf(r);
    }
    for (int frame = 0; frame < 48; ++frame) {
        const float heading = (float)frame * 7.5f;
        const TzMuzzleOffset m = tz_ship_muzzle_offset_frame48((int16_t)frame);
        float dx = 0.0f, dy = 0.0f;
        tz_screen_direction_from_heading(heading, neg_sin, cos_table, &dx, &dy);
        const float dot = dx * (float)m.x + dy * (float)m.y;
        assert(dot > 14.0f);
    }
}

int main(void) {
    test_muzzle_table();

    ZoneGame *g = zone_game_create(0x12345678u);
    assert(g);

    /* Recovered wave-1 population: wave+2 asteroids and one Mother Base in
       both shipping fixed preset tables. */
    assert(zone_game_world_object_count(g) == 4);
    assert(zone_game_count_type(g, TZ_TYPE_ASTE) == 3);
    assert(zone_game_count_type(g, TZ_TYPE_MOTH) == 1);
    ZoneHUDState hud = zone_game_hud(g);
    assert(hud.wave == 1 && hud.bases == 1 && hud.enemies == 0);

    /* Frame 0 visibly points right. Original Math #2 puts the muzzle at +16 X,
       and the projectile must continue rightward in portable screen space. */
    zone_game_debug_set_heading(g, 0.0f);
    const float player_x = zone_game_player_x(g);
    const float player_y = zone_game_player_y(g);
    ZoneInput in = {0};
    in.fire = 1;
    zone_game_step(g, in);
    const ZoneRenderItem shot = find_sprite(g, 148);
    assert(shot.sprite_id == 148);
    assert(shot.x > player_x + 16.0f);
    assert(fabsf(shot.y - player_y) < 0.1f);

    /* Thrust at visible frame 0 must also move right, not down. */
    ZoneGame *thrust = zone_game_create(0x87654321u);
    assert(thrust);
    zone_game_debug_set_heading(thrust, 0.0f);
    const float tx0 = zone_game_player_x(thrust);
    const float ty0 = zone_game_player_y(thrust);
    ZoneInput ti = {0};
    ti.thrust = 1;
    zone_game_step(thrust, ti);
    assert(zone_game_player_x(thrust) > tx0 + 0.20f);
    assert(fabsf(zone_game_player_y(thrust) - ty0) < 0.0001f);

    zone_game_destroy(thrust);
    zone_game_destroy(g);
    puts("ZoneCore deterministic smoke test: PASS");
    puts("48-frame original muzzle-offset regression: PASS");
    puts("Classic Mac V/H -> portable screen X/Y mapping: PASS");
    puts("Recovered professional wave-1 population: PASS");
    return 0;
}
