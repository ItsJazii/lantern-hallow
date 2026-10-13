class_name Interactable
extends Node3D
## Wrapper for anything the player can press E on. Gameplay (target id, prompt,
## collider) lives here; the look lives in the `Visual` child, built either from
## `model` (an imported GLB scene) or from a primitive placeholder. Swapping the
## model never changes ids or quest links.

## Stable id used by save data (leaves, lanterns, charms). Empty for singletons.
@export var target_id := ""
## Optional imported model. When empty a placeholder is built.
@export var model: PackedScene
@export var model_scale := 1.0
@export var model_yaw := 0.0
@export var model_offset := Vector3.ZERO
## Ray-pickable volume, relative to this node.
@export var interact_size := Vector3(1.0, 1.4, 1.0)
@export var interact_offset := Vector3(0.0, 0.7, 0.0)

var visual: Node3D
var area: Area3D


func _ready() -> void:
	visual = Node3D.new()
	visual.name = "Visual"
	add_child(visual)
	if model:
		var inst := model.instantiate()
		if inst is Node3D:
			(inst as Node3D).scale = Vector3.ONE * model_scale
			(inst as Node3D).rotation_degrees.y = model_yaw
			(inst as Node3D).position = model_offset
		visual.add_child(inst)
		_decorate_model(inst)
	else:
		_build_placeholder(visual)
	_build_area()
	_setup()
	GameState.changed.connect(_refresh)
	_refresh()


func _build_area() -> void:
	area = Area3D.new()
	area.collision_layer = 4
	area.collision_mask = 0
	area.monitoring = false
	area.set_meta("interactable", self)
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = interact_size
	cs.shape = box
	cs.position = interact_offset
	area.add_child(cs)
	add_child(area)


## Override points ------------------------------------------------------------------

func _build_placeholder(_v: Node3D) -> void:
	pass


## Extra touches on an imported model (glow, attached props). Optional.
func _decorate_model(_model_root: Node) -> void:
	pass


## Extra setup after the visual and area exist (colliders, lights, sounds).
func _setup() -> void:
	pass


## Rebuild visuals from committed state. Must never grant rewards.
func _refresh() -> void:
	pass


## Text after the E badge. Empty means "not interactable right now".
func get_prompt() -> String:
	return ""


func interact(_player: Player) -> void:
	pass


## Common helpers -------------------------------------------------------------------

func set_interactable(enabled: bool) -> void:
	area.collision_layer = 4 if enabled else 0


func game_node(group: String) -> Node:
	return get_tree().get_first_node_in_group(group)
