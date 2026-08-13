class_name DataChip
extends Area2D
## Collectible data chip. Adds to level chip counter and plays a sound.

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

func _on_body_entered(body: Node2D) -> void:
	if collected or not (body is Player):
		return
	collected = true
	AudioManager.play("chip")
	var level := get_tree().current_scene
	if level and level.has_method("on_chip_collected"):
		level.on_chip_collected(value)
	# Collect pop animation
	var tween := create_tween()
	tween.tween_property(sprite, "scale", Vector2(1.6, 1.6), 0.15)
	tween.tween_property(sprite, "modulate:a", 0.0, 0.2)
	tween.tween_callback(queue_free)
