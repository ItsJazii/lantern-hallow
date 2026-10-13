class_name PondLife
extends Node3D
## Fish under the clear water. Like real pond fish they cruise, then hang still
## and drift for a while; a splash makes nearby fish dart away. When a bobber
## lands, one curious fish approaches slowly and noses around it; the bite
## happens when it arrives. The caught fish leaves the pond until released.

const MOONFINS := 7
const KOI := 6
const DEPTH := 0.22

var _fish: Array[Dictionary] = []
var _rng := RandomNumberGenerator.new()
var _next_jump := 8.0
var _t := 0.0


func _ready() -> void:
	add_to_group("pond_life")
	_rng.seed = 77
	for i in MOONFINS + KOI:
		var kind := "moonfin" if i < MOONFINS else "koi"
		var holder := Node3D.new()
		add_child(holder)
		var body := FishArt.build(holder, kind, false)
		var s := _rng.randf_range(1.0, 1.35) if kind == "moonfin" else _rng.randf_range(1.1, 1.5)
		body.scale = Vector3.ONE * s
		# Moonfins carry their own soft moonlight; koi a faint warm sheen.
		# Real colours under clear water; Moonfins keep only a faint moon sheen.
		if kind == "moonfin":
			ModelLib.glow(body, 0.1, Color(0.6, 0.9, 1.0))
		ModelLib.set_layers(holder, WaterReflection.LAYER_UNDERWATER)
		var p := _random_point()
		holder.position = Vector3(p.x, Layout.WATER_Y - DEPTH, p.y)
		_fish.append({
			"node": holder, "body": body, "kind": kind, "target": _random_point(),
			"speed": _rng.randf_range(0.3, 0.6) if kind == "moonfin" else _rng.randf_range(0.2, 0.4),
			"heading": _rng.randf() * TAU, "phase": _rng.randf() * TAU,
			"depth": DEPTH + _rng.randf() * 0.18, "jump": 0.0,
			"mode": "swim", "mode_t": _rng.randf_range(4.0, 12.0), "lure": Vector2.ZERO, "lure_eta": 0.0,
		})


# --- Fishing hooks ------------------------------------------------------------------

## Sends the nearest willing Moonfin to inspect a bobber, arriving in `eta` s.
func attract(point: Vector3, eta: float) -> int:
	var p2 := Vector2(point.x, point.z)
	var best := -1
	var best_d := INF
	for i in _fish.size():
		var f := _fish[i]
		if f["kind"] != "moonfin" or f["mode"] in ["hooked", "lured"] or f["jump"] > 0.0:
			continue
		var d := Vector2(f["node"].position.x, f["node"].position.z).distance_to(p2)
		if d > 2.5 and d < best_d:
			best_d = d
			best = i
	if best >= 0:
		var f := _fish[best]
		f["mode"] = "lured"
		f["lure"] = p2
		f["lure_eta"] = maxf(eta, 1.0)
	return best


func unlure(i: int) -> void:
	if i >= 0 and i < _fish.size() and _fish[i]["mode"] in ["lured", "hooked"]:
		_fish[i]["node"].visible = true
		_set_mode(_fish[i], "dart", 1.2)


## The lured fish is on the line: it leaves the pond (the catch shows instead).
func hook(i: int) -> void:
	if i >= 0 and i < _fish.size():
		_fish[i]["mode"] = "hooked"
		_fish[i]["node"].visible = false


## Released back where it splashed down; it darts off, then calms down.
func release(i: int, at: Vector3) -> void:
	if i < 0 or i >= _fish.size():
		return
	var f := _fish[i]
	f["node"].position = Vector3(at.x, Layout.WATER_Y - 0.15, at.z)
	f["node"].visible = true
	_set_mode(f, "dart", 2.0)


## A caught fish was kept: it leaves for good, and a while later a new fish
## of the same kind swims into the pond from the stream inlet.
func replace(i: int) -> void:
	if i < 0 or i >= _fish.size():
		return
	var f := _fish[i]
	f["node"].visible = false
	f["mode"] = "away"
	f["mode_t"] = _rng.randf_range(10.0, 20.0)


## Fish close to a splash flee from it briefly.
func scatter(point: Vector3, radius: float) -> void:
	var p2 := Vector2(point.x, point.z)
	for f in _fish:
		if f["mode"] in ["hooked", "lured"]:
			continue
		var pos := Vector2(f["node"].position.x, f["node"].position.z)
		if pos.distance_to(p2) < radius:
			var away := (pos - p2).normalized()
			f["target"] = _clamp_to_pond(pos + away * 3.0)
			f["heading"] = atan2(away.x, away.y)
			_set_mode(f, "dart", 1.2)


# --- Simulation -------------------------------------------------------------------------

func _random_point() -> Vector2:
	var a := _rng.randf() * TAU
	var k := sqrt(_rng.randf()) * 0.72
	return Vector2(cos(a) * Layout.POND_RADII.x, sin(a) * Layout.POND_RADII.y) * k


func _clamp_to_pond(p: Vector2) -> Vector2:
	var k := Layout.pond_k(p)
	return p if k < 0.75 else p * (0.75 / k)


func _set_mode(f: Dictionary, mode: String, t: float) -> void:
	f["mode"] = mode
	f["mode_t"] = t


func _process(delta: float) -> void:
	_t += delta
	_next_jump -= delta
	if _next_jump <= 0.0:
		_next_jump = _rng.randf_range(16.0, 30.0)
		var f: Dictionary = _fish[_rng.randi() % _fish.size()]
		if f["jump"] <= 0.0 and f["mode"] == "swim":
			f["jump"] = 1.0
			_splash(f["node"].global_position)
	for f in _fish:
		_swim(f, delta)


func _swim(f: Dictionary, delta: float) -> void:
	var mode: String = f["mode"]
	if mode == "hooked":
		return
	if mode == "away":
		f["mode_t"] = float(f["mode_t"]) - delta
		if f["mode_t"] <= 0.0:
			var inlet := _clamp_to_pond(Vector2(-6.2, 5.2))
			f["node"].position = Vector3(inlet.x, Layout.WATER_Y - f["depth"], inlet.y)
			f["node"].visible = true
			f["heading"] = atan2(6.2, -5.2)
			f["target"] = _random_point()
			_set_mode(f, "swim", _rng.randf_range(6.0, 12.0))
		return
	var node: Node3D = f["node"]
	var pos := Vector2(node.position.x, node.position.z)
	f["mode_t"] = float(f["mode_t"]) - delta
	var speed: float = f["speed"]
	var turn := 0.9
	match mode:
		"swim":
			if pos.distance_to(f["target"]) < 0.8:
				f["target"] = _random_point()
			if f["mode_t"] <= 0.0:
				_set_mode(f, "drift", _rng.randf_range(2.0, 6.0))
		"drift":
			# Hanging almost still, only fins moving.
			speed *= 0.08
			turn = 0.25
			if f["mode_t"] <= 0.0:
				f["target"] = _random_point()
				_set_mode(f, "swim", _rng.randf_range(5.0, 14.0))
		"dart":
			speed *= 3.2
			turn = 4.0
			if f["mode_t"] <= 0.0:
				_set_mode(f, "swim", _rng.randf_range(4.0, 10.0))
		"lured":
			var lure: Vector2 = f["lure"]
			f["lure_eta"] = float(f["lure_eta"]) - delta
			var d := pos.distance_to(lure)
			if d > 0.45:
				# Cautious approach timed to arrive with the bite.
				f["target"] = lure
				speed = clampf(d / maxf(float(f["lure_eta"]), 0.3), 0.12, 0.6)
				turn = 1.5
			else:
				# Nosing around the bobber: tiny circles and nudges.
				var a := _t * 0.9 + float(f["phase"])
				f["target"] = lure + Vector2(cos(a), sin(a)) * 0.35
				speed = 0.12
				turn = 2.5
	var target: Vector2 = f["target"]
	var want := atan2(target.x - pos.x, target.y - pos.y)
	var heading: float = f["heading"]
	heading = lerp_angle(heading, want, clampf(delta * turn, 0.0, 1.0))
	f["heading"] = heading
	speed *= 1.0 + 0.25 * sin(_t * 0.7 + f["phase"])
	pos += Vector2(sin(heading), cos(heading)) * speed * delta
	pos = _clamp_to_pond(pos)
	var depth: float = f["depth"]
	if mode == "lured":
		depth = 0.14
	var y := Layout.WATER_Y - depth + sin(_t * 0.9 + f["phase"]) * 0.03
	var jump: float = f["jump"]
	if jump > 0.0:
		# A leap: an arc out of the water over ~1.1 s, then a splash back in.
		jump = maxf(jump - delta / 1.1, 0.0)
		var u := 1.0 - jump
		y = Layout.WATER_Y + sin(u * PI) * 0.75 - depth * (1.0 - sin(u * PI))
		node.rotation.x = lerpf(-0.9, 0.9, u)
		if jump <= 0.0:
			_splash(Vector3(pos.x, Layout.WATER_Y, pos.y))
			node.rotation.x = 0.0
		f["jump"] = jump
	node.position = Vector3(pos.x, y, pos.y)
	node.rotation.y = heading
	# Tail beat speeds up with swimming speed; drifting fish barely move.
	var body: Node3D = f["body"]
	var beat := 3.0 + speed * 14.0
	if body.has_meta("anim"):
		# The rig carries the tail beat; it quickens with speed.
		(body.get_meta("anim") as AnimationPlayer).speed_scale = clampf(0.35 + speed * 3.2, 0.3, 4.0)
		body.rotation.y = sin(_t * beat * 0.5 + f["phase"]) * 0.04
	else:
		body.rotation.y = sin(_t * beat + f["phase"]) * clampf(0.05 + speed * 0.3, 0.05, 0.3)


func _splash(at: Vector3) -> void:
	var p := Vector3(at.x, Layout.WATER_Y, at.z)
	Fx.splash(self, p, 16, 1.6)
	Fx.ripple(self, p, 1.0, 1.8)
	scatter(p, 2.5)
	Sfx.play_at("splash", p, -10.0, randf_range(1.1, 1.3))
