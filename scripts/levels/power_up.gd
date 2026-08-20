class_name PowerUp
extends Area2D
## Hack-tool powerup pickup. OVERCLOCK = bullet-time + speed boost;
## SHIELD = firewall bubble (temporary invincibility).

enum Type { OVERCLOCK, SHIELD }

@export var type: Type = Type.OVERCLOCK

var collected: bool = false

@onready var sprite: Sprite2D = $Sprite2D

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	# Idle float + gentle glow pulse
	var tween := create_tween().set_loops()
	tween.tween_property(sprite, "position:y", -4.0, 0.7).set_trans(Tween.TRANS_SINE)
	tween.tween_property(sprite, "position:y", 4.0, 0.7).set_trans(Tween.TRANS_SINE)
	tween.parallel().tween_property(sprite, "modulate:a", 0.7, 0.7).set_trans(Tween.TRANS_SINE)
	tween.tween_property(sprite, "modulate:a", 1.0, 0.7).set_trans(Tween.TRANS_SINE)

func _on_body_entered(body: Node2D) -> void:
	if collected or not (body is Player):
		return
	collected = true
	AudioManager.play("chip")
	if body.has_method("apply_powerup"):
		body.apply_powerup(type)
	var lvl := get_tree().current_scene
	if lvl and lvl.has_method("add_trauma"):
		lvl.add_trauma(0.3)
	if Settings.particles_enabled:
		_spawn_burst()
	var tween := create_tween()
	tween.tween_property(sprite, "scale", Vector2(1.9, 1.9), 0.15)
	tween.tween_property(sprite, "modulate:a", 0.0, 0.2)
	tween.tween_callback(queue_free)

func _spawn_burst() -> void:
	var b := CPUParticles2D.new()
	b.one_shot = true
	b.emitting = true
	b.amount = 18
	b.lifetime = 0.5
	b.explosiveness = 1.0
	b.position = Vector2.ZERO
	b.spread = 180.0
	b.gravity = Vector2(0, -80)
	b.initial_velocity_min = 70.0
	b.initial_velocity_max = 200.0
	b.scale_amount_min = 0.4
	b.scale_amount_max = 1.0
	b.color = Color(0.4, 1.0, 1.0, 0.9) if type == Type.OVERCLOCK else Color(1.0, 0.8, 0.3, 0.9)
	b.finished.connect(b.queue_free)
	add_child(b)
