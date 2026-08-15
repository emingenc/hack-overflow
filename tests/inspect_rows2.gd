extends SceneTree
## ASCII-dump rows 1-2 tiles with indices for reliable identification.
func _init() -> void:
	var img := Image.load_from_file("res://assets/kenney/tilemap-characters_packed.png")
	for r in range(1, 3):
		for c in range(9):
			var tile := img.get_region(Rect2i(c * 24, r * 24, 24, 24))
			print("=== tile idx=%d grid=(%d,%d) ===" % [r * 9 + c, c, r])
			for y in range(0, 24, 2):
				var line := ""
				for x in range(0, 24, 2):
					var px := tile.get_pixel(x, y)
					if px.a < 0.4:
						line += "."
					elif px.r > 0.6 and px.g > 0.6 and px.b < 0.4:
						line += "Y"
					elif px.g > px.r and px.g > px.b and px.g > 0.5:
						line += "G"
					elif px.b > px.r and px.b > px.g and px.b > 0.5:
						line += "B"
					elif px.r > px.g and px.r > px.b and px.r > 0.5:
						line += "R"
					else:
						line += "#"
				print(line)
	quit()
