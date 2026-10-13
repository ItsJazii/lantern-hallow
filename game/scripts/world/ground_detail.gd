class_name GroundDetail
extends Node3D
## Grounds the scene: 3D grass tufts over the lawns (thinning out toward path
## edges), denser rings of grass around anything standing on the ground, and
## soft contact shadows under objects so nothing looks pasted on.

const TILE := 8.0
const LAWN_DENSITY := 8.5   # tufts per square meter on open grass
const FADE_START := 9.0    # tufts are close-up detail only; gone by mid-distance
const FADE_END := 17.0

static var _shadow_tex: GradientTexture2D
## Built tiles, kept for the session: the scatter is deterministic, so a
## scene reload (restart, back to title) reuses them instead of rebuilding.
static var _cached: Array[MultiMesh] = []

var _mesh: ArrayMesh
var _material: ShaderMaterial
var _rng := RandomNumberGenerator.new()
var _tiles := {}  # Vector2i -> Array[Transform3D]
var _colors := {}  # Vector2i -> Array[Color]


func _ready() -> void:
	_rng.seed = 909
	_mesh = _tuft_mesh()
	_material = ShaderMaterial.new()
	_material.shader = load("res://shaders/grass.gdshader")
	_mesh.surface_set_material(0, _material)


## Scatters lawn grass, then rings of tufts around each contact point
## ([Vector2 center, float radius]), then builds the tiles.
func build(contacts: Array, exclude_rects: Array) -> void:
	if not _cached.is_empty():
		for mm in _cached:
			_add_tile(mm)
		return
	var b := Layout.BOUNDS.grow(6.0)
	var area := b.size.x * b.size.y
	var count := int(area * LAWN_DENSITY)
	for i in count:
		var p := Vector2(_rng.randf_range(b.position.x, b.end.x), _rng.randf_range(b.position.y, b.end.y))
		var pf := Layout.path_factor(p) if Layout.rim_distance(p) < 4.0 else 0.0
		# Path edges get a few stragglers so the border looks natural.
		if pf > 0.55 or (pf > 0.15 and _rng.randf() < pf * 1.6):
			continue
		if not _grassy(p, exclude_rects):
			continue
		_add(p, _rng.randf_range(0.6, 0.95))
	for c in contacts:
		var center: Vector2 = c[0]
		var r: float = c[1]
		var n := int(clampf(r * 22.0, 6.0, 40.0))
		for i in n:
			var a := _rng.randf() * TAU
			# Just outside the object, not growing through it.
			var p := center + Vector2(cos(a), sin(a)) * (r + _rng.randf_range(0.08, 0.3))
			if _grassy(p, exclude_rects) and Layout.path_factor(p) < 0.5:
				_add(p, _rng.randf_range(0.9, 1.4))
	for key in _tiles:
		_build_tile(key)


func _grassy(p: Vector2, exclude_rects: Array) -> bool:
	if Layout.pond_k(p) < 1.04 or Layout.stream_distance(p) < Layout.STREAM_HALF_WIDTH + 0.6:
		return false
	if Layout.rim_distance(p) > 6.0:
		return false
	for r in exclude_rects:
		if (r as Rect2).has_point(p):
			return false
	return true


func _add(p: Vector2, s: float) -> void:
	var key := Vector2i(floori(p.x / TILE), floori(p.y / TILE))
	if not _tiles.has(key):
		_tiles[key] = []
		_colors[key] = []
	var basis := Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3(s, s * _rng.randf_range(0.8, 1.25), s))
	(_tiles[key] as Array).append(Transform3D(basis, Vector3(p.x, Layout.mesh_height(p) - 0.02, p.y)))
	var tint := Color(1, 1, 1).lerp(Color(0.85, 0.95, 0.75), _rng.randf())
	if _rng.randf() < 0.18:
		tint = Color(1.12, 1.05, 0.78)  # sun-dried, yellower tufts
	(_colors[key] as Array).append(tint)


func _build_tile(key: Vector2i) -> void:
	var xfs: Array = _tiles[key]
	var cols: Array = _colors[key]
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = _mesh
	mm.instance_count = xfs.size()
	for i in xfs.size():
		mm.set_instance_transform(i, xfs[i])
		mm.set_instance_color(i, cols[i])
	_cached.append(mm)
	_add_tile(mm)


func _add_tile(mm: MultiMesh) -> void:
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mmi.layers = WaterReflection.LAYER_SMALL
	# Each tile fades out with distance so far lawns cost nothing.
	mmi.visibility_range_end = FADE_END
	mmi.visibility_range_end_margin = FADE_END - FADE_START
	mmi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	add_child(mmi)


## A tuft of curved, tapering blades. UV.y runs 0 (root) to 1 (tip).
func _tuft_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var r := RandomNumberGenerator.new()
	r.seed = 3
	for blade in 12:
		var yaw := r.randf() * TAU
		var dir := Vector3(sin(yaw), 0, cos(yaw))
		var side := Vector3(cos(yaw), 0, -sin(yaw))
		var base := dir * r.randf_range(0.0, 0.13)
		# A few tall blades over a soft, short layer, like real lawn tufts.
		var height := r.randf_range(0.2, 0.34) if blade % 4 == 0 else r.randf_range(0.09, 0.2)
		var lean := r.randf_range(0.15, 0.45)
		var width := r.randf_range(0.02, 0.034)
		var segs := 2
		var prev_l := Vector3.ZERO
		var prev_r := Vector3.ZERO
		for s in segs + 1:
			var t := float(s) / segs
			var center := base + dir * lean * height * t * t + Vector3.UP * height * t
			var w := width * (1.0 - t)
			var l := center - side * w
			var rr := center + side * w
			if s > 0:
				var t0 := float(s - 1) / segs
				_quad(st, prev_l, prev_r, l, rr, t0, t)
			prev_l = l
			prev_r = rr
	st.generate_normals()
	return st.commit()


func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, t0: float, t1: float) -> void:
	for v in [[a, t0], [b, t0], [c, t1], [b, t0], [d, t1], [c, t1]]:
		st.set_color(Color.WHITE)
		st.set_uv(Vector2(0.5, v[1]))
		st.set_normal(Vector3.UP)
		st.add_vertex(v[0])


## A soft dark blot projected onto the ground under `parent`.
static func contact_shadow(parent: Node3D, size: Vector2, strength := 0.65, offset := Vector3.ZERO) -> Decal:
	if _shadow_tex == null:
		var g := Gradient.new()
		g.set_color(0, Color(0, 0, 0, 1))
		g.set_color(1, Color(0, 0, 0, 0))
		g.add_point(0.45, Color(0, 0, 0, 0.55))
		_shadow_tex = GradientTexture2D.new()
		_shadow_tex.gradient = g
		_shadow_tex.fill = GradientTexture2D.FILL_RADIAL
		_shadow_tex.fill_from = Vector2(0.5, 0.5)
		_shadow_tex.fill_to = Vector2(1.0, 0.5)
		_shadow_tex.width = 128
		_shadow_tex.height = 128
	var d := Decal.new()
	d.texture_albedo = _shadow_tex
	d.size = Vector3(size.x, 0.8, size.y)
	d.modulate = Color(1, 1, 1, strength)
	d.albedo_mix = strength
	d.upper_fade = 0.2
	d.lower_fade = 0.2
	d.cull_mask = 1
	d.position = offset + Vector3(0, 0.15, 0)
	parent.add_child(d)
	return d
