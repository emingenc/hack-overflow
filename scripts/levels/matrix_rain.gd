extends CanvasLayer
## MatrixRain — fullscreen digital-rain backdrop (one ColorRect + one shader).
## Deep background layer (-5): the world scrolls over it while the rain stays fixed.
## Glyphs are procedural (in the shader), so no font/atlas dependency.

func _ready() -> void:
	layer = -5
	var rect := ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.name = "MatrixRain"
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://assets/digital_rain.gdshader")
	rect.material = mat
	add_child(rect)
