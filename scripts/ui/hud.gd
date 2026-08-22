extends Control
## HUD — top bar showing sector name, chips, time. Level-complete overlay.

var level_index: int = 0
var level_name: String = "SECTOR_00"

var _chips_label: Label
var _time_label: Label
var _name_label: Label
var _complete_overlay: Control
var _combo_label: Label

func _ready() -> void:
	# Top bar
	var bar := PanelContainer.new()
	bar.position = Vector2(0, 0)
	bar.custom_minimum_size = Vector2(0, 44)
	bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	# Tint the panel background, NOT the node modulate — modulating the bar
	# multiplies every child label into near-black and blanks the HUD.
	var bar_style := StyleBoxFlat.new()
	bar_style.bg_color = Color(0.03, 0.09, 0.05, 0.92)
	bar_style.border_color = Color(0.0, 1.0, 0.25, 0.6)
	bar_style.set_border_width_all(1)
	bar_style.border_width_bottom = 3  # terminal separator line
	bar_style.shadow_color = Color(0.0, 1.0, 0.3, 0.35)
	bar_style.shadow_size = 12
	bar_style.shadow_offset = Vector2(0, 4)
	bar_style.content_margin_top = 5
	bar_style.content_margin_bottom = 5
	bar.add_theme_stylebox_override("panel", bar_style)
	add_child(bar)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 28)
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	bar.add_child(hbox)

	_name_label = Label.new()
	_name_label.text = "SECTOR: " + level_name
	_name_label.add_theme_font_size_override("font_size", 18)
	_name_label.add_theme_font_override("font", preload("res://assets/fonts/VT323-Regular.ttf"))
	_name_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.3))
	hbox.add_child(_name_label)

	_chips_label = Label.new()
	_chips_label.add_theme_font_size_override("font_size", 18)
	_chips_label.add_theme_font_override("font", preload("res://assets/fonts/VT323-Regular.ttf"))
	hbox.add_child(_chips_label)

	_time_label = Label.new()
	_time_label.add_theme_font_size_override("font_size", 18)
	_time_label.add_theme_font_override("font", preload("res://assets/fonts/VT323-Regular.ttf"))
	hbox.add_child(_time_label)

	# Combo streak label (floats under the top bar, hidden until 2+ chained).
	_combo_label = Label.new()
	_combo_label.add_theme_font_size_override("font_size", 22)
	_combo_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	_combo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_combo_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_combo_label.position.y = 56
	_combo_label.visible = false
	add_child(_combo_label)

	# Controls hint (bottom)
	var hint := Label.new()
	hint.text = "A/D or DPAD move · W/SPACE or A jump (double!) · S or X dash · E or B interact"
	hint.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	hint.grow_vertical = Control.GROW_DIRECTION_BEGIN
	hint.offset_top = -32
	hint.offset_bottom = -10
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 13)
	hint.add_theme_color_override("font_color", Color(0.45, 0.75, 0.5, 0.7))
	add_child(hint)

	update_chips(0, GameManager.chips_total[level_index])

func _process(delta: float) -> void:
	if _time_label:
		_time_label.text = "TIME %05.1f" % _elapsed()

func _elapsed() -> float:
	var level := get_tree().current_scene
	if level and level.has_method("_get_level_time"):
		return level._get_level_time()
	return 0.0

func update_chips(collected: int, total: int) -> void:
	if _chips_label:
		_chips_label.text = "CHIPS  %d/%d" % [collected, total]
		_chips_label.add_theme_color_override("font_color", Color(0.5, 1.0, 0.6))

func show_combo(n: int) -> void:
	if n < 2:
		_combo_label.visible = false
		return
	_combo_label.text = "COMBO x%d" % n
	_combo_label.visible = true
	_combo_label.scale = Vector2(1.25, 1.25)
	var tw := create_tween()
	tw.tween_property(_combo_label, "scale", Vector2.ONE, 0.12)

func clear_combo() -> void:
	_combo_label.visible = false

func show_complete(idx: int, time_seconds: float, chips: int, total: int) -> void:
	# Level complete overlay
	var overlay := ColorRect.new()
	overlay.color = Color(0.02, 0.06, 0.03, 0.9)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)

	# Terminal panel behind the result (matches the puzzle modal aesthetic).
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	var ps := StyleBoxFlat.new()
	ps.bg_color = Color(0.04, 0.09, 0.05, 0.97)
	ps.border_color = Color(0.0, 1.0, 0.3, 0.7)
	ps.set_border_width_all(3)
	ps.set_corner_radius_all(6)
	ps.shadow_color = Color(0.0, 1.0, 0.3, 0.5)
	ps.shadow_size = 36
	ps.content_margin_left = 48
	ps.content_margin_right = 48
	ps.content_margin_top = 28
	ps.content_margin_bottom = 28
	panel.add_theme_stylebox_override("panel", ps)
	add_child(panel)
	for spec in [[Control.PRESET_TOP_LEFT, "┌"], [Control.PRESET_TOP_RIGHT, "┐"], [Control.PRESET_BOTTOM_LEFT, "└"], [Control.PRESET_BOTTOM_RIGHT, "┘"]]:
		var l := Label.new()
		l.text = spec[1]
		l.add_theme_font_size_override("font_size", 22)
		l.add_theme_color_override("font_color", Color(0.0, 1.0, 0.3, 0.9))
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(l)
		l.set_anchors_and_offsets_preset(spec[0], Control.PRESET_MODE_MINSIZE)

	var center := VBoxContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_theme_constant_override("separation", 16)
	panel.add_child(center)

	var big := Label.new()
	big.text = "SECTOR CLEARED"
	big.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	big.add_theme_font_size_override("font_size", 42)
	big.add_theme_font_override("font", preload("res://assets/fonts/VT323-Regular.ttf"))
	big.add_theme_color_override("font_color", Color(0.4, 1.0, 0.6))
	center.add_child(big)

	var stats := Label.new()
	stats.text = "CHIPS %d/%d   ·   TIME %.1fs   ·   PUZZLE SOLVED" % [chips, total, time_seconds]
	stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats.add_theme_font_size_override("font_size", 18)
	stats.add_theme_font_override("font", preload("res://assets/fonts/VT323-Regular.ttf"))
	stats.add_theme_color_override("font_color", Color(0.75, 1.0, 0.6))
	center.add_child(stats)

	var next_btn := Button.new()
	next_btn.text = "NEXT SECTOR →" if idx + 1 < GameManager.LEVELS.size() else "RETURN TO HUB"
	next_btn.custom_minimum_size = Vector2(260, 52)
	next_btn.pressed.connect(func() -> void:
		if idx + 1 < GameManager.LEVELS.size():
			get_tree().change_scene_to_file(GameManager.LEVELS[idx + 1])
		else:
			get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
	)
	center.add_child(next_btn)

	var retry_btn := Button.new()
	retry_btn.text = "REPLAY SECTOR"
	retry_btn.custom_minimum_size = Vector2(260, 42)
	retry_btn.pressed.connect(func() -> void:
		get_tree().reload_current_scene()
	)
	center.add_child(retry_btn)
