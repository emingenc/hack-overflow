extends Node
## EVALUATOR headless functional probe v2 — progress markers + watchdog.

var _results: Array[String] = []

func _report(tag: String, ok: bool, detail: String = "") -> void:
	_results.append("%s|%s|%s" % [tag, "PASS" if ok else "FAIL", detail])
	print("[EV] %s %s %s" % [tag, "PASS" if ok else "FAIL", detail])

func _ready() -> void:
	# Watchdog: force quit after 45s so we never hang the harness
	var wd := Timer.new()
	wd.one_shot = true
	wd.wait_time = 45.0
	wd.timeout.connect(func() -> void:
		print("=====EVAL SUMMARY=====")
		for r in _results:
			print(r)
		get_tree().quit())
	add_child(wd)
	wd.start()
	print("[EV] marker: start")
	await get_tree().process_frame
	print("[EV] marker: frame1")
	await _probe_menu()
	print("[EV] marker: menu done")
	await _probe_level(0)
	print("[EV] marker: L1 done")
	await _probe_level(1)
	print("[EV] marker: L2 done")
	await _probe_level(2)
	print("[EV] marker: L3 done")
	print("=====EVAL SUMMARY=====")
	for r in _results:
		print(r)
	get_tree().quit()

func _probe_menu() -> void:
	var menu: Node = load("res://scenes/main_menu.tscn").instantiate()
	add_child(menu)
	await get_tree().process_frame
	print("[EV] marker: menu instantiated")
	var btns: Array = []
	_find_buttons(menu, btns)
	var unlocked_btns := 0
	var locked_btns := 0
	for b in btns:
		if b.text.contains("🔒"):
			locked_btns += 1
		elif b.text.contains("▶"):
			unlocked_btns += 1
	_report("menu_buttons", btns.size() >= 4 and unlocked_btns >= 1 and locked_btns >= 2,
		"total=%d unlocked=%d locked=%d" % [btns.size(), unlocked_btns, locked_btns])
	menu.queue_free()
	await get_tree().process_frame

func _find_buttons(node: Node, out: Array) -> void:
	if node is Button:
		out.append(node)
	for c in node.get_children():
		_find_buttons(c, out)

func _probe_level(idx: int) -> void:
	var paths := ["level_01_terminal.tscn", "level_02_servers.tscn", "level_03_core.tscn"]
	var lvl: Node = load("res://scenes/levels/" + paths[idx]).instantiate()
	add_child(lvl)
	await get_tree().process_frame
	var tag := "L%d" % (idx + 1)
	print("[EV] marker: %s loaded" % tag)

	var player := lvl.get("player") as CharacterBody2D
	_report(tag + "_player_spawn", player != null, "pos=%s" % (str(player.position) if player else "none"))

	var hud := lvl.get("_hud") as Control
	var bar_count := 0
	if hud:
		for c in hud.get_children():
			if c is PanelContainer:
				bar_count += 1
	_report(tag + "_hud_duplicate", bar_count == 1, "top bars=%d (expect 1)" % bar_count)

	var portal := lvl.get("exit_portal") as Area2D
	var fw := lvl.get("firewall") as Area2D
	var portal_behind := false
	if portal and fw:
		portal_behind = portal.position.x < fw.position.x
	_report(tag + "_exit_after_firewall", not portal_behind,
		"exit.x=%.0f firewall.x=%.0f (exit must be AFTER firewall)" % [portal.position.x, fw.position.x])

	var turret: Node = _find_first(lvl, "FirewallTurret")
	var projs: Array = []
	if turret:
		var t0 := Time.get_ticks_msec()
		while Time.get_ticks_msec() - t0 < 2500:
			await get_tree().physics_frame
		_scan_type(lvl, "EnemyProjectile", projs)
		print("[EV] marker: %s projectiles=%d" % [tag, projs.size()])
		var sprites := 0
		var shapes := 0
		for p in projs:
			for c in p.get_children():
				if c is Sprite2D: sprites += 1
				if c is CollisionShape2D: shapes += 1
		_report(tag + "_projectile_exists", projs.size() > 0, "projectiles spawned=%d" % projs.size())
		_report(tag + "_projectile_visible", projs.size() > 0 and sprites == projs.size(), "with sprite=%d/%d" % [sprites, projs.size()])
		_report(tag + "_projectile_hittable", projs.size() > 0 and shapes == projs.size(), "with collision=%d/%d" % [shapes, projs.size()])
	else:
		_report(tag + "_projectile_exists", false, "no FirewallTurret found")

	if player:
		var start_y := player.position.y
		player.velocity = Vector2(0, -560.0)
		var min_y := start_y
		for i in range(120):
			player.move_and_slide()
			min_y = minf(min_y, player.position.y)
		var jump_h := start_y - min_y
		_report(tag + "_jump_height", absf(jump_h - 104.0) < 8.0, "single jump height=%.1fpx (expect ~104)" % jump_h)

	# Fall-off-map softlock probe
	if player:
		var map_h: int = lvl.call("_map_pixel_height")
		player.position = Vector2(100.0, float(map_h) + 400.0)
		player.velocity = Vector2.ZERO
		var recovered := false
		for i in range(150):
			await get_tree().physics_frame
			if not is_instance_valid(player):
				recovered = true
				break
		_report(tag + "_fall_respawn", recovered, "player below map 2.5s: respawned=%s (false=softlock)" % str(recovered))

	# Puzzle flow
	var ui := lvl.get("_puzzle_ui") as Control
	var exit := lvl.get("exit_portal") as Area2D
	if ui and exit:
		var pdata: Dictionary = GameManager.get_puzzle_for_level(idx)
		var correct_idx: int = int(pdata.correct_index)
		ui.show_puzzle(pdata)
		_report(tag + "_puzzle_ui_visible", ui.visible, "puzzle UI shows on interact")
		ui._on_option_pressed(correct_idx)
		ui._on_submit()
		await get_tree().create_timer(2.2).timeout
		_report(tag + "_puzzle_solve_unlocks", exit.monitoring == true, "exit.monitoring after correct=%s" % str(exit.monitoring))

	lvl.queue_free()
	await get_tree().process_frame

func _find_first(node: Node, type_name: String) -> Node:
	var stack := [node]
	while stack.size() > 0:
		var n: Node = stack.pop_back()
		if n.get_script() and n.get_script().get_global_name() == type_name:
			return n
		for c in n.get_children():
			stack.append(c)
	return null

func _scan_type(node: Node, type_name: String, out: Array) -> void:
	for c in node.get_children():
		if c.get_script() and c.get_script().get_global_name() == type_name:
			out.append(c)
		_scan_type(c, type_name, out)
