extends Node
## Gameplay simulation probe — presses real keys, verifies move/jump/dash.
## Death-robust: re-fetches the player after respawn.

var _failures: Array[String] = []
var _passes: int = 0
var _level: Node2D = null

func _ready() -> void:
	_run()

func _check(cond: bool, msg: String) -> void:
	if cond:
		_passes += 1
	else:
		_failures.append(msg)

func _player() -> Player:
	return _level.get("player") as Player

func _run() -> void:
	var scene := load("res://scenes/levels/level_01_terminal.tscn")
	_level = scene.instantiate()
	add_child(_level)
	await get_tree().create_timer(0.5).timeout

	var p := _player()
	if not p:
		_failures.append("player not spawned")
		_finish()
		return

	var start_x: float = p.global_position.x
	print("start: ", start_x)

	# Move right — re-fetch in case of death/respawn.
	Input.action_press("move_right")
	var reached := false
	var max_x := start_x
	for i in range(60):
		await get_tree().create_timer(0.05).timeout
		var cur := _player()
		if cur:
			max_x = maxf(max_x, cur.global_position.x)
			if cur.global_position.x > start_x + 120:
				reached = true
				break
	Input.action_release("move_right")
	print("after right: max_x=", max_x, " reached=", reached)
	_check(reached, "player can move right (reached %.1f px)" % (max_x - start_x))

	# Jump — teleport player to a safe flat spot first (avoid drone kill noise).
	p = _player()
	if p:
		p.global_position = Vector2(120, 120)  # flat ground near start
		await get_tree().create_timer(0.2).timeout
		var y_before: float = p.global_position.y
		Input.action_press("jump")
		var rose := false
		for i in range(10):
			await get_tree().create_timer(0.05).timeout
			var cur := _player()
			if cur and cur.global_position.y < y_before - 15:
				rose = true
				break
		Input.action_release("jump")
		print("jump: y ", y_before, " rose=", rose)
		_check(rose, "player jumps")

	# Dash — verify horizontal burst.
	p = _player()
	if p:
		p.global_position = Vector2(120, 120)
		await get_tree().create_timer(0.2).timeout
		var x_before: float = p.global_position.x
		Input.action_press("dash")
		await get_tree().create_timer(0.05).timeout
		Input.action_release("dash")
		var dashed := false
		for i in range(10):
			await get_tree().create_timer(0.05).timeout
			var cur := _player()
			if cur and cur.global_position.x > x_before + 50:
				dashed = true
				break
		print("dash: x ", x_before, " dashed=", dashed)
		_check(dashed, "player dashes")

	_finish()

func _finish() -> void:
	if _failures.is_empty():
		print("PLAYTEST PROBE PASSED (%d)" % _passes)
		get_tree().quit(0)
	else:
		for f in _failures:
			print("FAIL: ", f)
		print("PLAYTEST PROBE FAILED: %d failure(s), %d passed" % [_failures.size(), _passes])
		get_tree().quit(1)
