extends Node3D
## Light the Evening finale: the wish lantern and a handful of reused copies
## rise over the pond on gentle scripted curves while garden lights brighten
## and the ending music plays. Visual only; state was committed beforehand.

@export var lantern_model: PackedScene

var _running := false
var _player: Player
var _rng := RandomNumberGenerator.new()


var _floaters: Array[Node3D] = []


func _ready() -> void:
	add_to_group("celebration")
	# The pond's floating lanterns are the finale's gift: only once it's done.
	if GameState.has("ending_complete"):
		_float_lanterns(14, false)


func _process(_delta: float) -> void:
	var t := Time.get_ticks_msec() * 0.001
	for f in _floaters:
		var drift: Vector2 = f.get_meta("drift")
		var home: Vector2 = f.get_meta("home")
		var ph: float = f.get_meta("phase")
		var p := home + drift * sin(t * 0.03 + ph) * 1.2 + Vector2(sin(t * 0.11 + ph), cos(t * 0.09 + ph)) * 0.3
		# Sitting in the water, base just under the surface, bobbing gently.
		f.position = Vector3(p.x, Layout.WATER_Y - 0.025 + sin(t * 1.3 + ph) * 0.01, p.y)
		f.rotation = Vector3(sin(t * 1.1 + ph) * 0.04, ph + t * 0.02, cos(t * 0.9 + ph) * 0.04)


## Paper lanterns floating on the pond (the Tripo water lantern, or a simple
## stand-in). They appear with the finale and stay afterwards.
func _float_lanterns(count: int, animated: bool) -> void:
	var model := ModelLib.scene("water_lantern")
	var paper := PH.paper(2.6)
	paper.albedo_color = Color("ffe2b0")
	var frame := PH.mat(PH.WOOD_DARK, 0.8)
	var flame := PH.mat(Color("ffcf7a"), 0.5, Color("ffb347"), 5.0)
	var start := _floaters.size()
	for n in count:
		var i := start + n
		var a := TAU * i / 7.3 + _rng.randf_range(-0.3, 0.3)
		var k := _rng.randf_range(0.3, 0.72)
		var home := Vector2(cos(a) * Layout.POND_RADII.x * k, sin(a) * Layout.POND_RADII.y * k)
		var root := Node3D.new()
		add_child(root)
		var s := _rng.randf_range(0.85, 1.15)
		root.scale = Vector3.ONE * s
		if model:
			var inst := model.instantiate()
			root.add_child(inst)
			ModelLib.glow(inst, 1.8)
		else:
			PH.box(root, Vector3(0.34, 0.03, 0.34), Vector3(0, 0.015, 0), frame)
			PH.box(root, Vector3(0.28, 0.3, 0.28), Vector3(0, 0.18, 0), paper)
			PH.box(root, Vector3(0.32, 0.02, 0.32), Vector3(0, 0.34, 0), frame)
		PH.sphere(root, 0.03, Vector3(0, 0.1, 0), flame, Vector3.ONE, 8)
		if i % 3 == 0:
			PH.omni(root, Vector3(0, 0.22, 0), Color("ffb25e"), 0.9, 4.0).remove_from_group("garden_light")
		root.set_meta("home", home)
		root.set_meta("drift", Vector2(_rng.randf_range(-1, 1), _rng.randf_range(-1, 1)).normalized())
		root.set_meta("phase", _rng.randf() * TAU)
		_floaters.append(root)
		if animated:
			root.scale = Vector3.ONE * 0.01
			var t := root.create_tween()
			t.tween_interval(2.0 + n * 0.35)
			t.tween_property(root, "scale", Vector3.ONE * s, 1.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func play(origin: Vector3) -> void:
	if _running:
		return
	_running = true
	_player = get_tree().get_first_node_in_group("player") as Player
	if _player:
		_player.lock("celebration")
		_player.face_toward(origin + Vector3(-4, 5.5, -3), 2.5)
	Sfx.play_music("music_ending", 1.5)
	Sfx.play("lantern_release")
	var world := get_tree().get_first_node_in_group("world")
	if world:
		world.apply_evening(true, true)
	_launch(origin + Vector3(0, 0.7, 0), 0.0, true)
	_float_lanterns(14, true)
	for i in 9:
		var a := TAU * i / 9.0 + _rng.randf_range(-0.2, 0.2)
		var p := Vector3(cos(a) * Layout.POND_RADII.x * 0.75, Layout.WATER_Y + 0.25, sin(a) * Layout.POND_RADII.y * 0.75)
		_launch(p, 1.0 + i * 0.5, i % 3 == 0)
	var t := create_tween()
	t.tween_interval(6.5)
	t.tween_callback(_finish)


func _finish() -> void:
	if is_instance_valid(_player):
		_player.unlock("celebration")
	UI.quest_complete("Light the Evening")
	_running = false
	get_tree().create_timer(2.5).timeout.connect(UI.show_ending)


func _launch(from: Vector3, delay: float, with_light: bool) -> void:
	var lantern := Node3D.new()
	add_child(lantern)
	lantern.global_position = from
	lantern.scale = Vector3.ONE * 0.01
	var model := lantern_model if lantern_model else ModelLib.scene("wish_lantern")
	if model:
		var inst := model.instantiate()
		lantern.add_child(inst)
		ModelLib.glow(inst, 3.2)
		# A small flame inside so the open-top lantern reads as lit.
		PH.sphere(lantern, 0.05, Vector3(0, 0.08, 0), PH.mat(Color("ffcf7a"), 0.5, Color("ffb347"), 6.0), Vector3.ONE, 8)
	else:
		_build_wish_lantern(lantern)
	if with_light:
		PH.omni(lantern, Vector3(0, 0.2, 0), Color("ffb25e"), 1.6, 6.0).remove_from_group("garden_light")
	var drift := Vector3(_rng.randf_range(-5, 5), 0, _rng.randf_range(-5, 5))
	var phase := _rng.randf() * TAU
	var t := lantern.create_tween()
	t.tween_interval(delay)
	t.tween_property(lantern, "scale", Vector3.ONE, 0.8).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_method(_rise.bind(lantern, from, drift, phase), 0.0, 1.0, 18.0)
	t.tween_callback(lantern.queue_free)


func _rise(u: float, lantern: Node3D, from: Vector3, drift: Vector3, phase: float) -> void:
	var sway := Vector3(sin(u * 5.0 + phase), 0, cos(u * 4.0 + phase)) * 0.5
	lantern.global_position = from + drift * u + sway * u + Vector3(0, 26.0 * pow(u, 1.25), 0)
	lantern.rotation.y = u * 2.0 + phase


func _build_wish_lantern(root: Node3D) -> void:
	var paper := PH.paper(3.0)
	var rim := PH.mat(PH.WOOD_DARK, 0.8)
	PH.cyl(root, 0.2, 0.17, 0.42, Vector3(0, 0.21, 0), paper, Vector3.ZERO, 16)
	PH.torus(root, 0.15, 0.185, Vector3(0, 0.0, 0), rim)
	PH.torus(root, 0.18, 0.21, Vector3(0, 0.42, 0), rim)
	PH.sphere(root, 0.05, Vector3(0, 0.06, 0), PH.mat(Color("ffcf7a"), 0.5, Color("ffb347"), 6.0), Vector3.ONE, 8)
