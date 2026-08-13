class_name FirewallTurret
extends Area2D
## Stationary turret — damages on touch and periodically fires a projectile.

@export var fire_interval: float = 2.0
@export var projectile_speed: float = 220.0
@export var fire_direction: Vector2 = Vector2.LEFT

var _timer: float = 2.0

@onready var sprite: Sprite2D = $Sprite2D

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _physics_process(delta: float) -> void:
	_timer -= delta
	if _timer <= 0.0:
		_timer = fire_interval
		_fire()

func _fire() -> void:
	var proj := EnemyProjectile.new()
	proj.velocity = fire_direction * projectile_speed
	proj.position = position + fire_direction * 14.0
	get_parent().add_child(proj)

func _on_body_entered(body: Node2D) -> void:
	if body is Player:
		body.die()
