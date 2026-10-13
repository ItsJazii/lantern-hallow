extends Interactable
## One of the three gatherable moonleaf plants. Collected plants keep their
## stems but lose the glowing leaves, so the change reads at a glance.

var _leaves: Node3D
var _light: OmniLight3D
var _t := 0.0
var _glow_mat: StandardMaterial3D
var _model_glow: Array[StandardMaterial3D] = []


func _ready() -> void:
	interact_size = Vector3(0.9, 1.0, 0.9)
	interact_offset = Vector3(0, 0.35, 0)
	super._ready()


func get_prompt() -> String:
	if GameState.is_leaf_collected(target_id):
		return ""
	return "Gather moonleaf"


func interact(_player: Player) -> void:
	if not GameState.has("moss_met"):
		UI.toast("These leaves belong to the moss spirit's grove. Say hello to the spirit first.")
		return
	if not GameState.collect_leaf(target_id):
		return
	Sfx.play_at("leaf_pickup", global_position + Vector3.UP * 0.4, 0.0, randf_range(0.97, 1.05))
	var n := GameState.leaves()
	if n >= GameState.LEAF_IDS.size():
		UI.toast("Moonleaves 3 / 3 · Bring them to the tea keeper", UI.GOLD)
	else:
		UI.toast("Moonleaf %d / 3" % n, UI.LAVENDER)
	var t := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	t.tween_property(_leaves, "scale", Vector3.ONE * 0.01, 0.45)
	t.parallel().tween_property(_light, "light_energy", 0.0, 0.45)
	t.tween_callback(_refresh)


func _refresh() -> void:
	var collected := GameState.is_leaf_collected(target_id)
	_leaves.visible = not collected
	_leaves.scale = Vector3.ONE
	_light.visible = not collected
	_light.light_energy = 0.5


func _process(delta: float) -> void:
	_t += delta
	if _leaves.visible:
		var pulse := sin(_t * 2.2)
		if _glow_mat:
			_glow_mat.emission_energy_multiplier = 1.4 + pulse * 0.5
		for m in _model_glow:
			m.emission_energy_multiplier = 0.32 + pulse * 0.12


func _decorate_model(model_root: Node) -> void:
	_leaves = model_root as Node3D
	# Keep the glow tinted by the leaf texture so it stays violet, not white.
	_model_glow = ModelLib.glow(model_root, 0.32, Color(0.75, 0.62, 1.0))


func _build_placeholder(v: Node3D) -> void:
	var stem := PH.mat(Color("cfc6a4"), 0.9)
	_glow_mat = StandardMaterial3D.new()
	_glow_mat.albedo_color = Color("9a8ee6")
	_glow_mat.roughness = 0.6
	_glow_mat.emission_enabled = true
	_glow_mat.emission = Color("b6a8ff")
	_glow_mat.emission_energy_multiplier = 1.4
	var tip := PH.mat(Color("8fd3e8"), 0.6, Color("9be3ff"), 1.2)
	PH.sphere(v, 0.14, Vector3(0, 0.04, 0), PH.mat(Color("4f6a3f"), 1.0), Vector3(1.4, 0.4, 1.4), 12)
	_leaves = Node3D.new()
	v.add_child(_leaves)
	for i in 6:
		var a := TAU * i / 6.0 + 0.3
		var lean := 22.0 + (i % 2) * 10.0
		var blade := Node3D.new()
		blade.rotation = Vector3(0, a, 0)
		_leaves.add_child(blade)
		PH.cyl(blade, 0.008, 0.012, 0.3, Vector3(0, 0.15, 0.04), stem, Vector3(lean, 0, 0), 6)
		var leaf := PH.sphere(blade, 0.1, Vector3(0, 0.36, 0.13), _glow_mat, Vector3(0.55, 1.7, 0.2), 12)
		leaf.rotation_degrees = Vector3(lean + 8.0, 0, 0)
		PH.sphere(blade, 0.03, Vector3(0, 0.52, 0.2), tip, Vector3(0.6, 1.3, 0.3), 8)


func _setup() -> void:
	_light = PH.omni(self, Vector3(0, 0.5, 0), Color("b8a8ff"), 0.5, 2.5)
	_light.remove_from_group("garden_light")
