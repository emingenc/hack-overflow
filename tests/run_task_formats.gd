extends Node
## Verifies the new TRACE and ORDER task formats render and complete.
## Runs each task type end-to-end via the real PuzzleUI.

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
	print("RUN START")
	var ui := PuzzleUI.new()
	add_child(ui)
	print("UI CREATED")

	# ── TRACE task ──
	var trace_puzzle: Dictionary = {}
	for p in GameManager.PUZZLES:
		if str(p.get("type", "")) == "trace":
			trace_puzzle = p
			break
	ui.show_puzzle(trace_puzzle)
	_check(ui._task_type == "trace", "trace task detected")
	_check(ui.puzzle.has("steps"), "trace has steps")
	var steps: Array = trace_puzzle["steps"]
	# Answer each step correctly in sequence.
	for step_idx in range(steps.size()):
		var ci: int = int(steps[step_idx]["correct_index"])
		ui._on_option_pressed(ci)
		await get_tree().create_timer(0.1, true).timeout
		ui._on_submit()
		await get_tree().create_timer(1.0, true).timeout  # wait for the 0.9s advance
	# After steps, synthesis capstone appears (if present).
	_check(ui._step_index >= steps.size(), "trace advanced past all steps")
	if trace_puzzle.has("synthesis"):
		var syn: Dictionary = trace_puzzle["synthesis"]
		var sci: int = int(syn["correct_index"])
		ui._on_option_pressed(sci)
		await get_tree().create_timer(0.1, true).timeout
		ui._on_submit()
		await get_tree().create_timer(0.2, true).timeout
		_check(ui._last_correct, "trace sets solved after synthesis")
	else:
		_check(ui._last_correct, "trace sets solved after final step")
	ui._on_back()
	await get_tree().create_timer(0.2, true).timeout
	_check(not get_tree().paused, "trace task unpauses on back")

	# ── ORDER task ──
	var order_puzzle: Dictionary = {}
	for p in GameManager.PUZZLES:
		if str(p.get("type", "")) == "order":
			order_puzzle = p
			break
	ui.show_puzzle(order_puzzle)
	_check(ui._task_type == "order", "order task detected")
	var correct_order: Array = order_puzzle["correct_order"]
	# Place each step in correct order via _on_order_pool_pressed.
	for slot in range(correct_order.size()):
		var step_idx: int = int(correct_order[slot])
		ui._on_order_pool_pressed(step_idx)
	await get_tree().create_timer(0.2, true).timeout
	_check(ui._order_placed == correct_order, "order steps placed")
	ui._on_submit()
	await get_tree().create_timer(0.2, true).timeout
	_check(ui._last_correct, "order task solved")
	ui._on_back()
	await get_tree().create_timer(0.2, true).timeout

	ui.queue_free()
	_finish()

func _finish() -> void:
	if _failures.is_empty():
		print("TASK FORMATS PASSED (%d)" % _passes)
		get_tree().quit(0)
	else:
		for f in _failures:
			print("FAIL: ", f)
		print("TASK FORMATS FAILED: %d failure(s), %d passed" % [_failures.size(), _passes])
		get_tree().quit(1)
