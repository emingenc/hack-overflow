# Gauntlet Ledger — HACK://OVERFLOW platformer

Deliverable: /Users/eminmacprom1/Documents/Code/hacker-platformer
Deliverable-id: hack-overflow-r1
Tier: Medium (3-role fan-out)

## Done signal (acceptance criteria)
1. Game loads and runs: `godot --path . --quit-after 30` exits 0 with no SCRIPT/Parse errors.
2. All 3 levels load clean: no errors.
3. Player physics work: move (A/D), jump (W/SPACE, double jump), dash (S), coyote time + jump buffer in code.
4. Firewall terminal opens DSA puzzle UI on E; correct answer unlocks exit; wrong answer gives feedback + explanation.
5. HUD shows sector name, chips (x/y), timer; level-complete overlay shows next/retry.
6. Main menu: 3 level buttons, locks until previous sector solved.
7. Visual render: movie writer produces frames (1280x720) without crash.
8. Educational integrity: puzzle bank has >=10 LeetCode-style problems with correct answers, hints, explanations.

Users: Emin (creator) — plays to practice DSA while enjoying a platformer.
Key scenario: player completes sector 1, hits firewall, solves "Two Sum", exits, sector 2 unlocks.

Minimum eval set: (1) boot main menu, (2) play sector 1, (3) reach firewall, (4) solve puzzle, (5) complete sector, (6) unlock sector 2, (7) retry sector, (8) wrong-answer path, (9) dash+jump across gap, (10) collect all chips.

## Metric priority
correctness/safety > usability > performance > size > polish

## Round 0 baseline
- 3 levels load clean
- Movie render works at 1280x720
- Puzzle bank: 13 problems
- Tests: 0

## Round 1 (2026-08-13)
### Fan-out: inspector ✓, comparator ✓, evaluator ✓ (3/3, all completed)
### Evaluator scores: conformance 0.85, audience 0.68, craft 0.42, originality 0.70, friction 0.50, code 0.55
### Comparator examples (registered in eval-tasks.md v1.2):
- Celeste (www.celestegame.com) sha256 52d6249e... — mechanics/polish/pixel art
- Hollow Knight (www.hollowknight.com) sha256 145d9b8a... — craft/UI/art
- Glitch Hunt demo (early-sun-games.itch.io) sha256 00c368f5... — cyberpunk indie calibration
### Accepted fixes: 1xP0, 5xP1, 6xP2, 2xP3 (see failures.md)
### Post-fix verification:
- Tests: 26/26 PASS (new headless suite run_tests.gd)
- All 3 levels load clean
- Main menu loads: 0 errors
- Movie render: OK
- Music: added looping chiptune (Music bus)
- Persistence: user://save.cfg save/load added
- Gamepad: joypad bindings added
- Exit visual: distinct pulsing portal
- Death: checkpoint respawn preserves chips

## Round log
- R1: full fan-out (3 roles) — 1xP0, 5xP1, 6xP2 fixed. Scores: craft 0.42, friction 0.50.
- R2: leaner inspector — 1xP1 (tile physics offset) + 3xP2/P3 fixed. 28/28 runtime probe + 26 static tests pass.
- R3: leaner inspector — 1xP1 (atlas separation=1 corrupted tiles) + 3xP2/P3 fixed. ALIGN PROBE 24/24, all suites green.

## Round 2 verification (2026-08-13)
- Static tests: 26/26 PASS
- Behavioral probe: 12/12 PASS (new permanent test)
- All levels + menu: 0 errors
- Leak: residual ObjectDB warning = Godot headless audio-driver artifact (minimal repro), not game code
