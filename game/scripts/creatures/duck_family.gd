extends Node3D
## A mother duck and her ducklings. The mother wanders slowly near the pond
## edge; ducklings follow her wake in a line, each tracing the path of the one
## ahead. She dabbles now and then (tips forward, tail up), and the family
## steers away from anyone standing at the shore. Ducklings peep.

const DUCKLINGS := 4
const SPACING := 0.34

var _ducks: Array[Node3D] = []
var _trail: Array[Vector3] = []  # mother's recent positions, newest first
var _target := Vector2.ZERO
var _heading := 0.0
var _speed := 0.3
var _dabble := 0.0
var _next_dabble := 12.0
var _next_peep := 3.0
var _t := 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	var start := _pick_target()
	for i in DUCKLINGS + 1:
		var d := Node3D.new()
		add_child(d)
		var model := ModelLib.place("duck", d)
		if model == null:
			_placeholder(d, i == 0)
		else:
			# A little flock of ducklings of slightly different sizes, a third deep.
			var s := 1.05 if i == 0 else _rng.randf_range(0.85, 1.0)
			model.scale = Vector3.ONE * s
			model.position.y = -0.13 * s * 0.3
			var ap := Npc._find_animation_player(model)
			if ap and ap.has_animation("swim"):
				ap.get_animation("swim").loop_mode = Animation.LOOP_LINEAR
				ap.play("swim")
				ap.seek(_rng.randf() * ap.current_animation_length, true)
				ap.speed_scale = 0.8 if i == 0 else _rng.randf_range(1.0, 1.3)
				ap.animation_finished.connect(_back_to_swim.bind(ap))
				d.set_meta("anim", ap)
		d.position = Vector3(start.x - i * SPACING, Layout.WATER_Y, start.y)
		_ducks.append(d)
	_target = _pick_target()


func _pick_target() -> Vector2:
	var player := get_tree().get_first_node_in_group("player") as Node3D
	for i in 20:
		var a := _rng.randf() * TAU
		var k := _rng.randf_range(0.55, 0.85)
		var p := Vector2(cos(a) * Layout.POND_RADII.x, sin(a) * Layout.POND_RADII.y) * k
		# Keep clear of the dock and of where the player stands.
		if p.distance_to(Vector2(7.5, 5.2)) < 4.0:
			continue
		if player and p.distance_to(Vector2(player.global_position.x, player.global_position.z)) < 6.0:
			continue
		return p
	return Vector2(-4, -3)


func _process(delta: float) -> void:
	_t += delta
	var mother := _ducks[0]
	var pos := Vector2(mother.position.x, mother.position.z)
	var player := get_tree().get_first_node_in_group("player") as Node3D
	var shy := false
	if player:
		var pp := Vector2(player.global_position.x, player.global_position.z)
		if pp.distance_to(pos) < 5.0:
			shy = true
			if _target.distance_to(pp) < 6.0:
				_target = _pick_target()
	if pos.distance_to(_target) < 0.8:
		_target = _pick_target()
	var speed := 0.55 if shy else _speed
	if _dabble > 0.0:
		speed = 0.0
	var want := atan2(_target.x - pos.x, _target.y - pos.y)
	_heading = lerp_angle(_heading, want, clampf(delta * 0.8, 0.0, 1.0))
	pos += Vector2(sin(_heading), cos(_heading)) * speed * delta
	mother.position = Vector3(pos.x, Layout.WATER_Y + sin(_t * 2.0) * 0.008, pos.y)
	mother.rotation.y = _heading
	# Dabbling: tip forward, tail up, with a little splash.
	_next_dabble -= delta
	if _next_dabble <= 0.0 and not shy:
		_next_dabble = _rng.randf_range(14.0, 30.0)
		_dabble = 1.8
		Fx.ripple(self, mother.position, 0.5, 1.2)
	if _dabble > 0.0:
		_dabble = maxf(_dabble - delta, 0.0)
		var tip := sin((1.0 - _dabble / 1.8) * PI)
		mother.rotation.x = tip * 1.25
		if _dabble <= 0.0:
			Fx.ripple(self, mother.position, 0.5, 1.2)
	else:
		mother.rotation.x = 0.0
	# Ducklings follow the mother's wake.
	if _trail.is_empty() or _trail[0].distance_to(mother.position) > 0.05:
		_trail.push_front(mother.position)
		if _trail.size() > 200:
			_trail.pop_back()
	for i in range(1, _ducks.size()):
		# Ducklings bunch up loosely behind the leader rather than in a strict line.
		var want_pos := _trail_point(i * SPACING) + Vector3(sin(i * 2.3 + _t * 0.4) * 0.14, 0, cos(i * 1.7 + _t * 0.35) * 0.08)
		var d := _ducks[i]
		var prev := d.position
		var np := prev.lerp(want_pos, clampf(delta * 3.0, 0.0, 1.0))
		np.y = Layout.WATER_Y + sin(_t * 3.0 + i) * 0.01
		var mv := Vector2(np.x - prev.x, np.z - prev.z)
		if mv.length() > 0.0005:
			d.rotation.y = lerp_angle(d.rotation.y, atan2(mv.x, mv.y), clampf(delta * 5.0, 0.0, 1.0))
		d.position = np
	_next_peep -= delta
	if _next_peep <= 0.0:
		_next_peep = _rng.randf_range(2.5, 7.0)
		if player and player.global_position.distance_to(mother.position) < 16.0:
			var peeper := _ducks[_rng.randi_range(1, DUCKLINGS)]
			Sfx.play_at("peep", peeper.global_position, -8.0, _rng.randf_range(0.95, 1.2))
			if peeper.has_meta("anim"):
				(peeper.get_meta("anim") as AnimationPlayer).play("peep", 0.1)


func _back_to_swim(_finished: StringName, ap: AnimationPlayer) -> void:
	ap.play("swim", 0.2)


func _trail_point(dist: float) -> Vector3:
	var acc := 0.0
	for i in range(1, _trail.size()):
		var seg := _trail[i - 1].distance_to(_trail[i])
		if acc + seg >= dist:
			return _trail[i - 1].lerp(_trail[i], (dist - acc) / maxf(seg, 0.0001))
		acc += seg
	return _trail.back() if not _trail.is_empty() else _ducks[0].position


func _placeholder(d: Node3D, mother: bool) -> void:
	var s := 1.6 if mother else 1.0
	var down := PH.mat(Color("ebd27a") if not mother else Color("8a6a4a"), 0.9)
	var head := PH.mat(Color("f0dc8a") if not mother else Color("3f6b4f"), 0.8)
	var bill := PH.mat(Color("e09a3e"), 0.6)
	PH.sphere(d, 0.06 * s, Vector3(0, 0.03 * s, 0), down, Vector3(0.9, 0.7, 1.25), 12)
	PH.sphere(d, 0.035 * s, Vector3(0, 0.08 * s, 0.05 * s), head, Vector3.ONE, 10)
	PH.sphere(d, 0.015 * s, Vector3(0, 0.075 * s, 0.085 * s), bill, Vector3(1.2, 0.5, 1.4), 8)
