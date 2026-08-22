class_name PatrolDrone
extends Area2D
## Patrol drone — moves back and forth. Hurts on contact. Animated 4-frame
## Warped City drone sprite (matches the humanoid player's art style).

@export var patrol_distance: float = 80.0
@export var speed: float = 60.0
@export var wait_time: float = 0.4
@export var vertical: bool = false  # true = patrols up/down instead of left/right

var _start_x: float = 0.0
var _start_y: float = 0.0
var _dir: int = 1
var _waiting: float = 0.0
var _frames: Array[Texture2D] = []
var _anim_t: float = 0.0

@onready var sprite: Sprite2D = $Sprite2D

func _ready() -> void:
	_start_x = position.x
	_start_y = position.y
	body_entered.connect(_on_body_entered)
	# Load the 4-frame drone animation.
	for i in range(1, 5):
		_frames.append(load("res://assets/warped/enemy/drone-%d.png" % i))
	if not _frames.is_empty():
		sprite.texture = _frames[0]
		sprite.scale = Vector2(0.55, 0.55)

func _physics_process(delta: float) -> void:
	_anim_t += delta
	if not _frames.is_empty():
		var fi := int(_anim_t * 8.0) % _frames.size()
		sprite.texture = _frames[fi]
	if _waiting > 0.0:
		_waiting -= delta
		sprite.rotation = 0.0
		return
	if vertical:
		position.y += _dir * speed * delta
		if absf(position.y - _start_y) >= patrol_distance:
			position.y = _start_y + _dir * patrol_distance
			_dir *= -1
			_waiting = wait_time
	else:
		position.x += _dir * speed * delta
		if absf(position.x - _start_x) >= patrol_distance:
			position.x = _start_x + _dir * patrol_distance
			_dir *= -1
			_waiting = wait_time
	sprite.rotation = sin(Time.get_ticks_msec() * 0.02) * 0.15

func _on_body_entered(body: Node2D) -> void:
	if body is Player:
		body.die()
