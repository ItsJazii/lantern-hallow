class_name PH
## Placeholder geometry helpers: primitive meshes with shared materials.
## Used until a Tripo/Blender model is assigned to a wrapper's `model` slot.

const WOOD := Color("8a5a3a")
const WOOD_DARK := Color("5e3d2a")
const BARK := Color("6e4a33")
const BRASS := Color("c8994a")
const STONE := Color("7b8079")
const MOSS := Color("66805a")
const CREAM := Color("f3e4c7")
const PAPER := Color("f6dcae")
const AMBER := Color("f2b65d")
const NAVY := Color("17283f")
const LAVENDER := Color("a7a1df")
const CORAL := Color("db8f94")
const TEAL := Color("236e78")

static var _mats := {}


static func mat(color: Color, roughness := 0.85, emission := Color.BLACK, energy := 0.0, metallic := 0.0) -> StandardMaterial3D:
	var key := "%s|%.2f|%s|%.2f|%.2f" % [color.to_html(), roughness, emission.to_html(), energy, metallic]
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = roughness
	m.metallic = metallic
	if energy > 0.0:
		m.emission_enabled = true
		m.emission = emission
		m.emission_energy_multiplier = energy
	_mats[key] = m
	return m


## Warm glowing paper, kept below white clipping.
static func paper(energy := 2.2) -> StandardMaterial3D:
	return mat(PAPER, 0.9, Color("ffb35c"), energy)


static func add(parent: Node3D, mesh: Mesh, m: Material, pos := Vector3.ZERO, rot_deg := Vector3.ZERO, scl := Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = m
	mi.position = pos
	mi.rotation_degrees = rot_deg
	mi.scale = scl
	parent.add_child(mi)
	return mi


static func box(parent: Node3D, size: Vector3, pos: Vector3, m: Material, rot_deg := Vector3.ZERO) -> MeshInstance3D:
	var b := BoxMesh.new()
	b.size = size
	return add(parent, b, m, pos, rot_deg)


static func sphere(parent: Node3D, r: float, pos: Vector3, m: Material, scl := Vector3.ONE, segments := 24) -> MeshInstance3D:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	s.radial_segments = segments
	s.rings = maxi(segments / 2, 4)
	return add(parent, s, m, pos, Vector3.ZERO, scl)


static func cyl(parent: Node3D, r_top: float, r_bottom: float, h: float, pos: Vector3, m: Material, rot_deg := Vector3.ZERO, segments := 16) -> MeshInstance3D:
	var c := CylinderMesh.new()
	c.top_radius = r_top
	c.bottom_radius = r_bottom
	c.height = h
	c.radial_segments = segments
	c.rings = 1
	return add(parent, c, m, pos, rot_deg)


static func torus(parent: Node3D, inner: float, outer: float, pos: Vector3, m: Material, rot_deg := Vector3.ZERO) -> MeshInstance3D:
	var t := TorusMesh.new()
	t.inner_radius = inner
	t.outer_radius = outer
	t.rings = 24
	t.ring_segments = 10
	return add(parent, t, m, pos, rot_deg)


## A tapered cylinder spanning two points (branches, limbs, rails).
static func limb(parent: Node3D, from: Vector3, to: Vector3, r_from: float, r_to: float, m: Material, segments := 12) -> MeshInstance3D:
	var c := CylinderMesh.new()
	c.top_radius = r_to
	c.bottom_radius = r_from
	c.height = from.distance_to(to)
	c.radial_segments = segments
	c.rings = 1
	var mi := MeshInstance3D.new()
	mi.mesh = c
	mi.material_override = m
	var y := (to - from).normalized()
	var helper := Vector3.FORWARD if absf(y.dot(Vector3.FORWARD)) < 0.95 else Vector3.RIGHT
	var x := helper.cross(y).normalized()
	var z := x.cross(y).normalized()
	mi.transform = Transform3D(Basis(x, y, z), (from + to) * 0.5)
	parent.add_child(mi)
	return mi


## Static collision helpers (layer 1 = world).
static func static_body(parent: Node3D, surface := "") -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	if surface != "":
		body.set_meta("surface", surface)
	parent.add_child(body)
	return body


static func box_shape(body: Node3D, size: Vector3, pos: Vector3, rot_deg := Vector3.ZERO) -> CollisionShape3D:
	var cs := CollisionShape3D.new()
	var s := BoxShape3D.new()
	s.size = size
	cs.shape = s
	cs.position = pos
	cs.rotation_degrees = rot_deg
	body.add_child(cs)
	return cs


static func cylinder_shape(body: Node3D, r: float, h: float, pos: Vector3) -> CollisionShape3D:
	var cs := CollisionShape3D.new()
	var s := CylinderShape3D.new()
	s.radius = r
	s.height = h
	cs.shape = s
	cs.position = pos
	body.add_child(cs)
	return cs


static func omni(parent: Node3D, pos: Vector3, color: Color, energy: float, light_range: float, shadow := false) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.position = pos
	l.light_color = color
	l.light_energy = energy
	l.omni_range = light_range
	l.omni_attenuation = 1.4
	l.shadow_enabled = shadow
	l.add_to_group("garden_light")
	parent.add_child(l)
	return l


## A hanging paper lantern (pivot at the top of its string).
static func hanging_lantern(parent: Node3D, pos: Vector3, string_len := 0.4, energy := 2.2) -> Node3D:
	var root := Node3D.new()
	root.position = pos
	parent.add_child(root)
	cyl(root, 0.006, 0.006, string_len, Vector3(0, -string_len * 0.5, 0), mat(WOOD_DARK))
	var y := -string_len - 0.24
	cyl(root, 0.08, 0.1, 0.05, Vector3(0, y + 0.24, 0), mat(WOOD_DARK))
	sphere(root, 0.19, Vector3(0, y, 0), paper(energy), Vector3(1, 1.15, 1), 16)
	cyl(root, 0.1, 0.08, 0.05, Vector3(0, y - 0.23, 0), mat(WOOD_DARK))
	cyl(root, 0.015, 0.015, 0.12, Vector3(0, y - 0.31, 0), mat(CORAL))
	return root
