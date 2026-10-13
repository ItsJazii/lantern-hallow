class_name AmbientLife
extends Node3D
## Small moving life that makes the garden feel inhabited: wandering light
## wisps, moths around lanterns, mist and motes over the pond, leaves drifting
## from the giant tree, and the occasional frog croak or owl hoot.

const WISP_COLORS := [Color("9fe6ff"), Color("c9b2ff"), Color("ffd08a")]

var _wisps: Array[Dictionary] = []
var _rng := RandomNumberGenerator.new()
var _t := 0.0
var _next_frog := 4.0
var _next_owl := 18.0


func _ready() -> void:
	_rng.seed = 5150
	for i in WISP_COLORS.size():
		_wisps.append(_make_wisp(WISP_COLORS[i], i))
	_moths.call_deferred()
	_pond_mist()
	_pond_motes()
	_falling_leaves()


# --- Wisps -----------------------------------------------------------------------

func _make_wisp(color: Color, i: int) -> Dictionary:
	var root := Node3D.new()
	add_child(root)
	PH.sphere(root, 0.045, Vector3.ZERO, PH.mat(color, 0.3, color, 6.0), Vector3.ONE, 10)
	var halo := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(0.55, 0.55)
	var hm := StandardMaterial3D.new()
	hm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	hm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	hm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	hm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	hm.albedo_texture = Fx.soft_dot()
	hm.albedo_color = Color(color.r, color.g, color.b, 0.55)
	q.material = hm
	halo.mesh = q
	halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(halo)
	var light := PH.omni(root, Vector3.ZERO, color, 0.7, 3.2)
	light.remove_from_group("garden_light")
	root.add_child(_trail(color))
	return {"node": root, "angle": TAU * i / 3.0, "speed": _rng.randf_range(0.035, 0.06) * (1 if i % 2 == 0 else -1),
		"offset": _rng.randf_range(1.6, 3.2), "phase": _rng.randf() * TAU, "height": _rng.randf_range(1.1, 1.8)}


func _trail(color: Color) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = 16
	p.lifetime = 1.4
	p.local_coords = false
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3.UP
	pm.spread = 180.0
	pm.initial_velocity_min = 0.02
	pm.initial_velocity_max = 0.08
	pm.gravity = Vector3(0, 0.05, 0)
	pm.color_ramp = _fade_ramp()
	pm.scale_min = 0.4
	pm.scale_max = 1.0
	p.process_material = pm
	p.draw_pass_1 = _glow_quad(0.05, color, 3.0)
	p.layers = WaterReflection.LAYER_SMALL
	return p


func _process(delta: float) -> void:
	_t += delta
	for w in _wisps:
		w["angle"] = float(w["angle"]) + float(w["speed"]) * delta
		var a: float = w["angle"]
		var on_loop := Layout.loop_point(a)
		var outward := (on_loop - Layout.LOOP_CENTER).normalized()
		var wobble := sin(_t * 0.4 + float(w["phase"])) * 1.2
		var p2 := on_loop + outward * (float(w["offset"]) + wobble)
		var node: Node3D = w["node"]
		var y := Layout.ground_height(p2) + float(w["height"]) + sin(_t * 1.3 + float(w["phase"])) * 0.25
		node.position = Vector3(p2.x, y, p2.y)
	# Frog and owl calls now come from the animals themselves (scripts/creatures).


# --- Moths around lanterns -----------------------------------------------------------

func _moths() -> void:
	var lanterns := get_tree().get_nodes_in_group("sway")
	lanterns.shuffle()
	for i in mini(8, lanterns.size()):
		var l := lanterns[i] as Node3D
		var p := GPUParticles3D.new()
		p.amount = 5
		p.lifetime = 4.0
		p.preprocess = 4.0
		var pm := ParticleProcessMaterial.new()
		pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
		pm.emission_sphere_radius = 0.35
		pm.direction = Vector3.UP
		pm.spread = 180.0
		pm.initial_velocity_min = 0.1
		pm.initial_velocity_max = 0.3
		pm.gravity = Vector3.ZERO
		pm.turbulence_enabled = true
		pm.turbulence_noise_strength = 2.5
		pm.turbulence_noise_scale = 0.6
		pm.turbulence_influence_min = 0.3
		pm.turbulence_influence_max = 0.6
		pm.color_ramp = _fade_ramp()
		p.process_material = pm
		p.draw_pass_1 = _glow_quad(0.035, Color("fff0d6"), 1.4)
		p.layers = WaterReflection.LAYER_SMALL
		add_child(p)
		p.global_position = l.global_position + Vector3(0, -0.25, 0)


# --- Pond mist, motes and falling leaves ----------------------------------------------

func _pond_mist() -> void:
	var p := GPUParticles3D.new()
	p.amount = 14
	p.lifetime = 18.0
	p.preprocess = 18.0
	p.position = Vector3(0, Layout.WATER_Y + 0.35, 0)
	p.visibility_aabb = AABB(Vector3(-15, -1, -12), Vector3(30, 3, 24))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(10, 0.1, 7.5)
	pm.direction = Vector3(1, 0, 0.3)
	pm.spread = 30.0
	pm.initial_velocity_min = 0.05
	pm.initial_velocity_max = 0.15
	pm.gravity = Vector3.ZERO
	pm.scale_min = 0.8
	pm.scale_max = 1.6
	pm.color_ramp = _fade_ramp()
	p.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(3.2, 1.6)
	var m := StandardMaterial3D.new()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = Fx.soft_dot()
	m.albedo_color = Color(0.62, 0.74, 0.9, 0.09)
	m.proximity_fade_enabled = true
	m.proximity_fade_distance = 1.0
	q.material = m
	p.draw_pass_1 = q
	p.layers = WaterReflection.LAYER_SMALL
	add_child(p)


func _pond_motes() -> void:
	var p := GPUParticles3D.new()
	p.amount = 45
	p.lifetime = 7.0
	p.preprocess = 7.0
	p.position = Vector3(0, Layout.WATER_Y + 0.05, 0)
	p.visibility_aabb = AABB(Vector3(-14, -1, -11), Vector3(28, 5, 22))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(10, 0.05, 7.5)
	pm.direction = Vector3.UP
	pm.spread = 15.0
	pm.initial_velocity_min = 0.08
	pm.initial_velocity_max = 0.2
	pm.gravity = Vector3.ZERO
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = 0.4
	pm.color_ramp = _fade_ramp()
	p.process_material = pm
	p.draw_pass_1 = _glow_quad(0.04, Color("8ff2e6"), 2.2)
	p.layers = WaterReflection.LAYER_SMALL
	add_child(p)


func _falling_leaves() -> void:
	var p := GPUParticles3D.new()
	p.amount = 22
	p.lifetime = 11.0
	p.preprocess = 11.0
	p.position = Vector3(-28.0, 9.0, -4.0)
	p.visibility_aabb = AABB(Vector3(-10, -10, -10), Vector3(20, 12, 20))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(6, 1.5, 5)
	pm.direction = Vector3(1, -0.2, 0.4)
	pm.spread = 40.0
	pm.initial_velocity_min = 0.1
	pm.initial_velocity_max = 0.3
	pm.gravity = Vector3(0, -0.45, 0)
	pm.angular_velocity_min = -90.0
	pm.angular_velocity_max = 90.0
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = 1.2
	pm.turbulence_noise_scale = 2.0
	pm.color_ramp = _fade_ramp()
	p.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(0.09, 0.06)
	var m := StandardMaterial3D.new()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.vertex_color_use_as_albedo = true
	m.albedo_color = Color("d9b04c")
	m.emission_enabled = true
	m.emission = Color("c99a3c")
	m.emission_energy_multiplier = 0.4
	q.material = m
	p.draw_pass_1 = q
	p.layers = WaterReflection.LAYER_SMALL
	add_child(p)


# --- Helpers ----------------------------------------------------------------------------

func _fade_ramp() -> GradientTexture1D:
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 0))
	g.set_color(1, Color(1, 1, 1, 0))
	g.add_point(0.2, Color(1, 1, 1, 1))
	g.add_point(0.75, Color(1, 1, 1, 1))
	var gt := GradientTexture1D.new()
	gt.gradient = g
	return gt


func _glow_quad(size: float, color: Color, energy: float) -> QuadMesh:
	var q := QuadMesh.new()
	q.size = Vector2(size, size)
	var m := StandardMaterial3D.new()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = Fx.soft_dot()
	m.albedo_color = Color(color.r * energy, color.g * energy, color.b * energy, 1.0)
	q.material = m
	return q
