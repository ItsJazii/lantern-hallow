class_name Creature
extends Node3D
## Base for wildlife. Behavior is a small state machine driving root motion
## (position, facing, hops); the model's own animations ("idle", "eat",
## "alert", "hop", "croak", ...) add detail when the rigged model provides
## them. Until a Tripo model exists, `_build_placeholder` draws a stand-in.

@export var model_name := ""

const LOOPING := ["idle", "eat", "alert", "swim", "fly", "flap", "rest"]

var body: Node3D          ## Holds the model; procedural poses tilt/scale this.
var anim: AnimationPlayer
var state := ""
var state_time := 0.0
var rng := RandomNumberGenerator.new()
var _player: Node3D


func _ready() -> void:
	rng.randomize()
	body = Node3D.new()
	add_child(body)
	var scene := ModelLib.scene(model_name) if model_name != "" else null
	if scene:
		var inst := scene.instantiate()
		body.add_child(inst)
		anim = Npc._find_animation_player(inst)
		if anim:
			for a in LOOPING:
				if anim.has_animation(a):
					anim.get_animation(a).loop_mode = Animation.LOOP_LINEAR
	else:
		_build_placeholder(body)
	_setup()


func _build_placeholder(_b: Node3D) -> void:
	pass


func _setup() -> void:
	pass


func _process(delta: float) -> void:
	state_time += delta
	_tick(delta)


func _tick(_delta: float) -> void:
	pass


func enter(new_state: String) -> void:
	state = new_state
	state_time = 0.0


func play(anim_name: String, blend := 0.2, speed := 1.0) -> bool:
	if anim and anim.has_animation(anim_name):
		if anim.current_animation != anim_name or not anim_name in LOOPING:
			anim.play(anim_name, blend, speed)
			if anim_name in LOOPING and state_time == 0.0:
				# Never in step with a neighbour of the same kind.
				anim.seek(rng.randf() * anim.current_animation_length, true)
		return true
	return false


func player_node() -> Node3D:
	if not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Node3D
	return _player


func player_distance() -> float:
	var p := player_node()
	if p == null:
		return INF
	return Vector2(p.global_position.x - global_position.x, p.global_position.z - global_position.z).length()


## Direction (XZ) pointing from the player to this creature.
func away_from_player() -> Vector2:
	var p := player_node()
	if p == null:
		return Vector2.RIGHT
	var d := Vector2(global_position.x - p.global_position.x, global_position.z - p.global_position.z)
	return d.normalized() if d.length() > 0.01 else Vector2.RIGHT


## Smoothly turns to face an XZ direction (models face +Z).
func turn_toward(dir: Vector2, delta: float, rate := 6.0) -> void:
	if dir.length() < 0.001:
		return
	var want := atan2(dir.x, dir.y)
	rotation.y = lerp_angle(rotation.y, want, clampf(delta * rate, 0.0, 1.0))


func heading() -> Vector2:
	return Vector2(sin(rotation.y), cos(rotation.y))


static func ground_at(p: Vector2) -> float:
	return Layout.mesh_height(p)
