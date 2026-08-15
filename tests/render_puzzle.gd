extends Node
## Captures the puzzle UI directly to a PNG for visual inspection.
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_run()

func _run() -> void:
	await get_tree().process_frame
	var ui := PuzzleUI.new()
	add_child(ui)
	var mcq: Dictionary = {}
	for p in GameManager.PUZZLES:
		if str(p.get("type", "mcq")) == "mcq":
			mcq = p
			break
	ui.show_puzzle(mcq, 0)
	await get_tree().create_timer(0.5, true).timeout
	await get_tree().process_frame
	# Capture viewport to PNG
	var img := get_viewport().get_texture().get_image()
	img.save_png("res://../puzzle_capture.png")
	print("CAPTURED puzzle_capture.png, size=", img.get_width(), "x", img.get_height())
	get_tree().quit(0)
