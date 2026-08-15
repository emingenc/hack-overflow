extends Node
## MOBILE UX PROBE v3 (read-only) — runs via _mobile_ux_probe_runner_tmp.tscn.
## Answers: HUD/PuzzleUI camera-canvas membership, puzzle panel fit/centering,
## menu clipping, touch button CSS sizes at phone scales, firewall double-trigger.

var _info: Array[String] = []
var _fail: Array[String] = []

func _check(cond: bool, msg: String) -> void:
	if cond: _info.append("PASS: " + msg)
	else: _fail.append("FAIL: " + msg)

func _ready() -> void:
	_run()
	print("===== PROBE INFO =====")
	for l in _info: print("  " + l)
	if _fail.is_empty():
		print("===== PROBE: ALL CHECKS PASSED =====")
	else:
		print("===== PROBE FAILURES =====")
		for f in _fail: print("  " + f)
	get_tree().quit(0 if _fail.is_empty() else 1)

func _run() -> void:
	# ── 1. HUD / PuzzleUI canvas membership ────────────────────────
	var level := (load("res://scenes/levels/level_01_terminal.tscn") as PackedScene).instantiate()
	add_child(level)
	await get_tree().process_frame
	await get_tree().process_frame
	var hud: Control = level.get("_hud")
	var crt_layer: CanvasLayer = level.get_node_or_null("CRTLayer")
	var puzzle_ui: Control = level.get("_puzzle_ui")
	var player: Node2D = level.get("player")
	var cam: Camera2D = player.get_node_or_null("Camera2D") as Camera2D
	_info.append("camera zoom: %s" % cam.zoom)
	# After 2 frames the camera has set the viewport canvas transform:
	if hud:
		var g0: Transform2D = hud.get_global_transform()
		var g1: Transform2D = hud.get_global_transform_with_canvas()
		_info.append("HUD global origin: %s → canvas-space origin: %s (Δ=%s)" % [g0.origin, g1.origin, g1.origin - g0.origin])
		var bar: Control = hud.get_child(0)
		var br1: Rect2 = bar.get_global_rect_with_canvas_transform()
		_info.append("HUD top bar canvas-space rect: %s (top edge y=%.0f — screen y should be ~0 if fixed)" % [br1, br1.position.y])
		_check(br1.position.y >= -1.0 and br1.position.y < 2.0, "HUD top bar pinned to top of SCREEN (not scrolled by camera)")
		_check(bar.canvas_layer != 0 or absf(br1.size.y - 44.0) < 2.0, "HUD bar not scaled by camera zoom")
		# move the camera 300px right, re-measure
		var cam_before: Vector2 = cam.global_position
		cam.global_position.x += 300.0
		await get_tree().process_frame
		var br2: Rect2 = bar.get_global_rect_with_canvas_transform()
		_info.append("after cam +300px: HUD bar canvas rect y=%.0f..%.0f (before: y=%.0f..%.0f)" % [br2.position.y, br2.end.y, br1.position.y, br1.end.y])
		_check(absf(br2.position.y - br1.position.y) < 2.0, "HUD bar does NOT move when camera moves")
	else:
		_fail.append("FAIL: no HUD")
	_info.append("CRT overlay CanvasLayer.layer = %s" % (crt_layer.layer if crt_layer else -1))
	_info.append("PuzzleUI canvas_layer: %s (0 = world canvas → camera-affected)" % (puzzle_ui.canvas_layer if puzzle_ui else -1))

	# ── 2. Puzzle panel ────────────────────────────────────────────
	var firewall: FirewallTerminal = level.get("firewall")
	firewall.set("_in_range", true)
	firewall.set("_player", player)
	var emits: Array[int] = [0]
	firewall.puzzle_started.connect(func(_i): emits[0] += 1)
	var ev := InputEventKey.new()
	ev.physical_keycode = KEY_E
	ev.pressed = true
	firewall._unhandled_input(ev)
	_info.append("puzzle_started emissions after _unhandled_input(E): %d" % emits[0])
	Input.action_press("interact")
	var just_pressed: bool = Input.is_action_just_pressed("interact")
	Input.action_release("interact")
	_info.append("is_action_just_pressed('interact') true right after E event was handled? %s" % just_pressed)
	if just_pressed:
		_fail.append("FAIL: same-frame double trigger — _open_puzzle runs twice on desktop E (event + poll), puzzle re-randomizes")
	await get_tree().process_frame
	var ui: Control = level.get("_puzzle_ui")
	if ui and ui.visible:
		var panel: Control = ui.get_child(1) as Control
		var pr: Rect2 = panel.get_global_rect_with_canvas_transform()
		var vp := get_viewport().get_visible_rect()
		_info.append("puzzle panel canvas-space rect: %s; viewport: %s" % [pr, vp])
		_check(pr.size.x <= vp.size.x + 1.0 and pr.size.y <= vp.size.y + 1.0, "puzzle panel fits inside viewport")
		_check(absf((pr.position.x + pr.size.x / 2.0) - vp.size.x / 2.0) < 2.0, "panel horizontally centered")
		_check(absf((pr.position.y + pr.size.y / 2.0) - vp.size.y / 2.0) < 2.0, "panel vertically centered")
		var opts: VBoxContainer = ui.get("_options_box")
		if opts and opts.get_child_count() > 0:
			var b0: Control = opts.get_child(0)
			var br: Rect2 = b0.get_global_rect_with_canvas_transform()
			_info.append("option button canvas size: %s" % br.size)
			_check(br.size.y >= 44.0, "option button ≥ 44px on screen (desktop)")
		# total content height check (does the panel overflow a phone-height viewport?)
		var vbox: Control = panel.get_child(0).get_child(0)
		var total_h: float = 0.0
		for ch in vbox.get_children():
			total_h += ch.get_combined_minimum_size().y
		_info.append("puzzle panel minimum content height: %.0f game px (viewport 720)" % total_h)
	else:
		_fail.append("FAIL: puzzle UI did not open")
	level.queue_free()
	await get_tree().process_frame

	# ── 3. Menu clipping ───────────────────────────────────────────
	var menu := (load("res://scenes/main_menu.tscn") as PackedScene).instantiate()
	add_child(menu)
	await get_tree().process_frame
	var vbox2: VBoxContainer = menu.get_child(1) as VBoxContainer
	var vp2 := get_viewport().get_visible_rect()
	var vr := vbox2.get_global_rect()
	_info.append("menu VBox rect: %s; viewport: %s" % [vr, vp2])
	_check(vr.position.y >= 0.0 and vr.end.y <= vp2.size.y, "menu VBox fully inside viewport vertically")
	var lowest := 0.0
	for ch in vbox2.get_children():
		var r: Rect2 = ch.get_global_rect()
		lowest = maxf(lowest, r.end.y)
		_info.append("  menu child '%s' y..end: %.0f..%.0f (w=%.0f, h=%.0f)" % [ch.name, r.position.y, r.end.y, r.size.x, r.size.y])
	_check(lowest <= vp2.size.y, "no menu child extends below viewport (QUIT visible)")
	menu.queue_free()
	await get_tree().process_frame

	# ── 4. Touch buttons ───────────────────────────────────────────
	var tc: CanvasLayer = root.get_node("TouchControls")
	tc._build_ui()
	var sizes: Array = []
	for b in tc.get("_buttons"):
		sizes.append(b.size)
	_info.append("touch button sizes @1280x720 game px: %s" % sizes)
	# positions sanity: right cluster
	var positions: Array = []
	for b in tc.get("_buttons"):
		positions.append(b.position)
	_info.append("touch button positions: %s" % positions)
	for b in tc.get("_buttons"):
		b.queue_free()
	tc.get("_buttons").clear()
	var scale_land := minf(844.0 / 1280.0, 390.0 / 720.0)
	var scale_port := minf(390.0 / 1280.0, 844.0 / 720.0)
	var scale_land_big := minf(932.0 / 1280.0, 430.0 / 720.0)
	_info.append("phone scales: landscape 844x390 → %.3f | portrait 390x844 → %.3f | big landscape 932x430 → %.3f" % [scale_land, scale_port, scale_land_big])
	for entry in [["landscape", scale_land], ["portrait", scale_port], ["big-landscape", scale_land_big]]:
		var out: Array = []
		for sz in sizes:
			out.append(int(sz.x * entry[1]))
		_info.append("  %s: button CSS px = %s (44px target)" % [entry[0], out])
		for i in range(sizes.size()):
			if sizes[i].x * entry[1] < 44.0:
				_fail.append("FAIL: button %d is %d CSS px < 44px at %s" % [i, int(sizes[i].x * entry[1]), entry[0]])

	# ── 5. Firewall prompt ─────────────────────────────────────────
	var lvl2 := (load("res://scenes/levels/level_02_servers.tscn") as PackedScene).instantiate()
	add_child(lvl2)
	await get_tree().process_frame
	var fw2: FirewallTerminal = lvl2.get("firewall")
	if fw2:
		var prompt: Label = fw2.get_node("Prompt")
		_info.append("firewall prompt: '%s' font=%d, position=%s (world space, camera zoom 3)" % [prompt.text, prompt.get_theme_font_size("font_size"), prompt.position])
	lvl2.queue_free()
