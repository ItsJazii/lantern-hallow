class_name GardenMap
extends ColorRect
## The garden map (M). The picture is a real top-down render of the garden,
## taken by an orthographic camera in the live world each time the map opens,
## brightened and framed as a parchment chart. On top: place names, a gold
## pulse on where the current quest wants you, and an arrow for you, pointing
## the way you're facing.

## World area shown (XZ): the whole garden plus the entry lane.
const AREA := Rect2(-37.0, -30.0, 74.0, 68.0)
const MAP_SIZE := Vector2(940, 864)

const PLACES := [
	["Tea Stall", Vector2(-23.6, 0.6)],
	["Giant Tree", Vector2(-31.0, -10.5)],
	["Moonleaf Grove", Vector2(16.0, -16.8)],
	["Moon Pond", Vector2(-2.0, -1.0)],
	["Dock", Vector2(10.6, 9.0)],
	["Bridge", Vector2(-14.9, 13.6)],
	["Bench", Vector2(0.0, 20.2)],
	["Garden Gate", Vector2(-10.0, 34.5)],
]

var ui: Node
var _vp: SubViewport
var _cam: Camera3D
var _picture: TextureRect
var _overlay: Control
var _goal_label: Label
var _t := 0.0
var _chips: Array[Control] = []


func build(owner_ui: Node) -> void:
	ui = owner_ui
	color = Color(0.02, 0.04, 0.08, 0.45)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	process_mode = Node.PROCESS_MODE_ALWAYS
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	var card: PanelContainer = ui._card(true, Vector4(84, 26, 44, 26))
	center.add_child(card)
	var v: VBoxContainer = ui._vbox(8)
	card.add_child(v)
	var head: HBoxContainer = ui._hbox(12)
	v.add_child(head)
	head.add_child(ui._icon_rect("leaf", 40, ui.LEAF_TINT, "leaf_cream"))
	var title: Label = ui._label(42, ui.INK, true)
	title.text = "Lantern Hollow"
	head.add_child(title)
	head.add_child(ui._hspacer())
	head.add_child(ui._key("M", 18))
	var close: Label = ui._label(21, ui.INK_SOFT)
	close.text = "Close"
	head.add_child(close)

	var frame := PanelContainer.new()
	var fsb := StyleBoxFlat.new()
	fsb.bg_color = Color("3a2c1c")
	fsb.set_border_width_all(4)
	fsb.border_color = Color("9a7444")
	fsb.set_corner_radius_all(6)
	frame.add_theme_stylebox_override("panel", fsb)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(frame)
	var holder := Control.new()
	holder.custom_minimum_size = MAP_SIZE
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(holder)
	_picture = TextureRect.new()
	_picture.set_anchors_preset(Control.PRESET_FULL_RECT)
	_picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_picture.stretch_mode = TextureRect.STRETCH_SCALE
	# A warm, slightly faded wash so the live render reads as a chart.
	_picture.modulate = Color(1.08, 1.02, 0.9)
	_picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(_picture)
	_overlay = Control.new()
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.draw.connect(_draw_markers)
	holder.add_child(_overlay)
	for place in PLACES:
		var chip := PanelContainer.new()
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.95, 0.89, 0.76, 0.88)
		sb.set_corner_radius_all(5)
		sb.content_margin_left = 8
		sb.content_margin_right = 8
		sb.content_margin_top = 1
		sb.content_margin_bottom = 2
		sb.shadow_color = Color(0, 0, 0, 0.35)
		sb.shadow_size = 3
		chip.add_theme_stylebox_override("panel", sb)
		chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var l: Label = ui._label(19, ui.INK, true)
		l.text = place[0]
		chip.add_child(l)
		holder.add_child(chip)
		chip.set_meta("world", place[1])
		_chips.append(chip)

	var foot: HBoxContainer = ui._hbox(10)
	v.add_child(foot)
	var dot := Panel.new()
	var dsb := StyleBoxFlat.new()
	dsb.bg_color = Color("f2b65d")
	dsb.set_corner_radius_all(8)
	dot.add_theme_stylebox_override("panel", dsb)
	dot.custom_minimum_size = Vector2(16, 16)
	dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	foot.add_child(dot)
	_goal_label = ui._label(21, ui.INK_SOFT)
	_goal_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_goal_label.custom_minimum_size = Vector2(780, 0)
	foot.add_child(_goal_label)
	hide()


func _place_chip(chip: Control) -> void:
	var w: Vector2 = chip.get_meta("world")
	chip.position = to_map(w) - Vector2(chip.size.x * 0.5, chip.size.y * 0.5)


func to_map(w: Vector2) -> Vector2:
	return (w - AREA.position) / AREA.size * MAP_SIZE


## Re-renders the garden from above, then shows the map.
func open() -> void:
	_render()
	var o: Dictionary = Objectives.current()
	_goal_label.text = "%s: %s" % [o["quest"], str(o["text"]).replace("\n", " ")]
	show()
	_place_chips.call_deferred()


func _place_chips() -> void:
	for chip in _chips:
		chip.reset_size()
		_place_chip(chip)


func _render() -> void:
	var world := get_tree().current_scene.get_viewport().world_3d
	if _vp == null:
		_vp = SubViewport.new()
		_vp.size = Vector2i(MAP_SIZE)
		_vp.msaa_3d = Viewport.MSAA_4X
		add_child(_vp)
		_cam = Camera3D.new()
		_cam.projection = Camera3D.PROJECTION_ORTHOGONAL
		_cam.keep_aspect = Camera3D.KEEP_HEIGHT
		_cam.size = AREA.size.y
		_cam.far = 200.0
		# Skip grass and other small clutter so paths and places read clearly.
		_cam.cull_mask = 0xFFFFF & ~WaterReflection.LAYER_SMALL
		_vp.add_child(_cam)
	_vp.world_3d = world
	var c := AREA.get_center()
	_cam.position = Vector3(c.x, 90.0, c.y)
	_cam.rotation_degrees = Vector3(-90, 0, 0)
	var w := get_tree().get_first_node_in_group("world")
	if w and w.get("environment"):
		# The night garden, lifted so the map is readable: no fog, brighter.
		var env := (w.get("environment") as Environment).duplicate() as Environment
		env.fog_enabled = false
		env.volumetric_fog_enabled = false
		env.tonemap_exposure *= 2.4
		env.ambient_light_energy *= 1.8
		_cam.environment = env
	_cam.make_current()
	_vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	_picture.texture = _vp.get_texture()


func _process(delta: float) -> void:
	if visible:
		_t += delta
		_overlay.queue_redraw()


func _draw_markers() -> void:
	# Where the current quest wants you.
	var goal := _goal_point()
	if goal != Vector2.INF:
		var g := to_map(goal)
		var pulse := 0.5 + 0.5 * sin(_t * 4.0)
		_overlay.draw_circle(g, 22.0 + pulse * 8.0, Color(1.0, 0.75, 0.3, 0.18 + pulse * 0.12))
		_overlay.draw_arc(g, 16.0 + pulse * 6.0, 0, TAU, 40, Color(1.0, 0.8, 0.4, 0.95), 3.0, true)
		_overlay.draw_circle(g, 6.0, Color("f2b65d"))
	# You: a cream arrow with a dark rim, pointing where you face.
	var p := get_tree().get_first_node_in_group("player") as Node3D
	if p:
		var at := to_map(Vector2(p.global_position.x, p.global_position.z))
		var f3 := -p.global_basis.z
		var f := Vector2(f3.x, f3.z).normalized()
		if f == Vector2.ZERO:
			f = Vector2.UP
		var side := Vector2(-f.y, f.x)
		var pts := PackedVector2Array([at + f * 18.0, at - f * 10.0 + side * 11.0, at - f * 5.0, at - f * 10.0 - side * 11.0])
		_overlay.draw_circle(at, 20.0, Color(0.02, 0.05, 0.1, 0.35))
		_overlay.draw_colored_polygon(pts, Color("fff3d6"))
		pts.append(pts[0])
		_overlay.draw_polyline(pts, Color("22303f"), 2.5, true)


## Mirrors Objectives: the spot the current step happens at.
func _goal_point() -> Vector2:
	var gs := GameState
	var stall := Vector2(-21.6, 0.0)
	var grove := Vector2(16.0, -13.6)
	var dock := Vector2(7.2, 4.5)
	if not gs.has("keeper_met"):
		return stall
	if not gs.has("moss_met") or gs.leaves() < GameState.LEAF_IDS.size():
		return grove
	if not gs.has("leaves_returned") or not gs.has("tea_brewed"):
		return stall
	if not gs.has("tea_served"):
		return Vector2(-21.3, 2.4)
	if not gs.has("first_moonfin_released"):
		if gs.has("blue_met") and gs.bait() < 1:
			return stall
		return dock
	if not gs.has("ending_complete"):
		return dock
	return Vector2.INF
