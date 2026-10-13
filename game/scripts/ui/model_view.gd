class_name ModelView
extends SubViewportContainer
## A small live 3D window showing one of the game's own models (journal pages,
## cards). Own world, transparent background, warm lantern-ish key light, slow
## turntable spin. Keeps running while the game is paused.

var spin_speed := 0.45
var _vp: SubViewport
var _pivot: Node3D
var _cam: Camera3D
var _current := ""


func _init(view_size := Vector2i(400, 230)) -> void:
	stretch = true
	custom_minimum_size = Vector2(view_size)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS
	_vp = SubViewport.new()
	_vp.own_world_3d = true
	_vp.transparent_bg = true
	_vp.msaa_3d = Viewport.MSAA_4X
	_vp.size = view_size
	add_child(_vp)
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("c9c2b0")
	env.ambient_light_energy = 0.7
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var we := WorldEnvironment.new()
	we.environment = env
	_vp.add_child(we)
	var key := DirectionalLight3D.new()
	key.light_color = Color("ffe2b8")
	key.light_energy = 1.6
	key.rotation_degrees = Vector3(-38, -35, 0)
	_vp.add_child(key)
	var rim := DirectionalLight3D.new()
	rim.light_color = Color("a9c4ff")
	rim.light_energy = 0.7
	rim.rotation_degrees = Vector3(-20, 150, 0)
	_vp.add_child(rim)
	_pivot = Node3D.new()
	_vp.add_child(_pivot)
	_cam = Camera3D.new()
	_cam.fov = 28.0
	_vp.add_child(_cam)


## Shows `model_name` from assets/models, framed to fit. Glow adds an emissive
## touch for things that shine in game (moonleaves, Moonfins, lanterns).
func show_model(model_name: String, glow := 0.0, glow_tint := Color.WHITE) -> void:
	if model_name == _current:
		return
	_current = model_name
	for c in _pivot.get_children():
		c.queue_free()
	var scene := ModelLib.scene(model_name)
	if scene == null:
		return
	var inst := scene.instantiate() as Node3D
	_pivot.add_child(inst)
	if glow > 0.0:
		ModelLib.glow(inst, glow, glow_tint)
	var box := _bounds(inst)
	inst.position = -box.get_center()
	_pivot.rotation = Vector3(0, -0.6, 0)
	var radius := box.size.length() * 0.5
	var dist := radius / sin(deg_to_rad(_cam.fov * 0.5)) * 1.05
	_cam.position = Vector3(0, radius * 0.35, dist)
	_cam.look_at(Vector3.ZERO)


func _process(delta: float) -> void:
	_pivot.rotate_y(delta * spin_speed)


static func _bounds(root: Node3D) -> AABB:
	var box := AABB()
	var first := true
	for mi in ModelLib.mesh_instances(root):
		var m := mi as MeshInstance3D
		var local := _relative_transform(root, m) * m.get_aabb()
		box = local if first else box.merge(local)
		first = false
	return box


static func _relative_transform(root: Node3D, node: Node3D) -> Transform3D:
	var t := Transform3D.IDENTITY
	var n: Node = node
	while n != null and n != root:
		if n is Node3D:
			t = (n as Node3D).transform * t
		n = n.get_parent()
	return t
