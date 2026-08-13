class_name PatrolDrone
extends Area2D
## Patrol drone — moves back and forth. Hurts on contact.
## Properties set in scene: patrol_distance, speed, wait_time.

@export var patrol_distance: float = 80.0
@export var speed: float = 60.0
@export var wait_time: float = 0.4

var _start_x: float = 0.0
var _dir: int = 1
var _waiting: float = 0.0

@onready var sprite: Sprite2D = $Sprite2D

func _ready() -> void:
	_start_x = position.x
	body_entered.connect(_on_body_entered)

func _physics_process(delta: float) -> void:
	if _waiting > 0.0:
		_waiting -= delta
		sprite.rotation = 0.0
		return
	position.x += _dir * speed * delta
	if absf(position.x - _start_x) >= patrol_distance:
		position.x = _start_x + _dir * patrol_distance
		_dir *= -1
		_waiting = wait_time
	sprite.rotation = sin(Time.get_ticks_msec() * 0.02) * 0.15

func _on_body_entered(body: Node2D) -> void:
	if body is Player:
		body.die()
