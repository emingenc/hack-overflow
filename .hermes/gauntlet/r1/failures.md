# Gauntlet Failures Log — hack-overflow-r1

## Round 1 (2026-08-13)
### Accepted fixes (from evaluator + inspector fan-out)
- [P0] enemy_projectile.gd — projectiles had no sprite + no collision. FIX: sprite + CircleShape2D + layers.
- [P1] player.gd — air dash never refills. FIX: refill on landing (was_on_floor check).
- [P1] level_02/level_03 maps — exit behind spawn. FIX: moved E right of F.
- [P1] level.gd death — full reload wipes chips. FIX: checkpoint respawn preserves chips.
- [P1] puzzle_ui.gd — "ENTER NEXT SECTOR" cancelled unlock. FIX: emit true when solved; connect guarded.
- [P1] No pause during puzzle. FIX: get_tree().paused on show, unpause on exit + PREDELETE guard.
- [P1] Zero tests. FIX: tests/run_tests.gd (26 static assertions).
- [P1] No music/background. FIX: looping chiptune on Music bus.
- [P2] Level-01 drone swept spawn. FIX: map adjusted.
- [P2] Progress never persists. FIX: user://save.cfg.
- [P2] Deterministic puzzle rotation. FIX: random + difficulty ramp.
- [P2] Exit visual reads as terminal. FIX: distinct pulsing portal.
- [P2] Keyboard-only. FIX: joypad bindings.
- [P3] Wasted node in _on_player_died. FIX: removed.
- [P3] Stale _make_tileset comment. FIX: updated.

## Round 2 (2026-08-13) — leaner inspector re-check
### Accepted fixes
- [P1] level.gd _make_tileset — TileData collision polygons were corner-anchored (0..18) but Godot expects cell-centered (-9..+9) → physics offset +9px vs visuals on all tiles. FIX: cell-centered polygon points.
- [P2] audio_manager.gd — ObjectDB leak warning at exit (music stream + playback). FIX: stop + null stream + free in _exit_tree + clear _buses cache. (Residual leak is a Godot 4.7 headless audio-driver artifact — reproduced with a minimal no-game test; harmless at exit.)
- [P2] tests — static-only. FIX: added behavioral probe (tests/run_probe.gd + probe_runner.tscn, 12 runtime checks).
- [P3] hud.gd — gamepad hint added to controls line.
- [P3] level.gd _spawn_exit — dedicated portal.svg sprite (no more tinted terminal).

### Verification (post-R2 fixes)
- run_tests.gd: 26/26 PASS
- run_probe.gd (behavioral): 12/12 PASS
- All 3 levels + menu: 0 errors
- Movie render: OK

## Round 3 (2026-08-13) — leaner inspector re-check
### Accepted fixes
- [P1] level.gd _make_tileset — `src.separation = Vector2i(1,1)` on a separation-free Kenney atlas (360x162 = 20x9 tiles @18px, zero gaps) corrupted every tile (4-tile mosaic, 41% black). FIX: separation = ZERO. Runtime-verified: sampled region now == intended (offset 0,0) across all levels.
- [P2] tests — ported raycast alignment probe to permanent suite: tests/run_alignment.gd (24 checks, catches half-tile sink + atlas drift).
- [P2] tests/run_probe.gd — 2 source-grep checks duplicated run_tests.gd; noted for future cleanup (non-blocking).
- [P3] level.gd spawn — added comment explaining depenetration intent.

### Verification (post-R3 fixes)
- run_tests.gd: 26/26 PASS
- run_probe.gd: 12/12 PASS
- run_alignment.gd: 24/24 PASS (Δ=0.00 on floor/wall/plat, atlas regions exact)
- All 3 levels + menu: 0 errors
- Leak: proven Godot headless audio-driver artifact (controlled experiment: bare player + WAV leaks identically; no-audio control = 0 leaks)

## HUMAN GATE (2026-08-13) — "Can't playable" report → ROUND 5 fix
User reported the game was NOT playable despite green automated suites. Investigation found:
- **P0: Levels were tiny.** Maps 26 tiles x 18px = 468px wide, but window is 1280x720 and camera was clamped to map width → player was a small sprite in a huge black void (~800px dead screen). FIX: generated proper wide levels (130 tiles = 2340px, multi-height platforms, spikes, drones, turrets) via tools/gen_levels.py + camera zoom 3x so 18px tiles fill the window.
- **P1: Game stuck paused after solving puzzle.** The correct-answer auto-path emitted puzzle_completed(true) without unpausing (only _on_back did). FIX: hide + unpause before emitting in _on_submit success path.
- **P2: Test gap — suites never simulated real input or the full game loop.** FIX: added tests/run_playtest.gd (real key simulation: move/jump/dash) + tests/run_traversal.gd (firewall → puzzle → solve → unlock → unpause). Learned: Input.action_press() does NOT dispatch _unhandled_input — must inject InputEventKey for E-interact tests.

### Verification (post-human-gate fixes)
- run_tests.gd: 26/26 · run_probe.gd: 12/12 · run_playtest.gd: 3/3 · run_traversal.gd: 6/6 — ALL PASS
- Levels: 0 errors · commit 6a3a618

## Recurring categories
- (none — categories so far are one-off: physics alignment, projectile construction, pause leak, persistence, input breadth, visual distinctness, atlas geometry, level scale, test-input-fidelity)
