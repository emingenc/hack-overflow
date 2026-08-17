extends CanvasLayer
## On-screen virtual controls for mobile/web touch.
## Movement: VirtualJoystick (MarcoFazioRandom/Virtual-Joystick-Godot, MIT) —
##   analog left/right with dead zone + multitouch. Don't reinvent the wheel.
## Actions: jump / dash / hack buttons (the joystick library only does movement).
## Auto-hides while the puzzle UI is open.

var _joystick: Control = null
var _buttons: Array[TouchButton] = []
var _visible: bool = true

func _ready() -> void:
	layer = 50
	if _is_touch_device():
		_build_ui()
	get_viewport().size_changed.connect(func() -> void:
		if _is_touch_device() and _joystick == null:
			_build_ui()
		else:
			_reposition()
	)

## Show virtual controls only on touch-primary devices (mobile/tablet).
## Desktop PCs — even touch-capable laptops or browsers that report a
## touchscreen — should not get on-screen buttons.
func _is_touch_device() -> bool:
	var os_name := OS.get_name()
	if os_name == "Android" or os_name == "iOS":
		return true
	if os_name == "Web":
		# pointer:coarse = touch (mobile/tablet); pointer:fine = mouse (PC).
		if ClassDB.class_exists("JavaScriptBridge"):
			return bool(JavaScriptBridge.eval("window.matchMedia('(pointer: coarse)').matches", true))
		return DisplayServer.is_touchscreen_available()
	return false

func _build_ui() -> void:
	var vp := get_viewport().get_visible_rect().size
	var s := _scale()
	var pad := 12.0 * s

	# ── Movement: the battle-tested VirtualJoystick (left side) ──────────
	_joystick = preload("res://addons/virtual_joystick/virtual_joystick_scene.tscn").instantiate()
	_joystick.use_input_actions = true
	_joystick.action_left = "move_left"
	_joystick.action_right = "move_right"
	_joystick.action_up = ""     # platformer — no vertical movement
	_joystick.action_down = ""
	_joystick.joystick_mode = _joystick.Joystick_mode.FIXED
	_joystick.visibility_mode = _joystick.Visibility_mode.ALWAYS
	# Scale the whole joystick to fit the phone's bottom-left corner.
	_joystick.scale = Vector2(s, s)
	_joystick.position = Vector2(pad, vp.y - 220.0 * s - pad)
	# Anchor the joystick area to bottom-left.
	_joystick.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_joystick.position = Vector2(pad, -220.0 * s - pad)
	add_child(_joystick)

	# ── Action row (bottom-right): HACK (small, left), DASH (mid), JUMP (big) ──
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

	var act := _make_button("res://assets/sprites/ui_icon_hack.svg", "interact", Color(0.31, 0.31, 0.67), Color(0.5, 0.5, 0.8))
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
	if _joystick:
		_joystick.scale = Vector2(s, s)
		_joystick.position = Vector2(pad, -220.0 * s - pad)
	if _buttons.size() < 3:
		return
	var btn := 86.0 * s
	_buttons[0].position = Vector2(vp.x - btn - pad, vp.y - btn - pad)
	_buttons[1].position = Vector2(vp.x - btn - pad - btn * 0.78 - 10 * s, vp.y - btn - pad)
	_buttons[2].position = Vector2(vp.x - btn - pad - btn * 0.78 - 10 * s - btn * 0.78 - 10 * s, vp.y - btn - pad)

func hide_controls() -> void:
	_visible = false
	if _joystick:
		_joystick.visible = false
	for b in _buttons:
		b.visible = false
		b.release_action()

func show_controls() -> void:
	_visible = true
	if _joystick:
		_joystick.visible = true
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
