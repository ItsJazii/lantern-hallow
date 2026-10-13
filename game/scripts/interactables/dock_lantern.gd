extends Interactable
## One of the two lanterns at the end of the dock, lit after the wish lantern
## is received. Lit state is rebuilt from save data on load.

## Arm direction of the Tripo lantern post, so the lantern hangs over the water.
@export var arm_yaw := 0.0

var _paper: StandardMaterial3D
var _papers: Array[StandardMaterial3D] = []
var _light: OmniLight3D
var _light_pos := Vector3(0, 1.95, 0)


func _ready() -> void:
	interact_size = Vector3(0.7, 2.4, 0.7)
	interact_offset = Vector3(0, 1.2, 0)
	super._ready()


func get_prompt() -> String:
	if GameState.is_lantern_lit(target_id):
		return ""
	if GameState.has("wish_lantern_owned"):
		return "Light the lantern"
	return "Dock lantern"


func interact(_player: Player) -> void:
	if not GameState.has("wish_lantern_owned"):
		UI.toast("An unlit lantern. Its wick is waiting for something special.")
		return
	if not GameState.light_lantern(target_id):
		return
	Sfx.play_at("lantern_light", global_position + Vector3.UP * 1.9)
	_set_lit(true, true)
	if GameState.lit() >= GameState.LANTERN_IDS.size():
		UI.toast("Lanterns 2 / 2 · Release the wish lantern with the blue spirit", UI.GOLD)
	else:
		UI.toast("Lantern %d / 2" % GameState.lit(), UI.LAVENDER)


func _refresh() -> void:
	_set_lit(GameState.is_lantern_lit(target_id), false)


func _set_lit(lit: bool, animate: bool) -> void:
	var energy := 2.6 if lit else 0.0
	var light := 1.6 if lit else 0.0
	if animate:
		var t := create_tween().set_parallel(true)
		for m in _papers:
			t.tween_property(m, "emission_energy_multiplier", energy, 0.8)
		t.tween_property(_light, "light_energy", light, 0.8)
	else:
		for m in _papers:
			m.emission_energy_multiplier = energy
		_light.light_energy = light


func _setup() -> void:
	_light = PH.omni(self, _light_pos, Color("ffb866"), 0.0, 7.0)
	var body := PH.static_body(self)
	PH.cylinder_shape(body, 0.09, 2.2, Vector3(0, 1.1, 0))


func _build_placeholder(v: Node3D) -> void:
	var post := Prop.post_with_lantern(v, Vector3.ZERO, arm_yaw, false)
	if post:
		for m in post.get_meta("glow_mats"):
			_papers.append(m)
		_light_pos = post.transform * (post.get_meta("lantern_pos") as Vector3)
		return
	_build_box_lantern(v)
	_papers.append(_paper)


func _build_box_lantern(v: Node3D) -> void:
	var wood := PH.mat(PH.WOOD_DARK, 0.8)
	_paper = PH.mat(PH.PAPER, 0.9, Color("ffb35c"), 0.01).duplicate() as StandardMaterial3D
	_paper.emission_energy_multiplier = 0.0
	PH.cyl(v, 0.07, 0.09, 1.7, Vector3(0, 0.85, 0), wood, Vector3.ZERO, 10)
	PH.box(v, Vector3(0.34, 0.06, 0.34), Vector3(0, 1.72, 0), wood)
	PH.box(v, Vector3(0.26, 0.36, 0.26), Vector3(0, 1.93, 0), _paper)
	PH.box(v, Vector3(0.36, 0.05, 0.36), Vector3(0, 2.13, 0), wood)
	PH.cyl(v, 0.0, 0.2, 0.14, Vector3(0, 2.22, 0), wood, Vector3.ZERO, 4)
	for c in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
		PH.box(v, Vector3(0.03, 0.38, 0.03), Vector3(c.x * 0.13, 1.93, c.y * 0.13), wood)
