extends Node
## QA capture: loads the level, waits for render, saves viewport PNGs, quits.
## Run: godot --path . res://scenes/qa_capture.tscn

var shot_count := 0

func _ready() -> void:
	var level_scene := load("res://scenes/levels/level_01_terminal.tscn")
	var level := level_scene.instantiate()
	add_child(level)
	await get_tree().process_frame
	await get_tree().create_timer(1.0).timeout
	_capture("level1_topdown")
	# Simulate a couple of frames of player physics
	var player := level.get("player")
	if player:
		player.set("velocity", Vector2(100, 0))
	await get_tree().create_timer(0.5).timeout
	_capture("level1_moving")
	get_tree().quit()

func _capture(name: String) -> void:
	var img := get_viewport().get_texture().get_image()
	var path := "/tmp/%s.png" % name
	img.save_png(path)
	print("SAVED: ", path)
