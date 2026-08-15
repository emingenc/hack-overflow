extends SceneTree
## Render the character sheet tiles to understand the animation frames.
func _init() -> void:
	var img := Image.load_from_file("res://assets/kenney/tilemap-characters_packed.png")
	print("sheet size: ", img.get_width(), "x", img.get_height())
	# 9 cols x 3 rows, 24px tiles
	for r in range(3):
		for c in range(9):
			var tile := img.get_region(Rect2i(c * 24, r * 24, 24, 24))
			# Print a coarse ASCII of each tile to see the shape.
			var lines: Array[String] = []
			for y in range(0, 24, 2):
				var line := ""
				for x in range(0, 24, 2):
					var px := tile.get_pixel(x, y)
					if px.a < 0.5:
						line += "."
					elif px.r > 0.6 and px.g > 0.6 and px.b < 0.4:
						line += "Y"  # yellow
					elif px.g > px.r and px.g > px.b:
						line += "G"  # green
					elif px.b > px.r and px.b > px.g:
						line += "B"  # blue
					elif px.r > px.g and px.r > px.b:
						line += "R"  # red
					else:
						line += "#"  # grey/dark
				lines.append(line)
			print("--- tile (%d,%d) ---" % [c, r])
			for l in lines:
				print(l)
	quit()
