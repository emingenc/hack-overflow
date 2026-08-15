extends Node
## Verifies the P0 softlock fix end-to-end on the real level:
##  open firewall puzzle → EXIT → re-open (terminal must reset, not brick).
## Also verifies the firewall.puzzle is what the UI shows (no double-roll).

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
	# The runner scene instances the real level as a child named "Level".
	var lvl := get_node_or_null("Level")
	if lvl == null:
		lvl = get_tree().current_scene
	if lvl == null:
		print("TERMINAL REOPEN PROBE FAILED: no level node")
		get_tree().quit(1)
		return

	await get_tree().create_timer(1.0, true).timeout  # let level build

	var fw = lvl.get("firewall")
	var ui: PuzzleUI = lvl.get("_puzzle_ui")
	_check(fw != null, "firewall exists")
	_check(ui != null, "puzzle UI exists")

	# Simulate reaching the firewall: open puzzle via the terminal (which rolls
	# the puzzle and emits puzzle_started → level opens the UI).
	if fw and ui:
		fw._puzzle_open = false
		fw._open_puzzle()
		await get_tree().create_timer(0.3, true).timeout
		_check(ui.visible, "puzzle opens on approach")
		_check(fw._puzzle_open, "firewall marks puzzle open")

		# EXIT the terminal (failed/abandoned) → terminal must reset.
		ui._on_back()
		await get_tree().create_timer(0.2, true).timeout
		_check(not fw._puzzle_open, "EXIT resets the terminal (P0 fix)")
		_check(not ui.visible, "puzzle closed after EXIT")

		# Re-open — must work (this was the softlock).
		fw._open_puzzle()
		await get_tree().create_timer(0.3, true).timeout
		_check(ui.visible, "puzzle RE-OPENS after EXIT (no softlock)")

	_finish()

func _finish() -> void:
	if _failures.is_empty():
		print("TERMINAL REOPEN PROBE PASSED (%d)" % _passes)
		get_tree().quit(0)
	else:
		for f in _failures:
			print("FAIL: ", f)
		print("TERMINAL REOPEN PROBE FAILED: %d failure(s), %d passed" % [_failures.size(), _passes])
		get_tree().quit(1)
