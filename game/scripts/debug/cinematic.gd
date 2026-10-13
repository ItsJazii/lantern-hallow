extends Node
## Trailer (`-- --cinematic`), meant for Godot's Movie Maker so every frame
## renders at a fixed rate with the game's music, ambience and sound effects:
##   godot --path game --write-movie out.avi --fixed-fps 60 --resolution 1920x1080 -- --cinematic
## Part 1 (~22 s): camera glides around the garden, no HUD.
## Part 2 (~26 s): the four quests played in first person with the real HUD,
## dialogue and toasts, ending on the lantern release and the title.

const DIP := 0.3

## eye path, look path, seconds, fov
const SHOTS := [
	# Down over the treetops toward the pond.
	{"eye": [Vector3(30, 27, 40), Vector3(23, 20, 30), Vector3(16, 12, 20)],
	 "look": [Vector3(-6, 0, -3), Vector3(-5, 0, -1), Vector3(-4, 0.5, 0)], "time": 5.5, "fov": 55.0},
	# Behind the bench, high, drifting across the view over the pond.
	{"eye": [Vector3(3.2, 2.4, 23.0), Vector3(0.8, 2.3, 23.4), Vector3(-1.8, 2.2, 23.0)],
	 "look": [Vector3(0.5, 0.2, 4.0), Vector3(-0.5, 0.2, 3.5)], "time": 3.5, "fov": 55.0},
	# The tea stall, drifting across its front (well clear of the counter).
	{"eye": [Vector3(-16.8, 1.7, 5.2), Vector3(-16.4, 1.6, 2.2), Vector3(-16.8, 1.55, -0.8)],
	 "look": [Vector3(-22.8, 1.4, 0.8), Vector3(-23.0, 1.4, 0.2)], "time": 3.5, "fov": 52.0},
	# The giant tree: roots up to the owl.
	{"eye": [Vector3(-20.5, 0.9, -9.5), Vector3(-21.3, 1.3, -10.2), Vector3(-22.0, 1.6, -10.6)],
	 "look": [Vector3(-29.5, 1.2, -6.5), Vector3(-28.5, 3.5, -6.0), Vector3(-27.5, 5.3, -5.4)], "time": 3.5, "fov": 50.0},
	# Gliding over the pond toward the dock.
	{"eye": [Vector3(-9.5, 0.0, -1.5), Vector3(-6.0, -0.02, 0.2), Vector3(-3.0, 0.0, 1.4)],
	 "look": [Vector3(8.2, 0.6, 5.7)], "time": 3.5, "fov": 62.0},
]
## Pull back and up from the pond as the wish lanterns rise.
const FINALE := {"eye": [Vector3(3.0, 1.2, 12.5), Vector3(4.0, 4.0, 18.0), Vector3(5.0, 8.5, 25.0)],
	"look": [Vector3(0, 1.0, 0), Vector3(-0.5, 4.0, -1.0), Vector3(-1.0, 8.0, -2.0)], "time": 9.0, "fov": 58.0}

var _cam: Camera3D
var _black: ColorRect
var _title: Control
var _caption: PanelContainer
var _caption_num: Label
var _caption_title: Label
var _player: Player
var _scene: Node


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_scene = get_tree().current_scene
	_player = get_tree().get_first_node_in_group("player") as Player
	_cam = Camera3D.new()
	_cam.far = 500.0
	_scene.add_child.call_deferred(_cam)
	_build_overlay()
	_run.call_deferred()


func _run() -> void:
	_fresh_state()
	_player.frozen = true
	_player.set_process_unhandled_input(false)
	_player.global_position = Vector3(0, 0, 40)
	Sfx.play_music("music_main", 0.1)
	await _frames(2)

	# --- Part 1: cinematic ---------------------------------------------------------------
	UI.set_hud_visible(false)
	_cam.make_current()
	for i in SHOTS.size():
		await _shot(SHOTS[i], i == 0, true)

	# --- Part 2: the quests, in first person ---------------------------------------------
	UI.set_hud_visible(true)
	_player.camera.make_current()

	# Quest 1, A Little Help: gather moonleaves in the grove.
	var leaf_a := _node("MoonleafA") as Node3D
	_place(Vector3(14.6, 0, -11.6), leaf_a.global_position + Vector3(0, 0.3, 0))
	UI.refresh_objective()
	await _fade_in()
	_show_caption(1, "A Little Help")
	await _walk(Vector3(14.6, 0, -11.6), Vector3(14.0, 0, -13.2), leaf_a.global_position + Vector3(0, 0.3, 0), 1.3)
	leaf_a.interact(_player)
	await _wait(1.1)
	await _fade_out()

	# Quest 3, A Moonfin Wish: cast, a bite, reel in, the catch.
	var gs := GameState
	for k in ["leaves_returned", "tea_brewed", "tea_served", "blue_met", "has_rod"]:
		gs.data[k] = true
	gs.data["collected_leaf_ids"] = GameState.LEAF_IDS.duplicate()
	gs.data["bait"] = 2
	gs.changed.emit()
	var west := _node("DockLanternWest") as Node3D
	var east := _node("DockLanternEast") as Node3D
	var blue := _node("BlueSpirit") as Node3D
	var fishing := get_tree().get_first_node_in_group("fishing") as FishingController
	fishing.autoplay = true
	_place(Vector3(6.4, 0.2, 4.45), Vector3(0, -0.3, 1.5))
	_player.frozen = false
	UI.refresh_objective()
	await _fade_in()
	_show_caption(3, "A Moonfin Wish")
	fishing.try_start(_player)
	await _until(func() -> bool: return fishing.state == FishingController.State.WAITING, 5.0)
	await _wait(0.4)
	fishing._timer.start(0.05)
	await _wait(0.7)
	# Strike and reel it in on camera, hold on the catch, then cut.
	fishing.handle_action()
	await _until(func() -> bool: return fishing.state == FishingController.State.CATCH_REVEAL, 6.0)
	await _wait(1.3)
	await _fade_out()
	fishing.cancel_for_capture()
	(fishing.get("_rod") as Node3D).hide()
	UI.skip_conversation()
	_player.frozen = true
	# On the dock between the two lanterns, a step back toward the shore.
	var mid := (west.global_position + east.global_position) * 0.5
	var back := Vector3(8.21, 0, 5.69) - mid
	back.y = 0.0
	var stand := Vector3(mid.x, 0.15, mid.z) + back.normalized() * 1.6

	# Quest 4, Light the Evening: light the lantern, then the wish with the blue spirit.
	gs.data["first_moonfin_released"] = true
	gs.data["wish_lantern_owned"] = true
	gs.changed.emit()
	GameState.light_lantern(east.get("target_id"))
	east.call("_set_lit", true, false)
	_place(stand, west.global_position + Vector3(0, 1.7, 0))
	UI.refresh_objective()
	await _fade_in()
	_show_caption(4, "Light the Evening")
	await _wait(0.4)
	west.interact(_player)
	await _wait(0.8)
	await _turn_to(blue.global_position + Vector3(0, 0.2, 0), 0.7)
	blue.interact(_player)
	await _wait(1.1)
	UI.advance()
	await _wait(0.2)
	UI.advance()
	await _wait(0.6)

	# Finale: hand over to the crane camera, lanterns rising, then the title.
	_hide_caption()
	UI.set_hud_visible(false)
	_cam.make_current()
	await _shot(FINALE, false, false, true)
	print("CINEMATIC_DONE")
	get_tree().quit()


# --- State ------------------------------------------------------------------------------------

## A fresh garden (ignoring any save), keeper and moss spirit already met.
func _fresh_state() -> void:
	GameState.autosave = false
	GameState.data = GameState.defaults()
	GameState.data["keeper_met"] = true
	GameState.data["moss_met"] = true
	GameState.changed.emit()
	var cel := get_tree().get_first_node_in_group("celebration")
	if cel:
		for f in cel.get("_floaters"):
			(f as Node).queue_free()
		(cel.get("_floaters") as Array).clear()


func _node(n: String) -> Node:
	return _scene.find_child(n, true, false)


# --- Camera -----------------------------------------------------------------------------------

func _shot(s: Dictionary, fade_from_black: bool, dip_out: bool, finale := false) -> void:
	_cam.fov = float(s["fov"])
	var dur: float = s["time"]
	var t := 0.0
	while t <= dur:
		var u := clampf(t / dur, 0.0, 1.0)
		var e := lerpf(u, u * u * (3.0 - 2.0 * u), 0.45)
		var eye := _spline(s["eye"], e)
		var look := _spline(s["look"], e)
		_cam.global_position = eye
		_cam.look_at(look)
		var a := 0.0
		if fade_from_black:
			a = 1.0 - smoothstep(0.0, 1.6, t)
		elif t < DIP:
			a = 1.0 - t / DIP
		if dip_out and t > dur - DIP:
			a = maxf(a, (t - (dur - DIP)) / DIP)
		if finale:
			_title.modulate.a = smoothstep(3.0, 4.8, t)
			a = maxf(a, smoothstep(dur - 1.6, dur, t))
		_black.color.a = a
		await get_tree().process_frame
		t += get_process_delta_time()


## Catmull-Rom through the points (one point = fixed).
func _spline(pts: Array, u: float) -> Vector3:
	if pts.size() == 1:
		return pts[0]
	var n := pts.size() - 1
	var f := u * n
	var i := mini(int(f), n - 1)
	var t := f - i
	var p0: Vector3 = pts[maxi(i - 1, 0)]
	var p1: Vector3 = pts[i]
	var p2: Vector3 = pts[i + 1]
	var p3: Vector3 = pts[mini(i + 2, n)]
	var t2 := t * t
	return 0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t2 * t)


# --- First-person moves ---------------------------------------------------------------------

func _place(at: Vector3, look: Vector3) -> void:
	var p := Vector2(at.x, at.z)
	_player.global_position = Vector3(at.x, maxf(at.y, Layout.mesh_height(p)), at.z)
	var ang := _player.look_angles_to(look)
	_player.set_view(ang.x, ang.y)


func _walk(from: Vector3, to: Vector3, look: Vector3, dur: float) -> void:
	var t := 0.0
	while t < dur:
		var u := smoothstep(0.0, 1.0, t / dur)
		_place(from.lerp(to, u), look)
		await get_tree().process_frame
		t += get_process_delta_time()
	_place(to, look)


func _turn_to(look: Vector3, dur: float) -> void:
	var start := Vector2(_player.rotation.y, _player.camera.rotation.x)
	var end := _player.look_angles_to(look)
	var t := 0.0
	while t < dur:
		var u := smoothstep(0.0, 1.0, t / dur)
		_player.set_view(lerp_angle(start.x, end.x, u), lerpf(start.y, end.y, u))
		await get_tree().process_frame
		t += get_process_delta_time()
	_player.set_view(end.x, end.y)


# --- Overlay: fades, quest captions, title ---------------------------------------------------

func _build_overlay() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 120
	add_child(layer)
	_caption = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.03, 0.05, 0.1, 0.62)
	sb.set_corner_radius_all(14)
	sb.content_margin_left = 34
	sb.content_margin_right = 34
	sb.content_margin_top = 10
	sb.content_margin_bottom = 14
	_caption.add_theme_stylebox_override("panel", sb)
	_caption.anchor_left = 0.5
	_caption.anchor_right = 0.5
	_caption.anchor_top = 0.0
	_caption.offset_top = 150
	_caption.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_caption.modulate.a = 0.0
	layer.add_child(_caption)
	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	_caption.add_child(v)
	_caption_num = _label("", 24, false)
	_caption_num.add_theme_color_override("font_color", Color("f2c46d"))
	v.add_child(_caption_num)
	_caption_title = _label("", 50, true)
	v.add_child(_caption_title)

	_title = VBoxContainer.new()
	_title.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	(_title as VBoxContainer).alignment = BoxContainer.ALIGNMENT_CENTER
	_title.modulate.a = 0.0
	layer.add_child(_title)
	_title.add_child(_label("Lantern Hollow", 112, true))
	var sub := _label("a cozy night garden", 36, false)
	sub.modulate = Color(1, 1, 1, 0.85)
	_title.add_child(sub)
	_black = ColorRect.new()
	_black.color = Color.BLACK
	_black.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_black)


func _label(text: String, size: int, bold: bool) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_override("font", UI.get("_serif_bold") if bold else UI.get("_serif"))
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", Color("fff1d6"))
	l.add_theme_color_override("font_shadow_color", Color(0.0, 0.02, 0.06, 0.75))
	l.add_theme_constant_override("shadow_offset_y", 3)
	l.add_theme_constant_override("shadow_outline_size", 14)
	return l


func _show_caption(n: int, title: String) -> void:
	_caption_num.text = "QUEST %d" % n
	_caption_title.text = title
	_caption.reset_size()
	_caption.offset_left = -_caption.size.x * 0.5
	_caption.offset_right = _caption.size.x * 0.5
	var t := create_tween()
	t.tween_property(_caption, "modulate:a", 1.0, 0.35)
	t.tween_interval(2.0)
	t.tween_property(_caption, "modulate:a", 0.0, 0.5)


func _hide_caption() -> void:
	_caption.modulate.a = 0.0


func _fade_in() -> void:
	var t := create_tween()
	t.tween_property(_black, "color:a", 0.0, DIP)
	await t.finished


func _fade_out() -> void:
	var t := create_tween()
	t.tween_property(_black, "color:a", 1.0, DIP)
	await t.finished


func _wait(s: float) -> void:
	await get_tree().create_timer(s).timeout


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _until(cond: Callable, timeout: float) -> void:
	var t := 0.0
	while not cond.call() and t < timeout:
		await _wait(0.05)
		t += 0.05
