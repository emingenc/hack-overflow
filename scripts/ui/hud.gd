extends Control
## HUD — top bar showing sector name, chips, time. Level-complete overlay.

var level_index: int = 0
var level_name: String = "SECTOR_00"

var _chips_label: Label
var _time_label: Label
var _name_label: Label
var _complete_overlay: Control

func _ready() -> void:
	# Top bar
	var bar := PanelContainer.new()
	bar.position = Vector2(0, 0)
	bar.custom_minimum_size = Vector2(0, 44)
	bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	bar.modulate = Color(0.08, 0.12, 0.28, 0.85)
	add_child(bar)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 28)
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	bar.add_child(hbox)

	_name_label = Label.new()
	_name_label.text = "SECTOR: " + level_name
	_name_label.add_theme_font_size_override("font_size", 15)
	_name_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.3))
	hbox.add_child(_name_label)

	_chips_label = Label.new()
	_chips_label.add_theme_font_size_override("font_size", 15)
	hbox.add_child(_chips_label)

	_time_label = Label.new()
	_time_label.add_theme_font_size_override("font_size", 15)
	hbox.add_child(_time_label)

	# Controls hint (bottom)
	var hint := Label.new()
	hint.text = "A/D or DPAD move · W/SPACE or A jump (double!) · S or X dash · E or B interact"
	hint.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	hint.position.y -= 4
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 12)
	hint.add_theme_color_override("font_color", Color(0.5, 0.6, 0.8, 0.7))
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

func show_complete(idx: int, time_seconds: float, chips: int, total: int) -> void:
	# Level complete overlay
	var overlay := ColorRect.new()
	overlay.color = Color(0.02, 0.05, 0.1, 0.9)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)

	var center := VBoxContainer.new()
	center.set_anchors_preset(Control.PRESET_CENTER)
	center.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_theme_constant_override("separation", 16)
	add_child(center)

	var big := Label.new()
	big.text = "SECTOR CLEARED ✓"
	big.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	big.add_theme_font_size_override("font_size", 42)
	big.add_theme_color_override("font_color", Color(0.4, 1.0, 0.6))
	center.add_child(big)

	var stats := Label.new()
	stats.text = "CHIPS %d/%d   ·   TIME %.1fs   ·   PUZZLE SOLVED" % [chips, total, time_seconds]
	stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats.add_theme_font_size_override("font_size", 18)
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
