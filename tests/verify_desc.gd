extends Node
## Verifies the puzzle description renders the FULL question text (brackets intact).
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_run()

func _run() -> void:
	await get_tree().process_frame
	var ui := PuzzleUI.new()
	add_child(ui)
	# Use an MCQ with brackets in the description (merge_intervals or two_sum).
	var mcq: Dictionary = {}
	for p in GameManager.PUZZLES:
		if p.get("id", "") == "merge_intervals":
			mcq = p
			break
	if mcq.is_empty():
		for p in GameManager.PUZZLES:
			if str(p.get("type", "mcq")) == "mcq":
				mcq = p
				break
	ui.show_puzzle(mcq, 0)
	await get_tree().create_timer(0.3, true).timeout
	var desc: String = ui._desc_label.text
	var passed: bool = desc.contains("merge") or desc.contains("intervals") or desc.contains("[")
	print("DESC_TEXT=", desc)
	if desc.contains("[") and desc.contains("]"):
		print("BRACKETS INTACT: PASS")
	else:
		print("BRACKETS INTACT: FAIL (brackets stripped)")
	get_tree().quit(0)
