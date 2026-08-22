extends Control
## Main menu — isometric Blind-75 route map (Pokémon-style tree) + title + stats.

var _t: float = 0.0
var _title: Label

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
	if _title:
		var pulse := 0.85 + 0.15 * sin(_t * 2.0)
		_title.modulate = Color(1, 1, 1, pulse)
	# Parallax drift on the background layers (smooth oscillation, no wrap).
	for i in range(_parallax_layers.size()):
		var layer: TextureRect = _parallax_layers[i]
		var amp: float = [8.0, 16.0, 28.0][i]    # far→near (near moves more)
		var speed: float = [0.3, 0.5, 0.8][i]
		layer.position.x = _parallax_base_x[i] + sin(_t * speed + i) * amp

var _parallax_layers: Array[TextureRect] = []
var _parallax_base_x: Array[float] = []

## Layered tiled cyberpunk skyline with slow horizontal drift (depth cue).
func _spawn_parallax_bg() -> void:
	var texs := [
		preload("res://assets/warped/bg-3.png"),  # far skyline
		preload("res://assets/warped/bg-2.png"),  # mid buildings
		preload("res://assets/warped/bg-1.png"),  # near structures
	]
	var alphas := [0.55, 0.65, 0.7]
	var y_offsets := [40.0, 240.0, 520.0]
	for i in range(texs.size()):
		var layer := TextureRect.new()
		layer.texture = texs[i]
		layer.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
		layer.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		layer.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
		layer.set_anchors_preset(Control.PRESET_TOP_LEFT)
		layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		layer.modulate = Color(1, 1, 1, alphas[i])
		layer.position = Vector2(0, y_offsets[i])
		layer.custom_minimum_size = Vector2(get_viewport_rect().size.x + 60, texs[i].get_height() * 2.5)
		add_child(layer)
		_parallax_layers.append(layer)
		_parallax_base_x.append(0.0)

func _build_ui() -> void:
	# 3-layer parallax cyberpunk background (Warped City) + dark overlay.
	_spawn_parallax_bg()

	var bg := ColorRect.new()
	bg.color = Color(0.02, 0.03, 0.02, 0.45)  # lighter so the skyline shows through
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	# Title (top).
	_title = Label.new()
	_title.text = "HACK://OVERFLOW"
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 38)
	_title.add_theme_font_override("font", preload("res://assets/fonts/PressStart2P-Regular.ttf"))
	_title.add_theme_color_override("font_color", Color(0.1, 1.0, 0.3))
	_title.add_theme_color_override("font_shadow_color", Color(0.0, 0.3, 0.15, 0.8))
	_title.add_theme_constant_override("shadow_offset_x", 3)
	_title.add_theme_constant_override("shadow_offset_y", 3)
	_title.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_title.position.y = 30
	add_child(_title)

	var subtitle := Label.new()
	subtitle.text = "// walk the route  |  hack every firewall"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 18)
	subtitle.add_theme_font_override("font", preload("res://assets/fonts/VT323-Regular.ttf"))
	subtitle.add_theme_color_override("font_color", Color(0.4, 0.8, 0.45))
	subtitle.set_anchors_preset(Control.PRESET_TOP_WIDE)
	subtitle.position.y = 88
	add_child(subtitle)

	# Isometric route map — fills the screen, centers itself.
	var map: Control = preload("res://scripts/ui/route_map.gd").new()
	map.set_anchors_preset(Control.PRESET_FULL_RECT)
	map.category_launched.connect(_launch_category)
	add_child(map)

	# Stats (bottom).
	var stats := Label.new()
	stats.text = "BLIND 75 ROUTE  |  %d / %d SOLVED" % [_solved_total(), _total_puzzles()]
	stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats.add_theme_font_size_override("font_size", 16)
	stats.add_theme_font_override("font", preload("res://assets/fonts/VT323-Regular.ttf"))
	stats.add_theme_color_override("font_color", Color(0.5, 0.85, 0.65))
	stats.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	stats.position.y = -44
	add_child(stats)

	# Controls hint (bottom).
	var controls := Label.new()
	if DisplayServer.is_touchscreen_available():
		controls.text = "tap a node to hack  |  ◀ ▶ ▲  in-level"
	else:
		controls.text = "click a node to hack  |  A/D · W/SPACE · S dash · E hack"
	controls.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	controls.add_theme_font_size_override("font_size", 14)
	controls.add_theme_font_override("font", preload("res://assets/fonts/VT323-Regular.ttf"))
	controls.add_theme_color_override("font_color", Color(0.35, 0.7, 0.4))
	controls.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	controls.position.y = -20
	add_child(controls)

	# Quit (bottom-right).
	var quit_btn := Button.new()
	quit_btn.text = "QUIT"
	quit_btn.custom_minimum_size = Vector2(120, 40)
	quit_btn.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	quit_btn.position = Vector2(-140, -44)
	quit_btn.pressed.connect(func() -> void: get_tree().quit())
	add_child(quit_btn)

## Total puzzles across all categories.
func _total_puzzles() -> int:
	return GameManager.PUZZLES.size()

## Total solved puzzles (mastery > 0).
func _solved_total() -> int:
	var n := 0
	for p in GameManager.PUZZLES:
		if GameManager.mastery_for(p["id"]) > 0:
			n += 1
	return n

## Launch a level pinned to a specific Blind-75 category.
func _launch_category(cat: String) -> void:
	GameManager.pending_category = cat
	get_tree().change_scene_to_file(GameManager.LEVELS[0])
