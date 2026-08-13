extends CanvasLayer
## On-screen virtual controls for mobile/web touch.
## Adds a d-pad (left/right), jump, dash, and interact buttons.
## Auto-shows only when a touchscreen is detected (mobile browsers / Android).

var _buttons: Array[TouchButton] = []

func _ready() -> void:
	layer = 50
	if DisplayServer.is_touchscreen_available():
		_build_ui()
	get_viewport().size_changed.connect(func() -> void:
		if DisplayServer.is_touchscreen_available() and _buttons.is_empty():
			_build_ui()
	)

func _build_ui() -> void:
	var vp := get_viewport().get_visible_rect().size

	var left := _make_button("res://assets/sprites/ui_icon_left.svg", "move_left")
	left.position = Vector2(28, vp.y - 168)
	left.size = Vector2(92, 92)
	add_child(left)
	_buttons.append(left)

	var right := _make_button("res://assets/sprites/ui_icon_right.svg", "move_right")
	right.position = Vector2(132, vp.y - 168)
	right.size = Vector2(92, 92)
	add_child(right)
	_buttons.append(right)

	var jump := _make_button("res://assets/sprites/ui_icon_jump.svg", "jump")
	jump.position = Vector2(vp.x - 196, vp.y - 196)
	jump.size = Vector2(104, 104)
	add_child(jump)
	_buttons.append(jump)

	var dash := _make_button("res://assets/sprites/ui_icon_dash.svg", "dash")
	dash.position = Vector2(vp.x - 84, vp.y - 168)
	dash.size = Vector2(68, 68)
	add_child(dash)
	_buttons.append(dash)

	var act := _make_button("res://assets/sprites/ui_icon_hack.svg", "interact")
	act.position = Vector2(vp.x - 120, vp.y - 320)
	act.size = Vector2(80, 80)
	add_child(act)
	_buttons.append(act)

	get_viewport().size_changed.connect(_reposition)

func _reposition() -> void:
	var vp := get_viewport().get_visible_rect().size
	if _buttons.size() < 5:
		return
	_buttons[0].position = Vector2(28, vp.y - 168)
	_buttons[1].position = Vector2(132, vp.y - 168)
	_buttons[2].position = Vector2(vp.x - 196, vp.y - 196)
	_buttons[3].position = Vector2(vp.x - 84, vp.y - 168)
	_buttons[4].position = Vector2(vp.x - 120, vp.y - 320)

func _make_button(icon_path: String, action: String) -> TouchButton:
	var btn := TouchButton.new()
	btn.action_name = action
	btn.custom_minimum_size = Vector2(60, 60)
	btn.mouse_filter = Control.MOUSE_FILTER_STOP

	# Glassy neon circle base
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.9, 1.0, 0.18)
	style.corner_radius_top_left = 48
	style.corner_radius_top_right = 48
	style.corner_radius_bottom_left = 48
	style.corner_radius_bottom_right = 48
	style.border_color = Color(0.3, 0.95, 1.0, 0.55)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	btn.add_theme_stylebox_override("normal", style)

	var pressed := style.duplicate()
	pressed.bg_color = Color(0.1, 0.9, 1.0, 0.4)
	pressed.border_color = Color(0.6, 1.0, 1.0, 0.9)
	pressed.border_width_left = 3
	pressed.border_width_top = 3
	pressed.border_width_right = 3
	pressed.border_width_bottom = 3
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_stylebox_override("hover", style)

	# Icon texture centered
	var icon := TextureRect.new()
	icon.texture = load(icon_path)
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.set_anchors_preset(Control.PRESET_FULL_RECT)
	icon.offset_left = 14
	icon.offset_top = 14
	icon.offset_right = -14
	icon.offset_bottom = -14
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(icon)
	return btn


class TouchButton:
	extends Button
	## A button that simulates a held action while pressed (for touch/mobile).
	var action_name: String = ""

	func _init() -> void:
		toggle_mode = false
		button_down.connect(func() -> void: Input.action_press(action_name))
		button_up.connect(func() -> void: Input.action_release(action_name))
		visibility_changed.connect(func() -> void:
			if not visible:
				Input.action_release(action_name)
		)
