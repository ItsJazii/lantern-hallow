extends Node
## Performance probe (`-- --perf`): stands at a few busy spots and reports
## average FPS, draw calls and objects drawn. Env toggles for experiments:
##   LH_NOREFL=1   water reflection off      LH_NOLIGHTS=1  garden omni lights off
##   LH_NOGRASS=1  grass/foliage multimeshes hidden

const SPOTS := [
	["spawn", Vector3(-10.0, 0.0, 33.0), Vector3(-17.0, 2.2, 2.0)],
	["dock", Vector3(6.4, 0.15, 4.45), Vector3(-22.0, 1.6, -3.0)],
	["stall", Vector3(-19.2, 0.0, 5.0), Vector3(-23.5, 1.5, 0.6)],
	["lawn", Vector3(4.0, 0.0, 19.0), Vector3(12.0, 0.5, 15.0)],
]


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_run.call_deferred()


func _run() -> void:
	await get_tree().create_timer(3.0).timeout
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	UI.set_hud_visible(false)
	UI.hide_title()
	var scene := get_tree().current_scene
	if OS.get_environment("LH_NOREFL") == "1":
		for n in scene.find_children("*", "WaterReflection", true, false):
			n.set_process(false)
			(n.get("_viewport") as SubViewport).render_target_update_mode = SubViewport.UPDATE_DISABLED
	if OS.get_environment("LH_NOLIGHTS") == "1":
		for l in get_tree().get_nodes_in_group("garden_light"):
			(l as Light3D).visible = false
	if OS.get_environment("LH_NOGRASS") == "1":
		for m in scene.find_children("*", "MultiMeshInstance3D", true, false):
			(m as Node3D).visible = false
	var lights := 0
	for l in scene.find_children("*", "OmniLight3D", true, false):
		if (l as Light3D).is_visible_in_tree():
			lights += 1
	print("PERF omni lights visible: ", lights)
	var by := {}
	for m in scene.find_children("*", "MultiMeshInstance3D", true, false):
		var mmi := m as MultiMeshInstance3D
		if mmi.multimesh == null or mmi.multimesh.mesh == null or not mmi.is_visible_in_tree():
			continue
		var key := mmi.multimesh.mesh.resource_path.get_file().get_slice("::", 0)
		if key == "":
			key = "(generated)"
		var tris := mmi.multimesh.mesh.get_faces().size() / 3
		var cur: Array = by.get(key, [0, 0, tris, mmi.visibility_range_end])
		cur[0] += mmi.multimesh.instance_count
		cur[1] += mmi.multimesh.instance_count * tris
		by[key] = cur
	var keys := by.keys()
	keys.sort_custom(func(a, b): return by[a][1] > by[b][1])
	for k in keys:
		print("PERF mm %-28s inst %6d  tris/inst %5d  total %8d  range %4.0f" % [k, by[k][0], by[k][2], by[k][1], by[k][3]])
	# Ground tiles vs the browser renderer's per-object light limit.
	var omnis: Array[OmniLight3D] = []
	for l in scene.find_children("*", "OmniLight3D", true, false):
		if (l as Light3D).is_visible_in_tree():
			omnis.append(l)
	var limit: int = ProjectSettings.get_setting("rendering/limits/opengl/max_lights_per_object")
	for m in scene.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		if mi.mesh == null or mi.mesh.resource_path != "" or mi.get_aabb().size.x < 6.0 or mi.get_aabb().size.y > 15.0 or str(mi.get_parent().name) != "Terrain":
			continue
		var box := mi.global_transform * mi.get_aabb()
		var n := 0
		for l in omnis:
			var p := l.global_position
			var c := Vector3(clampf(p.x, box.position.x, box.end.x), clampf(p.y, box.position.y, box.end.y), clampf(p.z, box.position.z, box.end.z))
			if c.distance_to(p) < l.omni_range:
				n += 1
		if n >= 8:
			print("PERF tile %s..%s lights %d (limit %d)" % [Vector2(box.position.x, box.position.z).round(), Vector2(box.end.x, box.end.z).round(), n, limit])
	var singles := {}
	for m in scene.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		if mi.mesh == null or not mi.is_visible_in_tree():
			continue
		var key := mi.mesh.resource_path.get_file().get_slice("::", 0)
		if key == "":
			key = str(mi.get_parent().name) + "/" + str(mi.name)
		var cur: Array = singles.get(key, [0, 0])
		cur[0] += 1
		cur[1] += mi.mesh.get_faces().size() / 3
		singles[key] = cur
	var skeys := singles.keys()
	skeys.sort_custom(func(a, b): return singles[a][1] > singles[b][1])
	for k in skeys.slice(0, 15):
		print("PERF mesh %-34s count %4d  total tris %8d" % [k, singles[k][0], singles[k][1]])
	var player := get_tree().get_first_node_in_group("player") as Player
	player.frozen = true
	player.set_process_unhandled_input(false)
	var total := 0.0
	for s in SPOTS:
		player.global_position = s[1]
		var ang := player.look_angles_to(s[2])
		player.set_view(ang.x, ang.y)
		await get_tree().create_timer(1.5).timeout
		var frames := 0
		var t0 := Time.get_ticks_usec()
		while Time.get_ticks_usec() - t0 < 2000000:
			await get_tree().process_frame
			frames += 1
		var fps := frames / ((Time.get_ticks_usec() - t0) / 1e6)
		total += fps
		print("PERF %-6s fps %6.1f  draws %5d  objects %5d  prims %8d" % [s[0], fps,
			Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
			Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME),
			Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)])
	print("PERF average fps %.1f  (render size %s)" % [total / SPOTS.size(), get_viewport().get_visible_rect().size])
	if not OS.has_feature("web"):
		get_tree().quit()
