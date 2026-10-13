class_name Npc
extends Interactable
## Shared NPC behavior. Models with an AnimationPlayer (e.g. the rigged keeper)
## loop "idle", switch to "talk" while their own lines are on screen, and can
## play one-shot reactions ("wave", "happy"). Models without animations fall
## back to a gentle procedural idle (bob, sway or breathing). No walking AI.

@export var speaker := ""
@export var bob_height := 0.0
@export var bob_speed := 1.6
@export var sway_degrees := 0.0
@export var breathe := 0.0
@export var solid_radius := 0.0
@export var solid_height := 1.0

const LOOPING := ["idle", "talk"]

var anim: AnimationPlayer
var _base_anim := "idle"
var _t := 0.0
var _hop := 0.0


func _setup() -> void:
	_t = randf() * 10.0
	if solid_radius > 0.0:
		var body := PH.static_body(self)
		PH.cylinder_shape(body, solid_radius, solid_height, Vector3(0, solid_height * 0.5, 0))
	# Soft contact shadow for anyone standing on land (not the floating blue spirit).
	if Layout.pond_k(Vector2(global_position.x, global_position.z)) > 1.0:
		GroundDetail.contact_shadow(self, Vector2.ONE * maxf(solid_radius * 3.0, 0.85), 0.6)
	anim = _find_animation_player(visual)
	if anim:
		for a in LOOPING:
			if anim.has_animation(a):
				anim.get_animation(a).loop_mode = Animation.LOOP_LINEAR
		anim.animation_finished.connect(_on_animation_finished)
		_play(_base_anim, 0.0)
		# Seed the idle at a random point so several NPCs never move in sync.
		if anim.is_playing():
			anim.seek(randf() * anim.current_animation_length, true)
		UI.line_shown.connect(_on_line_shown)
		UI.conversation_closed.connect(_on_conversation_closed)


func _process(delta: float) -> void:
	_t += delta
	var y := sin(_t * bob_speed) * bob_height
	if _hop > 0.0:
		_hop = maxf(_hop - delta, 0.0)
		y += sin((1.0 - _hop / 0.45) * PI) * 0.12
	visual.position.y = y
	if anim:
		return
	if sway_degrees > 0.0:
		visual.rotation.y = deg_to_rad(sin(_t * 0.6) * sway_degrees)
	if breathe > 0.0:
		var s := 1.0 + sin(_t * 1.9) * breathe
		visual.scale = Vector3(1.0 + (s - 1.0) * 0.5, s, 1.0 + (s - 1.0) * 0.5)


func hop() -> void:
	_hop = 0.45


## A happy reaction: the model's own "happy" animation, or a little hop.
func cheer() -> void:
	if not react("happy"):
		hop()


## Plays a one-shot reaction, then returns to idle/talk. False if unavailable.
func react(anim_name: String) -> bool:
	if anim == null or not anim.has_animation(anim_name):
		return false
	_play(anim_name, 0.25)
	return true


func talk_start() -> void:
	UI.open_conversation()


func talk_end() -> void:
	UI.close_conversation()


func _play(anim_name: String, blend: float) -> void:
	if anim and anim.has_animation(anim_name):
		anim.play(anim_name, blend)


func _on_line_shown(line_speaker: String) -> void:
	var next := "talk" if line_speaker == speaker else "idle"
	if next == _base_anim:
		return
	_base_anim = next
	if not _is_reacting():
		_play(_base_anim, 0.35)


func _on_conversation_closed() -> void:
	_base_anim = "idle"
	if not _is_reacting():
		_play("idle", 0.5)


func _on_animation_finished(finished: StringName) -> void:
	if not String(finished) in LOOPING:
		_play(_base_anim, 0.35)


func _is_reacting() -> bool:
	return anim != null and anim.is_playing() and not String(anim.current_animation) in LOOPING


static func _find_animation_player(root: Node) -> AnimationPlayer:
	if root is AnimationPlayer:
		return root
	for c in root.get_children():
		var found := _find_animation_player(c)
		if found:
			return found
	return null
