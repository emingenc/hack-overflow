extends Node
## Verifies the easter-egg task types: restart (REBOOT solves) and windows_update
## (kill switch solves), plus mastery recording works.

var _failures: Array[String] = []
var _passes: int = 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_run()

func _check(cond: bool, msg: String) -> void:
	if cond:
		_passes += 1
	else:
		_failures.append(msg)

func _run() -> void:
	var ui := PuzzleUI.new()
	add_child(ui)

	# ── RESTART easter egg ──
	var restart: Dictionary = {}
	for p in GameManager.PUZZLES:
		if p.get("id", "") == "easter_restart":
			restart = p
			break
	ui.show_puzzle(restart, 0)
	_check(ui._task_type == "restart", "restart task detected")
	_check(ui._submit_button.text == "REBOOT SYSTEM", "restart shows REBOOT button")
	_check(not ui._submit_button.disabled, "REBOOT button is enabled")
	ui._on_reboot_pressed()
	_check(ui._last_correct, "reboot solves the puzzle")
	_check(GameManager.mastery_for("easter_restart") > 0, "restart mastery recorded")
	ui._on_back()
	await get_tree().create_timer(0.2, true).timeout

	# ── WINDOWS UPDATE easter egg ──
	var update: Dictionary = {}
	for p in GameManager.PUZZLES:
		if p.get("id", "") == "easter_windows_update":
			update = p
			break
	ui.show_puzzle(update, 0)
	_check(ui._task_type == "windows_update", "windows_update task detected")
	_check(ui._update_egg_bar != null, "progress bar present")
	_check(ui._kill_button != null, "kill switch present")
	ui._on_kill_update()
	_check(ui._last_correct, "kill switch solves the update")
	_check(ui._update_egg_bar.value >= 100.0, "update bar reaches 100% after kill")
	ui._on_back()
	await get_tree().create_timer(0.2, true).timeout

	ui.queue_free()
	_finish()

func _finish() -> void:
	if _failures.is_empty():
		print("EASTER EGG PROBE PASSED (%d)" % _passes)
		get_tree().quit(0)
	else:
		for f in _failures:
			print("FAIL: ", f)
		print("EASTER EGG PROBE FAILED: %d failure(s), %d passed" % [_failures.size(), _passes])
		get_tree().quit(1)
