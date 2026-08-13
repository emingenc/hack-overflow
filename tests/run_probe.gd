extends Node
## Behavioral smoke test — instantiates level_01 and verifies core mechanics live.
## Run: godot --headless --path . res://tests/probe_runner.tscn
## Exit 0 = pass. Complements run_tests.gd (static assertions) with runtime checks.

var _failures: Array[String] = []
var _passes: int = 0
var _level: Node2D = null

func _ready() -> void:
	_run()

func _check(cond: bool, msg: String) -> void:
	if cond:
		_passes += 1
	else:
		_failures.append(msg)

func _run() -> void:
	var scene := load("res://scenes/levels/level_01_terminal.tscn")
	_level = scene.instantiate()
	add_child(_level)

	# Let physics settle.
	await get_tree().create_timer(0.8).timeout

	_check(_level.get("player") != null, "player spawned")
	var player: Player = _level.get("player")
	if player:
		_check(player.is_on_floor(), "player rests on floor after settle")

	# Firewall is left of exit (F before E in map).
	var firewall: Node2D = _level.get("firewall")
	var exit_portal: Area2D = _level.get("exit_portal")
	_check(firewall != null, "firewall spawned")
	_check(exit_portal != null, "exit portal spawned")
	if firewall and exit_portal:
		_check(firewall.position.x < exit_portal.position.x, "exit is right of firewall")
		_check(not exit_portal.monitoring, "exit locked until puzzle solved")

	# Projectiles carry sprite + collision.
	var proj_src := FileAccess.open("res://scripts/enemies/enemy_projectile.gd", FileAccess.READ).get_as_text()
	_check(proj_src.contains("Sprite2D.new()"), "projectile script builds sprite")
	_check(proj_src.contains("CircleShape2D.new()"), "projectile script builds collision")

	# Puzzle UI pauses the tree.
	var ui: PuzzleUI = _level.get("_puzzle_ui")
	_check(ui != null, "puzzle UI exists")
	if ui:
		var test_puzzle := {
			"id": "test", "title": "Test", "difficulty": "EASY",
			"description": "test", "options": ["A", "B"], "correct_index": 0,
			"explanation": "test", "hint": "test",
		}
		ui.show_puzzle(test_puzzle)
		_check(get_tree().paused, "puzzle pauses the game")
		ui._on_back()
		_check(not get_tree().paused, "closing puzzle unpauses the game")

	# Chip accounting.
	var chips: int = _level.get("chips_total")
	_check(chips > 0, "level has collectible chips (%d)" % chips)

	_level.queue_free()
	await get_tree().create_timer(0.2).timeout

	if _failures.is_empty():
		print("PROBE PASSED (%d)" % _passes)
		get_tree().quit(0)
	else:
		for f in _failures:
			print("FAIL: ", f)
		print("PROBE FAILED: %d failure(s), %d passed" % [_failures.size(), _passes])
		get_tree().quit(1)
