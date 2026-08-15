extends Node
## Settings — global juice/accessibility toggles, persisted to user://settings.cfg.
## Every juice call site gates on these so reduced-motion kills shake/hitstop/flash in one place.

const CONFIG_PATH: String = "user://settings.cfg"

# Juice toggles
var screen_shake_scale: float = 1.0   # 0.0..1.0
var hitstop_enabled: bool = true
var particles_enabled: bool = true
var chromatic_aberration: bool = true

# Accessibility
var reduced_motion: bool = false       # master kill-switch for shake/hitstop/flash
var game_speed: float = 1.0            # 0.5 / 0.75 / 1.0 / 1.25
var background_parallax_enabled: bool = true

func _ready() -> void:
	load_settings()
	_apply_game_speed()

func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(CONFIG_PATH) != OK:
		return
	screen_shake_scale = cfg.get_value("juice", "screen_shake_scale", 1.0)
	hitstop_enabled = cfg.get_value("juice", "hitstop_enabled", true)
	particles_enabled = cfg.get_value("juice", "particles_enabled", true)
	chromatic_aberration = cfg.get_value("juice", "chromatic_aberration", true)
	reduced_motion = cfg.get_value("access", "reduced_motion", false)
	game_speed = cfg.get_value("access", "game_speed", 1.0)
	background_parallax_enabled = cfg.get_value("access", "background_parallax", true)

func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("juice", "screen_shake_scale", screen_shake_scale)
	cfg.set_value("juice", "hitstop_enabled", hitstop_enabled)
	cfg.set_value("juice", "particles_enabled", particles_enabled)
	cfg.set_value("juice", "chromatic_aberration", chromatic_aberration)
	cfg.set_value("access", "reduced_motion", reduced_motion)
	cfg.set_value("access", "game_speed", game_speed)
	cfg.set_value("access", "background_parallax", background_parallax_enabled)
	cfg.save(CONFIG_PATH)

func set_game_speed(value: float) -> void:
	game_speed = clampf(value, 0.5, 1.5)
	_apply_game_speed()
	save_settings()

func _apply_game_speed() -> void:
	if not reduced_motion:
		Engine.time_scale = game_speed

## Convenience: should juice run at all this frame?
func juice_allowed() -> bool:
	return not reduced_motion
