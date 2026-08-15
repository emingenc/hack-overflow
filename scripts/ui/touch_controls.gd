extends CanvasLayer
## On-screen virtual controls for mobile/web touch.
## Bottom-left d-pad; bottom-right action row [HACK][DASH][JUMP].
## Sizes scale with viewport so hit targets stay >= 44px on real phones.
## Auto-hides while the puzzle UI is open.

var _buttons: Array[TouchButton] = []
var _visible: bool = true

func _ready() -> void:
	layer = 50
	if DisplayServer.is_touchscreen_available():
		_build_ui()
	get_viewport().size_changed.connect(func() -> void:
		if DisplayServer.is_touchscreen_available() and _buttons.is_empty():
			_build_ui()
		else:
			_reposition()
	)

func _build_ui() -> void:
	var vp := get_viewport().get_visible_rect().size
	var s := _scale()
	var pad := 12.0 * s

	# D-pad (bottom-left): cyan
	var left := _make_button("res://assets/sprites/ui_icon_left.svg", "move_left", Color(0.1, 0.7, 1.0), Color(0.5, 0.95, 1.0))
	left.size = Vector2(96 * s, 96 * s)
	left.position = Vector2(pad, vp.y - (96 * s) - pad)
	add_child(left)
	_buttons.append(left)

	var right := _make_button("res://assets/sprites/ui_icon_right.svg", "move_right", Color(0.1, 0.7, 1.0), Color(0.5, 0.95, 1.0))
	right.size = Vector2(96 * s, 96 * s)
	right.position = Vector2(pad + 104 * s, vp.y - (96 * s) - pad)
	add_child(right)
	_buttons.append(right)

	# Action row (bottom-right): HACK (small, left), DASH (mid), JUMP (big, rightmost)
	var btn := 86.0 * s
	var jump := _make_button("res://assets/sprites/ui_icon_jump.svg", "jump", Color(0.2, 0.9, 0.55), Color(0.6, 1.0, 0.8))
	jump.size = Vector2(btn, btn)
	jump.position = Vector2(vp.x - btn - pad, vp.y - btn - pad)
	add_child(jump)
	_buttons.append(jump)

	var dash := _make_button("res://assets/sprites/ui_icon_dash.svg", "dash", Color(1.0, 0.7, 0.15), Color(1.0, 0.9, 0.5))
	dash.size = Vector2(btn * 0.78, btn * 0.78)
	dash.position = Vector2(vp.x - btn - pad - btn * 0.78 - 10 * s, vp.y - btn - pad)
	add_child(dash)
	_buttons.append(dash)

	var act := _make_button("res://assets/sprites/ui_icon_hack.svg", "interact", Color(0.85, 0.35, 1.0), Color(1.0, 0.7, 1.0))
	act.size = Vector2(btn * 0.78, btn * 0.78)
	act.position = Vector2(vp.x - btn - pad - btn * 0.78 - 10 * s - btn * 0.78 - 10 * s, vp.y - btn - pad)
	add_child(act)
	_buttons.append(act)

	# Hide while puzzle UI is open (PuzzleLayer = 110, we're on 50)
	var puzzle_layer := get_node_or_null("/root/Level/PuzzleLayer")
	if puzzle_layer == null:
		puzzle_layer = get_tree().current_scene.get_node_or_null("PuzzleLayer")
	if puzzle_layer:
		puzzle_layer.child_entered_tree.connect(func(_c: Node) -> void: hide_controls())
		puzzle_layer.child_exiting_tree.connect(func(_c: Node) -> void: show_controls())

func _scale() -> float:
	var vp := get_viewport().get_visible_rect().size
	# Reference: 1280x720. On smaller phones scale down but floor at 0.55 so
	# buttons never drop below ~44px hit target.
	return clampf(minf(vp.x / 1280.0, vp.y / 720.0), 0.55, 1.15)

func _reposition() -> void:
	var vp := get_viewport().get_visible_rect().size
	var s := _scale()
	var pad := 12.0 * s
	if _buttons.size() < 5:
		return
	_buttons[0].position = Vector2(pad, vp.y - (96 * s) - pad)
	_buttons[1].position = Vector2(pad + 104 * s, vp.y - (96 * s) - pad)
	var btn := 86.0 * s
	_buttons[2].position = Vector2(vp.x - btn - pad, vp.y - btn - pad)
	_buttons[3].position = Vector2(vp.x - btn - pad - btn * 0.78 - 10 * s, vp.y - btn - pad)
	_buttons[4].position = Vector2(vp.x - btn - pad - btn * 0.78 - 10 * s - btn * 0.78 - 10 * s, vp.y - btn - pad)

func hide_controls() -> void:
	_visible = false
	for b in _buttons:
		b.visible = false
		b.release_action()

func show_controls() -> void:
	_visible = true
	for b in _buttons:
		b.visible = true

func _make_button(icon_path: String, action: String, base: Color, glow: Color) -> TouchButton:
	var btn := TouchButton.new()
	btn.action_name = action
	btn.custom_minimum_size = Vector2(60, 60)
	btn.mouse_filter = Control.MOUSE_FILTER_STOP

	var mat := ShaderMaterial.new()
	mat.shader = preload("res://assets/ui_button.gdshader")
	mat.set_shader_parameter("base_color", base)
	mat.set_shader_parameter("glow_color", glow)
	btn.material = mat

	var icon := TextureRect.new()
	icon.texture = load(icon_path)
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.set_anchors_preset(Control.PRESET_FULL_RECT)
	icon.offset_left = 20
	icon.offset_top = 20
	icon.offset_right = -20
	icon.offset_bottom = -20
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(icon)
	return btn


class TouchButton:
	extends Button
	## A button that simulates a held action while pressed (for touch/mobile).
	var action_name: String = ""
	var _pressed_tween: Tween

	func _init() -> void:
		toggle_mode = false
		button_down.connect(_on_down)
		button_up.connect(_on_up)
		visibility_changed.connect(func() -> void:
			if not visible:
				release_action()
		)

	func _on_down() -> void:
		Input.action_press(action_name)
		if material is ShaderMaterial:
			material.set_shader_parameter("pressed", 1.0)
		if _pressed_tween and _pressed_tween.is_valid():
			_pressed_tween.kill()
		_pressed_tween = create_tween()
		_pressed_tween.tween_property(self, "scale", Vector2(0.88, 0.88), 0.06)

	func _on_up() -> void:
		release_action()
		if material is ShaderMaterial:
			material.set_shader_parameter("pressed", 0.0)
		if _pressed_tween and _pressed_tween.is_valid():
			_pressed_tween.kill()
		_pressed_tween = create_tween()
		_pressed_tween.tween_property(self, "scale", Vector2.ONE, 0.10)

	func release_action() -> void:
		Input.action_release(action_name)
