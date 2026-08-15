class_name FirewallTerminal
extends Area2D
## Checkpoint firewall — when the player touches it, they must solve a
## DSA problem to unlock the exit / next level.

signal puzzle_started(level_index: int)
signal access_granted(level_index: int)

@export var level_index: int = 0
@export var terminal_name: String = "FIREWALL_01"

var _player: Player = null
var _in_range: bool = false
var _puzzle_open: bool = false
var puzzle: Dictionary = {}

@onready var sprite: Sprite2D = $Sprite2D
@onready var prompt: Label = $Prompt

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	prompt.hide()
	# Glow pulse
	var tween := create_tween().set_loops()
	tween.tween_property(sprite, "modulate:a", 0.7, 0.8)
	tween.tween_property(sprite, "modulate:a", 1.0, 0.8)

func _physics_process(_delta: float) -> void:
	# Poll the action state so BOTH real key events AND virtual touch buttons
	# (Input.action_press, which does NOT dispatch _unhandled_input) work.
	if _in_range and _player and not _puzzle_open and Input.is_action_just_pressed("interact"):
		_open_puzzle()

func _on_body_entered(body: Node2D) -> void:
	if body is Player:
		_player = body
		_in_range = true
		prompt.show()

func _on_body_exited(body: Node2D) -> void:
	if body is Player:
		_player = null
		_in_range = false
		prompt.hide()

func _unhandled_input(event: InputEvent) -> void:
	if _in_range and _player and not _puzzle_open and event.is_action_pressed("interact"):
		_open_puzzle()
		get_viewport().set_input_as_handled()

func _open_puzzle() -> void:
	if _puzzle_open:
		return  # idempotency guard — prevents double-open on keyboard
	_puzzle_open = true
	puzzle = GameManager.get_puzzle_for_level(level_index)
	puzzle_started.emit(level_index)
	# The level scene listens and opens the puzzle UI (keeps this class decoupled).

## Reset after the puzzle closes so the terminal can be re-approached.
## Without this, EXIT or a lockout would permanently brick the level gate.
func reset_terminal() -> void:
	_puzzle_open = false
	prompt.show()
