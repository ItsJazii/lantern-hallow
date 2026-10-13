extends Interactable
## Garden bench facing the pond. Sitting is a quiet view; E stands back up.

const SEAT_EYE := 1.12

var _player: Player
var _return_transform: Transform3D
var _return_pitch := 0.0
var _sitting := false


func _ready() -> void:
	interact_size = Vector3(1.8, 1.0, 0.8)
	interact_offset = Vector3(0, 0.5, 0)
	super._ready()


func get_prompt() -> String:
	return "" if _sitting else "Sit on the bench"


func interact(player: Player) -> void:
	if _sitting:
		return
	_sitting = true
	_player = player
	_return_transform = player.global_transform
	_return_pitch = player.camera.rotation.x
	player.lock("bench")
	player.frozen = true
	player.action_handler = self
	Sfx.play("sit", -6.0)
	var seat := global_transform * Vector3(0, 0, 0.05)
	var forward := -global_transform.basis.z
	var t := player.create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(player, "global_position", seat, 0.7)
	t.tween_property(player.camera, "position:y", SEAT_EYE, 0.7)
	player.face_toward(seat + forward * 10.0 + Vector3.UP * 0.4, 0.7)
	# Seated, you can look around but not turn to see your own back.
	player.look_center = atan2(-forward.x, -forward.z)
	player.look_limit = deg_to_rad(85.0)


func handle_action() -> void:
	if not _sitting or _player == null:
		return
	_sitting = false
	var p := _player
	_player = null
	p.look_limit = -1.0
	var t := p.create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(p, "global_position", _return_transform.origin, 0.5)
	t.tween_property(p.camera, "position:y", Player.EYE_HEIGHT, 0.5)
	await t.finished
	p.frozen = false
	p.action_handler = null
	p.unlock("bench")


func get_action_prompt() -> String:
	return "Press E to stand up" if _sitting else ""


func _setup() -> void:
	var body := PH.static_body(self, "wood")
	PH.box_shape(body, Vector3(1.7, 0.9, 0.6), Vector3(0, 0.45, 0))
	GroundDetail.contact_shadow(self, Vector2(2.1, 1.1), 0.6)


func _build_placeholder(v: Node3D) -> void:
	var wood := PH.mat(PH.WOOD, 0.75)
	var dark := PH.mat(PH.WOOD_DARK, 0.8)
	for i in 3:
		PH.box(v, Vector3(1.6, 0.04, 0.12), Vector3(0, 0.45, -0.14 + i * 0.14), wood)
	for i in 2:
		PH.box(v, Vector3(1.6, 0.1, 0.035), Vector3(0, 0.66 + i * 0.16, 0.25), wood, Vector3(-12, 0, 0))
	for x in [-0.7, 0.7]:
		PH.box(v, Vector3(0.07, 0.45, 0.4), Vector3(x, 0.22, -0.02), dark)
		PH.box(v, Vector3(0.06, 0.55, 0.06), Vector3(x, 0.7, 0.24), dark, Vector3(-12, 0, 0))
		PH.box(v, Vector3(0.07, 0.04, 0.42), Vector3(x, 0.6, 0.0), dark)
