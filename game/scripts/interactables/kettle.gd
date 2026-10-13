extends Interactable
## Brass kettle on the counter. After the leaves are returned, a short brewing
## beat (steam + pour) sets tea_brewed.

var _steam: GPUParticles3D
var _brewing := false
var _simmer: AudioStreamPlayer3D


func _ready() -> void:
	interact_size = Vector3(0.5, 0.5, 0.5)
	interact_offset = Vector3(0, 0.18, 0)
	super._ready()


func get_prompt() -> String:
	if _brewing:
		return ""
	if GameState.has("leaves_returned") and not GameState.has("tea_brewed"):
		return "Brew moonleaf tea"
	return "Kettle"


func interact(player: Player) -> void:
	if _brewing:
		return
	if not GameState.has("leaves_returned"):
		UI.toast("The kettle is cold. The keeper needs moonleaves first.")
		return
	if GameState.has("tea_brewed"):
		if GameState.has("tea_served"):
			UI.toast("The kettle simmers quietly.")
		else:
			UI.toast("The tea is ready. Bring a cup to the fox.")
		return
	_brewing = true
	player.lock("brewing")
	Sfx.play_at("pour", global_position)
	Sfx.play_at("steam", global_position, -6.0)
	_steam.amount_ratio = 1.0
	_steam.emitting = true
	await get_tree().create_timer(2.2, false).timeout
	if not is_inside_tree():
		return
	GameState.brew_tea()
	Sfx.play_at("clink", global_position)
	UI.toast("Tea is ready · Serve it to the fox", UI.GOLD)
	player.unlock("brewing")
	_brewing = false
	_refresh()


func _refresh() -> void:
	# A thin wisp keeps rising once the tea is brewing or brewed.
	var warm := GameState.has("leaves_returned")
	_steam.emitting = warm
	_steam.amount_ratio = 1.0 if _brewing else 0.35
	if warm and _simmer == null:
		_simmer = Sfx.attach_loop("loop_kettle", self, -10.0, 2.5)


func _setup() -> void:
	_steam = GPUParticles3D.new()
	_steam.position = Vector3(0.13, 0.33, 0)
	_steam.amount = 24
	_steam.lifetime = 2.2
	_steam.emitting = false
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3(0.2, 1, 0)
	pm.spread = 12.0
	pm.initial_velocity_min = 0.15
	pm.initial_velocity_max = 0.3
	pm.gravity = Vector3(0, 0.05, 0)
	pm.scale_min = 0.6
	pm.scale_max = 1.2
	var curve := CurveTexture.new()
	var c := Curve.new()
	c.add_point(Vector2(0, 0.4))
	c.add_point(Vector2(1, 1.6))
	curve.curve = c
	pm.scale_curve = curve
	var grad := Gradient.new()
	grad.set_color(0, Color(1, 1, 1, 0.0))
	grad.set_color(1, Color(1, 1, 1, 0.0))
	grad.add_point(0.2, Color(1, 1, 1, 0.18))
	var gt := GradientTexture1D.new()
	gt.gradient = grad
	pm.color_ramp = gt
	_steam.process_material = pm
	var quad := QuadMesh.new()
	quad.size = Vector2(0.08, 0.08)
	var m := StandardMaterial3D.new()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = Fx.soft_dot()
	quad.material = m
	_steam.draw_pass_1 = quad
	add_child(_steam)


func _build_placeholder(v: Node3D) -> void:
	var brass := PH.mat(Color("a8875a"), 0.42, Color.BLACK, 0.0, 0.6)
	var wood := PH.mat(PH.WOOD_DARK, 0.7)
	PH.sphere(v, 0.14, Vector3(0, 0.13, 0), brass, Vector3(1, 0.85, 1))
	PH.cyl(v, 0.07, 0.1, 0.06, Vector3(0, 0.25, 0), brass)
	PH.sphere(v, 0.03, Vector3(0, 0.3, 0), wood, Vector3.ONE, 10)
	PH.limb(v, Vector3(0.1, 0.1, 0), Vector3(0.2, 0.26, 0), 0.025, 0.012, brass)
	PH.torus(v, 0.09, 0.11, Vector3(0, 0.3, 0), wood, Vector3(90, 0, 0))
