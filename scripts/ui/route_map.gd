extends Control
## Isometric Blind-75 route map — a Pokémon-style skill tree the hacker walks along.
## Each Blind-75 category is a node on a binary-tree route, rendered as a glowing
## isometric tile. The character (Warped City humanoid, 16-frame walk) stands on
## the current node and visibly walks to any clicked available/solved node.

signal category_launched(cat: String)

const TILE_W := 150.0   # diamond width (MUST be < COL_SPACING to avoid overlap)
const TILE_H := 78.0    # diamond height
const CHAR_SCALE := 1.7  # scale for the 71x67 composited sprite (menu)
## Vertical offset so the sprite's FEET sit on the tile centroid (sprite pivot is
## center; the composited frame is ~67px tall, feet near the bottom).
const CHAR_FEET_OFFSET := 26.0 * 1.7  # ≈ half sprite height * scale

var _font: Font
var _char: Sprite2D
var _walk_frames: Array[Texture2D] = []
var _idle_frames: Array[Texture2D] = []
var _nodes: Array[Dictionary] = []   # {cat, iso (grid-local), state, parent}
var _origin := Vector2.ZERO          # screen pos of grid (0,0)
var _char_index := -1                # node index the character stands on
var _char_from := Vector2.ZERO
var _char_to := Vector2.ZERO
var _char_anim := 1.0                # 0..1 walk progress (1 = idle at target)
var _hover := -1
var _t := 0.0

# Tree layout: [category, col, row, parent_index].
# col is symmetric around 0 (negative = left branch), row = depth (0 = root).
const _LAYOUT := [
	["Arrays & Hashing", 0.0, 0, -1],
	["Stack", -1.5, 1, 0],
	["Binary Search", 1.5, 1, 0],
	["Linked List", -2.5, 2, 1],
	["Trees", -0.5, 2, 1],
	["Sliding Window", 0.5, 2, 2],
	["Dynamic Programming", 2.5, 2, 2],
	["Intervals", -2.5, 3, 3],
	["Graphs", -0.5, 3, 4],
	["Design", 0.5, 3, 5],
	["Easter Egg", 2.5, 3, 6],
]

const COL_SPACING := 300.0   # px per column unit (drives iso lattice spacing)
const ROW_SPACING := 150.0   # px per depth unit (used only for reference)

enum { LOCKED, AVAILABLE, SOLVED }

func _ready() -> void:
	_font = preload("res://assets/fonts/VT323-Regular.ttf")
	# Load the SAME character frames the in-game player uses (composited, uniform
	# canvas) so the menu character and gameplay character are identical.
	for i in range(1, 5):
		_idle_frames.append(load("res://assets/warped/player/idle-%d.png" % i))
	for i in range(1, 17):
		_walk_frames.append(load("res://assets/warped/player/walk-%d.png" % i))
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_tree()
	# Character sprite (rendered above the drawn map). Nearest filtering so the
	# pixel art stays crisp — matches the in-game player's render mode.
	_char = Sprite2D.new()
	_char.texture = _idle_frames[0]
	_char.scale = Vector2(CHAR_SCALE, CHAR_SCALE)
	_char.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_char)
	call_deferred("_center_map")

func _build_tree() -> void:
	for row in _LAYOUT:
		var cat: String = row[0]
		var col: float = row[1]
		var depth: int = row[2]
		var parent: int = row[3]
		_nodes.append({
			"cat": cat,
			"iso": _iso(col, depth),
			"state": _state_for(cat),
			"parent": parent,
		})

## Screen position from (column, depth) via a TRUE isometric projection:
## x = (col - depth) * K, y = (col + depth) * K/2  (2:1 dimetric, Pokémon-style).
## This lays the tree out on a diagonal lattice so it reads as raised terrain,
## not a flat scatter plot.
func _iso(col: float, depth: int) -> Vector2:
	var k := COL_SPACING * 0.5
	return Vector2((col - float(depth)) * k, (col + float(depth)) * k * 0.5)

func _state_for(cat: String) -> int:
	var prog: Array[int] = GameManager.category_progress(cat)
	if prog[2] > 0 and prog[1] >= prog[2]:
		return SOLVED
	if GameManager.is_category_available(cat):
		return AVAILABLE
	return LOCKED

## Center the whole map and place the character on the current node.
func _center_map() -> void:
	var minp := Vector2(INF, INF)
	var maxp := Vector2(-INF, -INF)
	for n in _nodes:
		minp = minp.min(n["iso"])
		maxp = maxp.max(n["iso"])
	var center := (minp + maxp) * 0.5
	_origin = (size * 0.5) - center + Vector2(0, 16)
	# Character starts on the first available node (or root).
	var target := 0
	for i in _nodes.size():
		if _nodes[i]["state"] == AVAILABLE:
			target = i
			break
	_char_index = target
	_char_from = _screen_pos(_nodes[target]["iso"])
	_char_to = _char_from
	_char.position = _char_from - Vector2(0, CHAR_FEET_OFFSET)
	_char_anim = 1.0

func _screen_pos(iso: Vector2) -> Vector2:
	return _origin + iso

func _process(delta: float) -> void:
	_t += delta
	# Character walk toward the target node (feet anchored to tile centroids).
	if _char_anim < 1.0:
		_char_anim = minf(1.0, _char_anim + delta * 1.4)
		var p := _char_from.lerp(_char_to, _char_anim)
		_char.position = p - Vector2(0, CHAR_FEET_OFFSET)
		# 16-frame walk cycle, flip to face travel direction.
		var fi := int(_t * 12.0) % _walk_frames.size()
		_char.texture = _walk_frames[fi]
		_char.flip_h = _char_to.x < _char_from.x
	else:
		# Idle: 4-frame breathing cycle + gentle bob (feet stay near the ground).
		var fi := int(_t * 2.5) % _idle_frames.size()
		_char.texture = _idle_frames[fi]
		_char.position.y = _char_to.y - CHAR_FEET_OFFSET + sin(_t * 3.0) * 2.0
	queue_redraw()

func _draw() -> void:
	# 1) Route edges (parent -> child) — thick neon roads.
	for i in _nodes.size():
		var p: int = _nodes[i]["parent"]
		if p < 0:
			continue
		var a := _screen_pos(_nodes[p]["iso"])
		var b := _screen_pos(_nodes[i]["iso"])
		_draw_edge(a, b, _is_walked(p, i), i)
	# 2) All node FACES first (diamonds + side faces + glow rings).
	for i in _nodes.size():
		_draw_node_face(i)
	# 3) All LABELS last (second pass) so no diamond paints over a neighbor's
	#    label — this was the P1 clip bug.
	for i in _nodes.size():
		_draw_node_label(i)
	# 4) Character shadow (drawn last so it sits on the tile face the char is on).
	_draw_character_shadow()

func _is_walked(parent_i: int, child_i: int) -> bool:
	return child_i == _char_index or _nodes[child_i]["state"] == SOLVED

## Ellipse ground shadow under the character's feet, anchored to the tile face.
func _draw_character_shadow() -> void:
	# Lerp the shadow along the walk path so it doesn't teleport to the
	# destination while the character is still walking (P3 fix).
	var ground := _char_from.lerp(_char_to, _char_anim)
	draw_set_transform(ground, 0.0, Vector2(1.0, 0.34))
	draw_circle(Vector2.ZERO, 30.0, Color(0.0, 0.0, 0.0, 0.7))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

## Quadratic bezier point (route curves bow toward the viewer).
func _quad(a: Vector2, c: Vector2, b: Vector2, t: float) -> Vector2:
	var u := 1.0 - t
	return u * u * a + 2.0 * u * t * c + t * t * b

func _draw_edge(a: Vector2, b: Vector2, walked: bool, i: int) -> void:
	var under := Color(0.04, 0.1, 0.05, 0.95)
	var glow := Color(0.0, 1.0, 0.3, 0.6) if walked else Color(0.12, 0.22, 0.13, 0.85)
	# Curved route (control point bows down) so edges read as raised roads,
	# not straight sticks.
	var mid := (a + b) * 0.5 + Vector2(0, 28)
	var pts := PackedVector2Array()
	for s in range(17):
		pts.append(_quad(a, mid, b, float(s) / 16.0))
	for s in range(pts.size() - 1):
		draw_line(pts[s], pts[s + 1], under, 8.0, true)
	for s in range(pts.size() - 1):
		draw_line(pts[s], pts[s + 1], glow, 3.0, true)
	# Stepping-stone diamonds along the route.
	for s in range(1, 6):
		var p := _quad(a, mid, b, float(s) / 6.0)
		draw_rect(Rect2(p - Vector2(4, 4), Vector2(8, 8)), glow)
	# Data pulse flowing along walked routes (phase per edge = flowing feel).
	if walked:
		var tt := fmod(_t * 0.35 + float(i) * 0.17, 1.0)
		var p := _quad(a, mid, b, tt)
		draw_circle(p, 6.5, Color(0.7, 1.0, 0.8, 0.95))
		draw_circle(p, 12.0, Color(0.7, 1.0, 0.8, 0.25))

func _draw_node_face(i: int) -> void:
	var n: Dictionary = _nodes[i]
	var c := _screen_pos(n["iso"])
	var state: int = n["state"]
	var hw := TILE_W * 0.5
	var hh := TILE_H * 0.5
	var hovered := i == _hover

	var top := Color(0.06, 0.17, 0.08, 0.98)
	var side := Color(0.03, 0.09, 0.05, 0.98)
	var border := Color(0.0, 1.0, 0.25, 0.4)
	match state:
		LOCKED:
			# Bright enough to read as a tile (not a dark hole), green-tinted border.
			top = Color(0.12, 0.14, 0.14, 0.97)
			side = Color(0.07, 0.08, 0.08, 0.97)
			border = Color(0.15, 0.3, 0.18, 0.55)
		SOLVED:
			# Fully lit green panel — unmistakably "cleared".
			top = Color(0.06, 0.3, 0.12, 0.99)
			side = Color(0.03, 0.16, 0.07, 0.99)
			border = Color(0.3, 1.0, 0.45, 0.9)
		AVAILABLE:
			# Pulsing bright panel — the obvious "go here next".
			var pulse := 0.5 + 0.5 * sin(_t * 2.5 + i)
			top = Color(0.07, 0.24, 0.1, 0.98).lerp(Color(0.1, 0.4, 0.16, 0.99), pulse)
			side = Color(0.04, 0.12, 0.06, 0.98).lerp(Color(0.06, 0.2, 0.1, 0.99), pulse)
			border = Color(0.0, 1.0, 0.25, 0.85 if hovered else 0.6)

	# Soft drop shadow under the tile — grounds it, adds height/depth.
	var sh_off := Vector2(7, 10)
	draw_colored_polygon(PackedVector2Array([
		c + sh_off + Vector2(0, -hh), c + sh_off + Vector2(hw, 0),
		c + sh_off + Vector2(0, hh), c + sh_off + Vector2(-hw, 0),
	]), Color(0.0, 0.0, 0.0, 0.35))

	# Isometric thickness (side faces).
	var thick := 10.0
	draw_colored_polygon(PackedVector2Array([
		c + Vector2(-hw, 0), c + Vector2(0, hh), c + Vector2(0, hh + thick), c + Vector2(-hw, thick),
	]), side)
	draw_colored_polygon(PackedVector2Array([
		c + Vector2(hw, 0), c + Vector2(0, hh), c + Vector2(0, hh + thick), c + Vector2(hw, thick),
	]), side.darkened(0.3))

	# Top diamond face.
	var pts_top := PackedVector2Array([
		c + Vector2(0, -hh), c + Vector2(hw, 0), c + Vector2(0, hh), c + Vector2(-hw, 0),
	])
	draw_colored_polygon(pts_top, top)
	# Subtle inner grid lines (tech texture) on the top face.
	draw_polyline(PackedVector2Array([
		c + Vector2(0, -hh), c + Vector2(0, hh),
		c + Vector2(-hw, 0), c + Vector2(hw, 0),
	]), Color(0.0, 1.0, 0.3, 0.08), 1.0, true)

	# Glow ring (pulsing for available).
	var pulse := 0.5 + 0.5 * sin(_t * 2.0 + i)
	var ring := PackedVector2Array([
		c + Vector2(0, -hh), c + Vector2(hw, 0), c + Vector2(0, hh), c + Vector2(-hw, 0), c + Vector2(0, -hh),
	])
	if state == AVAILABLE:
		draw_polyline(ring, Color(border, 0.9 * pulse + 0.3), 3.0 if hovered else 2.0, true)
	else:
		draw_polyline(ring, border, 2.0, true)

func _draw_node_label(i: int) -> void:
	var n: Dictionary = _nodes[i]
	var c := _screen_pos(n["iso"])
	var state: int = n["state"]
	var hh := TILE_H * 0.5
	var thick := 10.0

	# Compact ASCII status label (no system emoji).
	var label: String = n["cat"]
	var prefix := ""
	var label_color := Color(0.78, 1.0, 0.82)
	match state:
		SOLVED:
			prefix = ""      # bright green panel + color already says "cleared"
			label_color = Color(0.3, 1.0, 0.5)
		AVAILABLE:
			prefix = "> "
			label_color = Color(0.9, 1.0, 0.6)
		LOCKED:
			prefix = ""
			label_color = Color(0.55, 0.6, 0.55)
	label = prefix + label
	# Smaller font + tighter panel so labels don't reach a neighbor diamond.
	var fsize := 20
	var tw := _font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize).x
	var pad := 5.0
	var panel_rect := Rect2(c.x - tw * 0.5 - pad, c.y + hh + thick + 10, tw + pad * 2, fsize + pad)
	draw_rect(panel_rect, Color(0.02, 0.05, 0.03, 0.9))
	draw_rect(panel_rect, Color(0.0, 1.0, 0.3, 0.18), false, 1.0)
	draw_string(_font, Vector2(c.x - tw * 0.5, c.y + hh + thick + 26), label, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize, label_color)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_hover = _node_at(event.position)
		queue_redraw()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_tap_node(_node_at(event.position))
	elif event is InputEventScreenTouch and event.pressed:
		_tap_node(_node_at(event.position))

func _tap_node(idx: int) -> void:
	if idx < 0 or _nodes[idx]["state"] == LOCKED:
		return
	_walk_to(idx)
	var cat: String = _nodes[idx]["cat"]
	get_tree().create_timer(0.2).timeout.connect(func() -> void:
		category_launched.emit(cat))

func _node_at(p: Vector2) -> int:
	# Generous hit zone: the diamond PLUS a margin and the label band below it,
	# so a finger-tap on a phone (where tiles shrink to ~45px) still lands.
	var best := -1
	var best_d := INF
	for i in _nodes.size():
		var c := _screen_pos(_nodes[i]["iso"])
		var d := p - c
		# Diamond (with extra margin) OR the label band under it.
		var in_diamond := absf(d.x) / (TILE_W * 0.5 + 22.0) + absf(d.y) / (TILE_H * 0.5 + 22.0) <= 1.0
		var in_label_band := absf(d.x) <= TILE_W * 0.5 + 22.0 and d.y >= TILE_H * 0.5 - 10.0 and d.y <= TILE_H * 0.5 + 46.0
		if in_diamond or in_label_band:
			var dist := absf(d.x) + absf(d.y)
			if dist < best_d:
				best_d = dist
				best = i
	return best

func _walk_to(idx: int) -> void:
	# _char_from/_char_to hold PURE tile centroids; the feet offset is applied in
	# _process so the lerp stays clean.
	_char_from = _screen_pos(_nodes[_char_index]["iso"])
	_char_to = _screen_pos(_nodes[idx]["iso"])
	_char_index = idx
	_char_anim = 0.0
