class_name Fx
## Small reusable engine-built effects: soft particle dot, water ripples,
## splash droplets.

static var _dot: GradientTexture2D
static var _ripple_mesh: TorusMesh


static func soft_dot() -> GradientTexture2D:
	if _dot:
		return _dot
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	g.add_point(0.35, Color(1, 1, 1, 0.6))
	_dot = GradientTexture2D.new()
	_dot.gradient = g
	_dot.fill = GradientTexture2D.FILL_RADIAL
	_dot.fill_from = Vector2(0.5, 0.5)
	_dot.fill_to = Vector2(1.0, 0.5)
	_dot.width = 64
	_dot.height = 64
	return _dot


## An expanding, fading ring on the water surface.
static func ripple(parent: Node, pos: Vector3, size := 0.6, duration := 1.4, strength := 0.55) -> void:
	if _ripple_mesh == null:
		_ripple_mesh = TorusMesh.new()
		_ripple_mesh.inner_radius = 0.92
		_ripple_mesh.outer_radius = 1.0
		_ripple_mesh.rings = 32
		_ripple_mesh.ring_segments = 4
	var m := StandardMaterial3D.new()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(0.85, 0.95, 1.0, strength)
	m.no_depth_test = false
	var mi := MeshInstance3D.new()
	mi.mesh = _ripple_mesh
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	mi.global_position = pos + Vector3.UP * 0.015
	mi.scale = Vector3(0.08, 0.02, 0.08)
	var t := mi.create_tween().set_parallel(true).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	t.tween_property(mi, "scale", Vector3(size, 0.02, size), duration)
	t.tween_property(m, "albedo_color:a", 0.0, duration)
	t.chain().tween_callback(mi.queue_free)


## A one-shot burst of droplets.
static func splash(parent: Node, pos: Vector3, amount := 18, speed := 1.6) -> void:
	var p := GPUParticles3D.new()
	p.amount = amount
	p.lifetime = 0.9
	p.one_shot = true
	p.explosiveness = 0.95
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3.UP
	pm.spread = 35.0
	pm.initial_velocity_min = speed * 0.6
	pm.initial_velocity_max = speed
	pm.gravity = Vector3(0, -6.5, 0)
	pm.scale_min = 0.5
	pm.scale_max = 1.0
	p.process_material = pm
	var quad := QuadMesh.new()
	quad.size = Vector2(0.05, 0.05)
	var m := StandardMaterial3D.new()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.albedo_color = Color(0.85, 0.95, 1.0, 0.8)
	m.albedo_texture = soft_dot()
	quad.material = m
	p.draw_pass_1 = quad
	parent.add_child(p)
	p.global_position = pos
	p.emitting = true
	p.finished.connect(p.queue_free)
