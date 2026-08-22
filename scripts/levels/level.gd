class_name Level
extends Node2D
## Procedural level loader: builds a platformer from an ASCII map.
## Symbols:
##   #  = wall block
##   =  = platform (solid block — jump through not supported in v1)
##   ^  = spike hazard
##   D  = patrol drone
##   V  = vertical patrol drone
##   T  = firewall turret
##   C  = data chip
##   F  = firewall terminal (checkpoint / puzzle)
##   P  = player spawn
##   E  = exit portal
##   O  = overclock powerup (bullet-time + speed)
##   S  = shield powerup (temporary invincibility)

@export var level_index: int = 0
@export var level_name: String = "SECTOR_00"
@export_multiline var level_map: String = ""

const TILE_SIZE: int = 18

var chips_total: int = 0
var _respawn_point: Vector2 = Vector2.ZERO
var _respawn_initialized: bool = false
var chips_collected_count: int = 0
var player: Player = null
var exit_portal: Area2D = null
var firewall: FirewallTerminal = null
var _puzzle_ui: PuzzleUI = null
var _hud: Control = null
var _level_time: float = 0.0
var _level_active: bool = false
var _combo: int = 0
var _combo_timer: float = 0.0
var _completed: bool = false
var _cam: Camera2D = null
var _shake: Node = null

func _ready() -> void:
	GameManager.chips_total[level_index] = 0
	_spawn_matrix_rain()
	_spawn_ambient_particles()
	_build_parallax()
	_build_from_map()
	_spawn_hud()
	_spawn_puzzle_ui()
	_spawn_crt_overlay()
	_level_active = true

## Matrix digital rain on its own deep canvas layer (behind the world).
func _spawn_matrix_rain() -> void:
	var rain := preload("res://scripts/levels/matrix_rain.gd").new()
	rain.name = "MatrixRainLayer"
	add_child(rain)

## Ambient rising data sparks (additive green dots) — the world is streaming data.
func _spawn_ambient_particles() -> void:
	if not Settings.particles_enabled:
		return
	# CPU particles: GPUParticles2D can crash the WebGL build with a wasm
	# "memory access out of bounds" on level load — CPU path is safe everywhere.
	var p := CPUParticles2D.new()
	p.amount = 24
	p.lifetime = 3.0
	p.position = Vector2(_map_pixel_width() * 0.5, _map_pixel_height() * 0.5)
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(_map_pixel_width() * 0.4, _map_pixel_height() * 0.4)
	p.direction = Vector2(0, -1)
	p.spread = 20.0
	p.gravity = Vector2.ZERO
	p.initial_velocity_min = 40.0
	p.initial_velocity_max = 130.0
	p.scale_amount_min = 1.0
	p.scale_amount_max = 2.5
	p.color = Color(0.35, 1.0, 0.6)
	var cm := CanvasItemMaterial.new()
	cm.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	p.material = cm
	p.texture = _make_dot_texture()
	p.name = "DataSparks"
	add_child(p)
	p.emitting = true

func _make_dot_texture() -> ImageTexture:
	var img := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	for y in 8:
		for x in 8:
			var d := Vector2(x - 3.5, y - 3.5).length() / 4.0
			img.set_pixel(x, y, Color(1, 1, 1, clampf(1.0 - d, 0.0, 1.0)))
	return ImageTexture.create_from_image(img)

## Full-screen post stack (bloom + scanlines + dither + vignette) on its own layer.
func _spawn_crt_overlay() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 100
	layer.name = "CRTLayer"
	add_child(layer)
	var crt := ColorRect.new()
	crt.color = Color.WHITE  # shader replaces this with the post-processed screen
	crt.set_anchors_preset(Control.PRESET_FULL_RECT)
	crt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	crt.material = ShaderMaterial.new()
	crt.material.shader = preload("res://assets/crt_overlay.gdshader")
	crt.name = "CRTOverlay"
	layer.add_child(crt)

## Two-layer parallax: far city skyline + mid grid. Follows the camera slowly.
func _build_parallax() -> void:
	var sky := TextureRect.new()
	sky.texture = preload("res://assets/sprites/city_bg.svg")
	sky.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	sky.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sky.set_anchors_preset(Control.PRESET_FULL_RECT)
	sky.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sky.modulate = Color(0.5, 0.7, 0.55, 0.7)  # brighter green cast so the sky reads
	sky.name = "ParallaxSky"
	add_child(sky)

	var grid := TextureRect.new()
	grid.texture = preload("res://assets/sprites/midgrid.svg")
	grid.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	grid.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	grid.set_anchors_preset(Control.PRESET_FULL_RECT)
	grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	grid.modulate = Color(0.3, 0.65, 0.45, 0.4)
	grid.name = "ParallaxGrid"
	add_child(grid)

func _process(delta: float) -> void:
	if _level_active and not _completed:
		_level_time += delta
	if _combo_timer > 0.0:
		_combo_timer -= delta
		if _combo_timer <= 0.0:
			_combo = 0
			if _hud:
				_hud.clear_combo()
	_update_parallax()
	_update_camera(delta)

## Scrolls the two background layers relative to the camera so they feel deep.
func _update_parallax() -> void:
	if not Settings.background_parallax_enabled:
		return
	if _cam == null or not is_instance_valid(_cam):
		return
	var cam_pos: Vector2 = _cam.global_position
	var sky := get_node_or_null("ParallaxSky")
	var grid := get_node_or_null("ParallaxGrid")
	if sky:
		(sky as TextureRect).position = Vector2(-cam_pos.x * 0.2 - 240.0, -cam_pos.y * 0.1 - 120.0)
	if grid:
		(grid as TextureRect).position = Vector2(-cam_pos.x * 0.4 - 240.0, -cam_pos.y * 0.2 - 120.0)

func _get_level_time() -> float:
	return _level_time

func _build_from_map() -> void:
	var rows := level_map.strip_edges().split("\n")
	var tile_layer := TileMapLayer.new()
	tile_layer.name = "TileLayer"
	add_child(tile_layer)
	var tileset := _make_tileset()
	tile_layer.tile_set = tileset

	for row_i in range(rows.size()):
		var line := rows[row_i]
		for col_i in range(line.length()):
			var ch := line[col_i]
			var cell := Vector2i(col_i, row_i)
			match ch:
				"#":
					tile_layer.set_cell(cell, 0, _wall_tile)
				"=":
					tile_layer.set_cell(cell, 1, _plat_tile)
				"^":
					_spawn_hazard(cell)
				"D":
					_spawn_drone(cell)
				"V":
					_spawn_drone(cell, true)
				"T":
					_spawn_turret(cell)
				"C":
					_spawn_chip(cell)
				"F":
					_spawn_firewall(cell)
				"P":
					_spawn_player(cell)
				"E":
					_spawn_exit(cell)
				"O":
					_spawn_powerup(cell, PowerUp.Type.OVERCLOCK)
				"S":
					_spawn_powerup(cell, PowerUp.Type.SHIELD)

	# Boundary walls: stop the player walking off the left/right map edges
	# (the maps only tile the floor, so the sides are open voids).
	var map_width := 0
	for line in rows:
		map_width = maxi(map_width, line.length())
	for row_i in range(rows.size()):
		tile_layer.set_cell(Vector2i(-1, row_i), 0, _wall_tile)
		tile_layer.set_cell(Vector2i(map_width, row_i), 0, _wall_tile)

func _make_tileset() -> TileSet:
	var ts := TileSet.new()
	ts.tile_size = Vector2(TILE_SIZE, TILE_SIZE)

	# Custom cyberpunk tiles: dark metal with neon edges (matches palette,
	# no fake tint needed). Two tile textures, one atlas source.
	var src := TileSetAtlasSource.new()
	var atlas := AtlasTexture.new()
	atlas.atlas = load("res://assets/sprites/tile_wall.svg")
	atlas.region = Rect2(0, 0, 36, 36)
	src.texture = atlas
	src.texture_region_size = Vector2i(TILE_SIZE, TILE_SIZE)
	src.separation = Vector2i.ZERO
	ts.add_source(src, 0)

	# Wall tile at (0,0); platform tile uses the second texture via a second source.
	src.create_tile(Vector2i(0, 0))

	var src2 := TileSetAtlasSource.new()
	var atlas2 := AtlasTexture.new()
	atlas2.atlas = load("res://assets/sprites/tile_platform.svg")
	atlas2.region = Rect2(0, 0, 36, 36)
	src2.texture = atlas2
	src2.texture_region_size = Vector2i(TILE_SIZE, TILE_SIZE)
	src2.separation = Vector2i.ZERO
	ts.add_source(src2, 1)
	src2.create_tile(Vector2i(0, 0))

	# Physics: cell-centered collision polygons (tile spans -9..+9, NOT 0..18).
	ts.add_physics_layer()
	var tile_half := float(TILE_SIZE) / 2.0
	var solid := PackedVector2Array([
		Vector2(-tile_half, -tile_half),
		Vector2(tile_half, -tile_half),
		Vector2(tile_half, tile_half),
		Vector2(-tile_half, tile_half),
	])
	ts.get_source(0).get_tile_data(Vector2i(0, 0), 0).set_collision_polygons_count(0, 1)
	ts.get_source(0).get_tile_data(Vector2i(0, 0), 0).set_collision_polygon_points(0, 0, solid)
	ts.get_source(1).get_tile_data(Vector2i(0, 0), 0).set_collision_polygons_count(0, 1)
	ts.get_source(1).get_tile_data(Vector2i(0, 0), 0).set_collision_polygon_points(0, 0, solid)

	_wall_tile = Vector2i(0, 0)  # source 0
	_plat_tile = Vector2i(0, 0)  # source 1
	return ts

var _wall_tile: Vector2i = Vector2i.ZERO
var _plat_tile: Vector2i = Vector2i.ZERO

func _spawn_player(cell: Vector2i) -> void:
	var scene := preload("res://scenes/player.tscn")
	player = scene.instantiate()
	# Spawn slightly inside the floor cell; physics depenetrates to rest on top.
	# This keeps the spawn point aligned with the tile grid (verified by tests/run_alignment.gd).
	player.position = Vector2(cell) * TILE_SIZE + Vector2(TILE_SIZE / 2, TILE_SIZE)
	if not _respawn_initialized:
		_respawn_point = player.position
		_respawn_initialized = true
	add_child(player)
	player.died.connect(_on_player_died)
	_camera_setup(player)

func _camera_setup(target: Node2D) -> void:
	if _cam and is_instance_valid(_cam):
		_cam.queue_free()  # drop the previous camera on respawn
	var cam := Camera2D.new()
	# Zoom in so the 18px pixel tiles fill the window (~3x = 54px tiles on screen).
	cam.zoom = Vector2(3.0, 3.0)
	cam.limit_left = 0
	cam.limit_right = _map_pixel_width()
	cam.limit_top = -TILE_SIZE * 4
	cam.limit_bottom = _map_pixel_height() + TILE_SIZE
	add_child(cam)  # sibling of the player → real deadzone is possible
	cam.position = target.position
	cam.make_current()
	_cam = cam
	# Trauma² screen shake, child of the camera so it composes with smoothing.
	_shake = preload("res://scripts/levels/camera_shake.gd").new()
	_shake.name = "CameraShake"
	cam.add_child(_shake)

const CAM_DEADZONE := Vector2(60.0, 40.0)
const CAM_LOOKAHEAD := 44.0

## Manual follow: deadzone + speed-based smoothing + facing lookahead.
func _update_camera(delta: float) -> void:
	if _cam == null or not is_instance_valid(_cam) or player == null:
		return
	var desired := player.global_position + Vector2(player.facing * CAM_LOOKAHEAD, -12.0)
	var diff := desired - _cam.position
	# Deadzone: ignore motion inside the box, track the excess outside it.
	if absf(diff.x) <= CAM_DEADZONE.x:
		diff.x = 0.0
	else:
		diff.x -= signf(diff.x) * CAM_DEADZONE.x
	if absf(diff.y) <= CAM_DEADZONE.y:
		diff.y = 0.0
	else:
		diff.y -= signf(diff.y) * CAM_DEADZONE.y
	var speed_ratio: float = clampf(absf(player.velocity.x) / Player.SPEED, 0.0, 1.0)
	var smooth: float = lerpf(6.0, 14.0, speed_ratio)
	_cam.position += diff * clampf(smooth * delta, 0.0, 1.0)

## Trauma² screen-shake entry point (called by the player on impact/dash/death).
func add_trauma(amount: float) -> void:
	if _shake and is_instance_valid(_shake):
		_shake.add_trauma(amount)

func _map_pixel_width() -> int:
	var rows := level_map.strip_edges().split("\n")
	var max_len := 0
	for r in rows:
		max_len = maxi(max_len, r.length())
	return max_len * TILE_SIZE

func _map_pixel_height() -> int:
	return level_map.strip_edges().split("\n").size() * TILE_SIZE

func _spawn_hazard(cell: Vector2i) -> void:
	var hazard := Area2D.new()
	hazard.collision_layer = 8  # hazards
	hazard.collision_mask = 1
	hazard.position = Vector2(cell) * TILE_SIZE + Vector2(TILE_SIZE / 2, TILE_SIZE / 2)
	var col := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(TILE_SIZE * 0.8, TILE_SIZE * 0.5)
	col.shape = shape
	hazard.add_child(col)
	var spr := Sprite2D.new()
	spr.texture = preload("res://assets/warped/enemy/turret-1.png")
	spr.modulate = Color(1.0, 0.35, 0.3)  # red tint = electric hazard
	spr.name = "Sprite2D"
	spr.position = Vector2(0, 6)
	spr.scale = Vector2(1.0, 1.0)
	hazard.add_child(spr)
	add_child(hazard)
	hazard.body_entered.connect(func(body: Node2D) -> void:
		if body is Player:
			body.die())

func _spawn_drone(cell: Vector2i, vertical: bool = false) -> void:
	var drone := PatrolDrone.new()
	drone.vertical = vertical
	drone.position = Vector2(cell) * TILE_SIZE + Vector2(TILE_SIZE / 2, TILE_SIZE / 2)
	drone.patrol_distance = TILE_SIZE * 2.0
	var spr := Sprite2D.new()
	spr.name = "Sprite2D"
	drone.add_child(spr)
	drone.add_child(_make_collision_circle(10.0))
	add_child(drone)

func _spawn_turret(cell: Vector2i) -> void:
	var turret := FirewallTurret.new()
	turret.position = Vector2(cell) * TILE_SIZE + Vector2(TILE_SIZE / 2, TILE_SIZE / 2)
	var spr := Sprite2D.new()
	spr.name = "Sprite2D"
	turret.add_child(spr)
	turret.add_child(_make_collision_circle(12.0))
	add_child(turret)

func _spawn_chip(cell: Vector2i) -> void:
	var chip := DataChip.new()
	chip.position = Vector2(cell) * TILE_SIZE + Vector2(TILE_SIZE / 2, TILE_SIZE / 2)
	var spr := Sprite2D.new()
	spr.texture = preload("res://assets/warped/props/monitor-face-1.png")  # data chip
	spr.modulate = Color(0.5, 1.0, 0.6)  # green glow
	spr.name = "Sprite2D"
	spr.scale = Vector2(1.0, 1.0)
	chip.add_child(spr)
	chip.add_child(_make_collision_circle(9.0))
	add_child(chip)
	chips_total += 1

func _spawn_powerup(cell: Vector2i, type: int) -> void:
	var p := PowerUp.new()
	p.type = type
	p.position = Vector2(cell) * TILE_SIZE + Vector2(TILE_SIZE / 2, TILE_SIZE / 2)
	var spr := Sprite2D.new()
	if type == PowerUp.Type.OVERCLOCK:
		spr.texture = preload("res://assets/warped/props/monitor-face-1.png")
		spr.modulate = Color(0.4, 1.0, 1.0)  # cyan = overclock
	else:
		spr.texture = preload("res://assets/warped/props/control-box-1.png")
		spr.modulate = Color(1.0, 0.8, 0.3)  # amber = shield
	spr.name = "Sprite2D"
	p.add_child(spr)
	p.add_child(_make_collision_circle(11.0))
	add_child(p)

func _spawn_firewall(cell: Vector2i) -> void:
	firewall = FirewallTerminal.new()
	firewall.level_index = level_index
	firewall.terminal_name = "FIREWALL_" + str(level_index + 1).pad_zeros(2)
	firewall.position = Vector2(cell) * TILE_SIZE + Vector2(TILE_SIZE / 2, TILE_SIZE)
	var spr := Sprite2D.new()
	spr.texture = preload("res://assets/warped/props/control-box-1.png")  # control console
	spr.name = "Sprite2D"
	spr.scale = Vector2(1.3, 1.3)
	firewall.add_child(spr)
	var prompt := Label.new()
	prompt.text = "PRESS E TO HACK"
	prompt.position = Vector2(-40, -34)
	prompt.add_theme_font_size_override("font_size", 10)
	prompt.add_theme_color_override("font_color", Color(0.4, 1.0, 0.6))
	prompt.name = "Prompt"
	firewall.add_child(prompt)
	firewall.add_child(_make_collision_rect(40.0, 56.0))
	add_child(firewall)
	firewall.puzzle_started.connect(_on_puzzle_started)

func _spawn_exit(cell: Vector2i) -> void:
	exit_portal = Area2D.new()
	exit_portal.collision_layer = 16
	exit_portal.collision_mask = 1
	exit_portal.position = Vector2(cell) * TILE_SIZE + Vector2(TILE_SIZE / 2, TILE_SIZE / 2)
	var col := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 22.0
	col.shape = shape
	exit_portal.add_child(col)
	# Distinct exit visual: pulsing portal sprite + inner glow, not a terminal.
	var ring := Sprite2D.new()
	ring.texture = preload("res://assets/warped/props/monitor-face-1.png")  # portal node
	ring.modulate = Color(0.5, 1.0, 0.7)
	ring.scale = Vector2(1.6, 1.6)
	ring.name = "Sprite2D"
	exit_portal.add_child(ring)
	var core := Sprite2D.new()
	core.texture = preload("res://assets/warped/props/monitor-face-1.png")
	core.scale = Vector2(1.2, 1.2)
	core.modulate = Color(0.4, 1.0, 0.9)
	core.position = Vector2(0, -6)
	core.name = "Core"
	exit_portal.add_child(core)
	var glow := PointLight2D.new()
	glow.texture = preload("res://assets/sprites/chip.svg")
	glow.scale = Vector2(3, 3)
	glow.color = Color(0.4, 1.0, 0.6, 0.8)
	glow.energy = 0.9
	glow.position = Vector2(0, -6)
	exit_portal.add_child(glow)
	var tween := create_tween().set_loops()
	tween.tween_property(core, "scale", Vector2(1.4, 1.4), 0.6).set_trans(Tween.TRANS_SINE)
	tween.tween_property(core, "scale", Vector2(1.2, 1.2), 0.6).set_trans(Tween.TRANS_SINE)
	add_child(exit_portal)
	exit_portal.body_entered.connect(_on_exit_entered)
	exit_portal.monitoring = false  # locked until puzzle solved

func _make_collision_circle(radius: float) -> CollisionShape2D:
	var col := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = radius
	col.shape = shape
	return col

func _make_collision_rect(w: float, h: float) -> CollisionShape2D:
	var col := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(w, h)
	col.shape = shape
	return col

func _on_puzzle_started(_level_idx: int) -> void:
	# Reaching the firewall sets the checkpoint.
	if firewall:
		_respawn_point = firewall.position + Vector2(0, 24)
		AudioManager.play("checkpoint")
	if _puzzle_ui:
		if not _puzzle_ui.puzzle_completed.is_connected(_on_puzzle_completed):
			_puzzle_ui.puzzle_completed.connect(_on_puzzle_completed)
		if not _puzzle_ui.puzzle_locked.is_connected(_on_puzzle_locked):
			_puzzle_ui.puzzle_locked.connect(_on_puzzle_locked)
		# Use the puzzle the firewall already rolled (avoid double-roll / drift).
		_puzzle_ui.show_puzzle(firewall.puzzle, level_index)

func _on_puzzle_locked() -> void:
	# Integrity exhausted → close the puzzle, reset the terminal, respawn.
	if _puzzle_ui:
		_puzzle_ui.hide()
		get_tree().paused = false
	if firewall:
		firewall.reset_terminal()
	_spawn_player_at(_respawn_point)

func _on_puzzle_completed(success: bool) -> void:
	# Reset the terminal so a failed attempt (EXIT or lockout) can be re-tried.
	if firewall:
		firewall.reset_terminal()
	if success and exit_portal:
		exit_portal.monitoring = true
		exit_portal.get_child(1).modulate = Color(0.4, 1.0, 0.9)
		AudioManager.play("unlock")

func on_chip_collected(value: int) -> void:
	chips_collected_count += value
	# Combo streak — chips chained within 2s multiply the buzz.
	_combo = _combo + 1 if _combo_timer > 0.0 else 1
	_combo_timer = 2.0
	if _hud:
		_hud.update_chips(chips_collected_count, chips_total)
		_hud.show_combo(_combo)

func _on_exit_entered(body: Node2D) -> void:
	if body is Player and not _completed:
		_completed = true
		GameManager.complete_level(level_index, _level_time, chips_collected_count)
		if _hud:
			_hud.show_complete(level_index, _level_time, chips_collected_count, chips_total)

func _on_player_died() -> void:
	# Respawn at the last checkpoint (spawn or firewall), keeping collected chips.
	if not _respawn_initialized:
		get_tree().reload_current_scene()
		return
	player = null  # dead player is being freed; clear the ref so the camera holds
	# Delay respawn past the death hitstop so the frozen death beat is visible.
	get_tree().create_timer(0.1).timeout.connect(func() -> void:
		_spawn_player_at(_respawn_point))

func _spawn_player_at(pos: Vector2) -> void:
	var scene := preload("res://scenes/player.tscn")
	player = scene.instantiate()
	player.position = pos
	add_child(player)
	player.died.connect(_on_player_died)
	_camera_setup(player)

func _spawn_hud() -> void:
	var hud_script := load("res://scripts/ui/hud.gd")
	# HUD must live on a CanvasLayer so the camera zoom/drift never applies.
	var layer := CanvasLayer.new()
	layer.layer = 10
	layer.name = "HUDLayer"
	var hud := Control.new()
	hud.set_script(hud_script)
	hud.set("level_index", level_index)
	hud.set("level_name", level_name)
	layer.add_child(hud)
	add_child(layer)
	_hud = hud

func _spawn_puzzle_ui() -> void:
	# Puzzle UI on its own layer ABOVE the CRT overlay (layer 110) so it's
	# always crisp, centered, and unaffected by camera transforms.
	var layer := CanvasLayer.new()
	layer.layer = 110
	layer.name = "PuzzleLayer"
	_puzzle_ui = PuzzleUI.new()
	layer.add_child(_puzzle_ui)
	add_child(layer)
