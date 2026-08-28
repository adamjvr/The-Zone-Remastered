#include "zone_core.h"

#include <stdio.h>
#include <stdlib.h>

int main(int argc, char **argv) {
    if (argc != 2) {
        fprintf(stderr, "usage: zone-jump-harness-test <expected-zone>\n");
        return 2;
    }
    const int expected = atoi(argv[1]);
    ZoneGame *g = zone_game_create(0x5A0E7E57u);
    if (!g) return 3;
    const int actual = zone_game_hud(g).wave;
    zone_game_destroy(g);
    if (actual != expected) {
        fprintf(stderr, "zone jump mismatch: expected=%d actual=%d\n", expected, actual);
        return 1;
    }
    return 0;
}
