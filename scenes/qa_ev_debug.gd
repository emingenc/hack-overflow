extends Node
## DEBUG2: full dump — atlas texture size, all cells, player contact, spawn cell.

func _ready() -> void:
	var lvl: Node = load("res://scenes/levels/level_01_terminal.tscn").instantiate()
	add_child(lvl)
	await get_tree().process_frame
	await get_tree().process_frame

	var tl: TileMapLayer = null
	for c in lvl.get_children():
		if c is TileMapLayer:
			tl = c
			break
	var ts: TileSet = tl.tile_set
	var src: TileSetAtlasSource = ts.get_source(0)
	print("[DBG] src0 texture=%s size=%s" % [src.texture.resource_path, src.texture.get_size()])
	var src2: TileSetAtlasSource = ts.get_source(1)
	print("[DBG] src1 texture=%s size=%s" % [src2.texture.resource_path, src2.texture.get_size()])
	var wall_pre := preload("res://assets/sprites/wall.svg") as Texture2D
	print("[DBG] preload wall=%s size=%s" % [wall_pre.resource_path, wall_pre.get_size()])
	var plat_pre := preload("res://assets/sprites/platform.svg") as Texture2D
	print("[DBG] preload platform=%s size=%s" % [plat_pre.resource_path, plat_pre.get_size()])
	print("[DBG] atlas texture size=%s tile_size=%s" % [src.texture.get_size(), ts.tile_size])
	var cells: Array = tl.get_used_cells()
	print("[DBG] used cells=%d" % cells.size())
	for c in cells:
		var at: Vector2i = tl.get_cell_atlas_coords(c)
		print("[DBG] cell=%s src=%d atlas=%s" % [c, tl.get_cell_source_id(c), at])
	# tile (0,0) physics polygon points
	var td: TileData = src.get_tile_data(Vector2i(0, 0), 0)
	print("[DBG] tile(0,0) polygons=%d" % td.get_collision_polygons_count(0))
	var poly: PackedVector2Array = td.get_collision_polygon_points(0, 0)
	print("[DBG] tile(0,0) poly points=%s" % poly)

	var player: CharacterBody2D = lvl.get("player")
	print("[DBG] player pos=%s" % player.position)
	if player.get_slide_collision_count() > 0:
		var sc := player.get_slide_collision(0)
		print("[DBG] slide collider=%s normal=%s point=%s" % [sc.get_collider(), sc.get_normal(), sc.get_position()])
	# scan all physics bodies with collision shapes in level
	for n in lvl.get_children():
		if n is StaticBody2D or n is TileMapLayer:
			print("[DBG] static body: %s" % n)
	var names: Array[String] = []
	for c in lvl.get_children():
		names.append(str(c.name))
	print("[DBG] level children: %s" % str(names))
	get_tree().quit()
