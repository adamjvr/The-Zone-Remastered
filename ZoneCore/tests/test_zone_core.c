#include "zone_core.h"
#include "thezone_decomp.h"

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

int main(void) {
    ZoneGame *g = zone_game_create(0x12345678u);
    assert(g);
    assert(zone_game_render_item_count(g) >= 2);

    /* Recovered orientation contract: heading 0 is frame 0 and its vector is
       (-sin(0), cos(0)) = (0,+1). */
    assert(tz_heading_to_frame48(0.0f) == 0);
    assert(tz_heading_to_frame48(359.9f) == 47);

    const float x0 = zone_game_player_x(g);
    const float y0 = zone_game_player_y(g);
    ZoneInput in = {0};
    in.thrust = 1;
    zone_game_step(g, in);
    const float x1 = zone_game_player_x(g);
    const float y1 = zone_game_player_y(g);
    assert(fabsf(x1 - x0) < 0.0001f);
    assert(y1 > y0 + 0.20f);

    /* A heading-0 shot must leave the ship in the same recovered +Y basis. */
    in.thrust = 0;
    in.fire = 1;
    zone_game_step(g, in);
    const ZoneRenderItem shot = find_sprite(g, 148);
    assert(shot.sprite_id == 148);
    assert(fabsf(shot.x - zone_game_player_x(g)) < 0.01f);
    assert(shot.y > zone_game_player_y(g));

    ZoneHUDState hud = zone_game_hud(g);
    assert(hud.wave == 1 && hud.shields == 100);

    zone_game_destroy(g);
    puts("ZoneCore deterministic smoke test: PASS");
    puts("Recovered heading/thrust/projectile basis regression: PASS");
    return 0;
}
