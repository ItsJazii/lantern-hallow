extends Creature
## Moon rabbit. Real-rabbit rhythm: long stretches of grazing, sitting up to
## scan, short bursts of 1–4 hops to a new patch. Notices an approaching player
## (freezes, ears up); too close and it bolts in fast zigzag hops to the
## nearest bushes, hides, and only creeps back out once things are quiet.

const NOTICE := 7.5
const BOLT := 4.0
const SAFE := 11.0

var _world: Node
var _hop_from := Vector3.ZERO
var _hop_to := Vector3.ZERO
var _hop_u := 1.0
var _hop_time := 0.32
var _hop_height := 0.16
var _hops_left := 0
var _goal := Vector2.ZERO
var _dur := 3.0
var _zig := 1.0
var _last_d := INF


func _setup() -> void:
	_world = get_tree().get_first_node_in_group("world")
	GroundDetail.contact_shadow(self, Vector2(0.5, 0.55), 0.55)
	enter_graze()


func _tick(delta: float) -> void:
	var d := player_distance()
	var approaching := d < _last_d - 0.02
	_last_d = d
	if _hop_u < 1.0:
		_advance_hop(delta)
		return
	match state:
		"graze":
			_pose_graze()
			if d < BOLT:
				_bolt()
			elif d < NOTICE and approaching:
				_freeze()
			elif state_time > _dur:
				if rng.randf() < 0.45:
					_look()
				else:
					_start_hops(rng.randi_range(1, 4), 2.5)
		"look":
			_pose_alert(delta)
			if d < BOLT:
				_bolt()
			elif d < NOTICE and approaching:
				_freeze()
			elif state_time > _dur:
				if rng.randf() < 0.5:
					enter_graze()
				else:
					_start_hops(rng.randi_range(1, 3), 2.0)
		"freeze":
			_pose_alert(delta)
			turn_toward(-away_from_player(), delta, 2.0)
			if d < BOLT:
				_bolt()
			elif d > NOTICE + 1.5 and state_time > 2.0:
				_look()
		"hop":
			if _hops_left > 0:
				_next_hop(_hop_time, 0.45, 0.0)
			else:
				enter_graze()
		"bolt":
			if _hops_left > 0:
				_zig = -_zig
				_next_hop(0.24, 0.85, 0.55 * _zig)
			else:
				enter("hide")
				_dur = rng.randf_range(7.0, 13.0)
		"hide":
			_pose_crouch()
			if d < BOLT * 0.8:
				_bolt()
			elif state_time > _dur and d > SAFE:
				_look()


# --- States -----------------------------------------------------------------------

func enter_graze() -> void:
	enter("graze")
	_dur = rng.randf_range(3.5, 9.0)
	if not play("eat"):
		play("idle")


func _look() -> void:
	enter("look")
	_dur = rng.randf_range(1.5, 3.5)
	play("alert")


func _freeze() -> void:
	enter("freeze")
	play("alert")


func _start_hops(count: int, radius: float) -> void:
	enter("hop")
	_hops_left = count
	_goal = _pick_point(Vector2(position.x, position.z), radius, false)


func _bolt() -> void:
	enter("bolt")
	_goal = _cover_point()
	_hops_left = rng.randi_range(5, 8)


# --- Hopping ------------------------------------------------------------------------

func _next_hop(time: float, length: float, sideways: float) -> void:
	_hops_left -= 1
	var here := Vector2(position.x, position.z)
	var dir := (_goal - here)
	if state == "bolt":
		dir = dir.normalized() * 0.6 + away_from_player() * 0.4
	if dir.length() < 0.2:
		_hops_left = 0
		return
	dir = dir.normalized()
	dir = (dir + Vector2(-dir.y, dir.x) * sideways).normalized()
	var to := here + dir * minf(length, here.distance_to(_goal) + 0.3 if state == "hop" else length)
	if not _valid(to, state == "bolt"):
		to = here + dir.rotated(rng.randf_range(-1.2, 1.2)) * length * 0.6
		if not _valid(to, true):
			_hops_left = 0
			return
	_hop_from = position
	_hop_to = Vector3(to.x, ground_at(to), to.y)
	_hop_time = time
	_hop_height = 0.12 + length * 0.12
	_hop_u = 0.0
	rotation.y = atan2(dir.x, dir.y)
	play("hop", 0.05, 0.32 / time)


func _advance_hop(delta: float) -> void:
	_hop_u = minf(_hop_u + delta / _hop_time, 1.0)
	var p := _hop_from.lerp(_hop_to, _hop_u)
	p.y += sin(_hop_u * PI) * _hop_height
	position = p
	if anim == null:
		body.rotation.x = -0.35 * cos(_hop_u * PI)
		body.scale = Vector3(1, 1.0 + 0.08 * sin(_hop_u * PI), 1)
	if _hop_u >= 1.0 and player_distance() < 10.0:
		Sfx.play_at("step_grass", global_position, -20.0, 1.4)


# --- Poses (only used when the model has no animations) ----------------------------------

func _pose_graze() -> void:
	if anim:
		return
	var nibble := sin(state_time * 16.0) * 0.04 if fmod(state_time, 1.6) < 0.7 else 0.0
	body.rotation.x = lerpf(body.rotation.x, 0.3 + nibble, 0.2)
	body.scale = body.scale.lerp(Vector3.ONE, 0.2)


func _pose_alert(delta: float) -> void:
	if anim:
		return
	body.rotation.x = lerpf(body.rotation.x, -0.18, clampf(delta * 8.0, 0.0, 1.0))
	body.scale = body.scale.lerp(Vector3(1, 1.08, 1), 0.2)


func _pose_crouch() -> void:
	if anim:
		return
	body.rotation.x = lerpf(body.rotation.x, 0.1, 0.1)
	body.scale = body.scale.lerp(Vector3(1.05, 0.85, 1.05), 0.1)


# --- Where it may go ---------------------------------------------------------------------

func _valid(p: Vector2, fleeing: bool) -> bool:
	if Layout.outside_distance(p) > 0.0:
		return false
	if Layout.pond_k(p) < 1.12 or Layout.stream_distance(p) < Layout.STREAM_HALF_WIDTH + 1.0:
		return false
	# Grazing rabbits stay off the paths; a bolting one will cross them.
	if not fleeing and Layout.distance_to_any_path(p) < 0.5:
		return false
	return true


func _pick_point(around: Vector2, radius: float, fleeing: bool) -> Vector2:
	for i in 12:
		var p := around + Vector2(rng.randf_range(-radius, radius), rng.randf_range(-radius, radius))
		if _valid(p, fleeing):
			return p
	return around


func _cover_point() -> Vector2:
	var here := Vector2(position.x, position.z)
	var away := away_from_player()
	var best := here + away * 5.0
	var best_score := -INF
	var covers: Array = _world.get("cover_points") if _world else []
	for c in covers:
		var cp: Vector2 = c
		var to := cp - here
		var dist := to.length()
		if dist < 1.0 or dist > 14.0:
			continue
		# Prefer bushes that lie away from the player and aren't too far.
		var score := to.normalized().dot(away) * 2.0 - dist * 0.15
		if score > best_score:
			best_score = score
			best = cp
	return best


func _build_placeholder(b: Node3D) -> void:
	var fur := PH.mat(Color("f1ebe0"), 0.95)
	var tip := PH.mat(Color("bfb3e6"), 0.9)
	var dark := PH.mat(Color("1d1a1c"), 0.3)
	PH.sphere(b, 0.11, Vector3(0, 0.11, -0.02), fur, Vector3(1.0, 0.95, 1.25), 14)
	PH.sphere(b, 0.075, Vector3(0, 0.2, 0.1), fur, Vector3.ONE, 14)
	for side in [-1.0, 1.0]:
		var ear := PH.sphere(b, 0.03, Vector3(0.03 * side, 0.32, 0.08), fur, Vector3(0.7, 3.0, 0.5), 10)
		ear.rotation_degrees = Vector3(-10, 0, -12 * side)
		PH.sphere(b, 0.018, Vector3(0.036 * side, 0.39, 0.075), tip, Vector3(0.8, 1.6, 0.5), 8)
		PH.sphere(b, 0.012, Vector3(0.04 * side, 0.22, 0.16), dark, Vector3.ONE, 8)
	PH.sphere(b, 0.04, Vector3(0, 0.12, -0.16), fur, Vector3.ONE, 10)
