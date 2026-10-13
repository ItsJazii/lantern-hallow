class_name ModelLib
## Looks up processed models in res://assets/models/<name>.glb. Everything
## returns null when a model isn't there yet, so callers fall back to their
## placeholder and the game stays runnable while assets are being replaced.

const DIR := "res://assets/models/"

static var _scenes := {}
static var _meshes := {}


## True in the browser build (or natively with `-- --weblite`, to preview it):
## weak laptop GPUs there get lighter trees and grass and shorter grass reach.
static func web_lite() -> bool:
	return OS.has_feature("web") or OS.get_cmdline_user_args().has("--weblite")


static func has(model_name: String) -> bool:
	return ResourceLoader.exists(DIR + model_name + ".glb")


static func scene(model_name: String) -> PackedScene:
	if _scenes.has(model_name):
		return _scenes[model_name]
	var s: PackedScene = null
	if has(model_name):
		s = load(DIR + model_name + ".glb") as PackedScene
	_scenes[model_name] = s
	return s


## The first mesh of a model, with its imported materials, for MultiMesh use.
static func mesh(model_name: String) -> Mesh:
	if _meshes.has(model_name):
		return _meshes[model_name]
	var m: Mesh = null
	var s := scene(model_name)
	if s:
		var inst := s.instantiate()
		var mi := _first_mesh_instance(inst)
		if mi:
			m = mi.mesh
		inst.free()
	_meshes[model_name] = m
	return m


## Instances a model under `parent`; returns null if the model is missing.
static func place(model_name: String, parent: Node3D, pos := Vector3.ZERO, rot_deg := Vector3.ZERO, scl := 1.0) -> Node3D:
	var s := scene(model_name)
	if s == null:
		return null
	var n := s.instantiate() as Node3D
	n.position = pos
	n.rotation_degrees = rot_deg
	n.scale = Vector3.ONE * scl
	parent.add_child(n)
	return n


## Makes a model's surfaces emit their own texture (lantern paper, glowing
## leaves). Returns the new materials so callers can animate their energy.
static func glow(root: Node, energy: float, tint := Color(1.0, 0.78, 0.5)) -> Array[StandardMaterial3D]:
	var out: Array[StandardMaterial3D] = []
	for mi in mesh_instances(root):
		for s in mi.mesh.get_surface_count():
			var src := mi.get_active_material(s) as StandardMaterial3D
			if src == null:
				continue
			var m := src.duplicate() as StandardMaterial3D
			m.emission_enabled = true
			m.emission = tint
			m.emission_texture = src.albedo_texture
			m.emission_energy_multiplier = energy
			mi.set_surface_override_material(s, m)
			out.append(m)
	return out


static var _wind_shader: Shader


## A wind-swaying copy of a mesh's first material. `height` is the mesh's own
## height in its local units (sway grows from the base to the top).
static func wind_material(m: Mesh, height: float, sway: float, flutter := 0.02) -> ShaderMaterial:
	if m == null:
		return null
	if _wind_shader == null:
		_wind_shader = load("res://shaders/foliage_wind.gdshader")
	var src := m.surface_get_material(0) as StandardMaterial3D
	var sm := ShaderMaterial.new()
	sm.shader = _wind_shader
	if src:
		sm.set_shader_parameter("albedo_color", src.albedo_color)
		sm.set_shader_parameter("has_albedo", src.albedo_texture != null)
		sm.set_shader_parameter("albedo_tex", src.albedo_texture)
		sm.set_shader_parameter("has_normal", src.normal_enabled and src.normal_texture != null)
		sm.set_shader_parameter("normal_tex", src.normal_texture)
		sm.set_shader_parameter("roughness", src.roughness)
	sm.set_shader_parameter("height", height)
	sm.set_shader_parameter("sway", sway)
	sm.set_shader_parameter("flutter", flutter)
	return sm


## Applies a wind material to every mesh under a placed model.
static func make_windy(root: Node, height: float, sway: float, flutter := 0.02) -> void:
	for mi in mesh_instances(root):
		mi.material_override = wind_material(mi.mesh, height, sway, flutter)


static func set_layers(root: Node, mask: int) -> void:
	if root is VisualInstance3D:
		(root as VisualInstance3D).layers = mask
	for c in root.get_children():
		set_layers(c, mask)


static func mesh_instances(root: Node) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	if root is MeshInstance3D:
		out.append(root)
	for c in root.get_children():
		out.append_array(mesh_instances(c))
	return out


static func _first_mesh_instance(root: Node) -> MeshInstance3D:
	if root is MeshInstance3D:
		return root
	for c in root.get_children():
		var found := _first_mesh_instance(c)
		if found:
			return found
	return null
