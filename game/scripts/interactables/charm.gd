extends Interactable
## Optional hidden spirit charm (stretch content). Three exist.

var _t := 0.0


func _ready() -> void:
	interact_size = Vector3(0.6, 0.6, 0.6)
	interact_offset = Vector3(0, 0.45, 0)
	super._ready()


func get_prompt() -> String:
	return "" if GameState.is_charm_collected(target_id) else "Pick up the spirit charm"


func interact(_player: Player) -> void:
	if not GameState.collect_charm(target_id):
		return
	Sfx.play_at("sparkle", global_position + Vector3.UP * 0.4)
	UI.toast("Spirit charm %d / 3" % GameState.charms(), UI.LAVENDER)
	if GameState.charms() == GameState.CHARM_IDS.size():
		UI.toast("All three charms found. The garden hums happily.", UI.GOLD)


func _refresh() -> void:
	visible = not GameState.is_charm_collected(target_id)
	set_interactable(visible)


func _process(delta: float) -> void:
	_t += delta
	visual.position.y = 0.45 + sin(_t * 1.8) * 0.05
	visual.rotation.y = _t * 0.8


func _build_placeholder(v: Node3D) -> void:
	var glow := PH.mat(Color("e3b6d8"), 0.4, Color("f0a8d8"), 1.8)
	var gold := PH.mat(PH.BRASS, 0.3, Color.BLACK, 0.0, 0.8)
	PH.sphere(v, 0.05, Vector3.ZERO, glow, Vector3(1, 1.3, 1), 12)
	PH.torus(v, 0.055, 0.07, Vector3(0, 0, 0), gold, Vector3(90, 0, 0))
	PH.cyl(v, 0.004, 0.004, 0.1, Vector3(0, 0.1, 0), gold)
	PH.omni(v, Vector3.ZERO, Color("f0a8d8"), 0.3, 1.5).remove_from_group("garden_light")
