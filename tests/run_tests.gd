extends SceneTree
## Headless test suite for HACK://OVERFLOW.
## Run: godot --headless --path . --script res://tests/run_tests.gd
## Exit code 0 = all pass, 1 = failures.

var _failures: Array[String] = []
var _passes: int = 0

func _init() -> void:
	_test_projectile_setup()
	_test_puzzle_bank()
	_test_level_maps()
	_test_dash_refill_code()
	_test_respawn_code()
	_test_pause_code()

	if _failures.is_empty():
		print("ALL TESTS PASSED (%d)" % _passes)
		quit(0)
	else:
		for f in _failures:
			print("FAIL: ", f)
		print("TESTS FAILED: %d failure(s), %d passed" % [_failures.size(), _passes])
		quit(1)

func _check(cond: bool, msg: String) -> void:
	if cond:
		_passes += 1
	else:
		_failures.append(msg)

func _read_file(path: String) -> String:
	var f := FileAccess.open(path, FileAccess.READ)
	if not f:
		return ""
	return f.get_as_text()

func _test_projectile_setup() -> void:
	var src := _read_file("res://scripts/enemies/enemy_projectile.gd")
	_check(src.contains("Sprite2D.new()"), "projectile creates a Sprite2D")
	_check(src.contains("CircleShape2D.new()"), "projectile creates a CollisionShape2D")
	_check(src.contains("collision_layer = 4"), "projectile on layer 4")
	_check(src.contains("body_entered.connect"), "projectile connects body_entered")

func _test_puzzle_bank() -> void:
	var gm := _read_file("res://scripts/autoload/game_manager.gd")
	# Count puzzle dicts: each has "id" and "correct_index"
	var ids := 0
	for line in gm.split("\n"):
		if line.contains("\"id\":"):
			ids += 1
	_check(ids >= 10, "puzzle bank has >=10 problems (found %d)" % ids)

func _test_level_maps() -> void:
	for path in ["res://scenes/levels/level_01_terminal.tscn",
			"res://scenes/levels/level_02_servers.tscn",
			"res://scenes/levels/level_03_core.tscn"]:
		var src := _read_file(path)
		var map := ""
		var in_map := false
		for line in src.split("\n"):
			if line.contains("level_map = "):
				in_map = true
				map = line.split("level_map = ", true)[1]
			elif in_map:
				# Continuation lines in .tscn have no quotes until the closing one.
				var stripped := line.strip_edges()
				if stripped.begins_with("\""):
					in_map = false
				elif stripped.is_empty():
					continue
				else:
					map += "\n" + stripped
		_check(map.contains("P"), "level has player spawn")
		_check(map.contains("F"), "level has firewall")
		_check(map.contains("E"), "level has exit")
		# Exit must come AFTER firewall in map rows (right of it)
		var p := map.find("F")
		var e := map.find("E")
		_check(e > p, "exit is right of firewall (F at %d, E at %d)" % [p, e])

func _test_dash_refill_code() -> void:
	var src := _read_file("res://scripts/player/player.gd")
	_check(src.contains("can_dash = true"), "dash refill exists")
	# Refill happens on landing via was_on_floor check (not the missing floor_entered signal).
	_check(src.contains("not was_on_floor"), "refill tied to landing transition")
	_check(not src.contains("floor_entered.connect"), "no dependency on unavailable signal")

func _test_respawn_code() -> void:
	var src := _read_file("res://scripts/levels/level.gd")
	_check(src.contains("_respawn_point"), "level tracks a respawn point")
	_check(src.contains("_spawn_player_at"), "death respawns via checkpoint helper")
	# The hard-reload is allowed only as an uninitialized fallback.
	_check(src.count("reload_current_scene") <= 1, "hard-reload is not the primary death path")

func _test_pause_code() -> void:
	var src := _read_file("res://scripts/checkpoint/puzzle_ui.gd")
	_check(src.contains("get_tree().paused = true"), "puzzle pauses the tree")
	_check(src.contains("PROCESS_MODE_WHEN_PAUSED"), "puzzle UI keeps running while paused")
	_check(src.contains("get_tree().paused = false"), "puzzle unpauses on exit")
