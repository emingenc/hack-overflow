extends Node
## Verifies the firewall integrity economy:
##  - wrong answers drain integrity
##  - hint drains integrity
##  - at 0 on a non-tutorial level, the terminal locks (puzzle_locked fires)
##  - tutorial level (0) never locks

var _failures: Array[String] = []
var _passes: int = 0
var _locked: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_run()

func _check(cond: bool, msg: String) -> void:
	if cond:
		_passes += 1
	else:
		_failures.append(msg)

func _on_locked() -> void:
	_locked = true

## Pick a wrong option that isn't the correct one and isn't already locked.
func _pick_wrong(mcq: Dictionary, locked: Array) -> int:
	var correct: int = int(mcq["correct_index"])
	for i in range(mcq["options"].size()):
		if i != correct and not locked.has(i):
			return i
	return 0

func _run() -> void:
	var ui := PuzzleUI.new()
	add_child(ui)
	ui.puzzle_locked.connect(_on_locked)

	# Use a TRACE puzzle — wrong answers don't lock options, so integrity can
	# genuinely reach 0 (unlike MCQ where elimination caps at 3 wrongs).
	var trace: Dictionary = {}
	for p in GameManager.PUZZLES:
		if str(p.get("type", "")) == "trace":
			trace = p
			break
	ui.show_puzzle(trace, 1)
	_check(ui._integrity == 1.0, "integrity starts full")

	# Answer the first step wrong 4 times → 4 × 0.30 = 1.20 → locks.
	for n in range(4):
		var step: Dictionary = trace["steps"][ui._step_index]
		var wrong: int = 0
		if int(step["correct_index"]) == 0:
			wrong = 1
		ui._on_option_pressed(wrong)
		await get_tree().create_timer(0.1, true).timeout
		ui._on_submit()
		await get_tree().create_timer(0.2, true).timeout

	_check(_locked, "terminal locks after integrity hits 0")
	_check(ui._integrity <= 0.0, "integrity drained to 0 (got %.2f)" % ui._integrity)

	# Tutorial level never locks even at 0.
	_locked = false
	ui.show_puzzle(trace, 0)
	for n in range(5):
		var step: Dictionary = trace["steps"][ui._step_index]
		var wrong: int = 0
		if int(step["correct_index"]) == 0:
			wrong = 1
		ui._on_option_pressed(wrong)
		await get_tree().create_timer(0.1, true).timeout
		ui._on_submit()
		await get_tree().create_timer(0.2, true).timeout
	_check(not _locked, "tutorial level (0) never locks")
	_check(ui._integrity <= 0.0, "tutorial integrity still drains to 0")

	# Hint drains integrity.
	var ui2 := PuzzleUI.new()
	add_child(ui2)
	ui2.show_puzzle(trace, 1)
	var before: float = ui2._integrity
	ui2._on_hint()
	_check(ui2._integrity < before, "hint drains integrity")

	ui.queue_free()
	ui2.queue_free()
	_finish()

func _finish() -> void:
	if _failures.is_empty():
		print("INTEGRITY PROBE PASSED (%d)" % _passes)
		get_tree().quit(0)
	else:
		for f in _failures:
			print("FAIL: ", f)
		print("INTEGRITY PROBE FAILED: %d failure(s), %d passed" % [_failures.size(), _passes])
		get_tree().quit(1)
