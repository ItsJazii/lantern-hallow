class_name Player
extends CharacterBody3D
## First-person walker: capsule body, 1.6 m eye camera, a short interaction ray.
## E is routed here first: dialogue > active focus handler (fishing, bench) >
## the interactable under the crosshair.

const WALK_SPEED := 3.0
const ACCEL := 12.0
const EYE_HEIGHT := 1.6
const INTERACT_RANGE := 2.6
const STEP_DISTANCE := 1.2  # metres per footfall: about 2.5 steps a second at walking speed
const JUMP_SPEED := 3.8  # a small hop, about 0.7 m
const MASK_WORLD := 1
const MASK_INTERACT := 4

var camera: Camera3D
var ray: RayCast3D
## Anything that needs E while active: fishing session, bench. Must implement
## handle_action() and get_action_prompt().
var action_handler: Object = null
## While frozen the body skips physics entirely (used when seated).
var frozen := false
## While seated the view may only turn this far (radians) either side of
## look_center, so you can't swivel to stare through your own back. < 0 = free.
var look_limit := -1.0
var look_center := 0.0

var _locks := {}
var _step_accum := 0.0
var _gravity := 9.8
var _focused: Interactable = null


func _ready() -> void:
	add_to_group("player")
	collision_layer = 2
	collision_mask = MASK_WORLD
	floor_snap_length = 0.45
	floor_max_angle = deg_to_rad(42.0)
	var shape := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.32
	cap.height = 1.75
	shape.shape = cap
	shape.position.y = 0.875
	add_child(shape)
	camera = Camera3D.new()
	camera.position.y = EYE_HEIGHT
	camera.fov = 75.0
	camera.near = 0.03
	camera.far = 500.0
	add_child(camera)
	camera.make_current()
	ray = RayCast3D.new()
	ray.target_position = Vector3(0, 0, -INTERACT_RANGE)
	ray.collision_mask = MASK_WORLD | MASK_INTERACT
	ray.collide_with_areas = true
	camera.add_child(ray)


# --- Locks --------------------------------------------------------------------------

func lock(reason: String) -> void:
	_locks[reason] = true


func unlock(reason: String) -> void:
	_locks.erase(reason)


func is_locked() -> bool:
	return not _locks.is_empty()


# --- Camera helpers -------------------------------------------------------------------

func look_angles_to(point: Vector3) -> Vector2:
	var eye := global_position + Vector3(0, camera.position.y, 0)
	var d := point - eye
	var yaw := atan2(-d.x, -d.z)
	var pitch := atan2(d.y, Vector2(d.x, d.z).length())
	return Vector2(yaw, pitch)


## Smoothly turns the view toward a world point.
func face_toward(point: Vector3, duration := 0.6) -> Tween:
	var a := look_angles_to(point)
	var yaw := rotation.y + wrapf(a.x - rotation.y, -PI, PI)
	var t := create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(self, "rotation:y", yaw, duration)
	t.tween_property(camera, "rotation:x", clampf(a.y, -1.3, 1.3), duration)
	return t


func set_view(yaw: float, pitch: float) -> void:
	rotation.y = yaw
	camera.rotation.x = clampf(pitch, -1.4, 1.4)


# --- Input ---------------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var rel := (event as InputEventMouseMotion).screen_relative
		var sens := 0.0006 + Settings.mouse_sensitivity * 0.004
		rotate_y(-rel.x * sens)
		if look_limit >= 0.0:
			var d := wrapf(rotation.y - look_center, -PI, PI)
			rotation.y = look_center + clampf(d, -look_limit, look_limit)
		camera.rotation.x = clampf(camera.rotation.x - rel.y * sens * (-1.0 if Settings.invert_y else 1.0), deg_to_rad(-82), deg_to_rad(82))
	elif event.is_action_pressed("interact"):
		get_viewport().set_input_as_handled()
		_on_action()


func _on_action() -> void:
	if UI.conversation_open:
		UI.advance()
	elif action_handler != null:
		action_handler.handle_action()
	elif not is_locked() and is_instance_valid(_focused):
		_focused.interact(self)


# --- Simulation ------------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if frozen:
		velocity = Vector3.ZERO
		return
	if not is_on_floor():
		velocity.y -= _gravity * delta
	var input := Vector2.ZERO
	if not is_locked():
		input = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	if not is_locked() and is_on_floor() and Input.is_action_just_pressed("jump"):
		velocity.y = JUMP_SPEED
		_footstep("jump")
	var dir := transform.basis * Vector3(input.x, 0.0, input.y)
	dir.y = 0.0
	var target := dir.normalized() * WALK_SPEED * minf(input.length(), 1.0)
	velocity.x = move_toward(velocity.x, target.x, ACCEL * delta)
	velocity.z = move_toward(velocity.z, target.z, ACCEL * delta)
	var falling := -velocity.y
	var was_air := not is_on_floor()
	move_and_slide()
	if was_air and is_on_floor():
		if falling > 2.5:
			_footstep("land")
			_step_accum = 0.0
		elif falling > 1.2:
			# Stepping down off a ledge: an ordinary footfall.
			_footstep()
			_step_accum = 0.0
	if is_on_floor():
		var speed := Vector2(velocity.x, velocity.z).length()
		if speed < 0.2:
			# Standing still: the first step of the next walk lands right away.
			_step_accum = STEP_DISTANCE * 0.8
		_step_accum += speed * delta
		if _step_accum >= STEP_DISTANCE:
			_step_accum = 0.0
			_footstep()


func _process(_delta: float) -> void:
	var prompt := ""
	var badge := true
	var card := {}
	_focused = null
	if UI.conversation_open:
		prompt = ""
	elif action_handler != null:
		prompt = action_handler.get_action_prompt()
		badge = false
		if action_handler.has_method("get_action_card"):
			card = action_handler.get_action_card()
	elif not is_locked():
		var it := _find_interactable()
		if it:
			prompt = it.get_prompt()
			if prompt != "":
				_focused = it
	UI.set_prompt(prompt, badge)
	UI.set_fishing_card(str(card.get("title", "")), str(card.get("action", "")), float(card.get("progress", -1.0)), float(card.get("tension", 0.0)))
	UI.set_dot_active(_focused != null)


func _find_interactable() -> Interactable:
	if not ray.is_colliding():
		return null
	var c := ray.get_collider()
	if c == null or not c.has_meta("interactable"):
		return null
	var it: Variant = c.get_meta("interactable")
	if it is Interactable and is_instance_valid(it):
		return it
	return null


## Plays the footfall for the ground underfoot: a step, the push-off of a jump,
## or a landing. Surfaces without their own jump/landing takes use a heavier step.
func _footstep(kind := "step") -> void:
	var surface := _surface()
	var pitch := randf_range(0.95, 1.05)
	match kind:
		"jump":
			if Sfx.has_clip("jump_" + surface):
				Sfx.play("jump_" + surface, -9.0, pitch)
			else:
				Sfx.play("step_" + surface, -10.0, pitch * 1.03)
		"land":
			if Sfx.has_clip("land_" + surface):
				Sfx.play("land_" + surface, -10.0, pitch)
			else:
				Sfx.play("step_" + surface, -5.0, pitch * 0.92)
		_:
			Sfx.play("step_" + surface, -11.0, pitch)


func _surface() -> String:
	var surface := "grass"
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP * 0.3, global_position + Vector3.DOWN * 0.4, MASK_WORLD)
	var hit := space.intersect_ray(q)
	if hit:
		var col: Object = hit["collider"]
		if col.has_meta("surface"):
			surface = str(col.get_meta("surface"))
		if surface == "terrain":
			var p := Vector2(global_position.x, global_position.z)
			if Layout.pond_k(p) < 1.1 or Layout.stream_distance(p) < Layout.STREAM_HALF_WIDTH + 1.0:
				surface = "sand"
			elif Layout.path_factor(p) > 0.5:
				surface = "dirt"
			else:
				surface = "grass"
	return surface
