#include "zone_core.h"
#include "thezone_decomp.h"
#include "thezone_types.h"

#include <assert.h>
#include <math.h>
#include <stdio.h>

static int nearly(float a, float b) {
    return fabsf(a - b) < 0.0001f;
}

static ZoneRenderItem find_sprite(const ZoneGame *g, int32_t sprite_id) {
    const int32_t count = zone_game_render_item_count(g);
    for (int32_t i = 0; i < count; ++i) {
        const ZoneRenderItem item = zone_game_render_item_at(g, i);
        if (item.sprite_id == sprite_id) return item;
    }
    return (ZoneRenderItem){0};
}

static void park_wave1_except(ZoneGame *g, int32_t keep_a, int32_t keep_b) {
    const float positions[4][2] = {{80, 80}, {560, 80}, {80, 400}, {560, 400}};
    for (int32_t i = 0; i < 4; ++i) {
        if (i == keep_a || i == keep_b) continue;
        zone_game_debug_set_world_state(g, i, positions[i][0], positions[i][1], 0, 0, 0);
    }
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
        assert(dx * (float)m.x + dy * (float)m.y > 14.0f);
    }
}

static void test_recovered_impact_damage(void) {
    assert(tz_player_impact_damage(TZ_TYPE_ASTE, 10.0f, 5.0f, 1.0f) == 3);
    assert(tz_player_impact_damage(TZ_TYPE_STON, 12.0f, 18.0f, 1.0f) == 5);
    assert(tz_player_impact_damage(TZ_TYPE_ROCK, 100.0f, 100.0f, 1.0f) == 30);
    assert(tz_player_impact_damage(TZ_TYPE_ROCK, 100.0f, 100.0f, 2.0f) == 15);
    assert(tz_player_impact_damage(TZ_TYPE_RAID, 100.0f, 100.0f, 1.0f) == 20);
    assert(tz_player_impact_damage(TZ_TYPE_BEE, 100.0f, 100.0f, 1.0f) == 20);
    assert(tz_player_impact_damage(TZ_TYPE_ROTO, 100.0f, 100.0f, 1.0f) == 8);
    assert(tz_player_impact_damage(TZ_TYPE_MOTH, 10.0f, 10.0f, 1.0f) == 0);
    assert(tz_player_base_impact_damage(12.0f, 1.0f) == 9);
    assert(tz_player_base_impact_damage(100.0f, 1.0f) == 30);
}

static void test_player_asteroid_collision(void) {
    ZoneGame *g = zone_game_create(0xC0111DEu);
    assert(g);
    zone_game_debug_set_heading(g, 0.0f);
    park_wave1_except(g, 0, -1);
    zone_game_debug_set_player_state(g, 300.0f, 240.0f, 10.0f, 0.0f);
    zone_game_debug_set_world_state(g, 0, 300.0f, 240.0f, 5.0f, 0.0f, 0);

    zone_game_step(g, (ZoneInput){0});
    ZoneDebugBodyState ship = zone_game_debug_player_state(g);
    ZoneDebugBodyState aste = zone_game_debug_world_state(g, 0);
    ZoneHUDState hud = zone_game_hud(g);
    assert(nearly(ship.vx, 5.0f) && nearly(ship.vy, 0.0f));
    assert(nearly(aste.vx, 10.0f) && nearly(aste.vy, 0.0f));
    assert(hud.shields == 97); /* trunc((10 + 5) / 5) */

    /* They remain overlapped on the next tick, but one physical contact must
       not apply the damage again or swap the velocities back. */
    zone_game_step(g, (ZoneInput){0});
    ship = zone_game_debug_player_state(g);
    aste = zone_game_debug_world_state(g, 0);
    hud = zone_game_hud(g);
    assert(nearly(ship.vx, 5.0f));
    assert(nearly(aste.vx, 10.0f));
    assert(hud.shields == 97);
    zone_game_destroy(g);
}

static void test_player_mother_base_collision(void) {
    ZoneGame *g = zone_game_create(0xBA5EC011u);
    assert(g);
    park_wave1_except(g, 3, -1);
    zone_game_debug_set_heading(g, 0.0f);
    zone_game_debug_set_player_state(g, 300.0f, 240.0f, 12.0f, 0.0f);
    zone_game_debug_set_world_state(g, 3, 300.0f, 240.0f, 0.0f, 0.0f, 0);

    zone_game_step(g, (ZoneInput){0});
    const ZoneDebugBodyState ship = zone_game_debug_player_state(g);
    const ZoneDebugBodyState moth = zone_game_debug_world_state(g, 3);
    const ZoneHUDState hud = zone_game_hud(g);
    assert(nearly(ship.vx, 0.0f));
    assert(nearly(moth.vx, 12.0f));
    assert(hud.shields == 91); /* trunc(12 * 0.75) */
    zone_game_destroy(g);
}

static void test_world_body_exchange_latch(void) {
    ZoneGame *g = zone_game_create(0xB00CEu);
    assert(g);
    zone_game_debug_set_player_state(g, 40.0f, 40.0f, 0.0f, 0.0f);
    park_wave1_except(g, 0, 1);
    zone_game_debug_set_world_state(g, 0, 300.0f, 240.0f, 4.0f, 0.0f, 0);
    zone_game_debug_set_world_state(g, 1, 300.0f, 240.0f, -2.0f, 0.0f, 0);

    zone_game_step(g, (ZoneInput){0});
    ZoneDebugBodyState a = zone_game_debug_world_state(g, 0);
    ZoneDebugBodyState b = zone_game_debug_world_state(g, 1);
    assert(nearly(a.vx, -2.0f));
    assert(nearly(b.vx, 4.0f));

    zone_game_step(g, (ZoneInput){0});
    a = zone_game_debug_world_state(g, 0);
    b = zone_game_debug_world_state(g, 1);
    assert(nearly(a.vx, -2.0f));
    assert(nearly(b.vx, 4.0f));
    zone_game_destroy(g);
}

int main(void) {
    test_muzzle_table();
    test_recovered_impact_damage();

    ZoneGame *g = zone_game_create(0x12345678u);
    assert(g);
    assert(zone_game_world_object_count(g) == 4);
    assert(zone_game_count_type(g, TZ_TYPE_ASTE) == 3);
    assert(zone_game_count_type(g, TZ_TYPE_MOTH) == 1);
    ZoneHUDState hud = zone_game_hud(g);
    assert(hud.wave == 1 && hud.bases == 1 && hud.enemies == 0);

    zone_game_debug_set_heading(g, 0.0f);
    park_wave1_except(g, -1, -1);
    const float player_x = zone_game_player_x(g);
    const float player_y = zone_game_player_y(g);
    ZoneInput in = {0};
    in.fire = 1;
    zone_game_step(g, in);
    const ZoneRenderItem shot = find_sprite(g, 148);
    assert(shot.sprite_id == 148);
    assert(shot.x > player_x + 16.0f);
    assert(fabsf(shot.y - player_y) < 0.1f);
    zone_game_destroy(g);

    ZoneGame *thrust = zone_game_create(0x87654321u);
    assert(thrust);
    park_wave1_except(thrust, -1, -1);
    zone_game_debug_set_heading(thrust, 0.0f);
    const float tx0 = zone_game_player_x(thrust);
    const float ty0 = zone_game_player_y(thrust);
    ZoneInput ti = {0};
    ti.thrust = 1;
    zone_game_step(thrust, ti);
    assert(zone_game_player_x(thrust) > tx0 + 0.20f);
    assert(fabsf(zone_game_player_y(thrust) - ty0) < 0.0001f);
    zone_game_destroy(thrust);

    test_player_asteroid_collision();
    test_player_mother_base_collision();
    test_world_body_exchange_latch();

    puts("ZoneCore deterministic smoke test: PASS");
    puts("48-frame original muzzle-offset regression: PASS");
    puts("Recovered player-impact damage tables: PASS");
    puts("Player/object momentum exchange + contact latch: PASS");
    puts("Mother Base collision transfer: PASS");
    puts("Wave-1 world/body collision exchange: PASS");
    return 0;
}
