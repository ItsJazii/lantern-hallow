extends Node3D
## Builds the engine-side garden at load: environment and lighting, terrain,
## pond and stream water, invisible boundaries, scattered foliage and rocks,
## path lanterns, fireflies and ambience. Gameplay objects live in the scene.

const TERRAIN_MIN := Layout.TERRAIN_MIN
const TERRAIN_MAX := Layout.TERRAIN_MAX
const TERRAIN_STEP := Layout.TERRAIN_STEP

@export var bridge_path := NodePath("../Props/Bridge")
@export var dock_path := NodePath("../Props/Dock")

var environment: Environment
var moon: DirectionalLight3D
var _rng := RandomNumberGenerator.new()
var _exclusions: Array = []  # [Vector2 center, float radius]
## Bush positions animals can run to for cover.
var cover_points: Array = []
## [Vector2 center, float radius] of things standing on the ground (grass rings).
var contact_points: Array = []
## Centres of flower clumps (XZ), for moths and bees.
var flower_points: Array = []


func _ready() -> void:
	add_to_group("world")
	_rng.seed = 2024
	var prof := "--profile" in OS.get_cmdline_user_args()
	var t0 := Time.get_ticks_msec()
	var steps := [_collect_exclusions, _build_environment, _build_terrain, _build_water, _build_boundaries,
		_build_forest, _build_ground_cover, _build_shore, _build_lilies, _build_path_lanterns,
		_build_grove_dressing, _build_fireflies, _add_life, _add_dressing, _build_ground_detail, _build_audio]
	for step in steps:
		var ts := Time.get_ticks_msec()
		(step as Callable).call()
		if prof:
			print("PROFILE %-24s %5d ms" % [(step as Callable).get_method(), Time.get_ticks_msec() - ts])
	if prof:
		print("PROFILE total world %d ms" % (Time.get_ticks_msec() - t0))
	GameState.changed.connect(_on_state_changed)
	apply_evening(GameState.has("ending_complete"), false)


func _add_life() -> void:
	add_child(PondLife.new())
	add_child(AmbientLife.new())
	add_child(Wildlife.new())


func _add_dressing() -> void:
	var dressing := GardenDressing.new()
	dressing.name = "GardenDressing"
	add_child(dressing)
	dressing.build(self)


## After the ending, garden lights stay a little brighter.
func apply_evening(bright: bool, animate: bool) -> void:
	for l in get_tree().get_nodes_in_group("garden_light"):
		var light := l as Light3D
		if light == null:
			continue
		if not light.has_meta("base_energy"):
			light.set_meta("base_energy", light.light_energy)
		var target := float(light.get_meta("base_energy")) * (1.35 if bright else 1.0)
		if animate:
			light.create_tween().tween_property(light, "light_energy", target, 3.0)
		else:
			light.light_energy = target
	var ambient := 1.15 if bright else 1.0
	if animate:
		create_tween().tween_property(environment, "ambient_light_energy", ambient, 3.0)
	else:
		environment.ambient_light_energy = ambient


func _build_ground_detail() -> void:
	var stall := Vector2(-23.6, 0.0)
	for c in [Vector2(1.45, 2.05), Vector2(1.45, -2.05), Vector2(-1.3, 2.05), Vector2(-1.3, -2.05)]:
		contact_points.append([stall + c, 0.35])
	contact_points.append([Vector2(-31.0, -6.0), 5.6])  # giant tree roots
	contact_points.append([Vector2(0.0, 17.7), 0.95])   # bench
	contact_points.append([Vector2(10.6, 7.3), 0.9])    # dock, land end
	var bridge := get_node_or_null(bridge_path) as Node3D
	if bridge:
		var axis := bridge.global_transform.basis.x
		for e in [-3.0, 3.0]:
			var p := bridge.global_position + axis * float(e)
			contact_points.append([Vector2(p.x, p.z), 0.8])
	# The small generated grass tufts (GroundDetail) are off: they read as
	# stubble. Lawns use your grass models (GardenDressing) only.


func _on_state_changed() -> void:
	pass


## Gentle swing for every hanging lantern (group "sway"), each slightly out of
## step with its neighbors.
func _process(_delta: float) -> void:
	var t := Time.get_ticks_msec() / 1000.0
	for n in get_tree().get_nodes_in_group("sway") + get_tree().get_nodes_in_group("sway_herb"):
		var node := n as Node3D
		var ph := node.global_position.x * 1.7 + node.global_position.z * 1.3
		node.rotation.x = sin(t * 1.15 + ph) * 0.05
		node.rotation.z = sin(t * 0.9 + ph * 1.4) * 0.07


# --- Environment ---------------------------------------------------------------------------

func _build_environment() -> void:
	environment = Environment.new()
	var sky := Sky.new()
	var sky_mat := ShaderMaterial.new()
	sky_mat.shader = load("res://shaders/sky.gdshader")
	sky.sky_material = sky_mat
	sky.radiance_size = Sky.RADIANCE_SIZE_256
	environment.background_mode = Environment.BG_SKY
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("3a5683")
	environment.ambient_light_energy = 1.25
	environment.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.tonemap_exposure = 1.05
	environment.tonemap_white = 6.0
	environment.glow_enabled = true
	environment.glow_intensity = 0.65
	environment.glow_strength = 1.0
	environment.glow_bloom = 0.03
	environment.glow_hdr_threshold = 1.0
	environment.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	environment.ssao_enabled = true
	environment.ssao_radius = 1.2
	environment.ssao_intensity = 1.6
	environment.ssr_enabled = true
	environment.ssr_max_steps = 56
	environment.ssr_fade_in = 0.15
	environment.ssr_fade_out = 2.0
	environment.fog_enabled = true
	environment.fog_light_color = Color("2a4a74")
	environment.fog_light_energy = 1.0
	environment.fog_density = 0.009
	environment.fog_sky_affect = 0.12
	environment.fog_height = -0.1
	environment.fog_height_density = 0.18
	environment.adjustment_enabled = true
	environment.adjustment_saturation = 1.08
	environment.adjustment_contrast = 1.04
	var we := WorldEnvironment.new()
	we.environment = environment
	add_child(we)

	moon = DirectionalLight3D.new()
	moon.light_color = Color(0.62, 0.74, 1.0)
	moon.light_energy = 0.85
	moon.shadow_enabled = true
	moon.shadow_blur = 1.6
	moon.directional_shadow_max_distance = 45.0
	moon.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	# Fade between the two shadow zones instead of a hard straight edge on
	# the ground (very visible in the browser renderer).
	moon.directional_shadow_blend_splits = true
	if RenderingServer.get_current_rendering_method() == "gl_compatibility":
		# Browser renderer: its moon shadow map darkens the ground just past
		# its coverage, a hard straight band across the lawns even with no
		# shadow casters at all. The lanterns still light the scene; only the
		# soft moonlight shadows are dropped there.
		moon.shadow_enabled = false
	var toward_moon := Vector3(-0.42, 0.58, -0.7).normalized()
	moon.basis = Basis.looking_at(-toward_moon, Vector3.UP)
	add_child(moon)

	var probe := ReflectionProbe.new()
	probe.size = Vector3(46, 16, 38)
	probe.position = Vector3(0, 3.0, 0)
	probe.update_mode = ReflectionProbe.UPDATE_ONCE
	probe.intensity = 1.0
	probe.max_distance = 80.0
	add_child(probe)


# --- Terrain ---------------------------------------------------------------------------------

## The terrain never changes, so its mesh and collision are built once per
## session and reused when the scene reloads (restart, return to title).
static var _terrain_mesh: ArrayMesh
static var _terrain_shape: Shape3D
static var _terrain_chunks: Array[ArrayMesh] = []

## Cells per side of each visible terrain tile. The ground is drawn as tiles
## (not one huge mesh) so each tile is lit by its own nearby lanterns: the
## browser renderer only lights an object with its 8 nearest lights, and a
## single mesh showed hard straight seams where that set changed.
const TERRAIN_CHUNK := 24


func _build_terrain() -> void:
	if _terrain_mesh == null:
		_terrain_mesh = _make_terrain_mesh()
		_terrain_shape = _terrain_mesh.create_trimesh_shape()
		_terrain_chunks = _split_terrain(_terrain_mesh)
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/terrain.gdshader")
	m.set_shader_parameter("noise_tex", _noise_texture(FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 0.02, false))
	m.set_shader_parameter("cell_tex", _cell_texture())
	var root := Node3D.new()
	root.name = "Terrain"
	add_child(root)
	for chunk in _terrain_chunks:
		var mi := MeshInstance3D.new()
		mi.mesh = chunk
		mi.material_override = m
		# The ground doesn't shade itself: in the browser renderer its own
		# moon shadow showed as hard straight bands across the lawns.
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(mi)
	var body := PH.static_body(self, "terrain")
	body.name = "TerrainBody"
	var cs := CollisionShape3D.new()
	cs.shape = _terrain_shape
	body.add_child(cs)


func _make_terrain_mesh() -> ArrayMesh:
	var nx := int((TERRAIN_MAX.x - TERRAIN_MIN.x) / TERRAIN_STEP) + 1
	var nz := int((TERRAIN_MAX.y - TERRAIN_MIN.y) / TERRAIN_STEP) + 1
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for iz in nz:
		for ix in nx:
			var p := Vector2(TERRAIN_MIN.x + ix * TERRAIN_STEP, TERRAIN_MIN.y + iz * TERRAIN_STEP)
			# Same function everything else uses to sit on the ground.
			var h := Layout.grid_height(ix, iz)
			var k := Layout.pond_k(p)
			var sd := Layout.stream_distance(p)
			var near_garden := Layout.rim_distance(p) < 4.0
			var pf := Layout.path_factor(p) if near_garden else 0.0
			var bank := maxf(1.0 - smoothstep(0.98, 1.1, k), 1.0 - smoothstep(Layout.STREAM_HALF_WIDTH + 0.3, Layout.STREAM_HALF_WIDTH + 1.4, sd))
			var bed := smoothstep(-0.2, -0.55, h)
			st.set_color(Color(pf, bank, bed))
			st.set_uv(p * 0.25)
			st.add_vertex(Vector3(p.x, h, p.y))
	for iz in nz - 1:
		for ix in nx - 1:
			var i := iz * nx + ix
			st.add_index(i)
			st.add_index(i + 1)
			st.add_index(i + nx)
			st.add_index(i + 1)
			st.add_index(i + nx + 1)
			st.add_index(i + nx)
	st.generate_normals()
	return st.commit()


## Cuts the full terrain into square tiles, sharing the full mesh's normals
## so there are no lighting seams at tile edges.
func _split_terrain(full: ArrayMesh) -> Array[ArrayMesh]:
	var src := full.surface_get_arrays(0)
	var verts: PackedVector3Array = src[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = src[Mesh.ARRAY_NORMAL]
	var colors: PackedColorArray = src[Mesh.ARRAY_COLOR]
	var uvs: PackedVector2Array = src[Mesh.ARRAY_TEX_UV]
	var nx := int((TERRAIN_MAX.x - TERRAIN_MIN.x) / TERRAIN_STEP) + 1
	var nz := int((TERRAIN_MAX.y - TERRAIN_MIN.y) / TERRAIN_STEP) + 1
	var out: Array[ArrayMesh] = []
	var cz := 0
	while cz < nz - 1:
		var cx := 0
		while cx < nx - 1:
			var x1 := mini(cx + TERRAIN_CHUNK, nx - 1)
			var z1 := mini(cz + TERRAIN_CHUNK, nz - 1)
			var w := x1 - cx + 1
			var v := PackedVector3Array()
			var n := PackedVector3Array()
			var c := PackedColorArray()
			var t := PackedVector2Array()
			for iz in range(cz, z1 + 1):
				for ix in range(cx, x1 + 1):
					var i := iz * nx + ix
					v.append(verts[i])
					n.append(normals[i])
					c.append(colors[i])
					t.append(uvs[i])
			var idx := PackedInt32Array()
			for iz in z1 - cz:
				for ix in x1 - cx:
					var i := iz * w + ix
					idx.append_array([i, i + 1, i + w, i + 1, i + w + 1, i + w])
			var arrays := []
			arrays.resize(Mesh.ARRAY_MAX)
			arrays[Mesh.ARRAY_VERTEX] = v
			arrays[Mesh.ARRAY_NORMAL] = n
			arrays[Mesh.ARRAY_COLOR] = c
			arrays[Mesh.ARRAY_TEX_UV] = t
			arrays[Mesh.ARRAY_INDEX] = idx
			var mesh := ArrayMesh.new()
			mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
			out.append(mesh)
			cx += TERRAIN_CHUNK
		cz += TERRAIN_CHUNK
	return out


func _noise_texture(type: FastNoiseLite.NoiseType, freq: float, normal_map: bool, size := 512) -> NoiseTexture2D:
	var n := FastNoiseLite.new()
	n.noise_type = type
	n.frequency = freq
	n.seed = _rng.randi()
	var t := NoiseTexture2D.new()
	t.noise = n
	t.width = size
	t.height = size
	t.seamless = true
	t.as_normal_map = normal_map
	t.bump_strength = 6.0
	t.generate_mipmaps = true
	return t


func _cell_texture() -> NoiseTexture2D:
	var n := FastNoiseLite.new()
	n.noise_type = FastNoiseLite.TYPE_CELLULAR
	n.frequency = 0.03
	n.cellular_distance_function = FastNoiseLite.DISTANCE_EUCLIDEAN
	n.cellular_return_type = FastNoiseLite.RETURN_DISTANCE2_SUB
	n.cellular_jitter = 0.9
	var t := NoiseTexture2D.new()
	t.noise = n
	t.width = 512
	t.height = 512
	t.seamless = true
	t.normalize = true
	t.generate_mipmaps = true
	return t


# --- Water --------------------------------------------------------------------------------

func _water_material(pond: bool) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/water.gdshader")
	m.set_shader_parameter("normal_a", _noise_texture(FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 0.012, true))
	m.set_shader_parameter("normal_b", _noise_texture(FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 0.02, true))
	m.set_shader_parameter("pond_radii", Layout.POND_RADII)
	m.set_shader_parameter("use_pond_depth", 1.0 if pond else 0.0)
	if not pond:
		m.set_shader_parameter("flow", Vector2(-0.05, 0.04))
		m.set_shader_parameter("ripple_strength", 0.22)
	return m


func _build_water() -> void:
	var pond := MeshInstance3D.new()
	pond.name = "Pond"
	var plane := PlaneMesh.new()
	plane.size = Layout.POND_RADII * 2.0 + Vector2(1.5, 1.5)
	plane.subdivide_width = 8
	plane.subdivide_depth = 8
	pond.mesh = plane
	pond.material_override = _water_material(true)
	pond.position = Vector3(0, Layout.WATER_Y, 0)
	pond.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	pond.layers = WaterReflection.LAYER_UNDERWATER
	add_child(pond)

	# Stream: a ribbon following the inlet polyline.
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	var pts: Array = Layout.STREAM
	var half := Layout.STREAM_HALF_WIDTH + 0.7
	for i in pts.size():
		var p: Vector2 = pts[i]
		var dir: Vector2
		if i == 0:
			dir = (pts[1] - pts[0]).normalized()
		elif i == pts.size() - 1:
			dir = (pts[i] - pts[i - 1]).normalized()
		else:
			dir = (pts[i + 1] - pts[i - 1]).normalized()
		var n := Vector2(-dir.y, dir.x) * half
		st.set_normal(Vector3.UP)
		st.add_vertex(Vector3(p.x + n.x, Layout.STREAM_WATER_Y, p.y + n.y))
		st.set_normal(Vector3.UP)
		st.add_vertex(Vector3(p.x - n.x, Layout.STREAM_WATER_Y, p.y - n.y))
	var stream := MeshInstance3D.new()
	stream.name = "Stream"
	stream.mesh = st.commit()
	stream.material_override = _water_material(false)
	stream.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	stream.layers = WaterReflection.LAYER_UNDERWATER
	add_child(stream)
	var reflection := WaterReflection.new()
	reflection.materials = [pond.material_override as ShaderMaterial, stream.material_override as ShaderMaterial]
	add_child(reflection)


# --- Invisible boundaries -----------------------------------------------------------------

func _build_boundaries() -> void:
	var body := PH.static_body(self)
	body.name = "Boundaries"
	var b := Layout.BOUNDS
	var h := 6.0
	# Outer rectangle with an entry lane on the south side.
	PH.box_shape(body, Vector3(1, h, b.size.y + 2), Vector3(b.position.x - 0.5, h * 0.5, b.get_center().y))
	PH.box_shape(body, Vector3(1, h, b.size.y + 2), Vector3(b.end.x + 0.5, h * 0.5, b.get_center().y))
	PH.box_shape(body, Vector3(b.size.x + 2, h, 1), Vector3(b.get_center().x, h * 0.5, b.position.y - 0.5))
	var gap := Layout.ENTRY_GAP_X
	var west_len := gap.x - b.position.x
	var east_len := b.end.x - gap.y
	PH.box_shape(body, Vector3(west_len, h, 1), Vector3(b.position.x + west_len * 0.5, h * 0.5, b.end.y + 0.5))
	PH.box_shape(body, Vector3(east_len, h, 1), Vector3(gap.y + east_len * 0.5, h * 0.5, b.end.y + 0.5))
	var lane := Layout.ENTRY_DEPTH - b.end.y
	PH.box_shape(body, Vector3(1, h, lane), Vector3(gap.x - 0.5, h * 0.5, b.end.y + lane * 0.5))
	PH.box_shape(body, Vector3(1, h, lane), Vector3(gap.y + 0.5, h * 0.5, b.end.y + lane * 0.5))
	PH.box_shape(body, Vector3(gap.y - gap.x + 2, h, 1), Vector3((gap.x + gap.y) * 0.5, h * 0.5, Layout.ENTRY_DEPTH + 0.5))
	_lane_fence()

	# Pond rim, with a gap where the dock reaches over the water.
	var dock := get_node_or_null(dock_path) as Node3D
	var n := 96
	for i in n:
		var a0 := TAU * i / n
		var a1 := TAU * (i + 1) / n
		# At the water's edge, so the sandy shore is walkable right down to it.
		var p0 := Vector2(cos(a0) * Layout.POND_RADII.x, sin(a0) * Layout.POND_RADII.y) * 0.9
		var p1 := Vector2(cos(a1) * Layout.POND_RADII.x, sin(a1) * Layout.POND_RADII.y) * 0.9
		var mid := (p0 + p1) * 0.5
		if dock and _in_dock_footprint(dock, mid, 1.62):
			continue
		_wall_segment(body, p0, p1, 1.4, 0.3)

	# Stream banks, open only where the bridge crosses.
	var bridge := get_node_or_null(bridge_path) as Node3D
	var bridge_xz := Vector2(bridge.global_position.x, bridge.global_position.z) if bridge else Vector2(INF, INF)
	var pts: Array = Layout.STREAM
	for side in [-1.0, 1.0]:
		for i in pts.size() - 1:
			var a: Vector2 = pts[i]
			var c: Vector2 = pts[i + 1]
			var seg_len := a.distance_to(c)
			var steps := maxi(int(seg_len / 0.8), 1)
			var dir := (c - a).normalized()
			var nrm := Vector2(-dir.y, dir.x) * (Layout.STREAM_HALF_WIDTH - 0.1) * float(side)
			for s in steps:
				# The edge pulls in where the stream narrows at the bridge.
				var c0 := a.lerp(c, float(s) / steps)
				var c1 := a.lerp(c, float(s + 1) / steps)
				var q0 := c0 + nrm / Layout.stream_widen(c0)
				var q1 := c1 + nrm / Layout.stream_widen(c1)
				var m := (q0 + q1) * 0.5
				if Layout.pond_k(m) < 1.0 or Layout.outside_distance(m) > 1.0:
					continue
				if m.distance_to(bridge_xz) < 2.8:
					continue
				_wall_segment(body, q0, q1, 1.4, 0.3)


## A weathered split-rail fence across the entry lane where the garden ends,
## so the path visibly carries on into the woods but you know not to follow.
func _lane_fence() -> void:
	var wood := PH.mat(Color("6b4a33"), 0.9)
	var dark := PH.mat(PH.WOOD_DARK, 0.9)
	var z := Layout.ENTRY_DEPTH + 0.2
	var xs: Array[float] = []
	var x := Layout.ENTRY_GAP_X.x - 0.6
	while x <= Layout.ENTRY_GAP_X.y + 0.7:
		xs.append(x)
		x += 1.75
	var rng := RandomNumberGenerator.new()
	rng.seed = 36
	for i in xs.size():
		var p := Vector3(xs[i], 0, z + rng.randf_range(-0.08, 0.08))
		p.y = Layout.mesh_height(Vector2(p.x, p.z))
		PH.box(self, Vector3(0.16, 1.25, 0.16), p + Vector3(0, 0.58, 0), dark, Vector3(rng.randf_range(-3, 3), rng.randf_range(0, 40), rng.randf_range(-3, 3)))
		contact_points.append([Vector2(p.x, p.z), 0.18])
		if i == 0:
			continue
		var a := Vector3(xs[i - 1], 0, z)
		a.y = Layout.mesh_height(Vector2(a.x, a.z))
		for hgt in [0.42, 0.86]:
			var from := a + Vector3(0, hgt + rng.randf_range(-0.04, 0.04), 0)
			var to := p + Vector3(0, hgt + rng.randf_range(-0.04, 0.04), 0)
			PH.limb(self, from, to, 0.055, 0.05, wood, 7)


func _in_dock_footprint(dock: Node3D, p: Vector2, half_width: float) -> bool:
	var local := dock.global_transform.affine_inverse() * Vector3(p.x, 0, p.y)
	return absf(local.x) < half_width and local.z > -Prop.DOCK_HALF_LEN - 0.5 and local.z < Prop.DOCK_HALF_LEN + 0.5


func _wall_segment(body: StaticBody3D, p0: Vector2, p1: Vector2, height: float, thickness: float) -> void:
	var mid := (p0 + p1) * 0.5
	var length := p0.distance_to(p1) + 0.12
	var angle := atan2(p1.y - p0.y, p1.x - p0.x)
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(length, height, thickness)
	cs.shape = box
	cs.position = Vector3(mid.x, Layout.ground_height(mid) + height * 0.5 - 0.2, mid.y)
	cs.rotation = Vector3(0, -angle, 0)
	body.add_child(cs)


# --- Scatter helpers -------------------------------------------------------------------------

func _collect_exclusions() -> void:
	_exclusions = [
		[Vector2(-23.6, 0.0), 4.2],    # tea stall
		[Vector2(-31.0, -6.0), 5.5],   # giant tree trunk and roots
		[Vector2(16.0, -13.0), 3.6],   # grove clearing
		[Vector2(8.2, 5.7), 4.0],      # dock
		[Vector2(0.0, 17.6), 2.6],     # bench
		[Vector2(-14.9, 10.5), 3.6],   # bridge
	]


func _excluded(p: Vector2, margin := 0.0) -> bool:
	for e in _exclusions:
		if p.distance_to(e[0]) < float(e[1]) + margin:
			return true
	return false


## Garden ground suitable for planting: off paths, out of water, not blocking.
func _plantable(p: Vector2, path_clear: float) -> bool:
	if Layout.distance_to_any_path(p) < path_clear:
		return false
	if Layout.pond_k(p) < 1.06 or Layout.stream_distance(p) < Layout.STREAM_HALF_WIDTH + 1.0:
		return false
	return not _excluded(p)


func _multimesh(mesh: Mesh, transforms: Array, colors: Array, material: Material, shadows := true) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = not colors.is_empty()
	mm.mesh = mesh
	mm.instance_count = transforms.size()
	for i in transforms.size():
		mm.set_instance_transform(i, transforms[i])
		if mm.use_colors:
			mm.set_instance_color(i, colors[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	if material:
		mmi.material_override = material
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)
	return mmi


## Like _multimesh, but split into square tiles so each tile picks its own
## mesh LOD by distance (one big MultiMesh would render every copy at full
## detail) and far tiles can be culled.
func _multimesh_tiled(mesh: Mesh, transforms: Array, material: Material, shadows: bool, tile: float) -> Array[MultiMeshInstance3D]:
	var buckets := {}
	for xf in transforms:
		var o: Vector3 = (xf as Transform3D).origin
		var key := Vector2i(floori(o.x / tile), floori(o.z / tile))
		if not buckets.has(key):
			buckets[key] = []
		(buckets[key] as Array).append(xf)
	var out: Array[MultiMeshInstance3D] = []
	for key in buckets:
		out.append(_multimesh(mesh, buckets[key], [], material, shadows))
	return out


## Browser build only: small ground cover fades out past ~30 m.
func _web_reach(mmi: MultiMeshInstance3D) -> void:
	if ModelLib.web_lite():
		mmi.visibility_range_end = 32.0
		mmi.visibility_range_end_margin = 8.0
		mmi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF


func _vc_material(roughness := 0.9, emission := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.roughness = roughness
	if emission > 0.0:
		m.emission_enabled = true
		m.emission_energy_multiplier = emission
	return m


func _xf(p: Vector3, scale: Vector3, yaw := 0.0) -> Transform3D:
	return Transform3D(Basis(Vector3.UP, yaw).scaled(scale), p)


var _solids := {}


## A simple upright collider (tree trunk, rock) so the player can't walk through.
func _solid(base: Vector3, radius: float, height: float, surface: String) -> void:
	if not _solids.has(surface):
		_solids[surface] = PH.static_body(self, surface)
		(_solids[surface] as Node).name = "Solid_" + surface
	var cs := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = radius
	shape.height = height
	cs.shape = shape
	cs.position = base + Vector3(0, height * 0.5 - 0.1, 0)
	(_solids[surface] as Node).add_child(cs)


func _ground(p: Vector2) -> Vector3:
	return Vector3(p.x, Layout.mesh_height(p), p.y)


# --- Forest ring and garden trees -----------------------------------------------------------

func _build_forest() -> void:
	var trunks: Array = []
	var trunk_colors: Array = []
	var crowns: Array = []
	var crown_colors: Array = []
	var placed: Array[Vector2] = []
	var greens := [Color("3f5f3c"), Color("4c6c40"), Color("355239"), Color("58733f"), Color("2f4a3a")]
	var tree_meshes := [ModelLib.mesh("forest_tree_a"), ModelLib.mesh("forest_tree_b")]
	var use_models: bool = tree_meshes[0] != null and tree_meshes[1] != null
	var model_trees := [[], [], [], []]  # a-near, a-far, b-near, b-far
	var attempts := 0
	while placed.size() < (200 if use_models else 260) and attempts < 9000:
		attempts += 1
		var p := Vector2(_rng.randf_range(TERRAIN_MIN.x + 4, TERRAIN_MAX.x - 4), _rng.randf_range(TERRAIN_MIN.y + 4, TERRAIN_MAX.y - 4))
		var out := Layout.outside_distance(p)
		var inside := out <= 0.0
		if inside:
			# Inside the garden, trees only frame the edges.
			var edge := minf(minf(p.x - Layout.BOUNDS.position.x, Layout.BOUNDS.end.x - p.x), minf(p.y - Layout.BOUNDS.position.y, Layout.BOUNDS.end.y - p.y))
			if edge > 6.5 or not _plantable(p, 3.0):
				continue
		elif out > 26.0:
			continue
		if Layout.stream_distance(p) < Layout.STREAM_HALF_WIDTH + 1.4:
			continue
		# Keep the entry lane open where it runs on into the woods.
		if p.y > 20.0 and Layout.polyline_distance(p, Layout.LANE) < Layout.LANE_HALF + 1.2:
			continue
		var min_gap := 3.2 if inside else 2.6
		var ok := true
		for q in placed:
			if p.distance_to(q) < min_gap:
				ok = false
				break
		if not ok:
			continue
		placed.append(p)
		var base := _ground(p)
		var height := _rng.randf_range(4.5, 8.5) + minf(out, 10.0) * 0.25
		if use_models:
			# Real tree models: alternate the two variants; only nearby trees cast shadows.
			var variant := _rng.randi() % 2
			var natural := 9.0 if variant == 0 else 8.0
			var scl := (height / natural) * 1.15
			var xf := _xf(base + Vector3(0, -0.15, 0), Vector3.ONE * scl, _rng.randf() * TAU)
			model_trees[variant * 2 + (0 if out < 9.0 else 1)].append(xf)
			if out < 3.0:
				_solid(base, 0.42 * scl, 4.0, "wood")
			continue
		var trunk_r := _rng.randf_range(0.22, 0.38)
		trunks.append(_xf(base + Vector3(0, height * 0.35, 0), Vector3(trunk_r / 0.3, height * 0.7 / 2.0, trunk_r / 0.3), _rng.randf() * TAU))
		trunk_colors.append(Color("4a3426").lerp(Color("6a4a32"), _rng.randf()))
		var crown_r := _rng.randf_range(1.6, 2.6) + height * 0.08
		for j in 3:
			var off := Vector3(_rng.randf_range(-0.8, 0.8), height * 0.72 + j * crown_r * 0.45, _rng.randf_range(-0.8, 0.8))
			var r := crown_r * (1.0 - j * 0.22)
			crowns.append(_xf(base + off, Vector3(r, r * 0.85, r), _rng.randf() * TAU))
			crown_colors.append(greens[_rng.randi() % greens.size()])
	if use_models:
		for i in 4:
			if not (model_trees[i] as Array).is_empty():
				var h := 9.0 if i < 2 else 8.0
				var mat := ModelLib.wind_material(tree_meshes[i / 2], h, 0.012, 0.004)
				var draw_mesh: Mesh = tree_meshes[i / 2]
				# Browser build: the outer forest ring uses a lighter copy of the
				# same tree (same textures); trees near the paths stay full detail.
				var web_name := ("forest_tree_a" if i < 2 else "forest_tree_b") + "_web"
				if i % 2 == 1 and ModelLib.web_lite() and ModelLib.has(web_name):
					draw_mesh = ModelLib.mesh(web_name)
				for trees in _multimesh_tiled(draw_mesh, model_trees[i], mat, i % 2 == 0, 14.0):
					if i % 2 == 1:
						trees.layers = WaterReflection.LAYER_SMALL  # far trees aren't mirrored
		return
	var trunk_mesh := CylinderMesh.new()
	trunk_mesh.top_radius = 0.18
	trunk_mesh.bottom_radius = 0.3
	trunk_mesh.height = 2.0
	trunk_mesh.radial_segments = 8
	_multimesh(trunk_mesh, trunks, trunk_colors, _vc_material(0.95))
	var crown_mesh := SphereMesh.new()
	crown_mesh.radius = 1.0
	crown_mesh.height = 2.0
	crown_mesh.radial_segments = 14
	crown_mesh.rings = 8
	_multimesh(crown_mesh, crowns, crown_colors, _vc_material(0.95))


# --- Bushes, flowers, ferns -------------------------------------------------------------------

func _build_ground_cover() -> void:
	var bushes: Array = []
	var bush_colors: Array = []
	var flowers: Array = []
	var flower_colors: Array = []
	var ferns: Array = []
	var fern_colors: Array = []
	var bush_greens := [Color("3d5a36"), Color("4f6d3c"), Color("5a7a44"), Color("36503a")]
	var petal_colors := [Color("e7a4b4"), Color("f0c3cf"), Color("f3e4c7"), Color("c8b8f0"), Color("e98fa4")]
	var m_bushes: Array = []
	var m_flowers: Array = []
	var m_ferns: Array = []
	for i in 2600:
		var p := Vector2(_rng.randf_range(Layout.BOUNDS.position.x, Layout.BOUNDS.end.x), _rng.randf_range(Layout.BOUNDS.position.y, Layout.BOUNDS.end.y))
		var path_d := Layout.distance_to_any_path(p)
		if not _plantable(p, 0.5):
			continue
		var g := _ground(p)
		var roll := _rng.randf()
		var yaw := _rng.randf() * TAU
		if path_d > 1.6 and path_d < 5.0 and roll < 0.09 and bushes.size() < 170:
			var r := _rng.randf_range(0.45, 0.95)
			bushes.append(_xf(g + Vector3(0, r * 0.45, 0), Vector3(r * 1.2, r * 0.8, r), yaw))
			bush_colors.append(bush_greens[_rng.randi() % bush_greens.size()])
			m_bushes.append(_xf(g + Vector3(0, -0.05, 0), Vector3.ONE * r * 1.5, yaw))
			cover_points.append(p)
		elif path_d < 2.8 and roll < 0.32 and flowers.size() < 420:
			# Flowers come in small clumps beside the paths.
			var c: Color = petal_colors[_rng.randi() % petal_colors.size()]
			flower_points.append(p)
			for j in _rng.randi_range(3, 6):
				var fp := p + Vector2(_rng.randf_range(-0.35, 0.35), _rng.randf_range(-0.35, 0.35))
				var s := _rng.randf_range(0.05, 0.08)
				flowers.append(_xf(_ground(fp) + Vector3(0, _rng.randf_range(0.12, 0.26), 0), Vector3(s, s * 0.7, s)))
				flower_colors.append(c)
				m_flowers.append(_xf(_ground(fp), Vector3.ONE * _rng.randf_range(0.7, 1.25), _rng.randf() * TAU))
		elif roll > 0.82 and ferns.size() < 240:
			var fs := _rng.randf_range(0.6, 1.1)
			ferns.append(_xf(g, Vector3(fs, fs, fs), yaw))
			fern_colors.append(Color("3f6a3a").lerp(Color("5f8a46"), _rng.randf()))
			m_ferns.append(_xf(g, Vector3.ONE * fs * 1.1, yaw))
	# Real models where available, primitive stand-ins otherwise.
	var shrub := ModelLib.mesh("shrub")
	var flower := ModelLib.mesh("flower")
	var fern := ModelLib.mesh("fern")
	if shrub:
		_multimesh_tiled(shrub, m_bushes, ModelLib.wind_material(shrub, 1.0, 0.03, 0.02), true, 12.0)
		bushes.clear()
	# Flowers and ferns in tiles, so each tile picks its own level of detail
	# by distance (one garden-wide group was drawn at full detail everywhere).
	if flower:
		for mmi in _multimesh_tiled(flower, m_flowers, ModelLib.wind_material(flower, 0.28, 0.07, 0.02), false, 10.0):
			mmi.layers = WaterReflection.LAYER_SMALL
			_web_reach(mmi)
		flowers.clear()
	if fern:
		for mmi in _multimesh_tiled(fern, m_ferns, ModelLib.wind_material(fern, 0.5, 0.05, 0.03), false, 10.0):
			mmi.layers = WaterReflection.LAYER_SMALL
			_web_reach(mmi)
		ferns.clear()
	if bushes.is_empty() and flowers.is_empty() and ferns.is_empty():
		return
	if not bushes.is_empty():
		var bush_mesh := SphereMesh.new()
		bush_mesh.radius = 1.0
		bush_mesh.height = 2.0
		bush_mesh.radial_segments = 12
		bush_mesh.rings = 7
		_multimesh(bush_mesh, bushes, bush_colors, _vc_material(0.95))
	if not flowers.is_empty():
		var flower_mesh := SphereMesh.new()
		flower_mesh.radius = 1.0
		flower_mesh.height = 2.0
		flower_mesh.radial_segments = 8
		flower_mesh.rings = 4
		_multimesh(flower_mesh, flowers, flower_colors, _vc_material(0.7, 0.25), false)
	if not ferns.is_empty():
		_multimesh(_fern_mesh(), ferns, fern_colors, _vc_material(0.9), false)


## A small fern: a fan of flattened leaf blades merged into one mesh.
func _fern_mesh() -> Mesh:
	var st := SurfaceTool.new()
	var blade := SphereMesh.new()
	blade.radius = 0.5
	blade.height = 1.0
	blade.radial_segments = 8
	blade.rings = 4
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 7:
		var a := TAU * i / 7.0
		var b := Basis(Vector3.UP, a) * Basis(Vector3.RIGHT, deg_to_rad(52.0)) * Basis.from_scale(Vector3(0.12, 0.55, 0.035))
		var xf := Transform3D(b, Basis(Vector3.UP, a) * Vector3(0, 0.16, 0.2))
		st.append_from(blade, 0, xf)
	return st.commit()


# --- Shore rocks ---------------------------------------------------------------------------------

func _build_shore() -> void:
	var rocks: Array = []
	var rock_colors: Array = []
	var model_rocks: Array = []
	var dock := get_node_or_null(dock_path) as Node3D
	# Rocks gather in small irregular clusters along the bank, leaving open
	# stretches so the shore doesn't read as a fence.
	var a := 0.0
	while a < TAU:
		a += _rng.randf_range(0.12, 0.42)
		if _rng.randf() < 0.3:
			continue
		for j in _rng.randi_range(1, 3):
			var aj := a + _rng.randf_range(-0.04, 0.04)
			var k := _rng.randf_range(0.95, 1.06)
			var p := Vector2(cos(aj) * Layout.POND_RADII.x, sin(aj) * Layout.POND_RADII.y) * k
			if dock and _in_dock_footprint(dock, p, 2.0):
				continue
			if Layout.stream_distance(p) < Layout.STREAM_HALF_WIDTH + 0.3:
				continue
			var s := _rng.randf_range(0.25, 0.75) * (1.0 if j == 0 else 0.6)
			var g := _ground(p)
			var yaw := _rng.randf() * TAU
			rocks.append(_xf(g + Vector3(0, s * 0.12, 0), Vector3(s * 1.3, s * 0.55, s), yaw))
			rock_colors.append(Color("5d635b").lerp(Color("4f5f48"), _rng.randf()))
			model_rocks.append(_xf(g + Vector3(0, -0.08 * s, 0), Vector3.ONE * s * 1.7, yaw))
			contact_points.append([p, s * 0.8])
			if s > 0.3:
				_solid(g, s * 0.62, s * 0.9, "stone")
	# A few larger mossy rocks in the garden.
	for i in 40:
		var p2 := Vector2(_rng.randf_range(-30, 30), _rng.randf_range(-24, 24))
		if not _plantable(p2, 1.8):
			continue
		var s2 := _rng.randf_range(0.4, 1.1)
		var yaw2 := _rng.randf() * TAU
		rocks.append(_xf(_ground(p2) + Vector3(0, s2 * 0.2, 0), Vector3(s2 * 1.2, s2 * 0.7, s2), yaw2))
		rock_colors.append(Color("697266").lerp(Color("5a704c"), _rng.randf()))
		model_rocks.append(_xf(_ground(p2) + Vector3(0, -0.1 * s2, 0), Vector3.ONE * s2 * 1.5, yaw2))
		contact_points.append([p2, s2 * 0.75])
		_solid(_ground(p2), s2 * 0.6, s2 * 0.9, "stone")
	var rock_model := ModelLib.mesh("rock")
	if rock_model:
		_multimesh(rock_model, model_rocks, [], null)
		return
	var rock_mesh := SphereMesh.new()
	rock_mesh.radius = 1.0
	rock_mesh.height = 2.0
	rock_mesh.radial_segments = 7
	rock_mesh.rings = 4
	_multimesh(rock_mesh, rocks, rock_colors, _vc_material(0.9))


func _build_lilies() -> void:
	var pads: Array = []
	var pad_colors: Array = []
	var blooms: Array = []
	var model_pads: Array = []
	var dock := get_node_or_null(dock_path) as Node3D
	var fishing := get_node_or_null("../Fishing") as FishingController
	var anchor := Vector2(fishing.cast_anchor.x, fishing.cast_anchor.z) if fishing else Vector2.ZERO
	var count := 0
	var tries := 0
	while count < 26 and tries < 400:
		tries += 1
		var a := _rng.randf() * TAU
		var k := _rng.randf_range(0.55, 0.9)
		var p := Vector2(cos(a) * Layout.POND_RADII.x, sin(a) * Layout.POND_RADII.y) * k
		if p.distance_to(anchor) < 3.5 or (dock and _in_dock_footprint(dock, p, 3.0)):
			continue
		count += 1
		var s := _rng.randf_range(0.28, 0.45)
		var yaw := _rng.randf() * TAU
		pads.append(_xf(Vector3(p.x, Layout.WATER_Y + 0.012, p.y), Vector3(s, 1.0, s), yaw))
		pad_colors.append(Color("4f7a46").lerp(Color("6e9550"), _rng.randf()))
		model_pads.append(_xf(Vector3(p.x, Layout.WATER_Y - 0.01, p.y), Vector3.ONE * s * 2.2, yaw))
		if _rng.randf() < 0.35:
			blooms.append(_xf(Vector3(p.x + 0.08, Layout.WATER_Y + 0.07, p.y), Vector3(0.09, 0.06, 0.09)))
	var pad_model := ModelLib.mesh("lily_pad")
	if pad_model:
		_multimesh(pad_model, model_pads, [], null, false)
		return
	var pad_mesh := CylinderMesh.new()
	pad_mesh.top_radius = 1.0
	pad_mesh.bottom_radius = 1.0
	pad_mesh.height = 0.01
	pad_mesh.radial_segments = 14
	_multimesh(pad_mesh, pads, pad_colors, _vc_material(0.6), false)
	var bloom_mesh := SphereMesh.new()
	bloom_mesh.radius = 1.0
	bloom_mesh.height = 2.0
	bloom_mesh.radial_segments = 8
	bloom_mesh.rings = 4
	var bloom_mat := PH.mat(Color("f6ecd8"), 0.6, Color("f6e3c0"), 0.5)
	_multimesh(bloom_mesh, blooms, [], bloom_mat, false)


# --- Lanterns along the path ----------------------------------------------------------------

func _build_path_lanterns() -> void:
	var spots: Array[Vector3] = []
	for deg in [200.0, 245.0, 290.0, 330.0, 15.0, 60.0, 100.0, 160.0]:
		var a := deg_to_rad(deg)
		var on_loop := Layout.loop_point(a)
		var outward := (on_loop - Layout.LOOP_CENTER).normalized()
		var p := on_loop + outward * (Layout.PATH_HALF_WIDTH + 0.7)
		if _excluded(p, -1.0):
			continue
		spots.append(_ground(p))
	spots.append(_ground(Vector2(-7.0, 24.0)))
	spots.append(_ground(Vector2(-11.6, 30.0)))
	var wood := PH.mat(PH.WOOD_DARK, 0.85)
	var stone := PH.mat(PH.STONE, 0.95)
	for s in spots:
		# Arm runs along the path (tangent) so lanterns never hang over the walkway.
		var to_center := Layout.LOOP_CENTER - Vector2(s.x, s.z)
		var tangent := Vector2(-to_center.y, to_center.x).normalized()
		contact_points.append([Vector2(s.x, s.z), 0.28])
		if Prop.post_with_lantern(self, s, rad_to_deg(atan2(-tangent.y, tangent.x))):
			continue
		var post := Node3D.new()
		post.position = s
		add_child(post)
		PH.cyl(post, 0.18, 0.24, 0.2, Vector3(0, 0.1, 0), stone, Vector3.ZERO, 8)
		PH.cyl(post, 0.06, 0.07, 1.9, Vector3(0, 1.1, 0), wood, Vector3.ZERO, 8)
		PH.box(post, Vector3(0.3, 0.05, 0.3), Vector3(0, 2.05, 0), wood)
		PH.box(post, Vector3(0.22, 0.3, 0.22), Vector3(0, 2.23, 0), PH.paper(2.2))
		PH.cyl(post, 0.0, 0.2, 0.14, Vector3(0, 2.45, 0), wood, Vector3.ZERO, 4)
		PH.omni(post, Vector3(0, 2.2, 0), Color("ffb666"), 1.3, 7.5)
		var body := PH.static_body(post, "wood")
		PH.cylinder_shape(body, 0.12, 2.4, Vector3(0, 1.2, 0))


# --- Grove dressing --------------------------------------------------------------------------

func _build_grove_dressing() -> void:
	var center := Vector2(16.0, -13.0)
	var glow := PH.mat(Color("8c80d8"), 0.7, Color("9d8fe8"), 0.5)
	for i in 14:
		var a := _rng.randf() * TAU
		var r := _rng.randf_range(4.2, 7.0)
		var p := center + Vector2(cos(a), sin(a)) * r
		if Layout.distance_to_any_path(p) < 0.6 or Layout.pond_k(p) < 1.08:
			continue
		var s := _rng.randf_range(0.5, 0.8)
		if ModelLib.place("moonleaf", self, _ground(p), Vector3(0, _rng.randf() * 360.0, 0), s):
			continue
		var plant := Node3D.new()
		plant.position = _ground(p)
		plant.rotation.y = _rng.randf() * TAU
		plant.scale = Vector3.ONE * s
		add_child(plant)
		for j in 5:
			var b := Node3D.new()
			b.rotation.y = TAU * j / 5.0
			plant.add_child(b)
			var leaf := PH.sphere(b, 0.1, Vector3(0, 0.3, 0.1), glow, Vector3(0.5, 1.6, 0.2), 10)
			leaf.rotation_degrees = Vector3(28, 0, 0)
	PH.omni(self, Vector3(center.x, 1.6, center.y), Color("b0a2ff"), 0.9, 8.0)


# --- Fireflies ------------------------------------------------------------------------------

func _build_fireflies() -> void:
	var p := GPUParticles3D.new()
	p.name = "Fireflies"
	p.amount = 70
	p.lifetime = 9.0
	p.preprocess = 9.0
	p.position = Vector3(0, 1.3, 0)
	p.visibility_aabb = AABB(Vector3(-34, -2, -28), Vector3(68, 8, 56))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(30, 0.9, 25)
	pm.direction = Vector3(0, 1, 0)
	pm.spread = 180.0
	pm.initial_velocity_min = 0.05
	pm.initial_velocity_max = 0.2
	pm.gravity = Vector3.ZERO
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = 0.6
	pm.turbulence_noise_scale = 3.0
	pm.turbulence_influence_min = 0.05
	pm.turbulence_influence_max = 0.12
	# Real fireflies flash: short pulses with long dark gaps.
	var grad := Gradient.new()
	grad.set_color(0, Color(1, 1, 1, 0))
	grad.set_color(1, Color(1, 1, 1, 0))
	for flash in [0.12, 0.38, 0.47, 0.7, 0.9]:
		grad.add_point(flash - 0.03, Color(1, 1, 1, 0.0))
		grad.add_point(flash, Color(1, 1, 1, 1.0))
		grad.add_point(flash + 0.04, Color(1, 1, 1, 0.0))
	var gt := GradientTexture1D.new()
	gt.gradient = grad
	pm.color_ramp = gt
	p.process_material = pm
	var quad := QuadMesh.new()
	quad.size = Vector2(0.07, 0.07)
	var m := StandardMaterial3D.new()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.vertex_color_use_as_albedo = true
	m.albedo_color = Color(2.5, 2.15, 1.1, 1.0)
	m.albedo_texture = Fx.soft_dot()
	quad.material = m
	p.draw_pass_1 = quad
	p.layers = WaterReflection.LAYER_SMALL
	add_child(p)


# --- Ambience ---------------------------------------------------------------------------------

func _build_audio() -> void:
	Sfx.play_ambience("loop_night")
	for spot in [Vector3(-9, 0.2, 3), Vector3(9, 0.2, -4), Vector3(4, 0.2, 8.5), Vector3(-2, 0.2, -9)]:
		var n := Node3D.new()
		n.position = spot
		add_child(n)
		Sfx.attach_loop("loop_water", n, -6.0, 4.0)
	var stream_spot := Node3D.new()
	stream_spot.position = Vector3(-16.5, 0.0, 11.8)
	add_child(stream_spot)
	Sfx.attach_loop("loop_stream", stream_spot, -4.0, 3.5)
