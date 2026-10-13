extends Node
## Player-facing settings (audio volumes, mouse sensitivity) plus input map
## and audio bus setup. Stored apart from progress so Restart keeps them.

signal changed

const PATH := "user://settings.cfg"
const BUSES: Array[String] = ["Master", "Music", "SFX", "Ambience"]

var volumes := {"Master": 0.8, "Music": 0.6, "SFX": 0.8, "Ambience": 0.7}
## 0..1 slider value; the player maps it to radians per pixel.
var mouse_sensitivity := 0.45
var invert_y := false
var fullscreen := false
var vsync := true

const DEFAULT_VOLUMES := {"Master": 0.8, "Music": 0.6, "SFX": 0.8, "Ambience": 0.7}


func _ready() -> void:
	_setup_input()
	_setup_buses()
	load_settings()
	apply()
	_apply_display.call_deferred()


func set_volume(bus: String, value: float) -> void:
	volumes[bus] = clampf(value, 0.0, 1.0)
	apply()


func set_sensitivity(value: float) -> void:
	mouse_sensitivity = clampf(value, 0.05, 1.0)
	changed.emit()


func set_invert_y(on: bool) -> void:
	invert_y = on
	changed.emit()


func set_fullscreen(on: bool) -> void:
	fullscreen = on
	_apply_display()
	changed.emit()


func set_vsync(on: bool) -> void:
	vsync = on
	_apply_display()
	changed.emit()


func reset_audio() -> void:
	volumes = DEFAULT_VOLUMES.duplicate()
	apply()


func reset_controls() -> void:
	mouse_sensitivity = 0.45
	invert_y = false
	changed.emit()


func reset_display() -> void:
	fullscreen = false
	vsync = true
	_apply_display()
	changed.emit()


func _apply_display() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var w := get_window()
	if fullscreen and w.mode != Window.MODE_FULLSCREEN:
		w.mode = Window.MODE_FULLSCREEN
	elif not fullscreen and w.mode == Window.MODE_FULLSCREEN:
		w.mode = Window.MODE_WINDOWED
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED)


func apply() -> void:
	for bus in BUSES:
		var idx := AudioServer.get_bus_index(bus)
		if idx == -1:
			continue
		var v: float = volumes.get(bus, 0.8)
		AudioServer.set_bus_mute(idx, v <= 0.001)
		AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(v, 0.001)))
	changed.emit()


func save_settings() -> void:
	var cfg := ConfigFile.new()
	for bus in BUSES:
		cfg.set_value("audio", bus, volumes[bus])
	cfg.set_value("input", "mouse_sensitivity", mouse_sensitivity)
	cfg.set_value("input", "invert_y", invert_y)
	cfg.set_value("display", "fullscreen", fullscreen)
	cfg.set_value("display", "vsync", vsync)
	cfg.save(PATH)


func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return
	for bus in BUSES:
		volumes[bus] = clampf(float(cfg.get_value("audio", bus, volumes[bus])), 0.0, 1.0)
	mouse_sensitivity = clampf(float(cfg.get_value("input", "mouse_sensitivity", mouse_sensitivity)), 0.05, 1.0)
	invert_y = bool(cfg.get_value("input", "invert_y", false))
	fullscreen = bool(cfg.get_value("display", "fullscreen", false))
	vsync = bool(cfg.get_value("display", "vsync", true))


func _setup_input() -> void:
	_add_keys("move_forward", [KEY_W, KEY_UP])
	_add_keys("move_back", [KEY_S, KEY_DOWN])
	_add_keys("move_left", [KEY_A, KEY_LEFT])
	_add_keys("move_right", [KEY_D, KEY_RIGHT])
	_add_keys("interact", [KEY_E])
	_add_keys("pause", [KEY_ESCAPE])
	_add_keys("toggle_hud", [KEY_H])
	_add_keys("fullscreen", [KEY_F11])
	_add_keys("journal", [KEY_J])
	_add_keys("map", [KEY_M])
	_add_keys("jump", [KEY_SPACE])
	if not InputMap.has_action("fish_action"):
		InputMap.add_action("fish_action")
		var rmb := InputEventMouseButton.new()
		rmb.button_index = MOUSE_BUTTON_RIGHT
		InputMap.action_add_event("fish_action", rmb)


func _add_keys(action: String, keys: Array) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for k in keys:
		var ev := InputEventKey.new()
		ev.physical_keycode = k
		InputMap.action_add_event(action, ev)


func _setup_buses() -> void:
	for bus in ["Music", "SFX", "Ambience"]:
		if AudioServer.get_bus_index(bus) != -1:
			continue
		AudioServer.add_bus()
		var idx := AudioServer.bus_count - 1
		AudioServer.set_bus_name(idx, bus)
		AudioServer.set_bus_send(idx, "Master")
	# A touch of room on effects, and a limiter so stacked cues never clip.
	var sfx_idx := AudioServer.get_bus_index("SFX")
	var reverb := AudioEffectReverb.new()
	reverb.room_size = 0.45
	reverb.damping = 0.6
	reverb.wet = 0.12
	reverb.dry = 1.0
	AudioServer.add_bus_effect(sfx_idx, reverb)
	AudioServer.add_bus_effect(0, AudioEffectHardLimiter.new())
