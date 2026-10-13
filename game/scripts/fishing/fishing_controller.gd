class_name FishingController
extends Node3D
## Dock fishing, played like the real thing:
##   IDLE → AIMING (rod up; right-click / E casts where you look)
##        → CASTING (back-swing, flick, the bobber arcs out)
##        → WAITING (4–7 s) → BITE (strike within ~1.6 s or it just nibbles)
##        → REELING (hold right-click / E; the fish fights back in bursts)
##        → CATCH_REVEAL (it hangs on the line) → RELEASING (into the basket)
##        → commit → IDLE
## Bait is only reserved while a session runs. The one commit point is the end
## of the release animation, where GameState.commit_release() changes bait,
## coins and quest flags together and saves. Every async step carries the
## session id it was started with and is ignored if the session has changed,
## so repeated input, cancels and restarts can never double-apply a reward.

enum State { IDLE, CASTING, WAITING, BITE, REELING, CATCH_REVEAL, RELEASING, AIMING }

const BITE_WINDOW := 1.6
const REEL_RATE := 0.3     # progress per second while reeling
const SURGE_RATE := 0.1    # slower while the fish pulls

const ROD_SHOWN := Vector3(0.28, -0.42, -0.32)
const ROD_HIDDEN := Vector3(0.45, -1.1, -0.2)
const ROD_ROTATION := Vector3(30, -12, -8)

## World-space water point where the bobber lands.
@export var cast_anchor := Vector3(2.6, -0.3, 0.4)
@export var rod_model: PackedScene
@export var fish_model: PackedScene
@export var bobber_model: PackedScene

var state: State = State.IDLE
## Tests and captures: cast and reel without player input, bites never time out.
var autoplay := false
## Where the bobber lands this cast.
var cast_point := Vector3.ZERO

var _rod_ready := false
var _bite_left := 0.0
var _reel := 0.0
var _tension := 0.0
var _surge := 0.0
var _next_surge := 0.0
var _reel_sound: AudioStreamPlayer
var _reel_from := Vector3.ZERO
var _reel_to := Vector3.ZERO

var _session := 0
var _pending_catch := false
var _wait_session := -1
var _player: Player
var _rod: Node3D
var _rod_tip: Node3D
var _bobber: Node3D
var _fish: Node3D
var _fish_anim: AnimationPlayer
var _fish_mouth := Vector3(0, 0.02, 0.16)
var _lift := 0.0
var _lift_from := Vector3.ZERO
var _line: MeshInstance3D
var _line_mesh: ImmediateMesh
var _line_mat: StandardMaterial3D
var _timer: Timer
var _tween: Tween
var _t := 0.0
var _next_bite_ripple := 0.0
## Index of the pond fish that came to inspect the bobber (-1 if none).
var _lured := -1


func _ready() -> void:
	add_to_group("fishing")
	_build_rod()
	_build_bobber()
	_build_fish()
	_build_line()
	_build_basket.call_deferred()
	_timer = Timer.new()
	_timer.one_shot = true
	_timer.timeout.connect(_on_wait_finished)
	add_child(_timer)
	# The reel's ratchet, looping only while you wind.
	_reel_sound = AudioStreamPlayer.new()
	_reel_sound.bus = "SFX"
	_reel_sound.stream = Sfx.get_stream("loop_reel")
	_reel_sound.volume_db = -9.0
	add_child(_reel_sound)


func is_active() -> bool:
	return state != State.IDLE


func can_cancel() -> bool:
	return state in [State.AIMING, State.CASTING, State.WAITING, State.BITE, State.REELING]


func try_start(player: Player) -> void:
	if is_active() or UI.conversation_open:
		return
	var gs := GameState
	if not gs.has("tea_served"):
		UI.toast("The pond is quiet. Perhaps the tea stall knows about fishing.")
	elif not gs.has("blue_met"):
		UI.toast("The blue spirit beside the dock wants a word first.")
	elif not gs.has("has_rod"):
		UI.toast("You'll need a rod. The tea keeper lends one with your first bait.")
	elif gs.bait() < 1:
		UI.toast("Out of bait. The tea keeper sells it for 1 coin.")
	else:
		_begin(player)


## E while a session is active. Anything outside BITE / CATCH_REVEAL is ignored.
func handle_action() -> void:
	match state:
		State.AIMING:
			_swing_cast()
		State.BITE:
			_strike()
		State.CATCH_REVEAL:
			_release()


## Right-click does everything E does while fishing.
func _unhandled_input(event: InputEvent) -> void:
	if state != State.IDLE and event.is_action_pressed("fish_action") and not get_tree().paused and not UI.conversation_open:
		get_viewport().set_input_as_handled()
		handle_action()


func _reel_held() -> bool:
	return autoplay or Input.is_action_pressed("interact") or Input.is_action_pressed("fish_action")


func get_action_prompt() -> String:
	match state:
		State.AIMING:
			return "Aim at the water · Right-click or E to cast   ·   Esc to stop" if _rod_ready else ""
		State.WAITING:
			return "Watch the bobber…   Esc to pause"
	return ""


## The big card for the moments that need the player: a bite, the fight, the catch.
func get_action_card() -> Dictionary:
	match state:
		State.BITE:
			return {"title": "A tug! Strike!", "action": "Strike"}
		State.REELING:
			return {"title": "Reel it in!", "action": "Hold to reel", "progress": _reel, "tension": _tension}
		State.CATCH_REVEAL:
			return {"title": "A Moonfin!", "action": "Keep it"}
	return {}


func cancel() -> void:
	if not can_cancel():
		return
	_end_session()
	UI.toast("You reel in your line. No bait used.")


## Debug captures only: drops any session without committing.
func cancel_for_capture() -> void:
	_end_session()


# --- Session flow -----------------------------------------------------------------

func _begin(player: Player) -> void:
	_session += 1
	_pending_catch = true
	# Rod comes up; the player aims and casts when ready.
	state = State.AIMING
	_rod_ready = false
	_player = player
	player.lock("fishing")
	player.action_handler = self
	if _rod.get_parent() != player.camera:
		_rod.get_parent().remove_child(_rod)
		player.camera.add_child(_rod)
	_rod.position = ROD_HIDDEN
	_rod.rotation_degrees = ROD_ROTATION
	_rod.show()
	player.face_toward(cast_anchor + Vector3(0, 0.9, 0), 0.5)
	_tween = create_tween()
	_tween.tween_property(_rod, "position", ROD_SHOWN, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.tween_callback(_rod_up.bind(_session))


func _rod_up(s: int) -> void:
	if s != _session:
		return
	_rod_ready = true
	if autoplay:
		_swing_cast()


## Back-swing over the shoulder, then a flick forward that sends the bobber out
## to the water where you're looking.
func _swing_cast() -> void:
	if state != State.AIMING or not _rod_ready:
		return
	state = State.CASTING
	cast_point = _aim_point()
	var s := _session
	var base := ROD_ROTATION
	_tween = create_tween()
	_tween.tween_property(_rod, "rotation_degrees", base + Vector3(48, 6, 4), 0.24).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_tween.tween_property(_rod, "rotation_degrees", base + Vector3(-22, -4, -2), 0.13).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_tween.tween_callback(_cast.bind(s))
	_tween.tween_property(_rod, "rotation_degrees", base, 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


## The water spot in front of the player: farther when looking up a little,
## always kept inside the pond.
func _aim_point() -> Vector3:
	if autoplay or not is_instance_valid(_player):
		return cast_anchor
	var fwd := -_player.camera.global_basis.z
	var flat := Vector2(fwd.x, fwd.z)
	if flat.length() < 0.1:
		return cast_anchor
	flat = flat.normalized()
	var dist := clampf(7.0 + _player.camera.rotation.x * 9.0, 4.0, 10.0)
	var p := Vector2(_player.global_position.x, _player.global_position.z) + flat * dist
	var k := Layout.pond_k(p)
	if k > 0.8:
		p *= 0.8 / k
	return Vector3(p.x, Layout.WATER_Y, p.y)


func _cast(s: int) -> void:
	if s != _session:
		return
	state = State.CASTING
	Sfx.play("whoosh", -2.0)
	Sfx.play("line_out", -9.0)
	var from := _rod_tip.global_position
	_bobber.global_position = from
	_bobber.rotation = Vector3.ZERO
	_bobber.show()
	_line.show()
	var fly := create_tween()
	fly.tween_method(_arc.bind(_bobber, from, cast_point, 1.3), 0.0, 1.0, 0.95)
	fly.tween_callback(_on_landed.bind(s))


func _on_landed(s: int) -> void:
	if s != _session:
		return
	Sfx.play_at("plop", cast_point)
	Fx.ripple(self, cast_point, 0.8)
	state = State.WAITING
	_wait_session = s
	var wait := randf_range(4.0, 7.0)
	_timer.start(wait)
	# The plop scares close fish away; a curious one comes to inspect.
	var pond := _pond()
	if pond:
		pond.scatter(cast_point, 1.8)
		_lured = pond.attract(cast_point, wait - 0.4)


func _on_wait_finished() -> void:
	if state != State.WAITING or _wait_session != _session:
		return
	state = State.BITE
	_bite_left = BITE_WINDOW
	_next_bite_ripple = 0.0
	Sfx.play("bite")
	Fx.ripple(self, cast_point, 0.6, 1.0, 0.8)


## Too slow: the fish only nibbled. The bait stays on; wait for the next bite.
func _missed_bite() -> void:
	state = State.WAITING
	_wait_session = _session
	_timer.start(randf_range(3.0, 6.0))
	UI.toast("It nibbled and let go. Watch for the next bite…")


## Strike: the hook sets with a sharp tug of the rod, and the fight begins.
func _strike() -> void:
	state = State.REELING
	var pond := _pond()
	if pond and _lured >= 0:
		pond.hook(_lured)
	Sfx.play("whoosh", -6.0, 1.5)
	Sfx.play_at("splash", cast_point, -4.0, 1.1)
	Sfx.play_at("thrash", cast_point, -4.0)
	Fx.splash(self, cast_point, 10, 1.2)
	_reel = 0.0
	_tension = 0.0
	_surge = 0.0
	_next_surge = 0.5
	_reel_from = cast_point
	var tip := _rod_tip.global_position
	_reel_to = Vector3(tip.x, Layout.WATER_Y, tip.z).lerp(cast_point, 0.18)
	var t := create_tween()
	t.tween_property(_rod, "rotation_degrees", ROD_ROTATION + Vector3(26, 0, 0), 0.1)
	t.tween_property(_rod, "rotation_degrees", ROD_ROTATION, 0.3)


## Holding reels the fish closer; it pulls back in bursts, and reeling hard
## through a burst builds tension until it takes some line back.
func _update_reel(delta: float) -> void:
	var held := _reel_held()
	if autoplay:
		_reel = minf(_reel + delta * 0.9, 1.0)
	else:
		_next_surge -= delta
		if _next_surge <= 0.0:
			_surge = randf_range(0.5, 0.9)
			_next_surge = randf_range(1.3, 2.6)
			Sfx.play_at("thrash", _bobber.global_position, -6.0, randf_range(0.95, 1.1))
			Fx.splash(self, _bobber.global_position, 6, 0.8)
		var surging := _surge > 0.0
		_surge = maxf(_surge - delta, 0.0)
		if held:
			_reel += delta * (SURGE_RATE if surging else REEL_RATE)
			_tension += delta * (1.4 if surging else -0.7)
		else:
			_tension -= delta * 1.4
			if surging:
				_reel -= delta * 0.08
		_tension = clampf(_tension, 0.0, 1.0)
		if _tension >= 1.0:
			# Too much strain: the fish runs and takes line, no harm done.
			_reel -= 0.12
			_tension = 0.35
			# The drag gives with a zip of line.
			Sfx.play("line_out", -6.0, 1.15)
		_reel = clampf(_reel, 0.0, 1.0)
	_set_reel_sound(held or autoplay, _surge > 0.0)
	# The hooked fish drags the float under and thrashes side to side.
	var side := (_reel_to - _reel_from).cross(Vector3.UP).normalized()
	var thrash := sin(_t * (14.0 if _surge > 0.0 else 4.0)) * (0.35 if _surge > 0.0 else 0.12) * (1.0 - _reel)
	_bobber.global_position = _reel_from.lerp(_reel_to, _reel) + side * thrash + Vector3(0, -0.06, 0)
	_next_bite_ripple -= delta
	if _next_bite_ripple <= 0.0:
		_next_bite_ripple = 0.35
		Fx.ripple(self, Vector3(_bobber.global_position.x, Layout.WATER_Y, _bobber.global_position.z), 0.4, 0.7, 0.5)
	# The rod bends toward the fish, more while it pulls.
	var bend := 14.0 + (16.0 if _surge > 0.0 else 0.0) + _tension * 8.0
	var shake := sin(_t * 23.0) * (2.0 if _surge > 0.0 else 0.5)
	_rod.rotation_degrees = _rod.rotation_degrees.lerp(ROD_ROTATION + Vector3(-bend, shake, shake * 0.5), clampf(delta * 10.0, 0.0, 1.0))
	if _reel >= 1.0:
		_rod.rotation_degrees = ROD_ROTATION
		_reveal(_session)


func _reveal(s: int) -> void:
	if s != _session:
		return
	state = State.CATCH_REVEAL
	var start := _bobber.global_position
	_bobber.hide()
	Sfx.play_at("splash", start, -8.0, 1.2)
	Fx.splash(self, start, 12, 1.4)
	Sfx.play("sparkle")
	# Lifted out on the line: it hangs head-up under the rod tip, swinging and
	# wriggling, side-on to you (see _hang).
	_lift_from = start
	_lift = 0.0
	_fish.scale = Vector3.ONE
	_fish.show()
	_hang(0.0)
	if _fish_anim:
		_fish_anim.play("flop", 0.1)
	_tween = create_tween()
	_tween.tween_property(self, "_lift", 1.0, 0.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _release() -> void:
	state = State.RELEASING
	var s := _session
	# Unhooked and swung into the basket of water on the dock.
	var from := _fish.global_position
	var to := (_basket.global_position + Vector3(0, 0.3, 0)) if _basket else from + Vector3(0, -0.4, 0)
	Sfx.play("whoosh", -10.0, 1.3)
	var dive := Basis(_fish.global_basis.x, PI).get_rotation_quaternion() * _fish.global_basis.get_rotation_quaternion()
	_tween = create_tween()
	_tween.tween_method(_arc.bind(_fish, from, to, 0.35), 0.0, 1.0, 0.7).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tween.parallel().tween_property(_fish, "quaternion", dive, 0.6)
	_tween.parallel().tween_property(_fish, "scale", Vector3.ONE * 0.45, 0.7)
	_tween.tween_callback(_on_released.bind(s))


func _on_released(s: int) -> void:
	if s != _session:
		return
	var pos := _fish.global_position
	_fish.hide()
	_fish.scale = Vector3.ONE
	# This fish is kept; another swims into the pond from the stream later,
	# so the pond never runs empty.
	var pond := _pond()
	if pond and _lured >= 0:
		pond.replace(_lured)
		_lured = -1
	_line.hide()
	Sfx.play_at("plop", pos, -3.0, 1.1)
	_commit(s)
	_refresh_basket()


## The only place a fishing session changes saved state.
func _commit(s: int) -> void:
	if s != _session or not _pending_catch:
		return
	_pending_catch = false
	var result := GameState.commit_release()
	_end_session()
	if not result["ok"]:
		return
	Sfx.play("reward")
	UI.toast("Moonfin kept in the basket · +%d coins" % GameState.RELEASE_REWARD, UI.GOLD)
	if result["first"]:
		var blue := get_tree().get_first_node_in_group("blue_spirit")
		if blue:
			blue.on_first_release()


# --- Basket of kept fish ------------------------------------------------------------------

var _basket: Node3D
var _basket_fish: Array[Node3D] = []


## A wooden bucket of pond water beside the fishing spot. Up to three of the
## Moonfins you've kept circle slowly inside it.
func _build_basket() -> void:
	var dock := get_node_or_null("../Props/Dock") as Node3D
	if dock == null:
		return
	_basket = Node3D.new()
	_basket.name = "FishBasket"
	dock.add_child(_basket)
	_basket.position = Vector3(0.95, 0.12, -1.85)
	var wood := PH.mat(Color("7a5536"), 0.85).duplicate() as StandardMaterial3D
	wood.cull_mode = BaseMaterial3D.CULL_DISABLED  # open bucket: the inside shows
	var band_mat := PH.mat(Color("3d3a36"), 0.5, Color.BLACK, 0.0, 0.6)
	var tub := PH.cyl(_basket, 0.23, 0.2, 0.36, Vector3(0, 0.18, 0), wood, Vector3.ZERO, 18)
	(tub.mesh as CylinderMesh).cap_top = false
	for y in [0.06, 0.33]:
		PH.torus(_basket, 0.215 + y * 0.06, 0.24 + y * 0.06, Vector3(0, y, 0), band_mat)
	# Clear water, so the fish you've kept are visible circling inside.
	var wm := StandardMaterial3D.new()
	wm.albedo_color = Color(0.3, 0.55, 0.55, 0.35)
	wm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	wm.roughness = 0.05
	wm.metallic_specular = 0.8
	var water := PH.cyl(_basket, 0.21, 0.21, 0.004, Vector3(0, 0.28, 0), wm, Vector3.ZERO, 18)
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var body := PH.static_body(_basket, "wood")
	PH.cylinder_shape(body, 0.24, 0.36, Vector3(0, 0.18, 0))
	for i in 3:
		var holder := Node3D.new()
		_basket.add_child(holder)
		var f := FishArt.build(holder, "moonfin", false)
		f.scale = Vector3.ONE * 0.4
		f.position = Vector3(0.09, 0.17, 0)
		f.rotation.y = PI * 0.5
		holder.rotation.y = TAU * i / 3.0
		_basket_fish.append(holder)
	_refresh_basket()
	GameState.changed.connect(_refresh_basket)


func _refresh_basket() -> void:
	var n := mini(int(GameState.data.get("release_count", 0)), 3)
	for i in _basket_fish.size():
		_basket_fish[i].visible = i < n


func _end_session() -> void:
	var pond := _pond()
	if pond and _lured >= 0:
		pond.unlure(_lured)
	_lured = -1
	_session += 1
	_pending_catch = false
	_timer.stop()
	if _tween:
		_tween.kill()
	state = State.IDLE
	_rod_ready = false
	_rod.rotation_degrees = ROD_ROTATION
	_bobber.hide()
	_fish.hide()
	_line.hide()
	_line_mesh.clear_surfaces()
	if is_instance_valid(_player):
		_player.action_handler = null
		_player.unlock("fishing")
		var t := create_tween()
		t.tween_property(_rod, "position", ROD_HIDDEN, 0.35).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		t.tween_callback(_hide_rod_if_idle)
	_player = null


func _pond() -> PondLife:
	return get_tree().get_first_node_in_group("pond_life") as PondLife


func _hide_rod_if_idle() -> void:
	if state == State.IDLE:
		_rod.hide()


## Winding sound: the ratchet runs while you hold, a little slower and lower
## while the fish is pulling against you.
func _set_reel_sound(on: bool, straining := false) -> void:
	if _reel_sound == null or _reel_sound.stream == null:
		return
	if on and not _reel_sound.playing:
		_reel_sound.play(randf() * 4.0)
	elif not on and _reel_sound.playing:
		_reel_sound.stop()
	_reel_sound.pitch_scale = 0.85 if straining else 1.0


# --- Per-frame visuals ---------------------------------------------------------------

func _process(delta: float) -> void:
	_t += delta
	for i in _basket_fish.size():
		_basket_fish[i].rotation.y += delta * (0.5 + 0.15 * i)
	match state:
		State.AIMING:
			# Holding the rod: a gentle sway with your breathing.
			if _rod_ready:
				_rod.rotation_degrees = ROD_ROTATION + Vector3(sin(_t * 1.3) * 1.5, 0, sin(_t * 0.9) * 1.0)
		State.WAITING:
			_bobber.global_position = cast_point + Vector3(0, sin(_t * 2.1) * 0.012, 0)
			_bobber.rotation.z = sin(_t * 1.3) * 0.1
		State.BITE:
			var dip := maxf(sin(_t * 7.5), 0.0) * 0.07
			_bobber.global_position = cast_point + Vector3(0, -dip, 0)
			_bobber.rotation.z = sin(_t * 9.0) * 0.25
			_next_bite_ripple -= delta
			if _next_bite_ripple <= 0.0:
				_next_bite_ripple = 0.9
				Fx.ripple(self, cast_point, 0.45, 0.9, 0.6)
			if not autoplay and not get_tree().paused:
				_bite_left -= delta
				if _bite_left <= 0.0:
					_missed_bite()
		State.REELING:
			_update_reel(delta)
		_:
			_set_reel_sound(false)
		State.CATCH_REVEAL:
			_hang(delta)
	_update_line()


func _update_line() -> void:
	_line_mesh.clear_surfaces()
	if not _line.visible or not is_instance_valid(_player):
		return
	var a := _rod_tip.global_position
	var b := _bobber.global_position + Vector3(0, 0.06, 0)
	if _fish.visible:
		b = _fish.global_transform * _fish_mouth
	var taut := state in [State.REELING, State.CATCH_REVEAL, State.RELEASING]
	var sag := clampf(a.distance_to(b) * (0.015 if taut else 0.07), 0.01, 0.6)
	var cam := _player.camera.global_position
	var dir := (b - a).normalized()
	_line_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP, _line_mat)
	for i in 21:
		var t := i / 20.0
		var p := a.lerp(b, t)
		p.y -= sin(t * PI) * sag
		var side := dir.cross(cam - p).normalized() * 0.0028
		_line_mesh.surface_add_vertex(p - side)
		_line_mesh.surface_add_vertex(p + side)
	_line_mesh.surface_end()


## The catch dangling from the line like a real fish: mouth on the hook, tail
## down, side turned toward the player, swinging as a pendulum and twisting.
func _hang(_delta: float) -> void:
	if not is_instance_valid(_player):
		return
	var tip := _rod_tip.global_position
	var hang := tip + Vector3(sin(_t * 1.6) * 0.07, -0.7, cos(_t * 1.2) * 0.05)
	var attach := _lift_from.lerp(hang, _lift)
	var to_cam := _player.camera.global_position - attach
	to_cam.y = 0.0
	to_cam = to_cam.normalized() if to_cam.length() > 0.01 else Vector3.BACK
	var z := Vector3.UP
	var x := to_cam.rotated(Vector3.UP, sin(_t * 2.3) * 0.5)
	var y := z.cross(x)
	var b := Basis(x, y, z).orthonormalized()
	# A little sideways swing of the whole fish around the hook.
	b = Basis(to_cam, sin(_t * 1.6) * 0.12) * b
	_fish.global_basis = b
	_fish.global_position = attach - b * _fish_mouth


func _arc(t: float, node: Node3D, from: Vector3, to: Vector3, height: float) -> void:
	var p := from.lerp(to, t)
	p.y += sin(t * PI) * height
	node.global_position = p


# --- Construction ----------------------------------------------------------------------

## The Tripo rod lies diagonally in its file: butt, tip direction and the side
## the reel hangs on were measured from the mesh (Godot axes, model scale).
const ROD_BUTT := Vector3(-0.5267, 0.028, 0.7926)
const ROD_FORWARD := Vector3(0.5006, 0.3174, -0.8054)
const ROD_REEL_SIDE := Vector3(-0.1426, -0.8874, -0.4383)
const ROD_LENGTH := 2.03
const ROD_GAME_LENGTH := 1.7


func _build_rod() -> void:
	_rod = Node3D.new()
	_rod.name = "Rod"
	add_child(_rod)
	_rod.hide()
	var scene := rod_model if rod_model else ModelLib.scene("fishing_rod")
	if scene:
		# Turn the model so its butt sits at the grip, tip along -Z, reel below.
		var inst := scene.instantiate() as Node3D
		var y_m := -ROD_REEL_SIDE.normalized()
		var z_m := -ROD_FORWARD.normalized()
		var x_m := y_m.cross(z_m).normalized()
		y_m = z_m.cross(x_m)
		var s := ROD_GAME_LENGTH / ROD_LENGTH
		var b := Basis(x_m, y_m, z_m).transposed().scaled(Vector3.ONE * s)
		inst.transform = Transform3D(b, -(b * ROD_BUTT))
		_rod.add_child(inst)
	else:
		var wood := PH.mat(Color("8d5b34"), 0.55)
		var brass := PH.mat(PH.BRASS, 0.3, Color.BLACK, 0.0, 0.85)
		var grip := PH.mat(Color("efe0c0"), 0.9)
		PH.cyl(_rod, 0.017, 0.019, 0.32, Vector3(0, 0, -0.1), grip, Vector3(90, 0, 0), 12)
		PH.cyl(_rod, 0.022, 0.022, 0.03, Vector3(0, 0, -0.27), brass, Vector3(90, 0, 0), 12)
		PH.cyl(_rod, 0.035, 0.035, 0.025, Vector3(0, -0.04, -0.2), brass, Vector3(0, 0, 90), 14)
		PH.limb(_rod, Vector3(0, 0, -0.27), Vector3(0, 0, -1.7), 0.011, 0.004, wood, 8)
		for z in [-0.6, -0.95, -1.3, -1.6]:
			PH.torus(_rod, 0.006, 0.01, Vector3(0, 0.012, z), brass, Vector3(0, 0, 0))
	_rod_tip = Node3D.new()
	_rod_tip.position = Vector3(0, 0.01, -1.7)
	_rod.add_child(_rod_tip)


func _build_bobber() -> void:
	_bobber = Node3D.new()
	_bobber.name = "Bobber"
	_bobber.top_level = true
	add_child(_bobber)
	_bobber.hide()
	var bob := bobber_model if bobber_model else ModelLib.scene("bobber")
	if bob:
		# Real floats ride half under: the red cap shows, the white belly is wet.
		var inst := bob.instantiate() as Node3D
		inst.scale = Vector3.ONE * 0.75
		inst.position.y = -0.03
		_bobber.add_child(inst)
		return
	PH.sphere(_bobber, 0.05, Vector3(0, 0.02, 0), PH.mat(PH.CORAL, 0.4, PH.CORAL, 0.25), Vector3(1, 0.9, 1), 16)
	PH.sphere(_bobber, 0.048, Vector3(0, -0.012, 0), PH.mat(Color("f3ead6"), 0.4), Vector3(1, 0.8, 1), 16)
	PH.torus(_bobber, 0.046, 0.054, Vector3(0, 0.004, 0), PH.mat(PH.NAVY, 0.5))
	PH.cyl(_bobber, 0.006, 0.008, 0.06, Vector3(0, 0.08, 0), PH.mat(Color("f3ead6"), 0.5))


func _build_fish() -> void:
	_fish = Node3D.new()
	_fish.name = "Moonfin"
	_fish.top_level = true
	add_child(_fish)
	_fish.hide()
	if fish_model:
		_fish.add_child(fish_model.instantiate())
	else:
		var art := FishArt.build(_fish, "moonfin", false)
		if art.has_meta("anim"):
			# The Tripo Moonfin stands on its belly; its mouth is up and forward.
			_fish_mouth = Vector3(0, 0.075, 0.17)
			_fish_anim = art.get_meta("anim")
	_add_fish_light()


## A small moon-colored fill so the catch reads clearly against night water.
func _add_fish_light() -> void:
	var l := PH.omni(_fish, Vector3(0.25, 0.35, 0.4), Color("e6eeff"), 0.9, 1.6)
	l.remove_from_group("garden_light")


func _build_line() -> void:
	_line_mesh = ImmediateMesh.new()
	_line_mat = StandardMaterial3D.new()
	_line_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_line_mat.albedo_color = Color(0.95, 0.92, 0.82, 0.9)
	_line_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_line = MeshInstance3D.new()
	_line.mesh = _line_mesh
	_line.top_level = true
	_line.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_line)
	_line.hide()
