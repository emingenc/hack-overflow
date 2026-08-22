class_name Player
extends CharacterBody2D
## Player — hooded hacker with tight platforming physics.
## Features: coyote time, jump buffering, variable jump height, double jump, dash.

signal died
signal checkpoint_reached
signal chip_collected(total: int)

# Movement constants
const SPEED: float = 260.0
const ACCEL: float = 1800.0
const FRICTION: float = 2200.0
const AIR_ACCEL: float = 1400.0
const JUMP_VELOCITY: float = -560.0
const JUMP_CUT_MULTIPLIER: float = 0.45
const MAX_FALL_SPEED: float = 900.0
const COYOTE_TIME: float = 0.12
const JUMP_BUFFER_TIME: float = 0.12
const BASE_SCALE: Vector2 = Vector2(0.5, 0.5)  # scene Sprite2D base scale (Warped City char)
const DASH_SPEED: float = 520.0
const DASH_TIME: float = 0.16
const DASH_COOLDOWN: float = 0.45

@onready var sprite: Sprite2D = $Sprite2D
@onready var anim: AnimationPlayer = $AnimationPlayer
@onready var dash_trail: CPUParticles2D = $DashTrail

var coyote_timer: float = 0.0
var jump_buffer_timer: float = 0.0
var jumps_remaining: int = 2  # double jump
var was_on_floor: bool = false
var can_dash: bool = true
var dash_timer: float = 0.0
var dash_cooldown_timer: float = 0.0
var dash_dir: Vector2 = Vector2.RIGHT
var is_dashing: bool = false
var facing: int = 1  # 1 = right, -1 = left
var gravity: float = 1500.0
var fall_speed_at_impact: float = 0.0
var _squash_tween: Tween = null
# Powerup state
var _speed_multiplier: float = 1.0
var _overclock_timer: float = 0.0
var _invincible_timer: float = 0.0

func _ready() -> void:
	dash_trail.emitting = false

func _physics_process(delta: float) -> void:
	dash_cooldown_timer = maxf(0.0, dash_cooldown_timer - delta)
	# Powerup timers
	if _overclock_timer > 0.0:
		_overclock_timer -= delta
		if _overclock_timer <= 0.0:
			Engine.time_scale = 1.0
			_speed_multiplier = 1.0
	_invincible_timer = maxf(0.0, _invincible_timer - delta)

	# Jump buffer is polled first so a dash can't eat the input; it freezes during
	# the dash so buffered dash→jump chains still fire when the dash ends.
	if Input.is_action_just_pressed("jump"):
		jump_buffer_timer = JUMP_BUFFER_TIME
	elif not is_dashing:
		jump_buffer_timer = maxf(0.0, jump_buffer_timer - delta)

	# ── Dash ──────────────────────────────────────────────────────
	if Input.is_action_just_pressed("dash") and can_dash and dash_cooldown_timer <= 0.0:
		dash_dir = Vector2(Input.get_axis("move_left", "move_right"), 0.0)
		if dash_dir.x == 0.0:
			dash_dir = Vector2(facing, 0.0)
		_start_dash()

	if is_dashing:
		dash_timer -= delta
		velocity = dash_dir * DASH_SPEED
		if dash_timer <= 0.0:
			is_dashing = false
			dash_trail.emitting = false
			velocity.x = dash_dir.x * SPEED * 0.6
		move_and_slide()
		return

	# ── Gravity ───────────────────────────────────────────────────
	if not is_on_floor():
		velocity.y += gravity * delta
		velocity.y = minf(velocity.y, MAX_FALL_SPEED)

	# ── Horizontal movement ───────────────────────────────────────
	var move_input := Input.get_axis("move_left", "move_right")
	var target_speed := move_input * SPEED * _speed_multiplier
	if move_input != 0.0:
		facing = 1 if move_input > 0.0 else -1
		if is_on_floor():
			velocity.x = move_toward(velocity.x, target_speed, ACCEL * delta)
		else:
			velocity.x = move_toward(velocity.x, target_speed, AIR_ACCEL * delta)
	else:
		if is_on_floor():
			velocity.x = move_toward(velocity.x, 0.0, FRICTION * delta)
		else:
			velocity.x = move_toward(velocity.x, 0.0, AIR_ACCEL * 0.6 * delta)

	# ── Jumping state machines ────────────────────────────────────
	if is_on_floor():
		coyote_timer = COYOTE_TIME
		jumps_remaining = 1  # one air jump on top of the ground jump
	else:
		coyote_timer = maxf(0.0, coyote_timer - delta)

	# Buffered + coyote jump (ground)
	if jump_buffer_timer > 0.0 and coyote_timer > 0.0:
		velocity.y = JUMP_VELOCITY
		jump_buffer_timer = 0.0
		coyote_timer = 0.0
		_spawn_dust()
		AudioManager.play("jump")
		_squash(Vector2(0.6, 1.4), 0.08)
	# Double jump (air)
	elif jump_buffer_timer > 0.0 and jumps_remaining > 0 and not is_on_floor():
		velocity.y = JUMP_VELOCITY * 0.95
		jump_buffer_timer = 0.0
		jumps_remaining -= 1
		_spawn_dust()
		AudioManager.play("double_jump")

	# Variable jump height (release early = short hop)
	if Input.is_action_just_released("jump") and velocity.y < 0.0:
		velocity.y *= JUMP_CUT_MULTIPLIER

	# ── Animation ─────────────────────────────────────────────────
	_update_animation()

	fall_speed_at_impact = velocity.y
	move_and_slide()

	# Landing: dust + refill dash (air dash only consumes one).
	if is_on_floor() and not was_on_floor and fall_speed_at_impact >= 0.0:
		_spawn_dust()
		AudioManager.play("land", -8.0)
		can_dash = true
		var impact := clampf(fall_speed_at_impact / MAX_FALL_SPEED, 0.0, 1.0)
		_squash(Vector2(1.0 + 0.5 * impact, 1.0 - 0.4 * impact), 0.07)
		if impact > 0.6:
			_add_trauma(0.3 * impact)
			Hitstop.freeze(0.05)
	was_on_floor = is_on_floor()

func _start_dash() -> void:
	is_dashing = true
	dash_timer = DASH_TIME
	can_dash = false
	dash_cooldown_timer = DASH_COOLDOWN
	dash_trail.restart()
	AudioManager.play("dash")
	Hitstop.freeze(0.04)
	_add_trauma(0.35)
	_squash(Vector2(1.3, 0.7), 0.12)
	# Refill happens on landing (see _physics_process).

func _update_animation() -> void:
	sprite.flip_h = facing < 0
	sprite.modulate = Color(0.55, 0.85, 1.0) if _invincible_timer > 0.0 else Color(1, 1, 1)
	if is_dashing:
		anim.play("jump")  # dash uses the stretched mid-air pose (no separate sprite)
		return
	if not is_on_floor():
		anim.play("jump")
	elif absf(velocity.x) > 20.0:
		anim.play("run")
	else:
		anim.play("idle")

func _spawn_dust() -> void:
	if not Settings.particles_enabled:
		return
	# Simple dust puff via CPUParticles2D at feet
	var p := CPUParticles2D.new()
	p.one_shot = true
	p.emitting = true
	p.amount = 5
	p.lifetime = 0.3
	p.explosiveness = 1.0
	p.position = Vector2(0, 10)
	p.direction = Vector2.UP
	p.spread = 60.0
	p.gravity = Vector2(0, -40)
	p.initial_velocity_min = 30.0
	p.initial_velocity_max = 80.0
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.0
	p.color = Color(0.0, 1.0, 0.25, 0.5)
	p.finished.connect(p.queue_free)
	add_child(p)

## Squash-and-stretch: fast ease-out scale, then settle (2026 norm — no slow wobble).
## Scales relative to BASE_SCALE (scene scale 0.75) so it never inflates the sprite.
func _squash(scale: Vector2, duration: float) -> void:
	if Settings.reduced_motion:
		return
	if _squash_tween and _squash_tween.is_valid():
		_squash_tween.kill()
	_squash_tween = create_tween()
	_squash_tween.tween_property(sprite, "scale", BASE_SCALE * scale, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_squash_tween.tween_property(sprite, "scale", BASE_SCALE, duration * 2.0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

## Route screen-shake to the owning level (the player's parent).
func _add_trauma(amount: float) -> void:
	var lvl := get_parent() as Level
	if lvl:
		lvl.add_trauma(amount)

## Apply a collected powerup (PowerUp.Type). OVERCLOCK = bullet-time + speed;
## SHIELD = temporary firewall invincibility.
func apply_powerup(type: int) -> void:
	if type == PowerUp.Type.OVERCLOCK:
		_overclock_timer = 4.0
		_speed_multiplier = 2.0
		Engine.time_scale = 0.35
		AudioManager.play("dash")
	elif type == PowerUp.Type.SHIELD:
		_invincible_timer = 5.0
		AudioManager.play("chip")

func die() -> void:
	if _invincible_timer > 0.0:
		return  # firewall shield absorbs the hit
	AudioManager.play("death")
	Hitstop.freeze(0.08)
	_add_trauma(0.5)
	died.emit()
	queue_free()
