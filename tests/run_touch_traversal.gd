extends Node
## Touch-input traversal probe — verifies the FULL game loop works via
## Input.action_press (what virtual touch buttons do), not just key events.
## This caught the production bug where the firewall ignored touch input.

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
	await get_tree().create_timer(0.5).timeout

	var firewall: FirewallTerminal = _level.get("firewall")
	var exit_portal: Area2D = _level.get("exit_portal")
	_check(firewall != null, "firewall exists")
	_check(exit_portal != null, "exit exists")
	if not firewall or not exit_portal:
		_finish()
		return

	# Teleport player next to the firewall
	var p := _level.get("player") as Player
	if p:
		p.global_position = firewall.position + Vector2(-10, 0)
		await get_tree().create_timer(0.5).timeout
	_check(firewall.get("_in_range") == true, "firewall detects player")

	# THE FIX: touch buttons call Input.action_press (no event dispatched).
	Input.action_press("interact")
	await get_tree().create_timer(0.1).timeout
	Input.action_release("interact")
	await get_tree().create_timer(0.4).timeout

	var ui: PuzzleUI = _level.get("_puzzle_ui")
	_check(ui != null and ui.visible, "puzzle UI opens via touch action_press")
	if ui and ui.visible:
		_check(get_tree().paused, "game pauses while puzzle open")
		await _solve_task(ui)
		_check(ui._last_correct, "task solved (touch)")
		ui._on_back()  # CONTINUE → puzzle_completed(true)
		await get_tree().create_timer(0.2).timeout
		_check(exit_portal.monitoring, "exit unlocked after CONTINUE (touch)")
		_check(not get_tree().paused, "game unpaused after puzzle")

	_finish()

## Solve any puzzle task type via the real UI methods.
func _solve_task(ui: PuzzleUI) -> void:
	match ui._task_type:
		"trace":
			var steps: Array = ui.puzzle.get("steps", [])
			for step_idx in range(steps.size()):
				var ci: int = int(steps[step_idx]["correct_index"])
				ui._on_option_pressed(ci)
				await get_tree().create_timer(0.1, true).timeout
				ui._on_submit()
				await get_tree().create_timer(1.0, true).timeout
			if ui.puzzle.has("synthesis"):
				var syn: Dictionary = ui.puzzle["synthesis"]
				var sci: int = int(syn["correct_index"])
				ui._on_option_pressed(sci)
				await get_tree().create_timer(0.1, true).timeout
				ui._on_submit()
				await get_tree().create_timer(0.2, true).timeout
		"order":
			var correct_order: Array = ui.puzzle["correct_order"]
			for slot in range(correct_order.size()):
				var step_idx: int = int(correct_order[slot])
				ui._on_order_pool_pressed(step_idx)
			await get_tree().create_timer(0.1, true).timeout
			ui._on_submit()
			await get_tree().create_timer(0.2, true).timeout
		_:
			var correct_idx: int = ui.puzzle.correct_index
			ui._on_option_pressed(correct_idx)
			await get_tree().create_timer(0.2, true).timeout
			ui._on_submit()
			await get_tree().create_timer(0.3, true).timeout

func _finish() -> void:
	if _failures.is_empty():
		print("TOUCH TRAVERSAL PASSED (%d)" % _passes)
		get_tree().quit(0)
	else:
		for f in _failures:
			print("FAIL: ", f)
		print("TOUCH TRAVERSAL FAILED: %d failure(s), %d passed" % [_failures.size(), _passes])
		get_tree().quit(1)
