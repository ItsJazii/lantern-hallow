class_name Wildlife
extends Node3D
## Places the garden's animals: rabbits on the lawns, frogs on their own lily
## pads near the shore, an owl in the giant tree, a duck family on the pond.

const RabbitScript := preload("res://scripts/creatures/rabbit.gd")
const FrogScript := preload("res://scripts/creatures/frog.gd")
const OwlScript := preload("res://scripts/creatures/owl.gd")
const DuckScript := preload("res://scripts/creatures/duck_family.gd")
const MothScript := preload("res://scripts/creatures/moth.gd")
const BeeScript := preload("res://scripts/creatures/bee.gd")

## Flower patches bees work (near the warm light of the stall and the bench).
const BEE_PATCHES := [Vector2(-20.0, 4.5), Vector2(1.5, 15.5), Vector2(-12.0, 26.0)]

## Giant tree at (-31, 0, -6); branch-top perches measured on its model.
const OWL_PERCHES := [Vector3(-27.53, 5.14, -5.39), Vector3(-27.96, 8.26, -7.0)]
## Lawns where rabbits feel at home.
const RABBIT_AREAS := [Vector2(7.0, 21.5), Vector2(24.0, -3.0), Vector2(-14.0, -19.0)]

var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.seed = 404
	_spawn_rabbits()
	_spawn_frogs()
	_spawn_owl()
	var ducks := DuckScript.new() as Node3D
	ducks.name = "Ducks"
	add_child(ducks)
	_spawn_bees()
	# Lanterns on props are built after the world, so moths find them a frame later.
	_spawn_moths.call_deferred()


func _flowers() -> Array:
	var world := get_tree().get_first_node_in_group("world")
	return world.get("flower_points") if world else []


func _spawn_moths() -> void:
	var flowers := _flowers()
	var lights := get_tree().get_nodes_in_group("sway")
	lights.shuffle()
	for i in 10:
		var m := MothScript.new() as Node3D
		m.set("model_name", "butterfly")
		m.set("flowers", flowers)
		if i < 6 and i < lights.size():
			# Lantern pivots hang the lantern ~0.25 m below them.
			m.set("light", (lights[i] as Node3D).global_position + Vector3(0, -0.2, 0))
		m.name = "Moth"
		add_child(m)


func _spawn_bees() -> void:
	var all := _flowers()
	for patch in BEE_PATCHES:
		var near: Array = []
		for f in all:
			if (f as Vector2).distance_to(patch) < 7.0:
				near.append(f)
		if near.size() < 3:
			continue
		for i in 2:
			var b := BeeScript.new() as Node3D
			b.set("model_name", "bee")
			b.set("flowers", near)
			b.name = "Bee"
			b.position = Vector3(patch.x, 0, patch.y)
			add_child(b)


func _spawn_rabbits() -> void:
	for area in RABBIT_AREAS:
		var spot := _lawn_point(area, 5.0)
		var r := RabbitScript.new() as Node3D
		r.set("model_name", "rabbit")
		r.name = "Rabbit"
		r.position = Vector3(spot.x, Layout.mesh_height(spot), spot.y)
		r.rotation.y = _rng.randf() * TAU
		r.add_to_group("grounded")
		add_child(r)


func _lawn_point(around: Vector2, radius: float) -> Vector2:
	for i in 40:
		var p := around + Vector2(_rng.randf_range(-radius, radius), _rng.randf_range(-radius, radius))
		if Layout.outside_distance(p) <= 0.0 and Layout.distance_to_any_path(p) > 1.0 \
				and Layout.pond_k(p) > 1.2 and Layout.stream_distance(p) > 3.0:
			return p
	return around


func _spawn_frogs() -> void:
	# A crescent of pads along the north and west shore, away from the dock.
	var pads: Array[Vector3] = []
	var angles := [3.4, 3.7, 4.0, 4.35, 4.7, 5.0, 2.9]
	for a in angles:
		var k := _rng.randf_range(0.8, 0.9)
		var p := Vector2(cos(a) * Layout.POND_RADII.x, sin(a) * Layout.POND_RADII.y) * k
		var pos := Vector3(p.x, Layout.WATER_Y + 0.012, p.y)
		pads.append(pos + Vector3(0, 0.03, 0))
		var pad := ModelLib.place("lily_pad", self, Vector3(p.x, Layout.WATER_Y - 0.01, p.y), Vector3(0, _rng.randf() * 360.0, 0), 1.35)
		if pad == null:
			PH.cyl(self, 0.25, 0.25, 0.01, pos, PH.mat(Color("4f7a46"), 0.6), Vector3.ZERO, 14)
	for i in 4:
		var f := FrogScript.new() as Node3D
		f.set("model_name", "frog")
		f.set("pads", pads)
		f.set("_pad", i * 2 % pads.size())
		f.name = "Frog"
		f.position = pads[i * 2 % pads.size()]
		f.rotation.y = _rng.randf() * TAU
		add_child(f)


func _spawn_owl() -> void:
	var o := OwlScript.new() as Node3D
	o.set("model_name", "owl")
	var perches: Array[Vector3] = []
	for p in OWL_PERCHES:
		perches.append(p)
	o.set("perches", perches)
	o.name = "Owl"
	o.rotation.y = deg_to_rad(80.0)  # faces the stall and path
	add_child(o)
