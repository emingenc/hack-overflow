extends Node
## Hitstop — freeze frames (world holds, real-time clock keeps ticking).
## Uses wall-clock time so the freeze timer decrements even while Engine.time_scale == 0.

var _until_ms: int = 0

func freeze(seconds: float) -> void:
	if not Settings.hitstop_enabled or Settings.reduced_motion:
		return
	var target: int = Time.get_ticks_msec() + int(seconds * 1000.0)
	_until_ms = maxi(_until_ms, target)
	Engine.time_scale = 0.0

func _process(_delta: float) -> void:
	if _until_ms == 0:
		return
	if Time.get_ticks_msec() >= _until_ms:
		_until_ms = 0
		Engine.time_scale = Settings.game_speed
