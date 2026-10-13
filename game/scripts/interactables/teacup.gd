class_name Teacup
extends Interactable
## Ceramic cup on the counter. Filled once tea is brewed; serving it (here or by
## interacting with the fox) hands it to the fox.

var _tea: Node3D
var _cup: Node3D


func _ready() -> void:
	interact_size = Vector3(0.4, 0.35, 0.4)
	interact_offset = Vector3(0, 0.1, 0)
	super._ready()


func get_prompt() -> String:
	if GameState.has("tea_brewed") and not GameState.has("tea_served"):
		return "Serve tea to the fox"
	return ""


func interact(_player: Player) -> void:
	var fox := game_node("fox")
	if fox:
		await fox.serve()


func _refresh() -> void:
	_cup.visible = not GameState.has("tea_served")
	_tea.visible = GameState.has("tea_brewed")


func _build_placeholder(v: Node3D) -> void:
	_cup = Node3D.new()
	v.add_child(_cup)
	_tea = build_cup(_cup, false)


func _decorate_model(model_root: Node) -> void:
	_cup = model_root as Node3D
	_tea = tea_surface(_cup)


## An amber tea surface sized for the Tripo cup.
static func tea_surface(cup: Node3D) -> Node3D:
	var tea := PH.cyl(cup, 0.052, 0.052, 0.004, Vector3(0, 0.082, 0), PH.mat(Color("b7853f"), 0.08, Color("6b4a1a"), 0.4), Vector3.ZERO, 20)
	return tea


## Builds a cup; returns the tea surface node. Also used for the fox's cup.
static func build_cup(parent: Node3D, filled: bool) -> Node3D:
	var ceramic := PH.mat(Color("f1ead9"), 0.25)
	var rim := PH.mat(Color("7f9fb3"), 0.3)
	PH.cyl(parent, 0.055, 0.04, 0.08, Vector3(0, 0.04, 0), ceramic)
	PH.torus(parent, 0.05, 0.058, Vector3(0, 0.08, 0), rim)
	PH.torus(parent, 0.015, 0.024, Vector3(0.06, 0.045, 0), ceramic, Vector3(90, 0, 0))
	PH.cyl(parent, 0.07, 0.07, 0.008, Vector3(0, 0.004, 0), ceramic)
	var tea := PH.cyl(parent, 0.05, 0.05, 0.004, Vector3(0, 0.07, 0), PH.mat(Color("b7853f"), 0.1, Color("6b4a1a"), 0.4))
	tea.visible = filled
	return tea
