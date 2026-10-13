extends Npc
## The ivory fox beside the stall. Serving it tea completes Tea for a Friend
## (the keeper then hands over 3 coins and opens the bait shop).

var _cup: Node3D
var _tea: Node3D
## The served cup empties sip by sip, then the keeper tidies it away.
const SIPS := 4
var _sips_left := 0
var _next_sip := 0.0
var _cup_time := 0.0


func _ready() -> void:
	add_to_group("fox")
	super._ready()


func get_prompt() -> String:
	if GameState.has("tea_brewed") and not GameState.has("tea_served"):
		return "Serve tea to the fox"
	return "Pet the fox"


func interact(_player: Player) -> void:
	if GameState.has("tea_brewed") and not GameState.has("tea_served"):
		await serve()
		return
	cheer()
	Sfx.play_at("fox_happy", global_position + Vector3.UP * 0.5, -2.0, randf_range(0.95, 1.1), 0.6)
	if GameState.has("tea_served"):
		UI.toast("The fox swishes its tail and leans into your hand.")
	else:
		UI.toast("The fox sniffs the air hopefully. It smells tea leaves somewhere.")


## Shared by the fox and the teacup. Commits first, then plays the scene.
func serve() -> void:
	if not GameState.serve_tea():
		return
	_fill_cup()
	if not react("drink"):
		hop()
	Sfx.play_at("clink", global_position + Vector3.UP * 0.4)
	Sfx.play_at("fox_happy", global_position + Vector3.UP * 0.5, 0.0, 1.05)
	talk_start()
	await UI.say("", "The fox laps up the moonleaf tea, then curls its tail around the cup, glowing with happiness.")
	var keeper := game_node("keeper") as Npc
	if keeper:
		keeper.react("happy")
	await UI.say("Keeper", "Our little friend looks happier already. Take these coins—there's someone waiting by the pond.")
	Sfx.play("coin")
	UI.toast("+%d garden coins" % GameState.TEA_REWARD, UI.GOLD)
	UI.quest_complete("Tea for a Friend")
	await UI.say("Keeper", "If you'd like to fish, I sell bait right here. One coin each.")
	talk_end()


func _refresh() -> void:
	# A cup only exists while this visit's tea is being drunk or just finished.
	if _cup:
		_cup.visible = _sips_left > 0 or _cup_time > 0.0


func _fill_cup() -> void:
	_sips_left = SIPS
	_next_sip = randf_range(14.0, 20.0)
	_cup_time = 0.0
	if _tea:
		_tea.visible = true
		_tea.position.y = _tea.get_meta("full_y", _tea.position.y)
		_tea.scale = Vector3.ONE
	_refresh()


func _process(delta: float) -> void:
	super._process(delta)
	if _sips_left > 0 and not UI.conversation_open:
		_next_sip -= delta
		if _next_sip <= 0.0:
			_sip()
	elif _cup_time > 0.0:
		_cup_time -= delta
		if _cup_time <= 0.0:
			_refresh()


## The fox dips its head for a sip; the tea level drops until the cup is dry.
func _sip() -> void:
	_sips_left -= 1
	_next_sip = randf_range(14.0, 22.0)
	if not react("drink"):
		hop()
	if _tea:
		var full_y: float = _tea.get_meta("full_y", _tea.position.y)
		var k := float(_sips_left) / SIPS
		var t := create_tween().set_parallel(true)
		t.tween_property(_tea, "position:y", full_y - (1.0 - k) * 0.05, 1.2)
		t.tween_property(_tea, "scale", Vector3(0.75 + 0.25 * k, 1.0, 0.75 + 0.25 * k), 1.2)
		if _sips_left == 0:
			t.chain().tween_callback(_tea.hide)
	if _sips_left == 0:
		# Empty cup sits a couple of minutes, then the keeper takes it back.
		_cup_time = 120.0


func _decorate_model(_model_root: Node) -> void:
	# The served cup sits on the ground in front of the fox.
	_cup = Node3D.new()
	_cup.position = Vector3(-0.18, 0, 0.3)
	visual.add_child(_cup)
	if ModelLib.place("teacup", _cup):
		_tea = Teacup.tea_surface(_cup)
	else:
		_tea = Teacup.build_cup(_cup, true)
	_tea.set_meta("full_y", _tea.position.y)


func _build_placeholder(v: Node3D) -> void:
	var fur := PH.mat(Color("f4ead9"), 0.95)
	var amber := PH.mat(Color("e6a65a"), 0.9)
	var dark := PH.mat(Color("221c1a"), 0.35)
	var blush := PH.mat(Color("eeb1a6"), 0.8)
	PH.sphere(v, 0.2, Vector3(0, 0.24, -0.02), fur, Vector3(0.9, 1.1, 1.1))
	PH.sphere(v, 0.14, Vector3(0, 0.37, 0.1), fur)
	PH.sphere(v, 0.15, Vector3(0, 0.56, 0.08), fur)
	PH.sphere(v, 0.065, Vector3(0, 0.52, 0.21), fur, Vector3(1.0, 0.8, 1.3), 12)
	PH.sphere(v, 0.018, Vector3(0, 0.535, 0.29), dark, Vector3.ONE, 8)
	for side in [-1.0, 1.0]:
		PH.cyl(v, 0.004, 0.065, 0.22, Vector3(0.085 * side, 0.74, 0.05), fur, Vector3(0, 0, -16 * side), 10)
		PH.cyl(v, 0.004, 0.032, 0.09, Vector3(0.112 * side, 0.82, 0.05), amber, Vector3(0, 0, -16 * side), 10)
		PH.sphere(v, 0.022, Vector3(0.055 * side, 0.585, 0.205), dark, Vector3.ONE, 8)
		PH.sphere(v, 0.025, Vector3(0.095 * side, 0.54, 0.19), blush, Vector3(1, 0.6, 0.4), 8)
		PH.sphere(v, 0.045, Vector3(0.07 * side, 0.04, 0.17), fur, Vector3(1, 0.7, 1.3), 10)
	var tail := [Vector3(0.05, 0.1, -0.22), Vector3(0.14, 0.14, -0.27), Vector3(0.22, 0.22, -0.24), Vector3(0.27, 0.32, -0.16), Vector3(0.28, 0.42, -0.08)]
	for i in tail.size():
		var r := 0.07 + 0.015 * i
		PH.sphere(v, r, tail[i], amber if i >= 3 else fur, Vector3.ONE, 12)
	# The served cup appears beside the fox once tea is served.
	_cup = Node3D.new()
	_cup.position = Vector3(-0.22, 0, 0.16)
	v.add_child(_cup)
	Teacup.build_cup(_cup, true)
