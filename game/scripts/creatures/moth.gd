extends Creature
## Moon moth. Two habits, both from real moths at night:
##   lantern: drawn to a light, it loops around it in erratic, tightening
##            circles, now and then bumping at the glow and veering off; after a
##            while it drifts away to rest on a flower, then comes back.
##   flower:  flits between flowers in a bobbing, unsteady line, lands, and
##            sits fanning its wings slowly before moving on.
## Anyone who comes close makes it flutter off in a burst.

const STARTLE := 1.4

## World position of the lantern it circles (lantern habit), or ZERO.
var light := Vector3.ZERO
## Flower spots it may visit (XZ), shared by everyone.
var flowers: Array = []

var _from := Vector3.ZERO
var _to := Vector3.ZERO
var _u := 0.0
var _dur := 1.0
var _angle := 0.0
var _radius := 0.4
var _spin := 1.0
var _wobble := 0.0
var _bump := 0.0


func _setup() -> void:
	_angle = rng.randf() * TAU
	_spin = 1.0 if rng.randf() < 0.5 else -1.0
	_wobble = rng.randf() * TAU
	if light != Vector3.ZERO:
		position = light + Vector3(cos(_angle), 0, sin(_angle)) * 0.4
		_enter_orbit()
	else:
		position = _flower_spot(Vector3.ZERO)
		_land()


func _tick(delta: float) -> void:
	if state in ["rest"] and player_distance() < STARTLE:
		_flee()
		return
	match state:
		"orbit":
			_orbit(delta)
			if state_time > _dur and not flowers.is_empty():
				_fly_to(_flower_spot(position), "land")
		"fly":
			_follow_path(delta)
		"rest":
			if state_time > _dur:
				if light != Vector3.ZERO and rng.randf() < 0.7:
					_fly_to(light + Vector3(_radius, 0, 0), "orbit")
				else:
					_fly_to(_flower_spot(position), "land")
		"flee":
			_follow_path(delta)


func _enter_orbit() -> void:
	enter("orbit")
	_dur = rng.randf_range(14.0, 40.0)
	_radius = rng.randf_range(0.25, 0.55)
	play("flap", 0.1, rng.randf_range(0.9, 1.2))


## Erratic loops around the light: radius breathes, direction sometimes flips,
## and every few seconds a quick dash at the glow.
func _orbit(delta: float) -> void:
	if player_distance() < STARTLE * 0.8:
		_flee()
		return
	_angle += delta * _spin * (2.2 + sin(state_time * 1.7 + _wobble) * 1.2)
	if rng.randf() < delta * 0.15:
		_spin = -_spin
	_bump = maxf(_bump - delta * 2.5, 0.0)
	if _bump <= 0.0 and rng.randf() < delta * 0.35:
		_bump = 1.0
	var r := _radius * (0.8 + 0.25 * sin(state_time * 0.9 + _wobble)) * (1.0 - 0.7 * sin(_bump * PI))
	var y := 0.08 * sin(state_time * 2.3 + _wobble) + 0.05 * sin(state_time * 5.1)
	var want := light + Vector3(cos(_angle) * r, y - 0.12, sin(_angle) * r)
	var prev := position
	position = position.lerp(want, clampf(delta * 6.0, 0.0, 1.0))
	_face(position - prev, delta)


func _fly_to(target: Vector3, then: String) -> void:
	enter("fly")
	set_meta("then", then)
	_from = position
	_to = target
	_u = 0.0
	_dur = clampf(_from.distance_to(_to) / rng.randf_range(0.5, 0.8), 0.6, 9.0)
	play("flap", 0.1, rng.randf_range(1.0, 1.25))


func _flee() -> void:
	var away := away_from_player()
	var target := position + Vector3(away.x, 0, away.y) * rng.randf_range(2.5, 4.0) + Vector3.UP * rng.randf_range(0.6, 1.4)
	_fly_to(target, "orbit" if light != Vector3.ZERO else "land")
	enter("flee")
	_dur *= 0.5
	if anim:
		anim.speed_scale = 1.5


## Moth flight is never straight: a bobbing, sideways-wandering path.
func _follow_path(delta: float) -> void:
	_u = minf(_u + delta / _dur, 1.0)
	var base := _from.lerp(_to, smoothstep(0.0, 1.0, _u))
	var side := (_to - _from).cross(Vector3.UP).normalized()
	var arc := sin(_u * PI)
	var wander := side * sin(_u * 9.0 + _wobble) * 0.25 * arc
	var bob := Vector3.UP * (sin(_u * 23.0 + _wobble) * 0.06 + arc * 0.35)
	var prev := position
	position = base + wander + bob
	_face(position - prev, delta)
	if _u >= 1.0:
		if anim:
			anim.speed_scale = 1.0
		var then: String = get_meta("then", "land")
		if then == "orbit" and light != Vector3.ZERO:
			_enter_orbit()
		else:
			_land()


func _land() -> void:
	enter("rest")
	_dur = rng.randf_range(6.0, 18.0)
	rotation.x = 0.0
	play("rest", 0.3)


func _face(motion: Vector3, delta: float) -> void:
	if motion.length() < 0.0005:
		return
	turn_toward(Vector2(motion.x, motion.z), delta, 10.0)
	rotation.x = lerpf(rotation.x, clampf(-motion.y / maxf(delta, 0.001) * 0.4, -0.5, 0.5), clampf(delta * 6.0, 0.0, 1.0))


func _flower_spot(near: Vector3) -> Vector3:
	if flowers.is_empty():
		return near
	var best: Vector2 = flowers[rng.randi() % flowers.size()]
	if near != Vector3.ZERO:
		# Prefer a flower a short flight away.
		for i in 6:
			var c: Vector2 = flowers[rng.randi() % flowers.size()]
			if c.distance_to(Vector2(near.x, near.z)) < 6.0:
				best = c
				break
	var p := best + Vector2(rng.randf_range(-0.2, 0.2), rng.randf_range(-0.2, 0.2))
	return Vector3(p.x, ground_at(p) + rng.randf_range(0.2, 0.3), p.y)


func _build_placeholder(b: Node3D) -> void:
	var wing := PH.mat(Color("ddd2f2"), 0.8, Color("b9b3ec"), 0.3)
	for side in [-1.0, 1.0]:
		var w := PH.sphere(b, 0.03, Vector3(0.03 * side, 0.01, 0), wing, Vector3(1.0, 0.1, 0.7), 8)
		w.rotation_degrees = Vector3(0, 0, 10 * side)
	PH.sphere(b, 0.008, Vector3(0, 0.01, 0), PH.mat(Color("8a7a60")), Vector3(1, 1, 3), 8)
