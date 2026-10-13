extends Creature
## Owl in the giant tree. Owls hold perfectly still and turn their heads in
## quick snaps, then hold; they blink slowly, puff their feathers, and fix their
## gaze on anything that moves nearby (you). Every few minutes it glides
## silently to its other branch.

const WATCH := 16.0

## World-space perch points (top of a branch).
var perches: Array[Vector3] = []
var _perch := 0
var _head_target := 0.0
var _head := 0.0
var _next_snap := 1.0
var _next_hoot := 20.0
var _next_ruffle := 12.0
var _next_move := 150.0
var _from := Vector3.ZERO
var _to := Vector3.ZERO
var _u := 0.0
var _skeleton: Skeleton3D
var _head_bone := -1


func _setup() -> void:
	# Head turns are applied after the AnimationPlayer has posed the skeleton.
	process_priority = 10
	if anim:
		_skeleton = _find_skeleton(body)
		if _skeleton:
			_head_bone = _skeleton.find_bone("Head")
	position = perches[0]
	enter("perch")
	play("idle")


func _tick(delta: float) -> void:
	match state:
		"perch":
			_perch_behaviour(delta)
		"fly":
			_u = minf(_u + delta / 2.6, 1.0)
			var p := _from.lerp(_to, smoothstep(0.0, 1.0, _u))
			p.y += sin(_u * PI) * 1.2 - sin(_u * PI * 0.5) * 0.4
			position = p
			if anim == null:
				body.scale = Vector3(1.0 + abs(sin(state_time * 9.0)) * 0.5, 1.0, 1.0)
			if _u >= 1.0:
				body.scale = Vector3.ONE
				enter("perch")
				play("idle")


func _perch_behaviour(delta: float) -> void:
	var pl := player_node()
	var d := player_distance()
	if d < WATCH and pl:
		# Track the player, still in small snaps rather than a smooth pan.
		var to := Vector2(pl.global_position.x - global_position.x, pl.global_position.z - global_position.z)
		_next_snap -= delta * 2.5
		if _next_snap <= 0.0:
			_next_snap = 0.35
			_head_target = wrapf(atan2(to.x, to.y) - rotation.y, -PI, PI)
	else:
		_next_snap -= delta
		if _next_snap <= 0.0:
			_next_snap = rng.randf_range(1.2, 4.5)
			_head_target = rng.randf_range(-2.2, 2.2) if rng.randf() < 0.75 else 0.0
	# Fast snap (owls turn their heads quickly, then freeze).
	_head = lerp_angle(_head, clampf(_head_target, -2.4, 2.4), clampf(delta * 14.0, 0.0, 1.0))
	_apply_head()
	_next_hoot -= delta
	if _next_hoot <= 0.0:
		_next_hoot = rng.randf_range(24.0, 48.0)
		play("hoot", 0.1)
		Sfx.play_at("owl", global_position, -2.0, rng.randf_range(0.95, 1.05))
	_next_ruffle -= delta
	if _next_ruffle <= 0.0:
		_next_ruffle = rng.randf_range(10.0, 25.0)
		if not play("ruffle", 0.1) and anim == null:
			var t := create_tween()
			t.tween_property(body, "scale", Vector3(1.15, 1.08, 1.15), 0.12)
			t.tween_property(body, "scale", Vector3(0.97, 1.0, 0.97), 0.1)
			t.tween_property(body, "scale", Vector3.ONE, 0.25)
	_next_move -= delta
	if _next_move <= 0.0 and perches.size() > 1 and d > 6.0:
		_next_move = rng.randf_range(110.0, 220.0)
		_perch = (_perch + 1) % perches.size()
		_from = position
		_to = perches[_perch]
		_u = 0.0
		rotation.y = atan2(_to.x - _from.x, _to.z - _from.z)
		enter("fly")
		play("fly", 0.1)


func _apply_head() -> void:
	if _skeleton and _head_bone >= 0:
		var rest := _skeleton.get_bone_rest(_head_bone).basis.get_rotation_quaternion()
		_skeleton.set_bone_pose_rotation(_head_bone, Quaternion(Vector3.UP, _head) * rest)
	elif anim == null:
		# Placeholder: the head piece is the second child.
		if body.get_child_count() > 1:
			(body.get_child(1) as Node3D).rotation.y = _head


func _find_skeleton(root: Node) -> Skeleton3D:
	if root is Skeleton3D:
		return root
	for c in root.get_children():
		var s := _find_skeleton(c)
		if s:
			return s
	return null


func _build_placeholder(b: Node3D) -> void:
	var feather := PH.mat(Color("2c3b57"), 0.9)
	var cream := PH.mat(Color("e9dcc0"), 0.9)
	var amber := PH.mat(Color("f2b65d"), 0.3, Color("f2b65d"), 1.2)
	var dark := PH.mat(Color("101010"), 0.2)
	PH.sphere(b, 0.13, Vector3(0, 0.15, 0), feather, Vector3(1.0, 1.15, 0.95), 14)
	var head := Node3D.new()
	head.position = Vector3(0, 0.3, 0)
	b.add_child(head)
	PH.sphere(head, 0.1, Vector3.ZERO, feather, Vector3(1.05, 0.9, 1.0), 14)
	PH.sphere(head, 0.075, Vector3(0, -0.005, 0.045), cream, Vector3(1.2, 0.85, 0.6), 12)
	for side in [-1.0, 1.0]:
		PH.sphere(head, 0.026, Vector3(0.035 * side, 0.01, 0.085), amber, Vector3.ONE, 10)
		PH.sphere(head, 0.012, Vector3(0.035 * side, 0.01, 0.106), dark, Vector3.ONE, 8)
		PH.cyl(head, 0.0, 0.02, 0.06, Vector3(0.06 * side, 0.09, 0), feather, Vector3(0, 0, -20 * side), 6)
	PH.sphere(b, 0.08, Vector3(0, 0.13, 0.08), cream, Vector3(1.0, 1.2, 0.5), 12)
