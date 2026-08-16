extends Control
## Isometric Blind-75 route map — a Pokémon-style skill tree the hacker walks along.
## Each Blind-75 category is a node on a binary-tree route, rendered as a glowing
## isometric diamond. The character stands on the current (first available) node;
## clicking an available/solved node launches that category.

signal category_launched(cat: String)

const TILE_W := 240.0   # diamond width
const TILE_H := 120.0   # diamond height

var _font: Font
var _char_tex: Texture2D
var _char_walk1: Texture2D
var _char_walk2: Texture2D
var _char: TextureRect
var _nodes: Array[Dictionary] = []   # {cat, iso (grid-local), state, parent}
var _origin := Vector2.ZERO          # screen pos of grid (0,0)
var _char_index := -1                # node index the character stands on
var _char_from := Vector2.ZERO
var _char_to := Vector2.ZERO
var _char_anim := 0.0                # 0..1 walk progress (0 = idle)
var _hover := -1
var _t := 0.0

# Tree layout: [category, grid_x, depth, parent_index] (index = CATEGORIES order).
const _LAYOUT := [
	["Arrays & Hashing", 0, 0, -1],
	["Stack", -2, 1, 0],
	["Binary Search", 2, 1, 0],
	["Linked List", -3, 2, 1],
	["Trees", -1, 2, 1],
	["Sliding Window", 1, 2, 2],
	["Dynamic Programming", 3, 2, 2],
	["Intervals", -3, 3, 3],
	["Graphs", -1, 3, 4],
	["Design", 1, 3, 5],
	["Easter Egg", 3, 3, 6],
]

enum { LOCKED, AVAILABLE, SOLVED }

func _ready() -> void:
	_font = preload("res://assets/fonts/VT323-Regular.ttf")
	_char_tex = preload("res://assets/char/idle.png")
	_char_walk1 = preload("res://assets/char/walk.png")
	_char_walk2 = preload("res://assets/char/walk2.png")
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_tree()
	# Character sprite (renders above the drawn map, below the labels we draw later
	# is fine — labels sit under each node, character stands on top of the diamond).
	_char = TextureRect.new()
	_char.texture = _char_tex
	_char.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_char.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_char.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_char.custom_minimum_size = Vector2(56, 56)
	add_child(_char)
	call_deferred("_center_map")

func _build_tree() -> void:
	for row in _LAYOUT:
		var cat: String = row[0]
		var gx: int = row[1]
		var depth: int = row[2]
		var parent: int = row[3]
		_nodes.append({
			"cat": cat,
			"iso": _iso(gx, depth),
			"state": _state_for(cat),
			"parent": parent,
		})

func _iso(gx: int, depth: int) -> Vector2:
	return Vector2((gx - depth) * TILE_W * 0.5, (gx + depth) * TILE_H * 0.5)

func _state_for(cat: String) -> int:
	var prog: Array[int] = GameManager.category_progress(cat)
	if prog[1] > 0 and prog[0] >= prog[1]:
		return SOLVED
	if GameManager.is_category_available(cat):
		return AVAILABLE
	return LOCKED

## Center the whole map in the control and place the character on the current node.
func _center_map() -> void:
	var minp := Vector2(INF, INF)
	var maxp := Vector2(-INF, -INF)
	for n in _nodes:
		minp = minp.min(n["iso"])
		maxp = maxp.max(n["iso"])
	var center := (minp + maxp) * 0.5
	_origin = (size * 0.5) - center + Vector2(0, 8)
	# Character starts on the first available node (or last solved / root).
	var target := 0
	for i in _nodes.size():
		if _nodes[i]["state"] == AVAILABLE:
			target = i
			break
	_char_index = target
	_char_from = _screen_pos(_nodes[target]["iso"])
	_char_to = _char_from
	_char.position = _char_from - Vector2(28, 44)

func _screen_pos(iso: Vector2) -> Vector2:
	return _origin + iso

func _process(delta: float) -> void:
	_t += delta
	# Character walk animation toward the target node.
	if _char_anim < 1.0:
		_char_anim = minf(1.0, _char_anim + delta * 2.2)
		var p := _char_from.lerp(_char_to, _char_anim)
		_char.position = p - Vector2(28, 44)
		# Walk animation: alternate frames + face the direction of travel.
		_char.texture = _char_walk1 if fmod(_t * 10.0, 2.0) < 1.0 else _char_walk2
		_char.scale.x = -1.0 if _char_to.x < _char_from.x else 1.0
	else:
		_char.texture = _char_tex
	# Idle bob + subtle scale pulse while standing.
	var bob := sin(_t * 3.0) * 2.0
	_char.position.y += bob
	queue_redraw()

func _draw() -> void:
	# 1) Route edges (parent -> child), drawn under the nodes.
	for i in _nodes.size():
		var p: int = _nodes[i]["parent"]
		if p < 0:
			continue
		var a := _screen_pos(_nodes[p]["iso"])
		var b := _screen_pos(_nodes[i]["iso"])
		# Walked route (up to the current node) glows green; the rest is dim.
		var walked := _is_walked(p, i)
		_draw_edge(a, b, walked)
	# 2) Node diamonds + labels.
	for i in _nodes.size():
		_draw_node(i)

func _is_walked(parent_i: int, child_i: int) -> bool:
	# Edge is "walked" if it leads toward the current character node.
	return child_i == _char_index or _nodes[child_i]["state"] == SOLVED

func _draw_edge(a: Vector2, b: Vector2, walked: bool) -> void:
	var under := Color(0.05, 0.12, 0.06, 0.9)
	var glow := Color(0.0, 1.0, 0.3, 0.55) if walked else Color(0.1, 0.2, 0.12, 0.7)
	draw_line(a, b, under, 6.0, true)
	draw_line(a, b, glow, 2.0, true)
	# Small diamond "stepping stones" along the route.
	var steps := 5
	for s in range(1, steps):
		var p := a.lerp(b, float(s) / steps)
		draw_rect(Rect2(p - Vector2(3, 3), Vector2(6, 6)), glow)

func _draw_node(i: int) -> void:
	var n: Dictionary = _nodes[i]
	var c := _screen_pos(n["iso"])
	var state: int = n["state"]
	var hw := TILE_W * 0.5
	var hh := TILE_H * 0.5
	var hovered := i == _hover

	# Base diamond (isometric top face) + 3D side faces for depth.
	var top := Color(0.05, 0.16, 0.07, 0.98)
	var side := Color(0.03, 0.09, 0.05, 0.98)
	var border := Color(0.0, 1.0, 0.25, 0.35)
	match state:
		LOCKED:
			top = Color(0.08, 0.09, 0.09, 0.95)
			side = Color(0.05, 0.05, 0.05, 0.95)
			border = Color(0.3, 0.35, 0.3, 0.4)
		SOLVED:
			top = Color(0.05, 0.22, 0.09, 0.98)
			border = Color(0.2, 1.0, 0.4, 0.7)
		AVAILABLE:
			top = Color(0.06, 0.2, 0.08, 0.98)
			border = Color(0.0, 1.0, 0.25, 0.8 if hovered else 0.55)

	# Side faces (isometric thickness).
	var thick := 9.0
	var pts_side := PackedVector2Array([
		c + Vector2(-hw, 0),
		c + Vector2(0, hh),
		c + Vector2(0, hh + thick),
		c + Vector2(-hw, thick),
	])
	draw_colored_polygon(pts_side, side)
	var pts_side_r := PackedVector2Array([
		c + Vector2(hw, 0),
		c + Vector2(0, hh),
		c + Vector2(0, hh + thick),
		c + Vector2(hw, thick),
	])
	draw_colored_polygon(pts_side_r, side.darkened(0.3))

	# Top diamond.
	var pts_top := PackedVector2Array([
		c + Vector2(0, -hh),
		c + Vector2(hw, 0),
		c + Vector2(0, hh),
		c + Vector2(-hw, 0),
	])
	draw_colored_polygon(pts_top, top)

	# Glow ring (pulsing for available).
	var pulse := 0.5 + 0.5 * sin(_t * 2.0 + i)
	if state == AVAILABLE:
		draw_polyline(PackedVector2Array([c + Vector2(0, -hh), c + Vector2(hw, 0), c + Vector2(0, hh), c + Vector2(-hw, 0), c + Vector2(0, -hh)]), Color(border, 0.9 * pulse + 0.3), 3.0 if hovered else 2.0, true)
	else:
		draw_polyline(PackedVector2Array([c + Vector2(0, -hh), c + Vector2(hw, 0), c + Vector2(0, hh), c + Vector2(-hw, 0), c + Vector2(0, -hh)]), border, 2.0, true)

	# Label under the diamond.
	var label: String = n["cat"]
	if state == SOLVED:
		label = "✓ " + label
	elif state == LOCKED:
		label = "🔒 " + label
	var fsize := 24
	var label_color := Color(0.75, 1.0, 0.8) if state != LOCKED else Color(0.45, 0.5, 0.45)
	var tw := _font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize).x
	draw_string(_font, Vector2(c.x - tw * 0.5, c.y + hh + thick + 18), label, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize, label_color)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_hover = _node_at(event.position)
		queue_redraw()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var idx := _node_at(event.position)
		if idx >= 0 and _nodes[idx]["state"] != LOCKED:
			_walk_to(idx)
			# Short hop before launching so the player sees the character move.
			var cat: String = _nodes[idx]["cat"]
			get_tree().create_timer(0.35).timeout.connect(func() -> void:
				category_launched.emit(cat))
	elif event is InputEventScreenTouch and event.pressed:
		var idx := _node_at(event.position)
		if idx >= 0 and _nodes[idx]["state"] != LOCKED:
			_walk_to(idx)
			var cat: String = _nodes[idx]["cat"]
			get_tree().create_timer(0.35).timeout.connect(func() -> void:
				category_launched.emit(cat))

func _node_at(p: Vector2) -> int:
	for i in _nodes.size():
		var c := _screen_pos(_nodes[i]["iso"])
		var d := p - c
		if absf(d.x) / (TILE_W * 0.5) + absf(d.y) / (TILE_H * 0.5 + 10.0) <= 1.0:
			return i
	return -1

func _walk_to(idx: int) -> void:
	_char_from = _char.position + Vector2(28, 44)
	_char_to = _screen_pos(_nodes[idx]["iso"])
	_char_index = idx
	_char_anim = 0.0
