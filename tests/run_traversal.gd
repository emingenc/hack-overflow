extends Node
## Full-level traversal probe — does the player actually reach the firewall,
## solve the puzzle, and unlock the exit? The real "is it playable" test.

var _failures: Array[String] = []
var _passes: int = 0
var _level: Node2D = null
var _t := 0.0

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
	await get_tree().create_timer(0.5).timeout

	var firewall: FirewallTerminal = _level.get("firewall")
	var exit_portal: Area2D = _level.get("exit_portal")
	_check(firewall != null, "firewall exists")
	_check(exit_portal != null, "exit exists")
	if not firewall or not exit_portal:
		_finish()
		return

	print("firewall at x=", firewall.position.x, " exit at x=", exit_portal.position.x)

	# Teleport player next to the firewall (testing the mechanic, not the platforming).
	var p := _level.get("player") as Player
	if p:
		p.global_position = firewall.position + Vector2(-10, 0)
		await get_tree().create_timer(0.5).timeout

	# Press E to open the puzzle (inject a real key event — action_press alone
	# does not dispatch _unhandled_input).
	var ev := InputEventKey.new()
	ev.physical_keycode = KEY_E
	ev.pressed = true
	Input.parse_input_event(ev)
	await get_tree().create_timer(0.1).timeout
	ev = InputEventKey.new()
	ev.physical_keycode = KEY_E
	ev.pressed = false
	Input.parse_input_event(ev)
	await get_tree().create_timer(0.3).timeout

	var ui: PuzzleUI = _level.get("_puzzle_ui")
	_check(ui != null and ui.visible, "puzzle UI opens on E")
	if ui and ui.visible:
		_check(get_tree().paused, "game pauses while puzzle open")
		# Answer correctly
		var correct_idx: int = ui.puzzle.correct_index
		ui._on_option_pressed(correct_idx)
		await get_tree().create_timer(0.2).timeout
		ui._on_submit()
		await get_tree().create_timer(2.2).timeout
		_check(exit_portal.monitoring, "exit unlocked after correct answer")
		_check(not get_tree().paused, "game unpaused after puzzle")
		print("puzzle title: ", ui.puzzle.title, " solved=", ui._last_correct)

	_finish()

func _finish() -> void:
	if _failures.is_empty():
		print("TRAVERSAL PROBE PASSED (%d)" % _passes)
		get_tree().quit(0)
	else:
		for f in _failures:
			print("FAIL: ", f)
		print("TRAVERSAL PROBE FAILED: %d failure(s), %d passed" % [_failures.size(), _passes])
		get_tree().quit(1)
