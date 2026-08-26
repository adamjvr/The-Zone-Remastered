#include "zone_core.h"
#include "thezone_types.h"

#include <assert.h>
#include <math.h>
#include <stdio.h>

static int nearly(float a, float b) { return fabsf(a - b) < 0.001f; }

int main(void) {
    assert(ZONE_PLAYFIELD_WIDTH == 528);
    assert(ZONE_PLAYFIELD_HEIGHT == 480);
    assert(ZONE_RADAR_WIDTH == 110);
    assert(ZONE_WORLD_EXTENT == 1056);

    ZoneGame *g = zone_game_create(0x111u);
    assert(g);
    assert(nearly(zone_game_player_x(g), 528.0f));
    assert(nearly(zone_game_player_y(g), 528.0f));
    assert(nearly(zone_game_debug_camera_left(g), 264.0f));
    assert(nearly(zone_game_debug_camera_top(g), 288.0f));

    const int32_t visible = zone_game_debug_spawn_world(
        g, TZ_TYPE_SEEK, 628.0f, 528.0f, 0.0f, 0.0f);
    assert(visible >= 0);
    ZoneDebugSpatialState s = zone_game_debug_world_spatial_state(g, visible);
    assert(s.active_128 == 1);
    assert(s.radar_129 == 1);
    assert(nearly(s.screen_x, 364.0f));
    assert(nearly(s.screen_y, 240.0f));
    assert(s.radar_x >= ZONE_PLAYFIELD_WIDTH + 1);
    assert(s.radar_x <= ZONE_PLAYFIELD_WIDTH + ZONE_RADAR_WIDTH);
    assert(s.radar_y >= 1 && s.radar_y <= ZONE_RADAR_WIDTH);

    /* Move across the torus seam: projection must choose the short path. */
    zone_game_debug_set_player_state(g, 20.0f, 20.0f, 0.0f, 0.0f);
    zone_game_debug_set_world_state(g, visible, 1040.0f, 20.0f, 0.0f, 0.0f, 0);
    s = zone_game_debug_world_spatial_state(g, visible);
    assert(s.active_128 == 1);
    assert(nearly(s.screen_x, (float)ZONE_PLAYFIELD_CENTER_X - 36.0f));
    assert(nearly(s.screen_y, (float)ZONE_PLAYFIELD_CENTER_Y));

    zone_game_destroy(g);
    puts("Milestone 1.11 spatial regression: PASS");
    return 0;
}
