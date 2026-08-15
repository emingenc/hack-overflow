extends Node
## CameraShake — trauma² screen shake, applied to the owning Camera2D's `offset`
## (offset is independent of position smoothing, so follow + shake compose cleanly).
## Attached as a child of the Camera2D; the camera is the `get_parent()`.

const DECAY: float = 1.5          # trauma lost per second
const MAX_OFFSET: float = 14.0    # px
const MAX_ROTATION: float = 0.2   # degrees — kept subtle

var trauma: float = 0.0
var _time: float = 0.0

func add_trauma(amount: float) -> void:
	if Settings.reduced_motion:
		return
	trauma = clampf(trauma + amount, 0.0, 1.0)

func _process(delta: float) -> void:
	var cam := get_parent() as Camera2D
	if cam == null:
		return
	_time += delta
	trauma = maxf(trauma - DECAY * delta, 0.0)
	if trauma <= 0.0:
		cam.offset = Vector2.ZERO
		cam.rotation_degrees = 0.0
		return
	var amp := trauma * trauma * Settings.screen_shake_scale
	cam.offset = Vector2(
		sin(_time * 97.3) * amp * MAX_OFFSET,
		cos(_time * 53.7) * amp * MAX_OFFSET
	)
	cam.rotation_degrees = sin(_time * 71.0) * amp * MAX_ROTATION
