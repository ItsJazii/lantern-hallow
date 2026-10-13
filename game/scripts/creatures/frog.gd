extends Creature
## Pond frog on a lily pad. Sits motionless, blinks, and calls with a pulsing
## throat. Frogs answer each other in a chorus, fall silent while someone is
## near, and if approached too closely leap into the pond with a splash, then
## resurface on another pad a while later.

const QUIET := 7.0
const LEAP := 2.6

static var last_call_time := -100.0
static var last_call_pos := Vector3.ZERO

## Lily pads this frog may use (world positions on the water).
var pads: Array[Vector3] = []
var _pad := 0
var _next_call := 0.0
var _quiet_until := 0.0
var _leap_from := Vector3.ZERO
var _leap_to := Vector3.ZERO
var _u := 0.0
var _hidden_for := 0.0


func _setup() -> void:
	_next_call = rng.randf_range(2.0, 10.0)
	enter("sit")
	play("idle")


func _tick(delta: float) -> void:
	var d := player_distance()
	var now := Time.get_ticks_msec() / 1000.0
	if d < QUIET:
		_quiet_until = now + rng.randf_range(6.0, 12.0)
	match state:
		"sit", "call":
			if d < LEAP:
				_leap()
				return
			if state == "call":
				_pose_call()
				if state_time > 0.8:
					enter("sit")
					play("idle")
			else:
				_pose_sit(delta)
				_next_call -= delta
				# Answer a nearby call, or start one, but only when undisturbed.
				var answering := now - last_call_time < 1.6 and now - last_call_time > 0.4 \
					and last_call_pos.distance_to(global_position) < 14.0 and rng.randf() < delta * 1.2
				if now > _quiet_until and (_next_call <= 0.0 or answering):
					_call()
		"leap":
			_u = minf(_u + delta / 0.55, 1.0)
			var p := _leap_from.lerp(_leap_to, _u)
			p.y += sin(_u * PI) * 0.35
			position = p
			body.rotation.x = lerpf(-0.6, 1.1, _u)
			if _u >= 1.0:
				Fx.splash(get_parent(), _leap_to, 10, 1.1)
				Fx.ripple(get_parent(), _leap_to, 0.7, 1.4)
				Sfx.play_at("plop", _leap_to, -2.0, 0.85)
				visible = false
				enter("under")
				_hidden_for = rng.randf_range(9.0, 20.0)
		"under":
			if state_time > _hidden_for and d > QUIET + 2.0:
				_surface()
		"surface":
			_u = minf(_u + delta / 0.7, 1.0)
			position = pads[_pad] + Vector3(0, lerpf(-0.12, 0.0, _u), 0)
			if _u >= 1.0:
				enter("sit")
				play("idle")


func _call() -> void:
	enter("call")
	_next_call = rng.randf_range(6.0, 16.0)
	last_call_time = Time.get_ticks_msec() / 1000.0
	last_call_pos = global_position
	play("croak", 0.1)
	if player_distance() < 30.0:
		Sfx.play_at("frog", global_position + Vector3.UP * 0.1, -4.0, rng.randf_range(0.9, 1.15))


func _leap() -> void:
	enter("leap")
	play("jump", 0.05)
	_u = 0.0
	_leap_from = position
	var away := away_from_player()
	_leap_to = position + Vector3(away.x, 0, away.y) * 0.9
	_leap_to.y = Layout.WATER_Y - 0.05
	rotation.y = atan2(away.x, away.y)


func _surface() -> void:
	# Pick a pad far from the player.
	var best := _pad
	var best_d := -1.0
	var pl := player_node()
	for i in pads.size():
		var dd := pads[i].distance_to(pl.global_position) if pl else rng.randf()
		if dd > best_d:
			best_d = dd
			best = i
	_pad = best
	position = pads[_pad] + Vector3(0, -0.12, 0)
	rotation.y = rng.randf() * TAU
	visible = true
	Fx.ripple(get_parent(), pads[_pad], 0.5, 1.2)
	_u = 0.0
	enter("surface")


func _pose_sit(delta: float) -> void:
	if anim:
		return
	# Throat pulses gently even when quiet; body otherwise perfectly still.
	var th := 1.0 + sin(state_time * 5.0) * 0.015
	body.scale = body.scale.lerp(Vector3(th, 1.0, th), clampf(delta * 6.0, 0.0, 1.0))
	body.rotation.x = lerpf(body.rotation.x, 0.0, 0.2)


func _pose_call() -> void:
	if anim:
		return
	# Two strong throat inflations per call.
	var pulse := maxf(sin(state_time * TAU * 2.5), 0.0)
	body.scale = Vector3(1.0 + pulse * 0.12, 1.0 - pulse * 0.04, 1.0 + pulse * 0.16)


func _build_placeholder(b: Node3D) -> void:
	var skin := PH.mat(Color("5f8a3e"), 0.5)
	var belly := PH.mat(Color("e8e0bf"), 0.6)
	var dark := PH.mat(Color("131813"), 0.15)
	PH.sphere(b, 0.06, Vector3(0, 0.045, 0), skin, Vector3(1.15, 0.75, 1.2), 14)
	PH.sphere(b, 0.045, Vector3(0, 0.035, 0.035), belly, Vector3(1.1, 0.6, 0.9), 12)
	for side in [-1.0, 1.0]:
		PH.sphere(b, 0.022, Vector3(0.035 * side, 0.085, 0.04), skin, Vector3.ONE, 10)
		PH.sphere(b, 0.014, Vector3(0.04 * side, 0.092, 0.052), dark, Vector3.ONE, 8)
		PH.sphere(b, 0.03, Vector3(0.06 * side, 0.02, -0.03), skin, Vector3(0.8, 0.5, 1.4), 10)
