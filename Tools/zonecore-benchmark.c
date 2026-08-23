#define _POSIX_C_SOURCE 200809L
#include "zone_core.h"

#include <inttypes.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <time.h>

static double monotonic_seconds(void) {
    struct timespec ts;
    if (clock_gettime(CLOCK_MONOTONIC, &ts) != 0) return 0.0;
    return (double)ts.tv_sec + (double)ts.tv_nsec / 1000000000.0;
}

static ZoneInput scripted_input(uint64_t i) {
    ZoneInput in = {0};
    in.turn = ((i / 180u) & 1u) ? -1.0f : 1.0f;
    in.thrust = ((i / 90u) & 1u) ? 1.0f : 0.0f;
    in.fire = (i % 18u) == 0u ? 1u : 0u;
    return in;
}

static void keep_scene_heavy(ZoneGame *game, uint64_t i) {
    /* Reload a late fixed wave periodically so destruction/progression cannot
       turn a long benchmark into an empty-world benchmark. */
    if ((i % 720u) == 0u) {
        zone_game_debug_load_fixed_wave(game, 18);
    }
}

int main(int argc, char **argv) {
    uint64_t iterations = 12000;
    if (argc > 1) {
        char *end = NULL;
        const unsigned long long parsed = strtoull(argv[1], &end, 10);
        if (!end || *end != '\0' || parsed < 120) {
            fprintf(stderr, "usage: %s [iterations>=120]\n", argv[0]);
            return 2;
        }
        iterations = (uint64_t)parsed;
    }

    ZoneGame *game = zone_game_create(UINT32_C(0x5A4F4E45));
    if (!game) {
        fprintf(stderr, "unable to create ZoneGame\n");
        return 1;
    }

    zone_game_debug_load_fixed_wave(game, 18);

    /* Warm caches and the sprite-collision paths before measuring. */
    for (uint64_t i = 0; i < 240; ++i) {
        keep_scene_heavy(game, i);
        zone_game_step(game, scripted_input(i));
        ZoneAudioEvent events[ZONE_MAX_AUDIO_EVENTS];
        (void)zone_game_drain_audio(game, events, ZONE_MAX_AUDIO_EVENTS);
    }

    const double begin = monotonic_seconds();
    for (uint64_t i = 0; i < iterations; ++i) {
        keep_scene_heavy(game, i);
        zone_game_step(game, scripted_input(i));
        ZoneAudioEvent events[ZONE_MAX_AUDIO_EVENTS];
        (void)zone_game_drain_audio(game, events, ZONE_MAX_AUDIO_EVENTS);
    }
    const double elapsed = monotonic_seconds() - begin;
    zone_game_destroy(game);

    if (elapsed <= 0.0) {
        fprintf(stderr, "invalid monotonic benchmark interval\n");
        return 1;
    }

    const double steps_per_second = (double)iterations / elapsed;
    const double microseconds_per_step = elapsed * 1000000.0 / (double)iterations;
    const int candidates[] = {240, 480, 720, 960, 1440};

    printf("ZoneCore headless benchmark\n");
    printf("  iterations:          %" PRIu64 "\n", iterations);
    printf("  elapsed:             %.6f s\n", elapsed);
    printf("  average step cost:   %.3f us\n", microseconds_per_step);
    printf("  measured throughput: %.1f steps/s\n", steps_per_second);
    printf("\nCandidate fixed-rate headroom:\n");
    for (size_t i = 0; i < sizeof(candidates) / sizeof(candidates[0]); ++i) {
        const int hz = candidates[i];
        const double headroom = steps_per_second / (double)hz;
        const double budget_us = 1000000.0 / (double)hz;
        printf("  %4d Hz: %7.2fx headroom (budget %.1f us) %s\n",
               hz, headroom, budget_us, headroom >= 4.0 ? "GOOD" :
               (headroom >= 2.0 ? "MARGINAL" : "NO"));
    }
    printf("\nPolicy: do not promote high-rate dynamics from this number alone;\n");
    printf("require large headroom plus gameplay regression coverage.\n");
    return 0;
}
