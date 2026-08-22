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

static void advance_ticks(ZoneGame *g, int ticks) {
    for (int i = 0; i < ticks; ++i) zone_game_step(g, (ZoneInput){0});
}

static void test_recovered_progression_constants(void) {
    assert(nearly(tz_initial_player_max_speed(), 25.0f));
    assert(nearly(tz_velocity_module_apply(25.0f), 30.0f));
    assert(nearly(tz_velocity_module_apply(49.0f), 50.0f));
    assert(nearly(tz_velocity_module_apply(50.0f), 50.0f));
    assert(tz_ammo_loader_apply(2) == 3);
    assert(tz_ammo_loader_apply(10) == 10);
    assert(tz_oscilloscope_apply(42) == 100);
    assert(tz_oscilloscope_apply(100) == 100);

    assert(tz_select_barrel_type(5, 0, 0, 0, false, 0) == TZ_TYPE_EQUI);
    assert(tz_select_barrel_type(5, 0, 0, 90, false, 0) == TZ_TYPE_BONU);
    assert(tz_select_barrel_type(12, 0, 0, 60, false, 0) == TZ_TYPE_GADG);
    assert(tz_select_barrel_type(12, 0, 0, 60, true, 0) == TZ_TYPE_EQUI);
}

static void test_ammo_is_shot_capacity(void) {
    ZoneGame *g = zone_game_create(0xA660u);
    assert(g);
    park_wave1_except(g, -1, -1);
    zone_game_debug_set_heading(g, 0.0f);
    assert(zone_game_hud(g).ammo == 2);

    ZoneInput fire = {0};
    fire.fire = 1;
    zone_game_step(g, fire);
    assert(zone_game_active_projectiles(g) == 1);
    advance_ticks(g, 8);
    zone_game_step(g, fire);
    assert(zone_game_active_projectiles(g) == 2);
    advance_ticks(g, 8);
    zone_game_step(g, fire);
    assert(zone_game_active_projectiles(g) == 2); /* original ammo capacity */
    zone_game_destroy(g);
}

static void test_pickup_effects(void) {
    ZoneGame *g = zone_game_create(0xC011EC7u);
    assert(g);
    park_wave1_except(g, -1, -1);
    const float x = zone_game_player_x(g), y = zone_game_player_y(g);
    zone_game_debug_set_progression(g, 42, 2, 25.0f, 1);

    assert(zone_game_debug_spawn_world(g, TZ_TYPE_OSCI, x, y, 0, 0) >= 0);
    zone_game_step(g, (ZoneInput){0});
    assert(zone_game_hud(g).shields == 100);
    assert(zone_game_count_type(g, TZ_TYPE_OSCI) == 0);

    assert(zone_game_debug_spawn_world(g, TZ_TYPE_VELO, x, y, 0, 0) >= 0);
    zone_game_step(g, (ZoneInput){0});
    assert(nearly(zone_game_player_max_speed(g), 30.0f));
    assert(zone_game_count_type(g, TZ_TYPE_VELO) == 0);

    assert(zone_game_debug_spawn_world(g, TZ_TYPE_AMMO, x, y, 0, 0) >= 0);
    zone_game_step(g, (ZoneInput){0});
    assert(zone_game_hud(g).ammo == 3);
    assert(zone_game_count_type(g, TZ_TYPE_AMMO) == 0);
    zone_game_destroy(g);
}

static void test_asteroid_payload(void) {
    ZoneGame *g = zone_game_create(0xA57E001u);
    assert(g);
    const int32_t asteroid = zone_game_debug_find_nth_type(g, TZ_TYPE_ASTE, 0);
    assert(asteroid >= 0);
    const int before_aste = zone_game_count_type(g, TZ_TYPE_ASTE);
    zone_game_debug_destroy_world(g, asteroid);
    assert(zone_game_count_type(g, TZ_TYPE_ASTE) == before_aste - 1);
    assert(zone_game_count_type(g, TZ_TYPE_VELO) +
           zone_game_count_type(g, TZ_TYPE_AMMO) == 1);
    assert(zone_game_hud(g).score == 20);
    zone_game_destroy(g);
}

static void test_big_rock_fragmentation(void) {
    ZoneGame *g = zone_game_create(0xB16B00Bu);
    assert(g);
    park_wave1_except(g, -1, -1);
    const int32_t rock = zone_game_debug_spawn_world(g, TZ_TYPE_ROCK,
                                                      320.0f, 240.0f, 0.0f, 0.0f);
    assert(rock >= 0);
    zone_game_debug_destroy_world(g, rock);
    const int stones = zone_game_count_type(g, TZ_TYPE_STON);
    assert(stones >= 2 && stones <= 4);
    assert(zone_game_count_type(g, TZ_TYPE_ROCK) == 0);
    assert(zone_game_hud(g).score == 50);
    zone_game_destroy(g);
}

static void test_player_death_respawn_skeleton(void) {
    ZoneGame *g = zone_game_create(0xD1E5u);
    assert(g);
    park_wave1_except(g, 0, -1);
    zone_game_debug_set_progression(g, 1, 2, 25.0f, 1);
    zone_game_debug_set_player_state(g, 300.0f, 240.0f, 10.0f, 0.0f);
    zone_game_debug_set_world_state(g, 0, 300.0f, 240.0f, 5.0f, 0.0f, 0);

    zone_game_step(g, (ZoneInput){0});
    assert(zone_game_player_alive(g) == 0);
    assert(zone_game_hud(g).shields == 0);

    advance_ticks(g, 120);
    assert(zone_game_player_alive(g) == 1);
    assert(zone_game_hud(g).shields == 100);
    zone_game_destroy(g);
}


static void test_recovered_enemy_behavior_constants(void) {
    assert(tz_enemy_chase_interval(TZ_TYPE_SWAR) == 4);
    assert(tz_enemy_axis_cap(TZ_TYPE_SWAR) == 8);
    assert(tz_enemy_chase_interval(TZ_TYPE_BLOO) == 3);
    assert(tz_enemy_axis_cap(TZ_TYPE_BLOO) == 9);
    assert(tz_enemy_chase_interval(TZ_TYPE_MOTO) == 1);
    assert(tz_enemy_axis_cap(TZ_TYPE_MOTO) == 10);
    assert(tz_enemy_chase_interval(TZ_TYPE_RAID) == 2);
    assert(tz_enemy_axis_cap(TZ_TYPE_RAID) == 9);

    assert(!tz_mother_should_launch_defenders(10000));
    assert(tz_mother_should_launch_defenders(10001));
    assert(tz_mother_should_launch_defenders(29999));
    assert(!tz_mother_should_launch_defenders(30000));
    assert(tz_mother_defender_active_cap(true) == 5);
    assert(tz_mother_defender_active_cap(false) == 3);
    assert(tz_mother_defender_batch_count(true, 0) == 2);
    assert(tz_mother_defender_batch_count(true, 3) == 5);
    assert(tz_mother_defender_batch_count(false, 0) == 1);
    assert(tz_mother_defender_batch_count(false, 2) == 3);
    assert(tz_hq_defender_active_cap(true) == 4);
    assert(tz_hq_defender_active_cap(false) == 2);
}

static void test_wave1_mother_defense_and_bee_semantics(void) {
    ZoneGame *g = zone_game_create(0x161D0u);
    assert(g);
    const int32_t moth = zone_game_debug_find_nth_type(g, TZ_TYPE_MOTH, 0);
    assert(moth >= 0);

    /* Professional Wave 1 has no Bloody quota: the sole Mother Base's
       defender subtype is Empire Fighter ('swar'). */
    assert(zone_game_debug_world_subtype(g, moth) == TZ_TYPE_SWAR);
    assert(zone_game_hud(g).enemies == 0);

    /* PPC 0x16504 excludes the requesting base itself. With only one base in
       Wave 1 there is no valid donor, therefore no Bee can be produced. */
    assert(zone_game_debug_request_bee(g, moth) < 0);
    assert(zone_game_count_type(g, TZ_TYPE_BEE) == 0);

    /* A valid 0x161D0 gate plus batch word 3 selects the Professional maximum
       batch of 5 and fills the recovered active-defender cap. */
    assert(zone_game_debug_trigger_mother_defense(g, moth, 15000, 3) == 5);
    assert(zone_game_count_type(g, TZ_TYPE_SWAR) == 5);
    assert(zone_game_hud(g).enemies == 5);
    assert(zone_game_debug_world_defender_count(g, moth) == 5);

    for (int n = 0; n < 5; ++n) {
        const int32_t swar = zone_game_debug_find_nth_type(g, TZ_TYPE_SWAR, n);
        assert(swar >= 0);
        assert(zone_game_debug_world_parent(g, swar) == moth);
    }

    assert(zone_game_debug_trigger_mother_defense(g, moth, 15000, 0) == 0);

    const int32_t first = zone_game_debug_find_nth_type(g, TZ_TYPE_SWAR, 0);
    assert(first >= 0);
    zone_game_debug_destroy_world(g, first);
    assert(zone_game_debug_world_defender_count(g, moth) == 4);
    assert(zone_game_hud(g).enemies == 4);

    /* Cap enforcement allows exactly one replacement even though the batch
       request asks for two. */
    assert(zone_game_debug_trigger_mother_defense(g, moth, 15000, 0) == 1);
    assert(zone_game_debug_world_defender_count(g, moth) == 5);
    assert(zone_game_hud(g).enemies == 5);
    zone_game_destroy(g);
}


static void test_two_base_bee_request_linkage(void) {
    ZoneGame *g = zone_game_create(0x16504u);
    assert(g);
    const int32_t requester = zone_game_debug_find_nth_type(g, TZ_TYPE_MOTH, 0);
    assert(requester >= 0);
    const int32_t donor = zone_game_debug_spawn_world(
        g, TZ_TYPE_MOTH, 420.0f, 160.0f, 0.0f, 0.0f);
    assert(donor >= 0 && donor != requester);

    const int32_t bee = zone_game_debug_request_bee(g, requester);
    assert(bee >= 0);
    assert(zone_game_count_type(g, TZ_TYPE_BEE) == 1);
    assert(zone_game_debug_world_parent(g, bee) == donor);
    assert(zone_game_hud(g).enemies == 1);

    /* Wave-1 bee_limit is one request per requester. */
    assert(zone_game_debug_request_bee(g, requester) < 0);

    zone_game_debug_destroy_world(g, bee);
    assert(zone_game_count_type(g, TZ_TYPE_BEE) == 0);
    assert(zone_game_hud(g).enemies == 0);

    /* Destroying the linked Bee repairs both recovered counters. */
    assert(zone_game_debug_request_bee(g, requester) >= 0);
    zone_game_destroy(g);
}

static void test_empire_fighter_live_chase(void) {
    ZoneGame *g = zone_game_create(0x5A4A2u);
    assert(g);
    park_wave1_except(g, -1, -1);
    zone_game_debug_set_player_state(g, 300.0f, 240.0f, 0.0f, 0.0f);
    const int32_t swar = zone_game_debug_spawn_world(
        g, TZ_TYPE_SWAR, 100.0f, 240.0f, 0.0f, 0.0f);
    assert(swar >= 0);

    advance_ticks(g, 3);
    ZoneDebugBodyState s0 = zone_game_debug_world_state(g, swar);
    assert(nearly(s0.vx, 0.0f) && nearly(s0.vy, 0.0f));

    advance_ticks(g, 1);
    ZoneDebugBodyState s1 = zone_game_debug_world_state(g, swar);
    assert(nearly(s1.vx, 1.0f));
    assert(nearly(s1.vy, 0.0f));
    assert(s1.frame == 0); /* 24-frame bank: frame 0 faces right */
    zone_game_destroy(g);
}



static void test_recovered_hostile_fire_constants(void) {
    assert(!tz_enemy_should_fire(TZ_TYPE_BLOO, 10000));
    assert(tz_enemy_should_fire(TZ_TYPE_BLOO, 10001));
    assert(tz_enemy_should_fire(TZ_TYPE_BLOO, 13499));
    assert(!tz_enemy_should_fire(TZ_TYPE_BLOO, 13500));

    assert(!tz_enemy_should_fire(TZ_TYPE_BEE, 10000));
    assert(tz_enemy_should_fire(TZ_TYPE_BEE, 14999));
    assert(!tz_enemy_should_fire(TZ_TYPE_BEE, 15000));

    assert(!tz_enemy_should_fire(TZ_TYPE_RAID, 10000));
    assert(tz_enemy_should_fire(TZ_TYPE_RAID, 19999));
    assert(!tz_enemy_should_fire(TZ_TYPE_RAID, 20000));

    assert(!tz_enemy_should_fire(TZ_TYPE_SEEK, 10000));
    assert(tz_enemy_should_fire(TZ_TYPE_SEEK, 10999));
    assert(!tz_enemy_should_fire(TZ_TYPE_SEEK, 11000));
    assert(!tz_enemy_should_fire(TZ_TYPE_SWAR, 12000));

    assert(tz_enemy_fire_active_cap(TZ_TYPE_BLOO) == 3);
    assert(tz_enemy_fire_active_cap(TZ_TYPE_BEE) == 3);
    assert(tz_enemy_fire_active_cap(TZ_TYPE_RAID) == 3);
    assert(tz_enemy_fire_active_cap(TZ_TYPE_SEEK) == 3);
    assert(tz_enemy_fire_active_cap(TZ_TYPE_SWAR) == 0);
    assert(nearly(tz_enemy_projectile_speed(), 11.25f));
}

static void test_hostile_projectile_cap_and_player_hit(void) {
    ZoneGame *g = zone_game_create(0xF1AEu);
    assert(g);
    park_wave1_except(g, -1, -1);
    zone_game_debug_set_player_state(g, 300.0f, 240.0f, 0.0f, 0.0f);
    const int32_t raid = zone_game_debug_spawn_world(
        g, TZ_TYPE_RAID, 360.0f, 240.0f, 0.0f, 0.0f);
    assert(raid >= 0);

    assert(zone_game_debug_enemy_fire(g, raid) == 1);
    assert(zone_game_debug_enemy_fire(g, raid) == 1);
    assert(zone_game_debug_enemy_fire(g, raid) == 1);
    assert(zone_game_debug_enemy_fire(g, raid) == 0);
    assert(zone_game_active_hostile_projectiles(g) == 3);
    zone_game_destroy(g);

    g = zone_game_create(0xF1AFu);
    assert(g);
    park_wave1_except(g, -1, -1);
    zone_game_debug_set_player_state(g, 300.0f, 240.0f, 0.0f, 0.0f);
    const int32_t shooter = zone_game_debug_spawn_world(
        g, TZ_TYPE_RAID, 360.0f, 240.0f, 0.0f, 0.0f);
    assert(shooter >= 0);
    assert(zone_game_debug_enemy_fire(g, shooter) == 1);
    zone_game_debug_destroy_world(g, shooter); /* shot must survive slot release */

    for (int i = 0; i < 30 && zone_game_hud(g).shields == 100; ++i) {
        zone_game_step(g, (ZoneInput){0});
    }
    assert(zone_game_hud(g).shields == 99);
    assert(zone_game_active_hostile_projectiles(g) == 0);
    zone_game_destroy(g);
}

static void test_seeker_near_far_speed_switch(void) {
    ZoneGame *g = zone_game_create(0x5EE0u);
    assert(g);
    park_wave1_except(g, -1, -1);
    zone_game_debug_set_player_state(g, 400.0f, 240.0f, 0.0f, 0.0f);
    int32_t seek = zone_game_debug_spawn_world(
        g, TZ_TYPE_SEEK, 100.0f, 240.0f, 0.0f, 0.0f);
    assert(seek >= 0);
    zone_game_step(g, (ZoneInput){0});
    ZoneDebugBodyState far_state = zone_game_debug_world_state(g, seek);
    assert(nearly(sqrtf(far_state.vx * far_state.vx + far_state.vy * far_state.vy), 10.0f));
    zone_game_destroy(g);

    g = zone_game_create(0x5EE1u);
    assert(g);
    park_wave1_except(g, -1, -1);
    zone_game_debug_set_player_state(g, 300.0f, 240.0f, 0.0f, 0.0f);
    seek = zone_game_debug_spawn_world(
        g, TZ_TYPE_SEEK, 200.0f, 240.0f, 0.0f, 0.0f);
    assert(seek >= 0);
    zone_game_step(g, (ZoneInput){0});
    ZoneDebugBodyState near_state = zone_game_debug_world_state(g, seek);
    assert(nearly(sqrtf(near_state.vx * near_state.vx + near_state.vy * near_state.vy),
                  zone_game_player_max_speed(g)));
    zone_game_destroy(g);
}

static void test_fixed_wave_lifecycle_1_to_2(void) {
    ZoneGame *g = zone_game_create(0x12754u);
    assert(g);
    const int32_t moth = zone_game_debug_find_nth_type(g, TZ_TYPE_MOTH, 0);
    assert(moth >= 0);
    zone_game_debug_destroy_world(g, moth);
    assert(zone_game_hud(g).bases == 0);
    assert(zone_game_hud(g).enemies == 0);

    advance_ticks(g, 91);
    const ZoneHUDState hud = zone_game_hud(g);
    assert(hud.wave == 2);
    assert(hud.bases == 2);
    assert(hud.enemies == 0);
    assert(zone_game_count_type(g, TZ_TYPE_ASTE) == 4);
    assert(zone_game_count_type(g, TZ_TYPE_MOTH) == 2);
    zone_game_destroy(g);
}


static void test_mother_base_long_damage_chain_and_feedback(void) {
    ZoneGame *g = zone_game_create(0x19C9Cu);
    assert(g);
    const int32_t moth = zone_game_debug_find_nth_type(g, TZ_TYPE_MOTH, 0);
    assert(moth >= 0);

    /* Saturate the recovered Professional defender cap first. This recreates
       the situation where later valid hits used to look ineffective because
       there was no further spawn reaction or hit feedback. */
    assert(zone_game_debug_trigger_mother_defense(g, moth, 15000, 3) == 5);
    assert(zone_game_debug_world_defender_count(g, moth) == 5);

    ZoneAudioEvent audio[ZONE_MAX_AUDIO_EVENTS];
    (void)zone_game_drain_audio(g, audio, ZONE_MAX_AUDIO_EVENTS);

    assert(zone_game_debug_apply_player_shot(g, moth) == 0);
    assert(zone_game_debug_world_damage(g, moth) == 1);

    const ZoneDebugBodyState state = zone_game_debug_world_state(g, moth);
    const ZoneRenderItem flashed = find_sprite(g, 9000 + state.frame);
    assert(flashed.sprite_id == 9000 + state.frame);
    assert(flashed.flash > 0.5f);

    const int32_t n = zone_game_drain_audio(g, audio, ZONE_MAX_AUDIO_EVENTS);
    int saw_hit = 0;
    for (int32_t i = 0; i < n; ++i) saw_hit |= audio[i].type == ZONE_AUDIO_HIT;
    assert(saw_hit);

    /* Professional Mother Base threshold is 40. Defender cap must not suppress
       damage accumulation: hits 2..39 remain nonlethal, hit 40 destroys it. */
    for (int hit = 2; hit <= 39; ++hit) {
        assert(zone_game_debug_apply_player_shot(g, moth) == 0);
        assert(zone_game_debug_world_damage(g, moth) == hit);
        (void)zone_game_drain_audio(g, audio, ZONE_MAX_AUDIO_EVENTS);
    }
    assert(zone_game_count_type(g, TZ_TYPE_MOTH) == 1);
    assert(zone_game_debug_apply_player_shot(g, moth) == 1);
    assert(zone_game_count_type(g, TZ_TYPE_MOTH) == 0);
    assert(zone_game_hud(g).bases == 0);
    assert(zone_game_hud(g).enemies == 5); /* linked defenders survive parent */
    zone_game_destroy(g);
}

static void test_hq_nonlethal_defender_reaction(void) {
    ZoneGame *g = zone_game_create(0x16390u);
    assert(g);
    park_wave1_except(g, -1, -1);

    const int32_t hq = zone_game_debug_spawn_world(
        g, TZ_TYPE_BASE, 320.0f, 240.0f, 0.0f, 0.0f);
    assert(hq >= 0);

    /* A debug-created HQ has no assigned subtype, so portable fallback is the
       recovered normal HQ defender family: Off-Shore ('moto'). */
    assert(zone_game_debug_trigger_hq_defense(g, hq) == 4);
    assert(zone_game_debug_world_defender_count(g, hq) == 4);
    assert(zone_game_count_type(g, TZ_TYPE_MOTO) == 4);
    assert(zone_game_debug_trigger_hq_defense(g, hq) == 0);

    const int32_t first = zone_game_debug_find_nth_type(g, TZ_TYPE_MOTO, 0);
    assert(first >= 0);
    zone_game_debug_destroy_world(g, first);
    assert(zone_game_debug_world_defender_count(g, hq) == 3);
    assert(zone_game_debug_trigger_hq_defense(g, hq) == 1);
    assert(zone_game_debug_world_defender_count(g, hq) == 4);

    /* The production nonlethal-shot consequence also calls 0x16390. */
    for (int i = 0; i < 4; ++i) {
        const int32_t moto = zone_game_debug_find_nth_type(g, TZ_TYPE_MOTO, 0);
        assert(moto >= 0);
        zone_game_debug_destroy_world(g, moto);
    }
    assert(zone_game_debug_world_defender_count(g, hq) == 0);
    assert(zone_game_debug_apply_player_shot(g, hq) == 0);
    assert(zone_game_debug_world_damage(g, hq) == 1);
    assert(zone_game_debug_world_defender_count(g, hq) == 4);
    zone_game_destroy(g);
}


static void test_mother_base_frame_is_stable(void) {
    ZoneGame *g = zone_game_create(0x14C70u);
    assert(g);
    const int32_t moth = zone_game_debug_find_nth_type(g, TZ_TYPE_MOTH, 0);
    assert(moth >= 0);
    park_wave1_except(g, moth, -1);
    const ZoneDebugBodyState before = zone_game_debug_world_state(g, moth);

    /* PPC moth handler 0x14C70 does not advance sprite_frame (+56).  The
       portable generic passive-animation loop must therefore leave the Mother
       Base's chosen frame unchanged while it is otherwise idle. */
    advance_ticks(g, 64);
    const ZoneDebugBodyState after = zone_game_debug_world_state(g, moth);
    assert(after.frame == before.frame);
    zone_game_destroy(g);
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
    test_recovered_hostile_fire_constants();
    test_hostile_projectile_cap_and_player_hit();
    test_seeker_near_far_speed_switch();
    test_fixed_wave_lifecycle_1_to_2();
    test_mother_base_frame_is_stable();
    test_recovered_enemy_behavior_constants();
    test_wave1_mother_defense_and_bee_semantics();
    test_two_base_bee_request_linkage();
    test_empire_fighter_live_chase();
    test_mother_base_long_damage_chain_and_feedback();
    test_hq_nonlethal_defender_reaction();
    test_recovered_impact_damage();
    test_recovered_progression_constants();
    test_ammo_is_shot_capacity();
    test_pickup_effects();
    test_asteroid_payload();
    test_big_rock_fragmentation();
    test_player_death_respawn_skeleton();

    ZoneGame *g = zone_game_create(0x12345678u);
    assert(g);
    assert(nearly(zone_game_player_max_speed(g), 25.0f));
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
    puts("Recovered initial max speed / pickup progression: PASS");
    puts("Ammunition concurrent-shot capacity: PASS");
    puts("Asteroid VELO/AMMO payload consequence: PASS");
    puts("Big Rock 2..4 fragment consequence: PASS");
    puts("Player death/respawn lifecycle skeleton: PASS");
    puts("Recovered Mother Base defender gate/cap/batch: PASS");
    puts("Professional Wave-1 Mother subtype / no-self-Bee request: PASS");
    puts("Two-base Bee donor/requester linkage + counter repair: PASS");
    puts("Linked Empire Fighter spawn/count cleanup: PASS");
    puts("Live Empire Fighter chase cadence/cap/facing: PASS");
    puts("Recovered hostile-fire gates/cap/speed: PASS");
    puts("Hostile projectile player-hit/source cleanup: PASS");
    puts("Seeker 200-unit near/far speed switch: PASS");
    puts("Fixed Wave 1 -> Wave 2 lifecycle: PASS");
    puts("Mother Base/HQ sprite-frame stability regression: PASS");
    puts("Mother Base 40-hit damage continuity + hit feedback: PASS");
    puts("Recovered Headquarters nonlethal defender response: PASS");
    return 0;
}
