extends Npc
## The blue spirit on the dock: asks for a Moonfin, gives the wish lantern
## blessing, and starts the ending once both dock lanterns are lit.

const NAME := "Blue Spirit"


func _ready() -> void:
	add_to_group("blue_spirit")
	super._ready()


func get_prompt() -> String:
	if GameState.lit() >= GameState.LANTERN_IDS.size() and not GameState.has("ending_complete"):
		return "Release the wish lantern"
	return "Talk to the blue spirit"


func interact(_player: Player) -> void:
	hop()
	Sfx.play_at("blue_bell", global_position, -2.0, randf_range(0.97, 1.05), 0.6)
	var gs := GameState
	if gs.lit() >= GameState.LANTERN_IDS.size() and not gs.has("ending_complete"):
		gs.complete_ending()
		cheer()
		talk_start()
		await UI.say(NAME, "Both lanterns are glowing. Ready? Let's make a wish together.")
		talk_end()
		var c := game_node("celebration")
		if c:
			c.play(global_position)
		return
	talk_start()
	await _conversation()
	talk_end()


func _conversation() -> void:
	var gs := GameState
	if not gs.has("tea_served"):
		await UI.say("", "The blue spirit chimes softly and gazes at the water. Perhaps the tea stall knows what it's waiting for.")
		return
	if not gs.has("blue_met"):
		gs.meet_blue()
		await UI.say(NAME, "Could you catch me a Moonfin? Bring one up, and we'll make a wish together.")
		if not gs.has("has_rod"):
			await UI.say(NAME, "The tea keeper sells bait, and lends a rod with it. Then cast from the end of this dock.")
		else:
			await UI.say(NAME, "Cast from the end of this dock. They're curious tonight.")
		return
	if not gs.has("first_moonfin_released"):
		if gs.bait() < 1:
			await UI.say(NAME, "You'll need bait from the tea keeper first. One coin.")
		else:
			await UI.say(NAME, "Cast from the end of the dock. Wait for the bell, then reel in.")
		return
	if gs.lit() < GameState.LANTERN_IDS.size():
		await UI.say(NAME, "Light the two lanterns at the end of the dock, then we'll send the wish up.")
		return
	await UI.say(NAME, "Every lantern is a little wish. Thank you for ours.")


## Called by the fishing controller right after the first committed release.
func on_first_release() -> void:
	cheer()
	Sfx.play_at("blue_bell", global_position, 0.0, 1.1)
	talk_start()
	await UI.say(NAME, "Oh, look how it shimmers! A little moon, right there in your basket.")
	UI.quest_complete("A Moonfin Wish")
	UI.toast("Received: wish lantern", UI.GOLD)
	await UI.say(NAME, "Now, would you light the two lanterns at the end of the dock?")
	talk_end()


func _setup() -> void:
	super._setup()
	PH.omni(self, Vector3(0, 0.45, 0.2), Color("9fd0ff"), 0.6, 3.0)


func _build_placeholder(v: Node3D) -> void:
	var body := PH.mat(Color("bfe1f6"), 0.25, Color("8cc8f0"), 0.35)
	var dark := PH.mat(Color("1d2a3a"), 0.3)
	var heart := PH.mat(Color("f2c46b"), 0.4, Color("ffc15a"), 4.0)
	PH.sphere(v, 0.25, Vector3(0, 0.3, 0), body, Vector3(1.0, 1.2, 0.95))
	var curl := [Vector3(0, 0.6, 0), Vector3(0.0, 0.68, 0.0), Vector3(0.03, 0.75, 0.0), Vector3(0.08, 0.79, 0.0), Vector3(0.12, 0.77, 0.0), Vector3(0.12, 0.72, 0.0)]
	for i in curl.size():
		PH.sphere(v, 0.05 - i * 0.006, curl[i], body, Vector3.ONE, 10)
	for side in [-1.0, 1.0]:
		PH.sphere(v, 0.07, Vector3(0.24 * side, 0.24, 0.02), body, Vector3(1.3, 0.55, 0.7), 10)
		PH.sphere(v, 0.024, Vector3(0.07 * side, 0.4, 0.228), dark, Vector3.ONE, 8)
		PH.sphere(v, 0.032, Vector3(0.023 * side, 0.27, 0.235), heart, Vector3(1, 1, 0.5), 8)
	PH.cyl(v, 0.0, 0.042, 0.06, Vector3(0, 0.235, 0.235), heart, Vector3(180, 0, 0), 8)
