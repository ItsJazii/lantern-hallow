class_name WaterReflection
extends Node
## Planar reflection for the pond and stream: a half-resolution camera mirrored
## below the water plane renders the garden; the water shader samples it with
## ripple distortion. Water, fish and tiny ground clutter live on render layers
## the mirror camera skips.

const LAYER_DEFAULT := 1
const LAYER_SMALL := 2      # flowers, ferns, fireflies: not worth reflecting
const LAYER_UNDERWATER := 4 # fish, the water surfaces themselves
const SCALE := 0.4

var _frame := 0

var materials: Array[ShaderMaterial] = []
var _viewport: SubViewport
var _camera: Camera3D


func _ready() -> void:
	_viewport = SubViewport.new()
	_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	_viewport.msaa_3d = Viewport.MSAA_DISABLED
	# No lantern shadow maps in the mirror; nobody can tell in a rippling reflection.
	_viewport.positional_shadow_atlas_size = 0
	add_child(_viewport)
	_camera = Camera3D.new()
	_camera.cull_mask = LAYER_DEFAULT
	var env := Environment.new()
	var main_env := (get_parent() as Node).get("environment") as Environment
	if main_env:
		env.background_mode = main_env.background_mode
		env.sky = main_env.sky
		env.ambient_light_source = main_env.ambient_light_source
		env.ambient_light_color = main_env.ambient_light_color
		env.ambient_light_energy = main_env.ambient_light_energy
		env.tonemap_mode = main_env.tonemap_mode
		env.tonemap_exposure = main_env.tonemap_exposure
		env.fog_enabled = true
		env.fog_light_color = main_env.fog_light_color
		env.fog_density = main_env.fog_density * 1.5
		env.glow_enabled = true
		env.glow_intensity = 0.5
		if RenderingServer.get_current_rendering_method() == "gl_compatibility":
			# The browser renderer can't draw the sky through the mirrored
			# camera (it comes out white); a night-blue backdrop reads the same
			# in a rippling reflection.
			env.background_mode = Environment.BG_COLOR
			env.background_color = Color(0.03, 0.06, 0.14)
	_camera.environment = env
	_viewport.add_child(_camera)
	_resize()
	get_viewport().size_changed.connect(_resize)
	for m in materials:
		m.set_shader_parameter("reflection_tex", _viewport.get_texture())


func _resize() -> void:
	var s := get_viewport().get_visible_rect().size * SCALE
	_viewport.size = Vector2i(maxi(int(s.x), 64), maxi(int(s.y), 64))


func _process(_delta: float) -> void:
	var main := get_viewport().get_camera_3d()
	if main == null or main == _camera:
		return
	# Calm water: refreshing the mirror every other frame is indistinguishable.
	_frame += 1
	if _frame % 2 == 0:
		return
	_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	var h := Layout.WATER_Y
	var t := main.global_transform
	var b := t.basis
	# Mirror across y = h. The mirrored basis is left-handed, so negate X to keep
	# it a valid camera; the shader flips U back when sampling.
	var mirror := Basis(Vector3(1, 0, 0), Vector3(0, -1, 0), Vector3(0, 0, 1))
	var mb := mirror * b
	var basis := Basis(-mb.x, mb.y, mb.z)
	var origin := Vector3(t.origin.x, 2.0 * h - t.origin.y, t.origin.z)
	_camera.global_transform = Transform3D(basis, origin)
	_camera.fov = main.fov
	_camera.near = 0.05
	_camera.far = main.far
