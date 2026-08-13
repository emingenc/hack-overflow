extends Control
## Main menu — title, level select (locked/unlocked), controls, quit.

var _levels_box: VBoxContainer

func _ready() -> void:
	_build_ui()

func _build_ui() -> void:
	# Background grid feel
	var bg := ColorRect.new()
	bg.color = Color(0.02, 0.03, 0.05, 1.0)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var center := VBoxContainer.new()
	center.set_anchors_preset(Control.PRESET_CENTER)
	center.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_theme_constant_override("separation", 18)
	add_child(center)

	var title := Label.new()
	title.text = "HACK://OVERFLOW"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 56)
	title.add_theme_color_override("font_color", Color(0.0, 0.9, 1.0))
	center.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "A platformer where every firewall demands an algorithm."
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 16)
	subtitle.add_theme_color_override("font_color", Color(0.6, 0.7, 0.9))
	center.add_child(subtitle)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 16)
	center.add_child(spacer)

	_levels_box = VBoxContainer.new()
	_levels_box.add_theme_constant_override("separation", 10)
	center.add_child(_levels_box)

	_rebuild_levels()

	var controls := Label.new()
	controls.text = "A/D move   W/SPACE jump (double)   S dash   E interact"
	controls.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	controls.add_theme_font_size_override("font_size", 13)
	controls.add_theme_color_override("font_color", Color(0.4, 0.5, 0.7))
	center.add_child(controls)

	var stats := Label.new()
	stats.text = "PUZZLES SOLVED: %d/%d   ·   BEST: %s" % [
		GameManager.puzzles_solved.count(true),
		GameManager.LEVELS.size(),
		_format_best()
	]
	stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats.add_theme_font_size_override("font_size", 13)
	stats.add_theme_color_override("font_color", Color(0.5, 0.8, 0.6))
	center.add_child(stats)

	var quit_btn := Button.new()
	quit_btn.text = "QUIT"
	quit_btn.custom_minimum_size = Vector2(200, 40)
	quit_btn.pressed.connect(func() -> void: get_tree().quit())
	center.add_child(quit_btn)

func _rebuild_levels() -> void:
	for child in _levels_box.get_children():
		child.queue_free()
	var names := ["SECTOR 01: THE TERMINAL", "SECTOR 02: SERVER FARM", "SECTOR 03: THE CORE"]
	for i in range(GameManager.LEVELS.size()):
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(420, 52)
		var unlocked := GameManager.is_level_unlocked(i)
		if unlocked:
			btn.text = "▶  " + names[i]
			btn.pressed.connect(func() -> void:
				get_tree().change_scene_to_file(GameManager.LEVELS[i]))
			btn.add_theme_stylebox_override("normal", _style(Color(0.1, 0.16, 0.38)))
			btn.add_theme_stylebox_override("hover", _style(Color(0.14, 0.22, 0.5)))
		else:
			btn.text = "🔒  " + names[i] + "  —  SOLVE PREVIOUS SECTOR"
			btn.disabled = true
			btn.add_theme_stylebox_override("normal", _style(Color(0.08, 0.1, 0.18)))
		btn.add_theme_font_size_override("font_size", 18)
		_levels_box.add_child(btn)

func _style(color: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.border_color = Color(0.0, 0.9, 1.0, 0.3)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(8)
	return sb

func _format_best() -> String:
	var parts: Array[String] = []
	for t in GameManager.best_times:
		parts.append("--" if t < 0.0 else "%.1fs" % t)
	return " | ".join(parts)
