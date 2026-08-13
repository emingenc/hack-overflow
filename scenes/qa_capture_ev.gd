extends Node
## Evaluator capture: loads menu + each level, waits for render, saves PNGs, quits.
## Run: godot --path . res://scenes/qa_capture.tscn  (this script is injected via scene override)

func _ready() -> void:
	await get_tree().process_frame
	# 1) Main menu
	var menu := load("res://scenes/main_menu.tscn").instantiate()
	add_child(menu)
	await get_tree().create_timer(0.8).timeout
	await _shot("menu")
	menu.queue_free()

	# 2) Each level
	for i in range(3):
		var path := "res://scenes/levels/level_0%d_%s.tscn" % [i + 1, ["terminal", "servers", "core"][i]]
		var lvl := load(path).instantiate()
		add_child(lvl)
		await get_tree().create_timer(0.7).timeout
		await _shot("level%d" % (i + 1))
		lvl.queue_free()
		await get_tree().process_frame

	get_tree().quit()

func _shot(tag: String) -> void:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var p := "/tmp/ev_%s.png" % tag
	img.save_png(p)
	print("SAVED ", p)
