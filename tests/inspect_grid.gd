extends SceneTree
## Renders the character sheet scaled up with tile-index labels for inspection.
func _init() -> void:
	var img := Image.load_from_file("res://assets/kenney/tilemap-characters_packed.png")
	var scale := 6
	var out := Image.create(216 * scale, 72 * scale, false, Image.FORMAT_RGBA8)
	out.fill(Color(0.1, 0.1, 0.15, 1.0))
	for r in range(3):
		for c in range(9):
			var tile := img.get_region(Rect2i(c * 24, r * 24, 24, 24))
			tile.resize(24 * scale, 24 * scale, Image.INTERPOLATE_NEAREST)
			out.blit_rect(tile, Rect2i(0, 0, 24 * scale, 24 * scale), Vector2i(c * 24 * scale, r * 24 * scale))
	out.save_png("res://../char_grid.png")
	print("saved char_grid.png")
	quit()
