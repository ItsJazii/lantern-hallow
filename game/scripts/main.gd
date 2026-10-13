extends Node3D
## Scene entry: places the player at the arrival lane, starts music and
## ambience, and opens the title menu over the live garden (a slow drifting
## camera across the pond). Entering glides that camera down into the
## player's eyes. Command-line tools (after `--`) skip the title:
## --capture=<dir>, --autotest, --groundcheck.

## Title view: across the pond toward the bridge, the stall and the giant tree.
const TITLE_EYE := Vector3(10.5, 3.0, 15.5)
const TITLE_TARGET := Vector3(-21.0, 2.4, -2.0)

@onready var player: Player = $Player

static var _profiled_reload := false
var _title_cam: Camera3D
var _t := 0.0


func _ready() -> void:
	player.global_position = Layout.SPAWN
	var a := player.look_angles_to(Vector3(-17.0, 2.2, 2.0))
	player.set_view(a.x, a.y)
	Sfx.play_music("music_main", 3.0)
	UI.refresh_objective()
	UI.fade_in(1.6)
	if _start_tools():
		UI.set_hud_visible(true)
	else:
		_open_title()
	UI.update_mouse.call_deferred()
	if "--profile" in OS.get_cmdline_user_args() and not _profiled_reload:
		_profiled_reload = true
		get_tree().create_timer(1.0).timeout.connect(get_tree().reload_current_scene)


func _open_title() -> void:
	player.lock("title")
	_title_cam = Camera3D.new()
	_title_cam.fov = 62.0
	_title_cam.far = 500.0
	add_child(_title_cam)
	_place_title_cam()
	_title_cam.make_current()
	UI.enter_garden.connect(_on_enter_garden, CONNECT_ONE_SHOT)
	UI.open_title()


func _process(delta: float) -> void:
	if _title_cam and _title_cam.is_current() and not _title_cam.has_meta("gliding"):
		_t += delta
		_place_title_cam()


## A slow, breathing drift so the menu background is clearly alive.
func _place_title_cam() -> void:
	var eye := TITLE_EYE + Vector3(sin(_t * 0.05) * 1.6, sin(_t * 0.09) * 0.15, cos(_t * 0.05) * 0.8 - 0.8)
	var target := TITLE_TARGET + Vector3(sin(_t * 0.04) * 1.2, 0, 0)
	_title_cam.look_at_from_position(eye, target)


func _on_enter_garden() -> void:
	_title_cam.set_meta("gliding", true)
	var to := player.camera.global_transform
	var t := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(_title_cam, "global_transform", to, 2.4)
	t.parallel().tween_property(_title_cam, "fov", player.camera.fov, 2.4)
	t.tween_callback(_finish_enter)


func _finish_enter() -> void:
	player.camera.make_current()
	_title_cam.queue_free()
	_title_cam = null
	player.unlock("title")
	UI.set_hud_visible(true)
	UI.update_mouse()
	if not GameState.has("keeper_met"):
		UI.toast("Follow the path to the tea stall under the giant tree.")


## Returns true when a command-line tool is running (no title menu).
func _start_tools() -> bool:
	var tool_mode := false
	# `?fps` in a browser build's URL shows a frame-rate counter.
	if OS.has_feature("web") and str(JavaScriptBridge.eval("location.search", true)).contains("fps"):
		var layer := CanvasLayer.new()
		layer.layer = 128
		var label := Label.new()
		label.position = Vector2(14, 10)
		label.add_theme_font_size_override("font_size", 22)
		label.add_theme_color_override("font_outline_color", Color.BLACK)
		label.add_theme_constant_override("outline_size", 6)
		layer.add_child(label)
		add_child(layer)
		var t := Timer.new()
		t.wait_time = 0.5
		t.autostart = true
		t.timeout.connect(func() -> void: label.text = "%d fps  ·  %dx%d" % [Engine.get_frames_per_second(), get_viewport().get_visible_rect().size.x, get_viewport().get_visible_rect().size.y])
		layer.add_child(t)
	# Browser builds take no command line: `?perf` in the page URL runs the
	# performance probe instead.
	if OS.has_feature("web") and str(JavaScriptBridge.eval("location.search", true)).contains("perf"):
		UI.pause_on_focus_loss = false
		add_child(preload("res://scripts/debug/perf.gd").new())
		return true
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture") or arg == "--autotest" or arg == "--groundcheck" or arg == "--cinematic" or arg == "--perf":
			UI.pause_on_focus_loss = false
			tool_mode = true
		if arg.begins_with("--capture"):
			var tool := preload("res://scripts/debug/capture.gd").new()
			tool.out_dir = arg.get_slice("=", 1) if "=" in arg else "user://captures"
			add_child(tool)
		elif arg == "--autotest":
			add_child(preload("res://scripts/debug/autotest.gd").new())
		elif arg == "--perf":
			add_child(preload("res://scripts/debug/perf.gd").new())
		elif arg == "--cinematic":
			add_child(preload("res://scripts/debug/cinematic.gd").new())
		elif arg == "--groundcheck":
			add_child(preload("res://scripts/debug/ground_check.gd").new())
	return tool_mode
