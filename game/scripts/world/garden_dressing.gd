class_name GardenDressing
extends Node3D
## Places the second wave of Tripo models around the garden:
##   grass clumps  (grass_a / grass_b) along path edges, around anything
##                 standing on the ground and scattered over the lawns, in
##                 distance-faded tiles so they cost nothing far away;
##   cattails      (reeds) in clumps along the pond bank and the stream;
##   mushrooms     (glow_mushrooms) at the giant tree's roots and in the grove;
##   stone lanterns around the pond, each with a warm candle;
##   barrel+crates beside the tea stall.
## Every piece sits on the exact terrain triangle (Layout.mesh_height).

const TILE := 10.0
const FADE_START := 30.0
const FADE_END := 44.0
const TUFT_DETAIL := 14.0   # full-detail "grass new" clumps out to here
const TUFT_END := 34.0      # lighter clumps fade out by here
## Browser build only (weak laptop GPUs draw far fewer triangles): lighter clumps
## everywhere and shorter grass reach. The desktop game never uses these.
const WEB_TUFT_END := 20.0
const WEB_FADE_START := 18.0
const WEB_FADE_END := 28.0

## Stone lanterns on the pond bank (angle around the pond, radius factor).
const STONE_LANTERNS := [[2.2, 1.16], [3.75, 1.14], [5.3, 1.15], [1.15, 1.17]]
## Barrel and crates tucked against the stall's south side.
const BARREL_SPOT := Vector3(-24.9, 0.0, 2.65)

var _rng := RandomNumberGenerator.new()
var _world: Node3D
var _tiles := {}  # "kind:x:z" -> Array[Transform3D]


func build(world: Node3D) -> void:
	_world = world
	_rng.seed = 5150
	_reeds()
	_mushrooms()
	_stone_lanterns()
	_barrel()
	# Last, so clumps also gather around the pieces placed above.
	_grass()


# --- Grass clumps --------------------------------------------------------------------------

static var _cached_grass := {}  # tile key -> MultiMesh, reused on scene reload


func _grass() -> void:
	if not (ModelLib.has("grass_a") and ModelLib.has("grass_b")):
		return
	if not _cached_grass.is_empty():
		for key in _cached_grass:
			_add_grass_tile(key, _cached_grass[key])
		return
	var contacts: Array = _world.get("contact_points")
	_index_obstacles(contacts)
	# 1) Path edges: the tall clumps that soften every border, like the concept.
	var b := Layout.BOUNDS
	for i in 9000:
		var p := Vector2(_rng.randf_range(b.position.x, b.end.x), _rng.randf_range(b.position.y, b.end.y))
		var d := Layout.distance_to_any_path(p)
		if d < 0.05 or d > 0.9:
			continue
		if _rng.randf() > 0.55 - d * 0.4:
			continue
		_clump(p, _rng.randf_range(0.8, 1.25))
	# 2) Around posts, rocks, roots and other ground contacts.
	for c in contacts:
		var center: Vector2 = c[0]
		var r: float = c[1]
		for j in clampi(int(r * 6.0), 2, 12):
			var a := _rng.randf() * TAU
			var rs := _rng.randf_range(0.65, 0.95)
			_clump(center + Vector2(cos(a), sin(a)) * (r + 0.12 + rs * 0.12 + _rng.randf_range(0.0, 0.25)), rs, "grass_b", true)
	# 2b) The first lantern post you see at the spawn: a small bed of grass
	# and flowers round its base, so it grows out of the lawn.
	for post in get_tree().get_nodes_in_group("lantern_post"):
		var c3 := (post as Node3D).global_position
		var c := Vector2(c3.x, c3.z)
		if c.distance_to(Vector2(Layout.SPAWN.x, Layout.SPAWN.z)) > 6.0:
			continue
		var a0 := _rng.randf() * TAU
		for j in 26:
			var a := a0 + TAU * j / 13.0 + _rng.randf_range(-0.2, 0.2)
			var d := _rng.randf_range(0.3, 0.55) if j < 13 else _rng.randf_range(0.6, 1.0)
			var q := c + Vector2(cos(a), sin(a)) * d
			if ModelLib.has("grass_tuft_1") and j % 2 == 0:
				var kind := "grass_tuft_%d" % (_rng.randi() % 3 + 1)
				_clump(q, _rng.randf_range(0.14, 0.2) / ModelLib.mesh(kind).get_aabb().size.y, kind, true)
			else:
				_clump(q, _rng.randf_range(0.95, 1.25), "grass_b", true)
		if ModelLib.has("flower"):
			for j in 7:
				var a2 := a0 + PI * 0.3 + j * 0.9
				_clump(c + Vector2(cos(a2), sin(a2)) * _rng.randf_range(0.38, 0.75), _rng.randf_range(0.75, 1.0), "flower", true)
	# 3) Loose clumps across the lawns.
	for i in 3200:
		var p := Vector2(_rng.randf_range(b.position.x, b.end.x), _rng.randf_range(b.position.y, b.end.y))
		_clump(p, _rng.randf_range(0.7, 1.15))
	# 4) Your new grass ("grass new"), split into its single clumps: lots of
	# small tufts through the lawns, 12-19 cm tall, a little back from paths.
	if ModelLib.has("grass_tuft_1"):
		for i in 9000:
			var p := Vector2(_rng.randf_range(b.position.x, b.end.x), _rng.randf_range(b.position.y, b.end.y))
			if Layout.distance_to_any_path(p) > 0.4:
				var kind := "grass_tuft_%d" % (_rng.randi() % 3 + 1)
				_clump(p, _rng.randf_range(0.12, 0.19) / ModelLib.mesh(kind).get_aabb().size.y, kind)
	# 5) The leafy plant: broad-leaved accents here and there, never on the
	# path edge.
	if ModelLib.has("leafy"):
		for i in 420:
			var p := Vector2(_rng.randf_range(b.position.x, b.end.x), _rng.randf_range(b.position.y, b.end.y))
			if Layout.distance_to_any_path(p) > 1.4 and _rng.randf() < 0.35:
				_clump(p, _rng.randf_range(0.75, 1.05), "leafy")
	for key in _tiles:
		_build_tile(key)


## Rough footprint radius of each grass model at scale 1 (meters).
const FOOTPRINT := {"grass_a": 0.24, "grass_b": 0.13, "grass_tuft_1": 0.2, "grass_tuft_2": 0.18, "grass_tuft_3": 0.18, "leafy": 0.16}
const NARROW := {"grass_a": 0.78, "grass_b": 0.85}  # thinner clumps, more of them

var _obstacles := {}  # Vector2i cell -> Array of [center, radius]


## Rocks, posts, roots, stall legs, bushes and the like, bucketed by 2 m cell,
## so grass can keep clear of them instead of growing through.
func _index_obstacles(contacts: Array) -> void:
	var all: Array = contacts.duplicate()
	for c in _world.get("cover_points"):
		all.append([c, 0.7])
	for o in all:
		var c: Vector2 = o[0]
		var cell := Vector2i(floori(c.x / 2.0), floori(c.y / 2.0))
		if not _obstacles.has(cell):
			_obstacles[cell] = []
		(_obstacles[cell] as Array).append(o)


func _blocked(p: Vector2, radius: float) -> bool:
	var cell := Vector2i(floori(p.x / 2.0), floori(p.y / 2.0))
	for dx in [-1, 0, 1]:
		for dz in [-1, 0, 1]:
			for o in _obstacles.get(cell + Vector2i(dx, dz), []):
				var r: float = float(o[1]) + radius * 0.6
				if p.distance_squared_to(o[0]) < r * r:
					return true
	return false


func _clump(p: Vector2, s: float, kind_override := "", hugging := false) -> void:
	if Layout.path_factor(p) > 0.35 or Layout.pond_k(p) < 1.05 or Layout.stream_distance(p) < Layout.STREAM_HALF_WIDTH + 0.6:
		return
	if Layout.rim_distance(p) > 4.0:
		return
	# Never inside the stall, on the dock or under the bench seat.
	for r in [Rect2(-25.2, -2.2, 3.0, 4.4), Rect2(8.0, 4.8, 3.2, 3.2), Rect2(-0.9, 17.2, 1.8, 0.9)]:
		if (r as Rect2).has_point(p):
			return
	var kind := kind_override if kind_override != "" else ("grass_a" if _rng.randf() < 0.55 else "grass_b")
	var narrow: float = NARROW.get(kind, 1.0)
	# Keep clear of rocks, posts and bushes (ring clumps sit just outside).
	if not hugging and _blocked(p, float(FOOTPRINT.get(kind, 0.2)) * s * narrow):
		return
	var key := "%s:%d:%d" % [kind, floori(p.x / TILE), floori(p.y / TILE)]
	if not _tiles.has(key):
		_tiles[key] = []
	var basis := Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3(s * narrow, s * _rng.randf_range(0.85, 1.2), s * narrow))
	# Slight lean so clumps aren't all bolt upright.
	basis = Basis(Vector3(_rng.randf_range(-1, 1), 0, _rng.randf_range(-1, 1)).normalized(), _rng.randf_range(0.0, 0.08)) * basis
	(_tiles[key] as Array).append(Transform3D(basis, Vector3(p.x, Layout.mesh_height(p) - 0.015, p.y)))


func _build_tile(key: String) -> void:
	var kind := key.get_slice(":", 0)
	var mesh := ModelLib.mesh(kind)
	var xfs: Array = _tiles[key]
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = xfs.size()
	for i in xfs.size():
		mm.set_instance_transform(i, xfs[i])
	_cached_grass[key] = mm
	_add_grass_tile(key, mm)


func _add_grass_tile(key: String, mm: MultiMesh) -> void:
	var kind := key.get_slice(":", 0)
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = _grass_material(kind)
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mmi.layers = WaterReflection.LAYER_SMALL
	mmi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	add_child(mmi)
	var web := ModelLib.web_lite()
	if web and kind.begins_with("grass_tuft") and ModelLib.has(kind + "_lite"):
		mmi.multimesh = _lite_copy(mm, kind)
		mmi.visibility_range_end = WEB_TUFT_END
		mmi.visibility_range_end_margin = 5.0
	elif web:
		mmi.visibility_range_end = WEB_FADE_END
		mmi.visibility_range_end_margin = WEB_FADE_END - WEB_FADE_START
	elif kind.begins_with("grass_tuft") and ModelLib.has(kind + "_lite"):
		# The small "grass new" clumps: full detail close by, a lighter copy
		# (same look at a few pixels' size) further out, gone where they'd be
		# specks. This is most of the lawn's triangles, so it matters a lot
		# for frame rate, especially in a browser.
		mmi.visibility_range_end = TUFT_DETAIL
		mmi.visibility_range_end_margin = 2.0
		var far := MultiMeshInstance3D.new()
		far.multimesh = _lite_copy(mm, kind)
		far.material_override = _grass_material(kind)
		far.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		far.layers = WaterReflection.LAYER_SMALL
		far.visibility_range_begin = TUFT_DETAIL
		far.visibility_range_begin_margin = 2.0
		far.visibility_range_end = TUFT_END
		far.visibility_range_end_margin = 6.0
		far.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
		add_child(far)
	else:
		mmi.visibility_range_end = FADE_END
		mmi.visibility_range_end_margin = FADE_END - FADE_START


## Same placements as `mm`, drawn with the lighter copy of the clump.
func _lite_copy(mm: MultiMesh, kind: String) -> MultiMesh:
	var lite := MultiMesh.new()
	lite.transform_format = MultiMesh.TRANSFORM_3D
	lite.mesh = ModelLib.mesh(kind + "_lite")
	lite.instance_count = mm.instance_count
	for i in mm.instance_count:
		lite.set_instance_transform(i, mm.get_instance_transform(i))
	return lite


var _grass_mats := {}


func _grass_material(kind: String) -> Material:
	if not _grass_mats.has(kind):
		# The leafy plant only stirs; grass sways.
		var sway := 0.035 if kind == "leafy" else (0.06 if kind.begins_with("grass_tuft") else 0.09)
		_grass_mats[kind] = ModelLib.wind_material(ModelLib.mesh(kind), ModelLib.mesh(kind).get_aabb().size.y, sway, 0.02 if kind == "leafy" else 0.03)
	return _grass_mats[kind]


# --- Cattails ---------------------------------------------------------------------------------

func _reeds() -> void:
	var mesh := ModelLib.mesh("reeds")
	if mesh == null:
		return
	var xfs: Array = []
	var dock := Vector2(8.2, 5.7)
	# Pond bank: clumps with open gaps between them.
	var a := 0.0
	while a < TAU:
		a += _rng.randf_range(0.18, 0.5)
		if _rng.randf() < 0.35:
			continue
		for j in _rng.randi_range(1, 3):
			var aj := a + _rng.randf_range(-0.05, 0.05)
			var p := Vector2(cos(aj) * Layout.POND_RADII.x, sin(aj) * Layout.POND_RADII.y) * _rng.randf_range(0.86, 0.94)  # in the shallows
			if p.distance_to(dock) < 4.5 or p.distance_to(Vector2(-7.0, 6.1)) < 2.5:
				continue
			xfs.append(_reed_xf(p))
	# Stream banks, both sides.
	for i in Layout.STREAM.size() - 1:
		var p0: Vector2 = Layout.STREAM[i]
		var p1: Vector2 = Layout.STREAM[i + 1]
		var n := (p1 - p0).orthogonal().normalized()
		var steps := int(p0.distance_to(p1) / 1.4)
		for k in steps:
			if _rng.randf() < 0.5:
				continue
			var t := (k + _rng.randf()) / float(steps)
			var side := 1.0 if _rng.randf() < 0.5 else -1.0
			var c := p0.lerp(p1, t)
			var p := c + n * side * (Layout.STREAM_HALF_WIDTH + _rng.randf_range(-0.1, 0.4)) / Layout.stream_widen(c)
			if p.distance_to(Layout.BRIDGE) < 3.5 or Layout.path_factor(p) > 0.2:
				continue
			if Layout.outside_distance(p) > 3.0:
				continue
			xfs.append(_reed_xf(p))
	var mmi := MultiMeshInstance3D.new()
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = xfs.size()
	for i in xfs.size():
		mm.set_instance_transform(i, xfs[i])
	mmi.multimesh = mm
	mmi.material_override = ModelLib.wind_material(mesh, 1.2, 0.07, 0.02)
	add_child(mmi)


func _reed_xf(p: Vector2) -> Transform3D:
	var s := _rng.randf_range(0.7, 1.1)
	var y := maxf(Layout.mesh_height(p), Layout.WATER_Y - 0.05) - 0.04
	return Transform3D(Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3.ONE * s), Vector3(p.x, y, p.y))


# --- Glowing mushrooms ------------------------------------------------------------------------

func _mushrooms() -> void:
	if not ModelLib.has("glow_mushrooms"):
		return
	var spots: Array = []
	# Between the giant tree's roots.
	for i in 6:
		var a := TAU * i / 6.0 + _rng.randf_range(-0.3, 0.3)
		spots.append(Vector2(-31.0, -6.0) + Vector2(cos(a), sin(a)) * _rng.randf_range(4.6, 6.2))
	# Around the moonleaf grove.
	for i in 7:
		var a := TAU * i / 7.0 + _rng.randf_range(-0.25, 0.25)
		spots.append(Vector2(16.0, -13.0) + Vector2(cos(a), sin(a)) * _rng.randf_range(3.4, 5.4))
	# A few along the forest edge.
	for i in 6:
		spots.append(Vector2(_rng.randf_range(-28, 28), _rng.randf_range(-24, -20)))
	var lights := 0
	for p in spots:
		var q: Vector2 = p
		if Layout.path_factor(q) > 0.1 or Layout.pond_k(q) < 1.1 or Layout.stream_distance(q) < 2.0:
			continue
		var s := _rng.randf_range(0.8, 1.5)
		var m := ModelLib.place("glow_mushrooms", self, Vector3(q.x, Layout.mesh_height(q) - 0.01, q.y), Vector3(0, _rng.randf() * 360.0, 0), s)
		ModelLib.glow(m, 0.28, Color(0.85, 0.85, 1.0))
		ModelLib.set_layers(m, WaterReflection.LAYER_SMALL)
		_world.get("contact_points").append([q, 0.18 * s])
		if lights < 5 and _rng.randf() < 0.4:
			lights += 1
			var l := PH.omni(m, Vector3(0, 0.25, 0), Color("9fb4ff"), 0.5, 2.2)
			l.remove_from_group("garden_light")


# --- Stone lanterns ---------------------------------------------------------------------------

func _stone_lanterns() -> void:
	if not ModelLib.has("stone_lantern"):
		return
	for spec in STONE_LANTERNS:
		var a: float = spec[0]
		var p := Vector2(cos(a) * Layout.POND_RADII.x, sin(a) * Layout.POND_RADII.y) * float(spec[1])
		if Layout.path_factor(p) > 0.05 or Layout.stream_distance(p) < Layout.STREAM_HALF_WIDTH + 1.0:
			continue
		var root := Node3D.new()
		root.name = "StoneLantern"
		root.position = Vector3(p.x, Layout.mesh_height(p) - 0.03, p.y)
		# Window faces the water.
		root.rotation.y = atan2(-p.x, -p.y)
		root.add_to_group("grounded")
		add_child(root)
		var m := ModelLib.place("stone_lantern", root)
		ModelLib.glow(m, 0.05)
		# A candle in the light chamber: warm glow through the paper windows.
		var flame := PH.sphere(root, 0.04, Vector3(0, 0.74, 0), PH.mat(Color("ffcf7a"), 0.5, Color("ffb347"), 6.0), Vector3(1, 1.4, 1), 8)
		flame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		PH.omni(root, Vector3(0, 0.78, 0), Color("ffb25e"), 1.1, 5.0)
		var body := PH.static_body(root, "stone")
		PH.box_shape(body, Vector3(0.5, 1.1, 0.5), Vector3(0, 0.55, 0))
		GroundDetail.contact_shadow(root, Vector2(1.0, 1.0), 0.55)
		_world.get("contact_points").append([p, 0.4])


# --- Barrel and crates --------------------------------------------------------------------------

func _barrel() -> void:
	if not ModelLib.has("barrel"):
		return
	var p := Vector2(BARREL_SPOT.x, BARREL_SPOT.z)
	var root := Node3D.new()
	root.name = "BarrelCrates"
	root.position = Vector3(p.x, Layout.mesh_height(p) - 0.02, p.y)
	root.rotation.y = deg_to_rad(-90.0)
	root.add_to_group("grounded")
	add_child(root)
	ModelLib.place("barrel", root)
	var body := PH.static_body(root, "wood")
	PH.box_shape(body, Vector3(1.3, 0.85, 0.65), Vector3(0, 0.42, 0))
	GroundDetail.contact_shadow(root, Vector2(1.8, 1.1), 0.6)
	_world.get("contact_points").append([p, 0.7])
