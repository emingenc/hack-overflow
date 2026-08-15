class_name EnemyProjectile
extends Area2D
## Projectile fired by FirewallTurret. Carries its own sprite + collision.

var velocity: Vector2 = Vector2.LEFT
var _lifetime: float = 3.0

func _ready() -> void:
	# Sprite
	var spr := Sprite2D.new()
	spr.texture = preload("res://assets/sprites/chip.svg")
	spr.scale = Vector2(0.35, 0.35)
	spr.modulate = Color(1.0, 0.22, 0.18)
	spr.name = "Sprite2D"
	add_child(spr)

	# Collision
	var col := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 5.0
	col.shape = shape
	add_child(col)

	# Layers: 4 = enemy projectile, mask hits player (1) and tiles
	collision_layer = 4
	collision_mask = 1 | 2
	body_entered.connect(_on_body_entered)

func _physics_process(delta: float) -> void:
	position += velocity * delta
	_lifetime -= delta
	if _lifetime <= 0.0:
		queue_free()

func _on_body_entered(body: Node2D) -> void:
	if body is Player:
		body.die()
	queue_free()
