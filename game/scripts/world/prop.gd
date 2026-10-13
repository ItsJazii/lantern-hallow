class_name Prop
extends Node3D
## Wrapper for a static set piece (tree, stall, bridge, dock). Collision always
## comes from here (simple proxies); the look comes from `model` when assigned,
## otherwise from a placeholder. Child nodes added in the scene (NPCs, kettle,
## lanterns) are left untouched, so swapping the mesh never breaks gameplay.

@export_enum("giant_tree", "tea_stall", "bridge", "dock") var kind := "giant_tree"
@export var model: PackedScene
@export var model_scale := 1.0
@export var model_yaw := 0.0
@export var model_offset := Vector3.ZERO

var visual: Node3D

## Deck height of the Tripo bridge (already sunk by its model_offset), sampled
## every 0.4 m along the span from x = -2.8 to 2.8.
const BRIDGE_MODEL_DECK := [0.03, 0.18, 0.32, 0.42, 0.53, 0.60, 0.63, 0.65, 0.65, 0.62, 0.56, 0.48, 0.35, 0.18, 0.02]
## Branch tips of the giant tree model at 11 m (from tools: Blender analysis).
const TREE_TIPS := [
	Vector3(-7.66, 6.86, 0.77), Vector3(-3.29, 10.13, 2.46), Vector3(-0.85, 10.76, 2.62), Vector3(0.81, 8.13, 2.07),
	Vector3(7.66, 6.63, 0.99), Vector3(6.82, 9.78, -2.62), Vector3(3.27, 8.15, -4.49), Vector3(1.28, 6.62, -4.07),
	Vector3(-4.93, 8.88, -3.6), Vector3(-6.12, 9.54, -3.83),
]

const BRIDGE_HALF := 2.8
const BRIDGE_ARCH := 0.42
const DOCK_HALF_LEN := 2.75
const DOCK_HALF_W := 1.5


func _ready() -> void:
	visual = Node3D.new()
	visual.name = "Visual"
	add_child(visual)
	if model:
		var inst := model.instantiate()
		if inst is Node3D:
			(inst as Node3D).scale = Vector3.ONE * model_scale
			(inst as Node3D).rotation_degrees.y = model_yaw
			(inst as Node3D).position = model_offset
		visual.add_child(inst)
	match kind:
		"giant_tree":
			_tree_collision()
			if model:
				_tree_canopy()
			else:
				_tree_visual(visual)
			_tree_lanterns()
		"tea_stall":
			_stall_collision()
			if model:
				var before := get_child_count()
				_stall_dressing()
				_settle_on_surfaces(before)
			else:
				_stall_visual(visual)
			_stall_lights()
		"bridge":
			_bridge_collision()
			if model:
				_bridge_lights()
				_bridge_piers()
			else:
				_bridge_visual(visual)
		"dock":
			_dock_collision()
			if not model:
				_dock_visual(visual)


func bridge_deck_y(x: float) -> float:
	if model:
		var f := clampf((x + 2.8) / 0.4, 0.0, BRIDGE_MODEL_DECK.size() - 1.001)
		var i := int(f)
		return lerpf(BRIDGE_MODEL_DECK[i], BRIDGE_MODEL_DECK[i + 1], f - i)
	var u := clampf(x / BRIDGE_HALF, -1.0, 1.0)
	return BRIDGE_ARCH * (1.0 - u * u) + 0.02


## A hanging paper lantern: the Tripo model when available, else the placeholder.
func lantern_at(pos: Vector3, energy := 2.4) -> Node3D:
	var root := Node3D.new()
	root.position = pos
	root.add_to_group("sway")
	add_child(root)
	var m := ModelLib.place("lantern", root, Vector3(0, -0.45, 0))
	if m:
		ModelLib.glow(m, energy)
	else:
		root.queue_free()
		return PH.hanging_lantern(self, pos, 0.25, energy)
	return root


static func dock_deck_y(z: float) -> float:
	return lerpf(0.16, 0.04, (z + DOCK_HALF_LEN) / (2.0 * DOCK_HALF_LEN))


# --- Giant tree --------------------------------------------------------------------------

func _tree_collision() -> void:
	var body := PH.static_body(self, "grass")
	PH.cylinder_shape(body, 2.2 if model else 1.45, 8.0, Vector3(0, 4, 0))
	GroundDetail.contact_shadow(self, Vector2(11, 11), 0.5)


## Leafy crowns (cut from the forest tree model) at the giant tree's branch tips.
func _tree_canopy() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 21
	for i in TREE_TIPS.size():
		var tip: Vector3 = TREE_TIPS[i]
		# Big enough, and low enough, that each cut branch end sits inside foliage.
		var s := rng.randf_range(0.58, 0.72)
		var out := Vector3(tip.x, 0, tip.z).normalized() * 0.4
		var crown := ModelLib.place("canopy", self, tip + out + Vector3(0, -1.9, 0), Vector3(0, rng.randf() * 360.0, 0), s)
		ModelLib.make_windy(crown, 7.0, 0.012, 0.005)
	# Fill between the branches so it reads as one big, lush crown.
	for c in [Vector3(0.2, 9.6, 0.0), Vector3(-2.5, 8.6, -1.0), Vector3(2.8, 8.4, -0.5),
			Vector3(-4.6, 7.4, 1.6), Vector3(4.4, 7.2, 1.8), Vector3(5.0, 8.0, -3.4),
			Vector3(-1.4, 9.0, 3.0), Vector3(-5.5, 8.2, -1.8), Vector3(1.6, 7.6, -3.6)]:
		ModelLib.make_windy(ModelLib.place("canopy", self, c, Vector3(0, rng.randf() * 360.0, 0), rng.randf_range(0.6, 0.7)), 7.0, 0.01, 0.005)


func _tree_visual(v: Node3D) -> void:
	var bark := PH.mat(Color("7a5034"), 0.95)
	var bark_dark := PH.mat(Color("5a3a28"), 0.95)
	var mossm := PH.mat(Color("5f7a3a"), 1.0)
	PH.limb(v, Vector3(0, -0.3, 0), Vector3(0.2, 3.5, 0.1), 1.55, 1.15, bark, 18)
	PH.limb(v, Vector3(0.2, 3.4, 0.1), Vector3(-0.2, 6.6, 0.3), 1.15, 0.8, bark, 18)
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	for i in 7:
		var a := TAU * i / 7.0 + rng.randf_range(-0.2, 0.2)
		var out := Vector3(cos(a), 0, sin(a))
		PH.limb(v, out * 0.6 + Vector3.UP * 1.2, out * rng.randf_range(2.6, 3.4) + Vector3.DOWN * 0.15, 0.75, 0.18, bark_dark, 10)
		PH.sphere(v, 0.5, out * 1.6 + Vector3.UP * 0.5, mossm, Vector3(1.4, 0.45, 1.0), 10)
	var tips: Array[Vector3] = []
	for i in 6:
		var a := TAU * i / 6.0 + 0.4
		var out := Vector3(cos(a), 0, sin(a))
		var start := Vector3(0, rng.randf_range(4.6, 6.2), 0) + out * 0.4
		var mid := start + out * rng.randf_range(2.0, 2.8) + Vector3.UP * rng.randf_range(1.0, 1.8)
		var tip := mid + out * rng.randf_range(1.6, 2.6) + Vector3.UP * rng.randf_range(0.4, 1.2)
		PH.limb(v, start, mid, 0.62, 0.38, bark, 10)
		PH.limb(v, mid, tip, 0.38, 0.16, bark, 8)
		tips.append(tip)
	var greens := [Color("7f9c45"), Color("94a74e"), Color("6b8a3d"), Color("a5b257")]
	for tip in tips:
		for j in 3:
			var c: Color = greens[rng.randi() % greens.size()]
			var off := Vector3(rng.randf_range(-1.2, 1.2), rng.randf_range(-0.3, 1.0), rng.randf_range(-1.2, 1.2))
			PH.sphere(v, rng.randf_range(1.7, 2.5), tip + off, PH.mat(c, 0.9), Vector3(1.0, 0.72, 1.0), 18)
	for j in 4:
		var c2: Color = greens[j % greens.size()]
		PH.sphere(v, rng.randf_range(2.6, 3.2), Vector3(rng.randf_range(-1.5, 1.5), rng.randf_range(9.0, 10.5), rng.randf_range(-1.5, 1.5)), PH.mat(c2, 0.9), Vector3(1.0, 0.7, 1.0), 20)


func _tree_lanterns() -> void:
	# Lanterns hang from the lower canopy toward the stall side (+X / +Z).
	var spots := [Vector3(3.2, 6.2, 1.5), Vector3(2.2, 5.6, 3.6), Vector3(4.2, 6.5, -1.4), Vector3(-1.0, 5.8, 3.4), Vector3(0.8, 6.9, -3.6), Vector3(-3.4, 6.4, 1.0)]
	if model:
		# Lanterns hang under the canopy on the stall side (+X), like the concept.
		spots = [Vector3(5.2, 4.6, 1.2), Vector3(3.6, 4.2, 3.4), Vector3(6.0, 4.9, -1.8), Vector3(2.0, 5.0, -3.2), Vector3(-1.8, 4.8, 2.6), Vector3(4.4, 5.6, 0.0)]
	for i in spots.size():
		if model:
			lantern_at(spots[i], 2.6)
		else:
			PH.hanging_lantern(self, spots[i], 0.5 + 0.25 * (i % 3), 2.4)
		if i < 3:
			PH.omni(self, spots[i] + Vector3(0, -0.9, 0), Color("ffb25e"), 1.6, 7.5)


# --- Tea stall (front faces +X, toward the pond) -----------------------------------------

func _stall_collision() -> void:
	var body := PH.static_body(self, "wood")
	PH.box_shape(body, Vector3(1.1 if model else 0.7, 1.15, 3.9), Vector3(1.0, 0.575, 0))
	GroundDetail.contact_shadow(self, Vector2(5.4, 5.0), 0.45, Vector3(0.1, 0, 0))
	PH.box_shape(body, Vector3(0.2, 2.6, 4.2), Vector3(-1.2, 1.3, 0))
	PH.box_shape(body, Vector3(2.5, 1.15, 0.2), Vector3(0.0, 0.575, 2.0))
	PH.box_shape(body, Vector3(2.5, 1.15, 0.2), Vector3(0.0, 0.575, -2.0))


func _stall_visual(v: Node3D) -> void:
	var wood := PH.mat(PH.WOOD, 0.8)
	var light_wood := PH.mat(Color("a9764b"), 0.7)
	var dark := PH.mat(PH.WOOD_DARK, 0.85)
	var roof := PH.mat(Color("4a3a36"), 0.9)
	var cloth := PH.mat(Color("c9b48f"), 1.0)
	var ceramic := PH.mat(Color("d9c9a8"), 0.35)
	PH.box(v, Vector3(2.7, 0.12, 4.3), Vector3(0, 0.06, 0), dark)
	PH.box(v, Vector3(0.6, 0.98, 3.7), Vector3(1.0, 0.55, 0), wood)
	for z in [-1.6, -0.8, 0.0, 0.8, 1.6]:
		PH.box(v, Vector3(0.04, 0.9, 0.06), Vector3(1.31, 0.55, z), dark)
	PH.box(v, Vector3(0.78, 0.07, 3.9), Vector3(1.03, 1.05, 0), light_wood)
	PH.box(v, Vector3(0.12, 2.6, 4.1), Vector3(-1.2, 1.3, 0), dark)
	for side in [-1.0, 1.0]:
		PH.box(v, Vector3(2.4, 1.0, 0.1), Vector3(0.0, 0.5, 1.98 * side), wood)
		PH.cyl(v, 0.08, 0.09, 2.8, Vector3(1.28, 1.4, 1.95 * side), dark)
		PH.cyl(v, 0.08, 0.09, 2.8, Vector3(-1.15, 1.4, 1.95 * side), dark)
		var slope := PH.box(v, Vector3(1.85, 0.1, 4.9), Vector3(0.78 * side, 3.05, 0), roof)
		slope.rotation_degrees = Vector3(0, 0, -24.0 * side)
	PH.cyl(v, 0.09, 0.09, 5.0, Vector3(0, 3.42, 0), dark, Vector3(90, 0, 0))
	PH.box(v, Vector3(0.08, 0.12, 4.0), Vector3(1.3, 2.62, 0), dark)
	for z in [-1.35, -0.45, 0.45, 1.35]:
		PH.box(v, Vector3(0.02, 0.3, 0.84), Vector3(1.33, 2.44, z), cloth)
	for y in [1.45, 1.95]:
		PH.box(v, Vector3(0.34, 0.04, 3.4), Vector3(-0.98, y, 0), light_wood)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for i in 12:
		var y2 := 1.45 if i < 6 else 1.95
		var z2 := -1.4 + (i % 6) * 0.56 + rng.randf_range(-0.08, 0.08)
		var jar_h := rng.randf_range(0.14, 0.24)
		var jc: Color = [Color("d9c9a8"), Color("8fa7b0"), Color("c48e5c"), Color("b7c79a")][i % 4]
		PH.cyl(v, 0.06, 0.07, jar_h, Vector3(-0.98, y2 + 0.02 + jar_h * 0.5, z2), PH.mat(jc, 0.4))
	# Bait jar on the counter, south end.
	PH.cyl(v, 0.075, 0.09, 0.2, Vector3(1.0, 1.19, 1.35), ceramic, Vector3.ZERO, 16)
	PH.cyl(v, 0.085, 0.085, 0.04, Vector3(1.0, 1.31, 1.35), dark, Vector3.ZERO, 16)
	PH.sphere(v, 0.025, Vector3(1.0, 1.35, 1.35), dark, Vector3.ONE, 8)
	# Stools for customers, out of the walkway.
	for z3 in [-2.5, 2.5]:
		PH.cyl(v, 0.2, 0.2, 0.06, Vector3(2.0, 0.5, z3), light_wood)
		PH.cyl(v, 0.04, 0.05, 0.48, Vector3(2.0, 0.24, z3), dark)


## Collision layer used only to find the stall model's real surfaces.
const SURFACE_LAYER := 1 << 15


## Drops every piece of dressing onto the real counter/shelf surface below it
## (and lifts hanging herbs up against the eave), using an exact trimesh of the
## stall model so nothing floats above the wood or sinks into it.
func _settle_on_surfaces(first_child: int) -> void:
	var body := StaticBody3D.new()
	body.name = "Surfaces"
	body.collision_layer = SURFACE_LAYER
	body.collision_mask = 0
	add_child(body)
	for mi in ModelLib.mesh_instances(visual):
		var cs := CollisionShape3D.new()
		cs.shape = mi.mesh.create_trimesh_shape()
		body.add_child(cs)
		cs.global_transform = mi.global_transform
	var items: Array[Node3D] = []
	for i in range(first_child, get_child_count()):
		var c := get_child(i) as Node3D
		if c and not c is Light3D and c != body:
			items.append(c)
	for n in ["Kettle", "Teacup", "Keeper"]:
		var it := get_node_or_null(n) as Node3D
		if it:
			items.append(it)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var space := get_world_3d().direct_space_state
	for it in items:
		if not is_instance_valid(it):
			continue
		var p := it.global_position
		var up := it.is_in_group("sway_herb")
		var q := PhysicsRayQueryParameters3D.create(p + Vector3(0, -0.35 if up else 0.3, 0), p + Vector3(0, 0.6 if up else -0.45, 0), SURFACE_LAYER)
		var hit := space.intersect_ray(q)
		if hit:
			it.global_position.y = float(hit["position"].y) + (-0.01 if up else 0.0)
	body.queue_free()


## Bait jar and a few cups on the Tripo stall.
func _stall_dressing() -> void:
	ModelLib.place("bait_jar", self, Vector3(1.0, 1.12, 1.4), Vector3(0, 70, 0))
	ModelLib.place("teacup", self, Vector3(0.75, 1.12, 0.9), Vector3(0, 30, 0))
	ModelLib.place("teacup", self, Vector3(0.8, 1.12, 1.05), Vector3(0, 160, 0))
	# A few balls of bait dough by the jar, the way the keeper sells it.
	for i in 3:
		var b := ModelLib.place("bait", self, Vector3(1.12 + 0.05 * i, 1.12, 1.12 - 0.07 * i), Vector3(0, 40.0 * i, 0), 0.22)
		if b == null:
			break
	_herb_bundles()
	_stall_shelves()


## Dried lavender hung upside down from the front eave, swaying a little.
func _herb_bundles() -> void:
	if not ModelLib.has("lavender"):
		return
	for z in [-0.95, 0.05, 0.92]:
		var pivot := Node3D.new()
		pivot.position = Vector3(1.8, 2.26, z)
		pivot.add_to_group("sway_herb")
		add_child(pivot)
		var s := 0.85 + absf(z) * 0.1
		ModelLib.place("lavender", pivot, Vector3(0, -0.4 * s, 0), Vector3(0, z * 70.0, 0), s)


## Back-wall shelves (measured on the stall model, after its 90° yaw).
const SHELF_X := -1.04
const SHELF_HEIGHTS := [1.10, 1.60]
## Old apothecary glass: dusty amber, bottle green, smoky clear, muted cobalt.
const GLASS := [Color("6b4423"), Color("4c5a32"), Color("8a8676"), Color("3d4a5c"), Color("7a5a2e")]
## Barely-there contents: tea tinctures and dried things, not neon potions.
const CONTENTS := [Color("8a5a24"), Color("5e6b33"), Color("6e4a3a"), Color("9a7a44")]


## An old apothecary shelf: dusty bottles, clay jugs, cloth-capped jars, a few
## books, with gaps so it looks used rather than stocked. Uses the Tripo
## "potion_bottles" / "herb_jars" clusters when available.
func _stall_shelves() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 9
	var models := ModelLib.has("potion_bottles") and ModelLib.has("herb_jars")
	for h in SHELF_HEIGHTS:
		var z := -1.22
		while z < 1.22:
			var p := Vector3(SHELF_X + rng.randf_range(-0.04, 0.04), h, z)
			if models and rng.randf() < 0.62:
				# The Tripo clusters, dulled with age so they sit with the old glass.
				var m := ModelLib.place("potion_bottles" if rng.randf() < 0.45 else "herb_jars", self, p, Vector3(0, 90 + rng.randf_range(-25, 25), 0), rng.randf_range(0.75, 0.9))
				_age(m)
				z += rng.randf_range(0.36, 0.46)
				continue
			var roll := rng.randf()
			if roll < 0.12:
				z += rng.randf_range(0.12, 0.22)  # an empty gap
			elif roll < 0.5:
				z += _old_bottle(p, rng)
			elif roll < 0.66:
				z += _clay_jug(p, rng)
			elif roll < 0.82:
				z += _cloth_jar(p, rng)
			elif roll < 0.92:
				z += _books(p, rng)
			else:
				z += _mortar(p, rng)
	# A low warm glow, as if from the lanterns, not from the bottles.
	PH.omni(self, Vector3(SHELF_X + 0.35, 1.45, 0.0), Color("ffb36b"), 0.35, 2.2).remove_from_group("garden_light")


## Dusty, faded look for bright models: muted, rougher, slightly darker.
static func _age(root: Node) -> void:
	for mi in ModelLib.mesh_instances(root):
		for s in mi.mesh.get_surface_count():
			var src := mi.get_active_material(s) as StandardMaterial3D
			if src == null:
				continue
			var m := src.duplicate() as StandardMaterial3D
			m.albedo_color = Color(0.78, 0.74, 0.66)
			m.roughness = maxf(m.roughness, 0.55)
			mi.set_surface_override_material(s, m)


func _glass_mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(c, 0.72)
	m.roughness = 0.32  # a little dust
	m.metallic_specular = 0.6
	m.rim_enabled = true
	m.rim = 0.25
	m.rim_tint = 0.6
	return m


func _old_bottle(p: Vector3, rng: RandomNumberGenerator) -> float:
	var root := Node3D.new()
	root.position = p
	root.rotation.y = rng.randf() * TAU
	add_child(root)
	var glass := _glass_mat(GLASS[rng.randi() % GLASS.size()])
	var fill := PH.mat(CONTENTS[rng.randi() % CONTENTS.size()], 0.5)
	var cork := PH.mat(Color("8c6a46"), 0.95)
	var wax := PH.mat(Color("6e2a26"), 0.6)
	var label := PH.mat(Color("cbbd98"), 1.0)
	var kind := rng.randi() % 3
	if kind == 0:
		# Tall shouldered bottle.
		var hgt := rng.randf_range(0.2, 0.3)
		var r := rng.randf_range(0.035, 0.045)
		PH.cyl(root, r, r, hgt * 0.75, Vector3(0, hgt * 0.375, 0), glass, Vector3.ZERO, 14)
		PH.cyl(root, r * 0.35, r, hgt * 0.15, Vector3(0, hgt * 0.825, 0), glass, Vector3.ZERO, 14)
		PH.cyl(root, r * 0.33, r * 0.33, hgt * 0.12, Vector3(0, hgt * 0.96, 0), glass, Vector3.ZERO, 10)
		PH.cyl(root, r * 0.85, r * 0.85, hgt * rng.randf_range(0.25, 0.55), Vector3(0, hgt * 0.2, 0), fill, Vector3.ZERO, 12)
		var top := wax if rng.randf() < 0.4 else cork
		PH.cyl(root, r * 0.4, r * 0.38, 0.03, Vector3(0, hgt * 1.02 + 0.012, 0), top, Vector3.ZERO, 10)
		if rng.randf() < 0.7:
			PH.box(root, Vector3(r * 1.3, hgt * 0.28, 0.004), Vector3(0, hgt * 0.42, r + 0.002), label)
		return r * 2.0 + rng.randf_range(0.04, 0.08)
	elif kind == 1:
		# Squat round flask.
		var r := rng.randf_range(0.045, 0.06)
		PH.sphere(root, r, Vector3(0, r, 0), glass, Vector3(1, 0.92, 1), 14)
		PH.sphere(root, r * 0.8, Vector3(0, r * 0.7, 0), fill, Vector3(1, 0.6, 1), 12)
		PH.cyl(root, 0.012, 0.016, 0.06, Vector3(0, r * 1.85 + 0.025, 0), glass, Vector3.ZERO, 10)
		PH.cyl(root, 0.014, 0.013, 0.022, Vector3(0, r * 1.85 + 0.06, 0), cork, Vector3.ZERO, 8)
		return r * 2.0 + rng.randf_range(0.04, 0.07)
	# Small square medicine bottle.
	var w := rng.randf_range(0.045, 0.06)
	var hh := rng.randf_range(0.1, 0.14)
	PH.box(root, Vector3(w, hh, w), Vector3(0, hh * 0.5, 0), glass)
	PH.box(root, Vector3(w * 0.8, hh * 0.4, w * 0.8), Vector3(0, hh * 0.2, 0), fill)
	PH.cyl(root, 0.012, 0.012, 0.03, Vector3(0, hh + 0.015, 0), cork, Vector3.ZERO, 8)
	PH.box(root, Vector3(w * 0.9, hh * 0.35, 0.003), Vector3(0, hh * 0.5, w * 0.5 + 0.002), label)
	return w + rng.randf_range(0.04, 0.07)


func _clay_jug(p: Vector3, rng: RandomNumberGenerator) -> float:
	var root := Node3D.new()
	root.position = p
	root.rotation.y = rng.randf() * TAU
	add_child(root)
	var clay := PH.mat([Color("8a6a4c"), Color("6f5a48"), Color("9c8466")][rng.randi() % 3], 0.85)
	var r := rng.randf_range(0.055, 0.07)
	PH.sphere(root, r, Vector3(0, r * 0.95, 0), clay, Vector3(1, 1.05, 1), 14)
	PH.cyl(root, r * 0.35, r * 0.55, 0.05, Vector3(0, r * 1.95 + 0.02, 0), clay, Vector3.ZERO, 12)
	PH.torus(root, 0.015, 0.024, Vector3(r * 0.85, r * 1.3, 0), clay, Vector3(90, 0, 0))
	PH.cyl(root, r * 0.33, r * 0.33, 0.02, Vector3(0, r * 1.95 + 0.05, 0), PH.mat(Color("8c6a46"), 0.95), Vector3.ZERO, 10)
	return r * 2.0 + rng.randf_range(0.05, 0.08)


func _cloth_jar(p: Vector3, rng: RandomNumberGenerator) -> float:
	var root := Node3D.new()
	root.position = p
	add_child(root)
	var hgt := rng.randf_range(0.11, 0.16)
	var r := rng.randf_range(0.05, 0.06)
	PH.cyl(root, r, r * 1.05, hgt, Vector3(0, hgt * 0.5, 0), _glass_mat(Color("8a8676")), Vector3.ZERO, 14)
	PH.cyl(root, r * 0.9, r * 0.95, hgt * 0.7, Vector3(0, hgt * 0.36, 0), PH.mat([Color("6b5236"), Color("5a6236"), Color("7a6a50")][rng.randi() % 3], 0.95), Vector3.ZERO, 12)
	# Cloth cap tied with twine.
	PH.sphere(root, r * 1.15, Vector3(0, hgt + 0.005, 0), PH.mat(Color("c7b896"), 1.0), Vector3(1, 0.35, 1), 12)
	PH.torus(root, r * 0.95, r * 1.08, Vector3(0, hgt - 0.01, 0), PH.mat(Color("9a7f5a"), 1.0))
	return r * 2.0 + rng.randf_range(0.05, 0.08)


func _books(p: Vector3, rng: RandomNumberGenerator) -> float:
	var root := Node3D.new()
	root.position = p
	root.rotation.y = rng.randf_range(-0.3, 0.3)
	add_child(root)
	var colors := [Color("5a3a2a"), Color("2f3d4a"), Color("4a4a2e"), Color("6b2f2a")]
	var y := 0.0
	for i in rng.randi_range(2, 3):
		var t := rng.randf_range(0.025, 0.04)
		var b := PH.box(root, Vector3(0.16, t, 0.22), Vector3(0, y + t * 0.5, 0), PH.mat(colors[rng.randi() % colors.size()], 0.9))
		b.rotation.y = rng.randf_range(-0.15, 0.15)
		PH.box(root, Vector3(0.155, t * 0.8, 0.005), Vector3(0, y + t * 0.5, 0.111), PH.mat(Color("d8cba8"), 1.0)).rotation.y = b.rotation.y
		y += t
	return 0.26


func _mortar(p: Vector3, rng: RandomNumberGenerator) -> float:
	var root := Node3D.new()
	root.position = p
	add_child(root)
	var stone := PH.mat(Color("8b8679"), 0.9)
	PH.cyl(root, 0.06, 0.045, 0.06, Vector3(0, 0.03, 0), stone, Vector3.ZERO, 14)
	var pestle := PH.cyl(root, 0.012, 0.016, 0.12, Vector3(0.015, 0.09, 0), stone, Vector3(0, 0, 25), 8)
	pestle.rotation_degrees.z = rng.randf_range(15, 35)
	return 0.17


func _stall_lights() -> void:
	for side in [-1.0, 1.0]:
		if model:
			lantern_at(Vector3(1.85, 2.2, 1.85 * side), 2.6)
		else:
			PH.hanging_lantern(self, Vector3(1.45, 2.95, 1.75 * side), 0.25, 2.6)
	PH.omni(self, Vector3(2.4, 2.6, 0.0), Color("ffb666"), 1.5, 8.0, true)
	PH.omni(self, Vector3(-0.3, 2.2, 0.0), Color("ffa552"), 0.8, 3.5)


# --- Bridge (span along local X) ------------------------------------------------------------

func _bridge_collision() -> void:
	var body := PH.static_body(self, "wood")
	var segs := 10
	for i in segs:
		var x0 := lerpf(-BRIDGE_HALF - 0.3, BRIDGE_HALF + 0.3, float(i) / segs)
		var x1 := lerpf(-BRIDGE_HALF - 0.3, BRIDGE_HALF + 0.3, float(i + 1) / segs)
		var y0 := bridge_deck_y(x0) - 0.04
		var y1 := bridge_deck_y(x1) - 0.04
		var mid := Vector3((x0 + x1) * 0.5, (y0 + y1) * 0.5 - 0.1, 0)
		var length := Vector2(x1 - x0, y1 - y0).length() + 0.05
		var angle := rad_to_deg(atan2(y1 - y0, x1 - x0))
		PH.box_shape(body, Vector3(length, 0.2, 2.0), mid, Vector3(0, 0, angle))
	var rail := 0.85 if model else 1.02
	for side in [-1.0, 1.0]:
		PH.box_shape(body, Vector3(2.0 * BRIDGE_HALF + 0.6, 1.8, 0.15), Vector3(0, 0.9, rail * side))


## The Tripo bridge's four middle posts stop just above the water; carry them
## down through the stream into the bed so the bridge stands in it.
func _bridge_piers() -> void:
	var wood := PH.mat(Color("5a3826"), 0.85)
	var wet := PH.mat(Color("2e231b"), 0.6)
	for x in [-1.03, 1.02]:
		for z in [-1.0, 1.0]:
			# From inside the post's foot (y -0.22) down into the bed.
			PH.box(self, Vector3(0.19, 0.5, 0.23), Vector3(x, -0.45, z), wood)
			# Darker, water-soaked lower part with a slightly wider foot.
			PH.box(self, Vector3(0.21, 0.6, 0.25), Vector3(x, -0.95, z), wet)


func _bridge_lights() -> void:
	PH.omni(self, Vector3(-BRIDGE_HALF, 1.3, 0), Color("ffb666"), 1.1, 6.0)
	PH.omni(self, Vector3(BRIDGE_HALF, 1.3, 0), Color("ffb666"), 1.1, 6.0)
	# Posts stand beside the bridge ends with their arms pointing away from the deck.
	for spec in [[Vector3(-BRIDGE_HALF - 0.5, 0.0, 1.35), -90.0], [Vector3(BRIDGE_HALF + 0.5, 0.0, -1.35), 90.0]]:
		# Stand each post on the bank's real height.
		var local: Vector3 = spec[0]
		var w := global_transform * local
		local.y = Layout.mesh_height(Vector2(w.x, w.z)) - global_position.y
		post_with_lantern(self, local, float(spec[1]))


## The Tripo lantern post (origin at the post) with a glowing lantern on its
## hook. Returns null when either model is missing.
static func post_with_lantern(parent: Node3D, pos: Vector3, yaw_deg: float, light := true) -> Node3D:
	if not ModelLib.has("lantern_post") or not ModelLib.has("lantern"):
		return null
	var root := Node3D.new()
	root.name = "LanternPost"
	root.position = pos + Vector3(0, -0.04, 0)  # base tucked into the ground
	# On a slope the wide base would hang over the low side: settle it on the
	# lowest ground under its footprint (posts standing on decks are left alone).
	if parent.is_inside_tree():
		var w := parent.global_transform * pos
		var c := Vector2(w.x, w.z)
		var h := Layout.mesh_height(c)
		if absf(w.y - h) < 0.2:
			var low := h
			for i in 8:
				var a := TAU * i / 8.0
				low = minf(low, Layout.mesh_height(c + Vector2(cos(a), sin(a)) * 0.32))
			root.position.y -= (h - low) + 0.03
	root.rotation_degrees.y = yaw_deg
	root.add_to_group("grounded")
	root.add_to_group("lantern_post")
	parent.add_child(root)
	# The post model is centered on its bounds; shift so the post sits at the origin.
	ModelLib.place("lantern_post", root, Vector3(0.42, 0, 0))
	# The lantern hangs from a pivot at the hook so it can swing.
	var pivot := Node3D.new()
	pivot.position = Vector3(1.11, 1.51, -0.03)
	pivot.add_to_group("sway")
	root.add_child(pivot)
	var lantern := ModelLib.place("lantern", pivot, Vector3(0, -0.45, 0))
	root.set_meta("glow_mats", ModelLib.glow(lantern, 2.6))
	root.set_meta("lantern_pos", Vector3(1.11, 1.25, 0))
	if light:
		PH.omni(root, Vector3(1.11, 1.25, 0), Color("ffb666"), 1.3, 7.5)
	var body := PH.static_body(root, "wood")
	PH.cylinder_shape(body, 0.14, 2.2, Vector3(0, 1.1, 0))
	GroundDetail.contact_shadow(root, Vector2(0.95, 0.95), 0.75)
	return root


func _bridge_visual(v: Node3D) -> void:
	var wood := PH.mat(Color("94603c"), 0.8)
	var dark := PH.mat(PH.WOOD_DARK, 0.85)
	var planks := 16
	for i in planks:
		var x := lerpf(-BRIDGE_HALF, BRIDGE_HALF, (i + 0.5) / planks)
		var dx := 0.02
		var slope := (bridge_deck_y(x + dx) - bridge_deck_y(x - dx)) / (2.0 * dx)
		PH.box(v, Vector3(0.32, 0.06, 1.9), Vector3(x, bridge_deck_y(x) - 0.03, 0), wood, Vector3(0, 0, rad_to_deg(atan(slope))))
	for side in [-1.0, 1.0]:
		var pts: Array[Vector3] = []
		for i in 9:
			var x2 := lerpf(-BRIDGE_HALF, BRIDGE_HALF, i / 8.0)
			pts.append(Vector3(x2, bridge_deck_y(x2) - 0.12, 0.88 * side))
		for i in pts.size() - 1:
			PH.limb(v, pts[i], pts[i + 1], 0.07, 0.07, dark, 8)
		var rail: Array[Vector3] = []
		for x3 in [-BRIDGE_HALF, -1.4, 0.0, 1.4, BRIDGE_HALF]:
			var base := Vector3(x3, bridge_deck_y(x3) - 0.05, 0.92 * side)
			var top := base + Vector3.UP * 0.92
			PH.limb(v, base, top, 0.05, 0.045, dark, 8)
			rail.append(top)
		for i in rail.size() - 1:
			PH.limb(v, rail[i], rail[i + 1], 0.035, 0.035, wood, 8)
		for x4 in [-BRIDGE_HALF, BRIDGE_HALF]:
			var post_top := Vector3(x4, bridge_deck_y(x4) + 0.9, 0.92 * side)
			PH.sphere(v, 0.085, post_top + Vector3(0, 0.1, 0), PH.paper(2.0), Vector3(1, 1.2, 1), 12)
			PH.cyl(v, 0.0, 0.11, 0.07, post_top + Vector3(0, 0.22, 0), dark, Vector3.ZERO, 8)
	PH.omni(self, Vector3(-BRIDGE_HALF, 1.4, 0), Color("ffb666"), 1.1, 6.0)
	PH.omni(self, Vector3(BRIDGE_HALF, 1.4, 0), Color("ffb666"), 1.1, 6.0)


# --- Dock (length along local Z; -Z reaches over the water) ---------------------------------

func _dock_collision() -> void:
	var body := PH.static_body(self, "wood")
	if model:
		# The Tripo dock is a level deck whose top sits at y = 0.12, with a gentle
		# invisible ramp from the shore so you can walk straight on.
		PH.box_shape(body, Vector3(2.0 * DOCK_HALF_W, 0.3, 2.0 * DOCK_HALF_LEN + 0.4), Vector3(0, 0.12 - 0.15, 0))
		var z0 := DOCK_HALF_LEN - 0.1
		var z1 := DOCK_HALF_LEN + 1.3
		var land := global_transform * Vector3(0, 0, z1)
		var y1 := Layout.mesh_height(Vector2(land.x, land.z)) - global_position.y - 0.03
		var drop := 0.12 - y1
		var run := z1 - z0
		var ang := atan2(drop, run)
		PH.box_shape(body, Vector3(2.0 * DOCK_HALF_W - 0.1, 0.2, sqrt(run * run + drop * drop)),
			Vector3(0, (0.12 + y1) * 0.5 - 0.1 * cos(ang), (z0 + z1) * 0.5), Vector3(rad_to_deg(ang), 0, 0))
	else:
		var tilt := rad_to_deg(atan2(dock_deck_y(-DOCK_HALF_LEN) - dock_deck_y(DOCK_HALF_LEN), 2.0 * DOCK_HALF_LEN))
		PH.box_shape(body, Vector3(2.0 * DOCK_HALF_W, 0.3, 2.0 * DOCK_HALF_LEN + 0.4), Vector3(0, 0.1 - 0.15, 0), Vector3(tilt, 0, 0))
	for side in [-1.0, 1.0]:
		PH.box_shape(body, Vector3(0.15, 1.6, 4.4), Vector3((DOCK_HALF_W + 0.07) * side, 0.8, -0.65))
	PH.box_shape(body, Vector3(2.0 * DOCK_HALF_W + 0.3, 1.6, 0.15), Vector3(0, 0.8, -DOCK_HALF_LEN - 0.08))


func _dock_visual(v: Node3D) -> void:
	var wood := PH.mat(Color("97653f"), 0.8)
	var dark := PH.mat(PH.WOOD_DARK, 0.85)
	var count := 19
	for i in count:
		var z := lerpf(-DOCK_HALF_LEN, DOCK_HALF_LEN, (i + 0.5) / count)
		var w := 2.0 * DOCK_HALF_W - (0.04 if i % 2 == 0 else 0.0)
		PH.box(v, Vector3(w, 0.06, 0.27), Vector3(0, dock_deck_y(z) - 0.03, z), wood)
	for side in [-1.0, 1.0]:
		var a := Vector3((DOCK_HALF_W - 0.1) * side, dock_deck_y(DOCK_HALF_LEN) - 0.12, DOCK_HALF_LEN)
		var b := Vector3((DOCK_HALF_W - 0.1) * side, dock_deck_y(-DOCK_HALF_LEN) - 0.12, -DOCK_HALF_LEN)
		PH.limb(v, a, b, 0.08, 0.08, dark, 8)
		for z2 in [-DOCK_HALF_LEN + 0.1, -0.9, 0.9]:
			PH.cyl(v, 0.1, 0.11, 1.9, Vector3((DOCK_HALF_W - 0.05) * side, dock_deck_y(z2) - 0.85, z2), dark, Vector3.ZERO, 10)
		# Low edge rail so the dock reads as safe; real blocking is the proxy wall.
		var r0 := Vector3((DOCK_HALF_W - 0.05) * side, dock_deck_y(0.9) + 0.45, 0.9)
		var r1 := Vector3((DOCK_HALF_W - 0.05) * side, dock_deck_y(-2.2) + 0.45, -2.2)
		PH.limb(v, r0, r1, 0.03, 0.03, wood, 6)
		for z3 in [0.9, -0.65, -2.2]:
			PH.limb(v, Vector3((DOCK_HALF_W - 0.05) * side, dock_deck_y(z3), z3), Vector3((DOCK_HALF_W - 0.05) * side, dock_deck_y(z3) + 0.47, z3), 0.035, 0.035, dark, 6)
