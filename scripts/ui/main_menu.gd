extends Control
## Main menu — title, level select (locked/unlocked), controls, quit.

var _levels_box: VBoxContainer
var _t: float = 0.0
var _title: Label
var _glow: ColorRect

func _ready() -> void:
	_build_ui()
	_spawn_post()

## Full-screen post stack (matches the in-level look: bloom + scanlines + dither + vignette).
func _spawn_post() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 100
	layer.name = "CRTLayer"
	add_child(layer)
	var crt := ColorRect.new()
	crt.color = Color.WHITE
	crt.set_anchors_preset(Control.PRESET_FULL_RECT)
	crt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	crt.material = ShaderMaterial.new()
	crt.material.shader = preload("res://assets/crt_overlay.gdshader")
	crt.name = "CRTOverlay"
	layer.add_child(crt)

func _process(delta: float) -> void:
	_t += delta
	# Subtle title pulse
	if _title:
		var pulse := 0.85 + 0.15 * sin(_t * 2.0)
		_title.modulate = Color(1, 1, 1, pulse)
	# Moving scanline on the glow bar
	if _glow:
		_glow.position.x = 640 - 200 + sin(_t * 0.7) * 140

func _build_ui() -> void:
	# Background: cyberpunk cityscape (parallax feel) + dark overlay
	var bg_img := TextureRect.new()
	bg_img.texture = preload("res://assets/sprites/city_bg.svg")
	bg_img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	bg_img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg_img.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg_img.modulate = Color(1, 1, 1, 0.55)
	bg_img.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg_img)

	var bg := ColorRect.new()
	bg.color = Color(0.02, 0.03, 0.02, 0.82)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	# Accent glow bar under title (animated)
	_glow = ColorRect.new()
	_glow.size = Vector2(400, 3)
	_glow.position = Vector2(440, 150)
	_glow.color = Color(0.0, 1.0, 0.25, 0.5)
	add_child(_glow)

	var center := VBoxContainer.new()
	center.set_anchors_preset(Control.PRESET_CENTER)
	center.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_theme_constant_override("separation", 16)
	add_child(center)

	# Title with layered glow (drop-shadow feel)
	_title = Label.new()
	_title.text = "HACK://OVERFLOW"
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 44)
	_title.add_theme_font_override("font", preload("res://assets/fonts/PressStart2P-Regular.ttf"))
	_title.add_theme_color_override("font_color", Color(0.1, 1.0, 0.3))
	_title.add_theme_color_override("font_shadow_color", Color(0.0, 0.3, 0.15, 0.8))
	_title.add_theme_constant_override("shadow_offset_x", 3)
	_title.add_theme_constant_override("shadow_offset_y", 3)
	center.add_child(_title)

	var subtitle := Label.new()
	subtitle.text = "// a platformer where every firewall demands an algorithm"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 20)
	subtitle.add_theme_color_override("font_color", Color(0.4, 0.8, 0.45))
	center.add_child(subtitle)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 14)
	center.add_child(spacer)

	_levels_box = VBoxContainer.new()
	_levels_box.add_theme_constant_override("separation", 10)
	center.add_child(_levels_box)
	_rebuild_levels()

	var controls := Label.new()
	if DisplayServer.is_touchscreen_available():
		controls.text = "◀ ▶ move  ·  ▲ jump (double!)  ·  ⚡ dash  ·  ✦ hack"
	else:
		controls.text = "A/D move  ·  W/SPACE jump (double)  ·  S dash  ·  E hack"
	controls.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	controls.add_theme_font_size_override("font_size", 18)
	controls.add_theme_color_override("font_color", Color(0.35, 0.75, 0.4))
	center.add_child(controls)

	var stats := Label.new()
	stats.text = "PUZZLES SOLVED: %d/%d   ·   BEST: %s" % [
		GameManager.puzzles_solved.count(true),
		GameManager.LEVELS.size(),
		_format_best()
	]
	stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats.add_theme_font_size_override("font_size", 13)
	stats.add_theme_color_override("font_color", Color(0.5, 0.85, 0.65))
	center.add_child(stats)

	var quit_btn := Button.new()
	quit_btn.text = "QUIT"
	quit_btn.custom_minimum_size = Vector2(200, 38)
	quit_btn.pressed.connect(func() -> void: get_tree().quit())
	quit_btn.add_theme_stylebox_override("normal", _style(Color(0.04, 0.09, 0.06), Color(0.3, 0.45, 0.3, 0.15)))
	quit_btn.add_theme_stylebox_override("hover", _style(Color(0.04, 0.12, 0.08), Color(0.0, 1.0, 0.25, 0.35)))
	quit_btn.add_theme_stylebox_override("pressed", _style(Color(0.03, 0.06, 0.04), Color(0.0, 1.0, 0.25, 0.5)))
	center.add_child(quit_btn)

func _rebuild_levels() -> void:
	for child in _levels_box.get_children():
		child.queue_free()
	var names := ["SECTOR 01 — THE TERMINAL", "SECTOR 02 — SERVER FARM", "SECTOR 03 — THE CORE"]
	for i in range(GameManager.LEVELS.size()):
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(440, 54)
		var unlocked := GameManager.is_level_unlocked(i)
		if unlocked:
			btn.text = "▶  " + names[i]
			btn.pressed.connect(func() -> void:
				get_tree().change_scene_to_file(GameManager.LEVELS[i]))
			btn.add_theme_stylebox_override("normal", _style(Color(0.04, 0.12, 0.08), Color(0.0, 1.0, 0.25, 0.3)))
			btn.add_theme_stylebox_override("hover", _style(Color(0.05, 0.16, 0.10), Color(0.2, 1.0, 0.35, 0.5)))
			btn.add_theme_stylebox_override("pressed", _style(Color(0.03, 0.08, 0.05), Color(0.0, 1.0, 0.25, 0.7)))
			btn.add_theme_color_override("font_color", Color(0.75, 1.0, 0.6))
		else:
			btn.text = "⛨  " + names[i] + "   —  solve previous sector"
			btn.disabled = true
			btn.add_theme_stylebox_override("normal", _style(Color(0.03, 0.06, 0.04), Color(0.2, 0.35, 0.25, 0.15)))
			btn.add_theme_color_override("font_color", Color(0.25, 0.5, 0.3))
		btn.add_theme_font_size_override("font_size", 18)
		_levels_box.add_child(btn)

func _style(color: Color, border: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.border_color = border
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(10)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	return sb

func _format_best() -> String:
	var parts: Array[String] = []
	for t in GameManager.best_times:
		parts.append("--" if t < 0.0 else "%.1fs" % t)
	return " | ".join(parts)
