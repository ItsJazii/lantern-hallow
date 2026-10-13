extends Node
## Debug tool: verifies everything placed on the ground actually touches it.
##   godot --headless --path game -- --groundcheck
## Casts a ray at the terrain (only) under every instanced plant/rock/tree,
## every lantern post, prop, NPC and creature, and reports floaters (gap above
## ground) and anything buried too deep.

const FLOAT_TOLERANCE := 0.03

var _space: PhysicsDirectSpaceState3D
var _exclude: Array[RID] = []
var _problems := 0


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	await get_tree().create_timer(1.0).timeout
	_space = get_tree().current_scene.get_world_3d().direct_space_state
	var scene := get_tree().current_scene
	for n in _all(scene):
		if n is CollisionObject3D and n.name != "TerrainBody":
			_exclude.append((n as CollisionObject3D).get_rid())
	var report := {}
	for n in _all(scene):
		if n is MultiMeshInstance3D:
			var mmi := n as MultiMeshInstance3D
			if mmi.multimesh == null or mmi.multimesh.mesh == null:
				continue
			var label := "multimesh:%s" % mmi.multimesh.mesh.resource_name if mmi.multimesh.mesh.resource_name != "" else "multimesh:%d tris" % (mmi.multimesh.mesh.get_faces().size() / 3)
			for i in mmi.multimesh.instance_count:
				var o := mmi.global_transform * mmi.multimesh.get_instance_transform(i).origin
				_measure(report, label, o, true)
	for n in get_tree().get_nodes_in_group("grounded"):
		if "Dock" in str(n.get_path()):
			continue  # stands on the dock deck, not the ground
		_measure(report, "grounded:" + str(n.name).rstrip("0123456789"), (n as Node3D).global_position, false)
	for path in ["Props/TeaStall", "Props/GiantTree", "Props/TeaStall/Fox", "Grove/MossSpirit", "Grove/MoonleafA", "Grove/MoonleafB", "Grove/MoonleafC", "Bench"]:
		var node := scene.get_node_or_null(path) as Node3D
		if node:
			_measure(report, "node:" + path.get_file(), node.global_position, false)
	print("")
	for k in report:
		var r: Dictionary = report[k]
		var flag := ""
		if r["max_float"] > FLOAT_TOLERANCE:
			flag = "  <-- FLOATING"
			_problems += 1
		print("%-34s n=%-4d highest gap %+.3f m   deepest %+.3f m%s" % [k, r["n"], r["max_float"], r["min"], flag])
	print("GROUNDCHECK %s (%d floating groups)" % ["PASS" if _problems == 0 else "FAIL", _problems])
	get_tree().quit(0 if _problems == 0 else 1)


func _measure(report: Dictionary, label: String, o: Vector3, skip_water: bool) -> void:
	var p2 := Vector2(o.x, o.z)
	if skip_water and (Layout.pond_k(p2) < 1.0 or Layout.stream_distance(p2) < Layout.STREAM_HALF_WIDTH):
		return  # floating on water on purpose (lily pads)
	var q := PhysicsRayQueryParameters3D.create(o + Vector3.UP * 3.0, o + Vector3.DOWN * 6.0, 1, _exclude)
	var hit := _space.intersect_ray(q)
	if hit.is_empty():
		return
	var gap := o.y - (hit["position"] as Vector3).y
	if not report.has(label):
		report[label] = {"n": 0, "max_float": -INF, "min": INF}
	var r: Dictionary = report[label]
	r["n"] += 1
	r["max_float"] = maxf(r["max_float"], gap)
	r["min"] = minf(r["min"], gap)


func _all(root: Node) -> Array[Node]:
	var out: Array[Node] = [root]
	for c in root.get_children():
		out.append_array(_all(c))
	return out
