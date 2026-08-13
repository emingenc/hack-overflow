extends SceneTree
## Raycast alignment probe — verifies tile collision surfaces align with the
## VISUAL tile grid (cell-centered collision polygons) + atlas regions.
## Run: godot --headless --path <project> --script res://tests/run_alignment.gd
## Quits 0 if all checks pass, 1 otherwise. Read-only; never edits the project.

const LEVELS: Array[String] = [
	"res://scenes/levels/level_01_terminal.tscn",
	"res://scenes/levels/level_02_servers.tscn",
	"res://scenes/levels/level_03_core.tscn",
]
const TILE := 18
const ATLAS_PATH := "res://assets/kenney/tilemap_packed.png"

var _frame := 0
var _lv := 0
var _state := "load"
var _level: Node = null
var _passes := 0
var _fails := 0
var _infos: Array[String] = []
var _done := false

func _process(_delta: float) -> bool:
	if _done:
		return false
	_frame += 1
	match _state:
		"load":
			if _frame >= 2:
				change_scene_to_file(LEVELS[_lv])
				_state = "settle"
				_frame = 0
		"settle":
			if current_scene != null and current_scene.has_method("_get_level_time"):
				_level = current_scene
				if _frame >= 90:
					_run_level_checks(_lv)
					_lv += 1
					if _lv < LEVELS.size():
						_state = "load"
						_frame = 0
					else:
						_state = "finish"
		"finish":
			_done = true
			_finish()
	return false

func _check(cond: bool, msg: String) -> void:
	if cond:
		_passes += 1
	else:
		_fails += 1
		_infos.append("  FAIL: " + msg)

func _info(msg: String) -> void:
	_infos.append("  " + msg)

func _run_level_checks(lv: int) -> void:
	var lvl: Node2D = _level as Node2D
	_infos.append("=== LEVEL %d ===" % (lv + 1))
	var tile_layer: TileMapLayer = lvl.get_node_or_null("TileLayer") as TileMapLayer
	if tile_layer == null:
		_check(false, "TileLayer exists")
		return

	var ts: TileSet = tile_layer.tile_set
	var src: TileSetAtlasSource = ts.get_source(0) as TileSetAtlasSource
	_check(ts.tile_size == Vector2i(TILE, TILE), "tile_size == 18x18 (got %s)" % str(ts.tile_size))
	_check(src.texture_region_size == Vector2i(TILE, TILE), "texture_region_size == 18x18 (got %s)" % str(src.texture_region_size))
	var tex: Texture2D = src.texture
	_info("atlas texture: %s (%s)" % [tex.resource_path, str(tex.get_size())])
	_info("separation: %s" % str(src.separation))

	var wall: Vector2i = (_level.get("_wall_tile") as Vector2i)
	var plat: Vector2i = (_level.get("_plat_tile") as Vector2i)
	# Atlas-region forensics: does the sampled region equal the intended one?
	_check_region(src, wall, "wall")
	_check_region(src, plat, "plat")

	# --- Raycast: floor top surface ---
	var space: PhysicsDirectSpaceState2D = lvl.get_world_2d().direct_space_state
	var player: Node2D = (_level.get("player") as Node2D)
	var exclude: Array[RID] = []
	if player != null:
		exclude.append(player.get_rid())

	var floor_cell: Vector2i = Vector2i(-1, -1)
	for cell in tile_layer.get_used_cells():
		if tile_layer.get_cell_atlas_coords(cell) == wall:
			var above := Vector2i(cell.x, cell.y - 1)
			if tile_layer.get_cell_source_id(above) == -1:
				floor_cell = cell
				break
	if floor_cell.x >= 0:
		var top_y: float = floor_cell.y * TILE
		var x_ray: float = floor_cell.x * TILE + TILE / 2.0
		var hit: Dictionary = _ray(space, Vector2(x_ray, top_y - 30.0), Vector2(x_ray, top_y + 30.0), exclude)
		if not hit.is_empty():
			var dy: float = hit["position"].y - top_y
			_info("floor ray @x=%.1f: surface y=%.2f, visual top y=%.2f (Δ=%.2f)" % [x_ray, hit["position"].y, top_y, dy])
			_check(absf(dy) <= 2.0, "floor collision surface aligns with visual tile top (Δ %.2f px)" % dy)
		else:
			_check(false, "floor raycast hit something (collider %s)" % str(hit))
	else:
		_check(false, "found a wall cell with air above")

	# --- Raycast: wall face (horizontal) at the leftmost wall ---
	var face_cell: Vector2i = Vector2i(-1, -1)
	var min_x := 999999
	for cell in tile_layer.get_used_cells():
		if tile_layer.get_cell_atlas_coords(cell) == wall:
			var left := Vector2i(cell.x - 1, cell.y)
			if tile_layer.get_cell_source_id(left) == -1 and cell.x < min_x:
				face_cell = cell
				min_x = cell.x
	if face_cell.x >= 0:
		var face_x: float = face_cell.x * TILE
		var y_ray: float = face_cell.y * TILE + TILE / 2.0
		var hit: Dictionary = _ray(space, Vector2(face_x - 30.0, y_ray), Vector2(face_x + 30.0, y_ray), exclude)
		if not hit.is_empty():
			var dx: float = hit["position"].x - face_x
			_info("wall ray @y=%.1f: face x=%.2f, visual face x=%.2f (Δ=%.2f)" % [y_ray, hit["position"].x, face_x, dx])
			_check(absf(dx) <= 2.0, "wall face collision aligns with visual wall edge (Δ %.2f px)" % dx)
		else:
			_check(false, "wall face raycast missed")
	else:
		_check(false, "found a wall cell with empty space to its left")

	# --- Raycast: platform top surface ---
	var plat_cell: Vector2i = Vector2i(-1, -1)
	for cell in tile_layer.get_used_cells():
		if tile_layer.get_cell_atlas_coords(cell) == plat:
			var above := Vector2i(cell.x, cell.y - 1)
			if tile_layer.get_cell_source_id(above) == -1:
				plat_cell = cell
				break
	if plat_cell.x >= 0:
		var top_y: float = plat_cell.y * TILE
		var x_ray: float = plat_cell.x * TILE + TILE / 2.0
		var hit: Dictionary = _ray(space, Vector2(x_ray, top_y - 30.0), Vector2(x_ray, top_y + 30.0), exclude)
		if not hit.is_empty():
			var dy: float = hit["position"].y - top_y
			_info("plat ray @x=%.1f: surface y=%.2f, visual top y=%.2f (Δ=%.2f)" % [x_ray, hit["position"].y, top_y, dy])
			_check(absf(dy) <= 2.0, "platform collision surface aligns with visual tile top (Δ %.2f px)" % dy)
		else:
			_check(false, "platform raycast missed")

	# --- Player rests ON the visual floor line ---
	if player != null:
		var radius := 0.0
		for c in player.get_children():
			if c is CollisionShape2D:
				var sh: CircleShape2D = ((c as CollisionShape2D).shape as CircleShape2D)
				if sh != null:
					radius = sh.radius
		var feet: float = player.global_position.y + radius
		var top := INF
		for cell in tile_layer.get_used_cells():
			if tile_layer.get_cell_source_id(cell) == -1:
				continue
			var at: Vector2i = tile_layer.get_cell_atlas_coords(cell)
			if at != wall and at != plat:
				continue
			var x0: float = cell.x * TILE
			var px: float = player.global_position.x
			if px >= x0 and px < x0 + TILE:
				var t: float = cell.y * TILE
				if t >= player.global_position.y - 4.0 and t < top:
					top = t
		_info("player: center y=%.2f radius=%.1f feet=%.2f on_floor=%s" % [player.global_position.y, radius, feet, str((player as CharacterBody2D).is_on_floor())])
		if top != INF:
			var dy: float = feet - top
			_check(absf(dy) <= 2.5, "player feet rest on visual floor line (Δ %.2f px)" % dy)
		else:
			_check(false, "found solid tile under player")
	else:
		_check(false, "player spawned")

func _ray(space: PhysicsDirectSpaceState2D, from: Vector2, to: Vector2, exclude: Array[RID]) -> Dictionary:
	var params := PhysicsRayQueryParameters2D.create(from, to)
	params.collision_mask = 1
	params.collide_with_areas = false
	params.collide_with_bodies = true
	params.exclude = exclude
	return space.intersect_ray(params)

func _check_region(src: TileSetAtlasSource, at: Vector2i, tag: String) -> void:
	var actual: Rect2i = src.get_tile_texture_region(at)
	var intended := Rect2i(at * TILE, Vector2i(TILE, TILE))
	var off: Vector2i = actual.position - intended.position
	_info("%s tile at %s: sampled region %s, intended region %s, offset %s" % [tag, str(at), str(actual), str(intended), str(off)])
	if off == Vector2i.ZERO:
		_passes += 1
	else:
		_fails += 1
		_info("  FAIL: %s tile samples a region offset by %s px (atlas separation mismatch?)" % [tag, str(off)])
		_compare_pixels(tag, actual, intended)

func _compare_pixels(tag: String, actual: Rect2i, intended: Rect2i) -> void:
	var img: Image = Image.load_from_file(ATLAS_PATH)
	if img == null:
		_info("  [pixel compare skipped: cannot load %s]" % ATLAS_PATH)
		return
	var diff := 0
	var total := 0
	for dy in range(TILE):
		for dx in range(TILE):
			var a: Color = img.get_pixel(actual.position.x + dx, actual.position.y + dy)
			var b: Color = img.get_pixel(intended.position.x + dx, intended.position.y + dy)
			total += 1
			if absf(a.r - b.r) > 0.05 or absf(a.g - b.g) > 0.05 or absf(a.b - b.b) > 0.05:
				diff += 1
	_info("  %s: %d/%d pixels differ between sampled and intended region" % [tag, diff, total])

func _finish() -> void:
	for i in _infos:
		print(i)
	print("ALIGN PROBE: %d passed, %d failed" % [_passes, _fails])
	quit(0 if _fails == 0 else 1)
