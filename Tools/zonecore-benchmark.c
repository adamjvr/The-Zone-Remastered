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

static void drain(ZoneGame *game) {
    ZoneAudioEvent events[ZONE_MAX_AUDIO_EVENTS];
    (void)zone_game_drain_audio(game, events, ZONE_MAX_AUDIO_EVENTS);
}

static void keep_scene_heavy(ZoneGame *game, uint64_t i) {
    if ((i % 720u) == 0u) zone_game_debug_load_fixed_wave(game, 18);
}

static double benchmark_classic(uint64_t intervals) {
    ZoneGame *game = zone_game_create(UINT32_C(0x5A4F4E45));
    if (!game) return 0.0;
    zone_game_debug_load_fixed_wave(game, 18);
    for (uint64_t i = 0; i < 240; ++i) {
        keep_scene_heavy(game, i);
        zone_game_step(game, scripted_input(i));
        drain(game);
    }
    const double begin = monotonic_seconds();
    for (uint64_t i = 0; i < intervals; ++i) {
        keep_scene_heavy(game, i);
        zone_game_step(game, scripted_input(i));
        drain(game);
    }
    const double elapsed = monotonic_seconds() - begin;
    zone_game_destroy(game);
    return elapsed;
}

static double benchmark_master(uint64_t intervals) {
    ZoneGame *game = zone_game_create(UINT32_C(0x5A4F4E45));
    if (!game) return 0.0;
    zone_game_debug_load_fixed_wave(game, 18);
    for (uint64_t i = 0; i < 240; ++i) {
        keep_scene_heavy(game, i);
        (void)zone_game_advance_master_ticks(
            game, scripted_input(i), ZONE_MASTER_TICKS_PER_CLASSIC_STEP);
        drain(game);
    }
    const double begin = monotonic_seconds();
    for (uint64_t i = 0; i < intervals; ++i) {
        keep_scene_heavy(game, i);
        (void)zone_game_advance_master_ticks(
            game, scripted_input(i), ZONE_MASTER_TICKS_PER_CLASSIC_STEP);
        drain(game);
    }
    const double elapsed = monotonic_seconds() - begin;
    zone_game_destroy(game);
    return elapsed;
}

int main(int argc, char **argv) {
    uint64_t intervals = 12000;
    if (argc > 1) {
        char *end = NULL;
        const unsigned long long parsed = strtoull(argv[1], &end, 10);
        if (!end || *end != '\0' || parsed < 120) {
            fprintf(stderr, "usage: %s [classic-intervals>=120]\n", argv[0]);
            return 2;
        }
        intervals = (uint64_t)parsed;
    }

    const double classic_elapsed = benchmark_classic(intervals);
    const double master_elapsed = benchmark_master(intervals);
    if (classic_elapsed <= 0.0 || master_elapsed <= 0.0) {
        fprintf(stderr, "invalid monotonic benchmark interval\n");
        return 1;
    }

    const double classic_us = classic_elapsed * 1000000.0 / (double)intervals;
    const double native_interval_us = master_elapsed * 1000000.0 / (double)intervals;
    const double master_ticks = (double)intervals * (double)ZONE_MASTER_TICKS_PER_CLASSIC_STEP;
    const double master_tick_us = master_elapsed * 1000000.0 / master_ticks;
    const double master_ticks_per_second = master_ticks / master_elapsed;
    const double headroom_720 = master_ticks_per_second / (double)ZONE_MASTER_HZ;

    printf("ZoneCore Classic/native-dynamics benchmark\n");
    printf("  Classic intervals:            %" PRIu64 "\n", intervals);
    printf("  legacy one-step interval:     %.3f us\n", classic_us);
    printf("  12x master-tick interval:     %.3f us\n", native_interval_us);
    printf("  average 720-Hz master tick:   %.3f us\n", master_tick_us);
    printf("  master-tick throughput:       %.1f ticks/s\n", master_ticks_per_second);
    printf("  720-Hz dynamics headroom:     %.2fx\n", headroom_720);
    printf("  interval cost ratio:          %.3fx\n", native_interval_us / classic_us);
    printf("\nPolicy: Classic decisions/collision remain 60 Hz; only real motion is\n");
    printf("integrated on the 720-Hz master grid in Milestone 1.5.\n");
    return 0;
}
