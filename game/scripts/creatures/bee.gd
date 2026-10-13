extends Creature
## Garden bee. Works a patch of flowers the way real bees forage: a short,
## direct hop to the next bloom, a hover in front of it, a brief landing to
## feed, then on to a neighbour. Keeps to its patch, gives people a wide berth,
## and its body hums with a fine, fast tremble.

const SHY := 1.2

var flowers: Array = []  # XZ flower spots in this bee's patch

var _from := Vector3.ZERO
var _to := Vector3.ZERO
var _u := 0.0
var _dur := 1.0
var _phase := 0.0


func _setup() -> void:
	_phase = rng.randf() * TAU
	position = _spot()
	_hover()


func _tick(delta: float) -> void:
	# Wing buzz shows as a tiny, fast shiver of the whole body.
	var buzz := 0.0 if state == "feed" else 1.0
	body.position = Vector3(sin(state_time * 83.0 + _phase), sin(state_time * 97.0), cos(state_time * 71.0)) * 0.0012 * buzz
	if state != "fly" and player_distance() < SHY:
		_go(_spot(true))
		return
	match state:
		"hover":
			# Hanging in the air before a bloom, drifting a few millimetres.
			position.y += sin(state_time * 6.0 + _phase) * 0.0006
			if state_time > _dur:
				if rng.randf() < 0.6:
					enter("feed")
					_dur = rng.randf_range(1.5, 4.5)
					position.y -= 0.04
				else:
					_go(_spot())
		"feed":
			if state_time > _dur:
				position.y += 0.04
				_go(_spot())
		"fly":
			_u = minf(_u + delta / _dur, 1.0)
			var p := _from.lerp(_to, smoothstep(0.0, 1.0, _u))
			p.y += sin(_u * PI) * 0.12
			var prev := position
			position = p
			var m := position - prev
			if m.length() > 0.0001:
				turn_toward(Vector2(m.x, m.z), delta, 14.0)
			if _u >= 1.0:
				_hover()


func _hover() -> void:
	enter("hover")
	_dur = rng.randf_range(0.6, 2.2)


func _go(target: Vector3) -> void:
	enter("fly")
	_from = position
	_to = target
	_u = 0.0
	_dur = clampf(_from.distance_to(_to) / rng.randf_range(0.9, 1.4), 0.25, 3.0)


func _spot(away := false) -> Vector3:
	var here := Vector2(position.x, position.z)
	var best: Vector2 = here
	var best_score := -INF
	for i in 6:
		var c: Vector2 = flowers[rng.randi() % flowers.size()] if not flowers.is_empty() else here
		var d := c.distance_to(here)
		var score := -absf(d - 0.8)
		if away:
			score = (c - here).normalized().dot(away_from_player()) * 2.0 - d * 0.2
		if score > best_score:
			best_score = score
			best = c
	var p := best + Vector2(rng.randf_range(-0.15, 0.15), rng.randf_range(-0.15, 0.15))
	return Vector3(p.x, ground_at(p) + rng.randf_range(0.24, 0.34), p.y)


func _build_placeholder(b: Node3D) -> void:
	PH.sphere(b, 0.009, Vector3(0, 0.01, 0), PH.mat(Color("e0a73a")), Vector3(1, 1, 1.6), 8)
