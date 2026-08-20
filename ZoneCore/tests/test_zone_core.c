#include "zone_core.h"
#include <assert.h>
#include <stdio.h>
int main(void) {
    ZoneGame *g=zone_game_create(0x12345678u); assert(g);
    assert(zone_game_render_item_count(g)>=2);
    ZoneInput in={0}; in.thrust=1;
    for(int i=0;i<30;i++) zone_game_step(g,in);
    float x=zone_game_player_x(g), y=zone_game_player_y(g);
    assert(x!=640.0f/3.0f || y!=480.0f/2.0f);
    in.thrust=0; in.fire=1;
    for(int i=0;i<4;i++) zone_game_step(g,in);
    assert(zone_game_render_item_count(g)>=3);
    ZoneHUDState hud=zone_game_hud(g); assert(hud.wave==1 && hud.shields==100);
    zone_game_destroy(g);
    puts("ZoneCore deterministic smoke test: PASS");
    return 0;
}
