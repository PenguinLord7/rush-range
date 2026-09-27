extends Node
## Persisted player settings (sensitivity, FOV, volumes, crosshair shape).
##
## Loaded once at startup and saved to user://settings.cfg whenever a value
## changes. The settings menu binds sliders straight to these properties and
## calls apply()/save().

const PATH := "user://settings.cfg"

signal changed

var mouse_sensitivity: float = 0.0025
var fov: float = 80.0
var master_volume: float = 0.9
var music_volume: float = 0.7
var effects_volume: float = 1.0
var crosshair_size: float = 8.0
var crosshair_gap: float = 6.0
var crosshair_thickness: float = 2.0
var crosshair_dot: bool = true
var invert_y: bool = false
var screen_shake: bool = true

func _ready() -> void:
	load_settings()
	apply()

func set_value(key: String, value: Variant) -> void:
	if not _keys().has(key):
		push_warning("Settings: unknown key '%s'" % key)
		return
	set(key, value)
	apply()
	changed.emit()
	save_settings()

func apply() -> void:
	AudioManager.set_bus_volume("Master", master_volume)
	AudioManager.set_bus_volume("Music", music_volume)
	AudioManager.set_bus_volume("Effects", effects_volume)

func save_settings() -> void:
	var cfg := ConfigFile.new()
	for key in _keys():
		cfg.set_value("settings", key, get(key))
	cfg.save(PATH)

func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return
	for key in _keys():
		if cfg.has_section_key("settings", key):
			set(key, cfg.get_value("settings", key))

func reset_defaults() -> void:
	var defaults := {
		"mouse_sensitivity": 0.0025,
		"fov": 80.0,
		"master_volume": 0.9,
		"music_volume": 0.7,
		"effects_volume": 1.0,
		"crosshair_size": 8.0,
		"crosshair_gap": 6.0,
		"crosshair_thickness": 2.0,
		"crosshair_dot": true,
		"invert_y": false,
		"screen_shake": true,
	}
	for key in defaults:
		set(key, defaults[key])
	apply()
	changed.emit()
	save_settings()

func _keys() -> Array:
	return [
		"mouse_sensitivity", "fov", "master_volume", "music_volume",
		"effects_volume", "crosshair_size", "crosshair_gap",
		"crosshair_thickness", "crosshair_dot", "invert_y", "screen_shake",
	]
