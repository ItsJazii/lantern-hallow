extends Node
## Debug tool: renders fixed viewpoints to PNG and quits.
##   godot --path game -- --capture=C:/out [--state=ending] [--hud] [--only=dock]
## Uses a throwaway save path so the player's real progress is untouched.

var out_dir := "user://captures"

const VIEWS := {
	"01_arrival_bridge": [Vector3(-12.2, 0.0, 13.0), Vector3(-25.0, 2.6, -2.5)],
	"02_dock": [Vector3(6.4, 0.15, 4.45), Vector3(-22.0, 1.6, -3.0)],
	"03_counter": [Vector3(-21.1, 0.0, 0.25), Vector3(-23.4, 1.25, -0.1)],
	"04_spawn": [Vector3(-10.0, 0.0, 33.0), Vector3(-17.0, 2.2, 2.0)],
	"05_grove": [Vector3(14.2, 0.0, -10.4), Vector3(17.0, 0.4, -14.6)],
	"06_bench": [Vector3(0.0, 0.0, 17.75), Vector3(0.0, 0.9, 0.0)],
	"12_owl": [Vector3(-23.0, 0.0, -9.5), Vector3(-27.5, 5.3, -5.4)],
	"13_frogs": [Vector3(-11.6, 0.0, -10.4), Vector3(-6.9, -0.2, -6.1)],
	"15_post": [Vector3(-9.2, 0.0, 27.2), Vector3(-7.0, 0.5, 24.0)],
	"14_rabbit": [Vector3(2.0, 0.0, 17.0), Vector3(7.0, 0.2, 21.5)],
	"16_stall_side": [Vector3(-19.2, 0.0, 5.0), Vector3(-23.5, 1.5, 0.6)],
	"17_stone_lantern": [Vector3(-8.3, 0.0, -9.4), Vector3(-11.7, 0.5, -6.2)],
	"18_tree_roots": [Vector3(-24.5, 0.0, -10.5), Vector3(-29.0, 0.4, -7.5)],
	"19_spawn_back": [Vector3(-10.0, 0.0, 31.0), Vector3(-10.6, 1.0, 46.0)],
	"20_shore": [Vector3(-7.5, 0.0, -10.2), Vector3(-1.0, -0.3, -4.0)],
	"21_stream": [Vector3(-14.9, 0.7, 10.5), Vector3(-25.0, -0.3, 20.0)],
	"22_counter": [Vector3(-21.4, 0.0, 0.3), Vector3(-23.0, 1.1, 0.0)],
	"23_forest_edge": [Vector3(-24.0, 0.0, 15.5), Vector3(-31.0, 1.5, 21.0)],
	"24_dock_walk": [Vector3(12.2, 0.0, 9.6), Vector3(7.0, 0.3, 3.4)],
	"31_tree_ring_0": [Vector3(-25.00, 0.0, -6.00), Vector3(-21.00, 7.0, -6.00)],
	"31_tree_ring_1": [Vector3(-26.76, 0.0, -1.76), Vector3(-23.93, 7.0, 1.07)],
	"31_tree_ring_2": [Vector3(-31.00, 0.0, 0.00), Vector3(-31.00, 7.0, 4.00)],
	"31_tree_ring_3": [Vector3(-35.24, 0.0, -1.76), Vector3(-38.07, 7.0, 1.07)],
	"31_tree_ring_4": [Vector3(-37.00, 0.0, -6.00), Vector3(-41.00, 7.0, -6.00)],
	"31_tree_ring_5": [Vector3(-35.24, 0.0, -10.24), Vector3(-38.07, 7.0, -13.07)],
	"31_tree_ring_6": [Vector3(-31.00, 0.0, -12.00), Vector3(-31.00, 7.0, -16.00)],
	"31_tree_ring_7": [Vector3(-26.76, 0.0, -10.24), Vector3(-23.93, 7.0, -13.07)],
	"32_post_200": [Vector3(-17.31, 0.0, -7.22), Vector3(-20.20, 0.25, -5.34)],
	"32_post_245": [Vector3(-5.85, 0.0, -14.60), Vector3(-9.23, 0.25, -15.23)],
	"32_post_290": [Vector3(8.91, 0.0, -12.71), Vector3(7.48, 0.25, -15.84)],
	"32_post_330": [Vector3(17.70, 0.0, -4.76), Vector3(18.66, 0.25, -8.06)],
	"32_post_15": [Vector3(18.00, 0.0, 6.99), Vector3(20.74, 0.25, 4.92)],
	"32_post_60": [Vector3(7.47, 0.0, 15.21), Vector3(10.90, 0.25, 15.50)],
	"32_post_100": [Vector3(-5.86, 0.0, 14.91), Vector3(-3.81, 0.25, 17.67)],
	"32_post_160": [Vector3(-18.76, 0.0, 3.22), Vector3(-20.20, 0.25, 6.34)],
	"33_spawn_post": [Vector3(-10.0, 0.0, 33.0), Vector3(-11.6, 0.3, 30.0)],
	"34_lawn_top": [Vector3(7.0, 22.0, 17.0), Vector3(7.01, 0.0, 16.99)],
	"28_bridge_side": [Vector3(-19.5, -0.5, 15.0), Vector3(-14.9, 0.3, 10.5)],
	"29_bridge_side2": [Vector3(-11.0, -0.5, 6.0), Vector3(-14.9, 0.3, 10.5)],
	"25_bridge_end": [Vector3(-10.9, 0.0, 14.3), Vector3(-13.4, 0.2, 11.9)],
	"26_bridge_far_end": [Vector3(-18.9, 0.0, 6.7), Vector3(-16.4, 0.2, 9.0)],
	"27_lawn": [Vector3(4.0, 0.0, 19.0), Vector3(12.0, 0.5, 15.0)],
}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_run()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var keep_hud := "--hud" in args
	var only := ""
	for a in args:
		if a.begins_with("--state="):
			_apply_state(a.get_slice("=", 1))
		elif a.begins_with("--only="):
			only = a.get_slice("=", 1)
	var dir := ProjectSettings.globalize_path(out_dir)
	DirAccess.make_dir_recursive_absolute(dir)
	if "--ui" in args:
		await _capture_ui(dir)
		print("CAPTURE_DONE ", dir)
		get_tree().quit()
		return
	await get_tree().create_timer(3.5).timeout
	UI.set_hud_visible(keep_hud)
	UI.hide_title()
	var player := get_tree().get_first_node_in_group("player") as Player
	player.frozen = true
	# Real mouse movement over the window must not steer scripted cameras.
	player.set_process_unhandled_input(false)
	for view_name in VIEWS:
		if only != "" and not view_name.contains(only):
			continue
		var v: Array = VIEWS[view_name]
		var pos: Vector3 = v[0]
		player.global_position = pos
		var ang := player.look_angles_to(v[1])
		player.set_view(ang.x, ang.y)
		await get_tree().create_timer(2.5).timeout
		print("fps %s: %d" % [view_name, Engine.get_frames_per_second()])
		await _shot(dir.path_join(view_name + ".png"))
	if "--fish" in args:
		await _capture_fishing(player, dir)
	if "--creatures" in args:
		await _capture_creatures(player, dir)
	if only == "" or only == "aerial":
		var cam := Camera3D.new()
		get_tree().current_scene.add_child(cam)
		cam.fov = 50.0
		cam.global_position = Vector3(0, 62, 52)
		cam.look_at(Vector3(-2, 0, 2))
		cam.make_current()
		await get_tree().create_timer(1.0).timeout
		await _shot(dir.path_join("07_aerial.png"))
	print("CAPTURE_DONE ", dir)
	get_tree().quit()


## Walks through a cast with the HUD on, plus one dialogue frame.
func _capture_fishing(player: Player, dir: String) -> void:
	_apply_state("fishing")
	UI.set_hud_visible(true)
	player.frozen = false
	player.global_position = Vector3(6.4, 0.2, 4.45)
	var fishing := get_tree().get_first_node_in_group("fishing") as FishingController
	fishing.autoplay = true
	fishing.try_start(player)
	while fishing.state != FishingController.State.WAITING:
		await get_tree().process_frame
	await get_tree().create_timer(0.8).timeout
	await _shot(dir.path_join("08_fishing_wait.png"))
	fishing._timer.start(0.05)
	await get_tree().create_timer(0.6).timeout
	await _shot(dir.path_join("09_fishing_bite.png"))
	fishing.handle_action()
	await get_tree().create_timer(0.55).timeout
	await _shot(dir.path_join("09b_fishing_reel.png"))
	while fishing.state != FishingController.State.CATCH_REVEAL:
		await get_tree().process_frame
	await get_tree().create_timer(0.9).timeout
	await _shot(dir.path_join("10_fishing_reveal.png"))
	fishing.handle_action()
	await get_tree().create_timer(1.6).timeout
	var cam_a := player.look_angles_to(fishing.get("_basket").global_position)
	player.set_view(cam_a.x, cam_a.y)
	await get_tree().create_timer(0.4).timeout
	await _shot(dir.path_join("10b_fish_basket.png"))
	fishing.cancel_for_capture()
	player.frozen = true
	player.global_position = Vector3(-21.3, 0.0, 0.2)
	var a := player.look_angles_to(Vector3(-23.4, 1.3, 0.1))
	player.set_view(a.x, a.y - 0.1)
	var keeper := get_tree().current_scene.get_node("Props/TeaStall/Keeper")
	keeper.interact(player)
	await get_tree().create_timer(1.5).timeout
	UI.advance()
	await get_tree().create_timer(0.5).timeout
	await _shot(dir.path_join("11_dialogue_shop.png"))
	UI.skip_conversation()


## Every menu over the live garden: title, welcome cards, settings, HUD,
## pause, journal and the ending screen.
func _capture_ui(dir: String) -> void:
	_apply_state("fishing")
	await get_tree().process_frame
	var main := get_tree().current_scene
	main.call("_open_title")
	await get_tree().create_timer(4.0).timeout
	await _shot(dir.path_join("ui_01_title.png"), true)
	UI._show_title_page(UI._welcome_new)
	await get_tree().create_timer(0.6).timeout
	await _shot(dir.path_join("ui_02_welcome.png"), true)
	UI._show_title_page(UI._welcome_back)
	await get_tree().create_timer(0.6).timeout
	await _shot(dir.path_join("ui_03_welcome_back.png"), true)
	UI._show_title_page(UI._title_menu)
	UI._open_settings("title")
	await get_tree().create_timer(0.6).timeout
	await _shot(dir.path_join("ui_04_settings_sound.png"), true)
	UI._select_tab(2)
	await get_tree().create_timer(0.4).timeout
	await _shot(dir.path_join("ui_05_settings_controls.png"), true)
	UI._close_settings()
	UI._on_enter_garden()
	await get_tree().create_timer(3.6).timeout
	var player := get_tree().get_first_node_in_group("player") as Player
	player.set_process_unhandled_input(false)
	player.global_position = Vector3(6.4, 0.15, 4.45)
	var a := player.look_angles_to(Vector3(-22.0, 1.6, -3.0))
	player.set_view(a.x, a.y)
	await get_tree().create_timer(1.5).timeout
	await _shot(dir.path_join("ui_06_hud.png"), true)
	UI.toast("Moonfin released · +2 coins", UI.GOLD)
	await get_tree().create_timer(0.6).timeout
	await _shot(dir.path_join("ui_07_toast.png"), true)
	UI.open_pause()
	await get_tree().create_timer(0.5).timeout
	await _shot(dir.path_join("ui_08_pause.png"), true)
	UI.close_pause()
	UI.open_journal()
	await get_tree().create_timer(1.0).timeout
	await _shot(dir.path_join("ui_09_journal.png"), true)
	UI.close_journal()
	UI.open_map()
	await get_tree().create_timer(1.0).timeout
	await _shot(dir.path_join("ui_09b_map.png"), true)
	UI.close_map()
	UI.show_ending()
	await get_tree().create_timer(2.2).timeout
	await _shot(dir.path_join("ui_10_ending.png"), true)


## Close-ups of each kind of animal, from a separate camera so the player (kept
## far away) doesn't scare them off.
func _capture_creatures(player: Player, dir: String) -> void:
	player.global_position = Layout.SPAWN
	var wild: Node = null
	for n in get_tree().current_scene.find_children("*", "Node3D", true, false):
		if n is Wildlife:
			wild = n
			break
	if wild == null:
		return
	var cam := Camera3D.new()
	cam.fov = 40.0
	get_tree().current_scene.add_child(cam)
	cam.make_current()
	var seen := {}
	var targets: Array = []
	for c in wild.get_children():
		var kind := String(c.name).rstrip("0123456789")
		if c.name == "Ducks":
			targets.append(["duck", (c as Node3D).get_child(0), 1.2])
		elif not seen.has(kind) and c is Node3D:
			seen[kind] = true
			var dist: float = {"Rabbit": 1.2, "Frog": 0.7, "Owl": 1.6, "Moth": 0.5, "Bee": 0.3}.get(kind, 1.5)
			targets.append([kind.to_lower(), c, dist])
	for t in targets:
		var n: Node3D = t[1]
		if not n.is_visible_in_tree():
			continue
		for i in 2:
			var d: float = t[2]
			var at := n.global_position + Vector3(0, d * 0.2, 0)
			var fwd := n.global_basis.z.normalized()
			cam.look_at_from_position(at + fwd * d + n.global_basis.x * d * 0.4 + Vector3.UP * d * 0.35, at)
			await get_tree().create_timer(0.6).timeout
			await _shot(dir.path_join("c_%s_%d.png" % [t[0], i]))
	player.camera.make_current()
	cam.queue_free()


func _shot(path: String, keep_menus := false) -> void:
	if get_tree().paused and not keep_menus:
		UI.close_pause()
		await get_tree().create_timer(0.3).timeout
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(path)
	print("saved ", path)


func _apply_state(preset: String) -> void:
	GameState.autosave = false
	var d := GameState.data
	if preset in ["tea", "fishing", "ending"]:
		for k in ["keeper_met", "moss_met", "leaves_returned", "tea_brewed", "tea_served"]:
			d[k] = true
		d["collected_leaf_ids"] = GameState.LEAF_IDS.duplicate()
		d["coins"] = 3
	if preset in ["fishing", "ending"]:
		d["blue_met"] = true
		d["has_rod"] = true
		d["bait"] = 2
	if preset == "ending":
		d["first_moonfin_released"] = true
		d["wish_lantern_owned"] = true
		d["lit_lantern_ids"] = GameState.LANTERN_IDS.duplicate()
		d["ending_complete"] = true
	GameState.changed.emit()
