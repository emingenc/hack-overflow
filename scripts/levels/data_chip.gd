class_name DataChip
extends Area2D
## Collectible data chip. Adds to level chip counter, plays a sound, and
## sparkles. A magnet pulls it toward the player when they get close.

@export var value: int = 1

var collected: bool = false

@onready var sprite: Sprite2D = $Sprite2D

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	# Idle bobbing + rotation
	var tween := create_tween().set_loops()
	tween.tween_property(sprite, "position:y", -3.0, 0.6).set_trans(Tween.TRANS_SINE)
	tween.tween_property(sprite, "position:y", 3.0, 0.6).set_trans(Tween.TRANS_SINE)
	tween.parallel().tween_property(sprite, "rotation", 0.15, 0.6)
	tween.tween_property(sprite, "rotation", -0.15, 0.6)

func _physics_process(delta: float) -> void:
	if collected:
		return
	# Magnet: pull toward the player when close (better collection feel).
	var level := get_tree().current_scene
	if level and level.get("player") != null and is_instance_valid(level.player):
		var p: Node2D = level.player
		var d: float = global_position.distance_to(p.global_position)
		if d < 90.0 and d > 4.0:
			global_position = global_position.move_toward(p.global_position, 440.0 * delta)

func _on_body_entered(body: Node2D) -> void:
	if collected or not (body is Player):
		return
	collected = true
	AudioManager.play("chip")
	var level := get_tree().current_scene
	if level and level.has_method("on_chip_collected"):
		level.on_chip_collected(value)
	# Sparkle burst + collect pop animation
	if Settings.particles_enabled:
		_spawn_sparkle()
	var tween := create_tween()
	tween.tween_property(sprite, "scale", Vector2(1.6, 1.6), 0.15)
	tween.tween_property(sprite, "modulate:a", 0.0, 0.2)
	tween.tween_callback(queue_free)

func _spawn_sparkle() -> void:
	var burst := CPUParticles2D.new()
	burst.one_shot = true
	burst.emitting = true
	burst.amount = 12
	burst.lifetime = 0.4
	burst.explosiveness = 1.0
	burst.position = Vector2.ZERO
	burst.spread = 180.0
	burst.gravity = Vector2(0, -60)
	burst.initial_velocity_min = 60.0
	burst.initial_velocity_max = 160.0
	burst.scale_amount_min = 0.3
	burst.scale_amount_max = 0.8
	burst.color = Color(0.4, 1.0, 0.6, 0.9)
	burst.finished.connect(burst.queue_free)
	add_child(burst)
