extends Interactable
## The marked spot at the end of the dock. Hands off to the FishingController.


func _ready() -> void:
	interact_size = Vector3(2.4, 1.2, 1.4)
	interact_offset = Vector3(0, 0.25, 0)
	super._ready()


func get_prompt() -> String:
	var fishing := game_node("fishing")
	if fishing == null or fishing.is_active():
		return ""
	if GameState.can_start_fishing():
		return "Cast your line · %d bait" % GameState.bait()
	return "Fishing spot"


func interact(player: Player) -> void:
	var fishing := game_node("fishing")
	if fishing:
		fishing.try_start(player)


func _build_placeholder(_v: Node3D) -> void:
	# The dock end itself is the spot; the prompt shows when you're there.
	pass
