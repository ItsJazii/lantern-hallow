extends Npc
## The tea keeper behind the counter: opens the story, takes the moonleaves,
## and runs the bait shop after the tea is served.

const NAME := "Keeper"


func _ready() -> void:
	add_to_group("keeper")
	super._ready()


func get_prompt() -> String:
	if GameState.shop_unlocked():
		return "Talk to the keeper · bait shop"
	return "Talk to the keeper"


func interact(_player: Player) -> void:
	talk_start()
	await _conversation()
	talk_end()


func _conversation() -> void:
	var gs := GameState
	if not gs.has("keeper_met"):
		gs.meet_keeper()
		react("wave")
		await UI.say(NAME, "Oh! A visitor. Welcome to Lantern Hollow.")
		await UI.say(NAME, "You found us just in time. Would you gather a little moonleaf for tonight's tea?")
		await UI.say(NAME, "The moss spirit tends the grove across the pond, to the northeast. Just follow the path around.")
		return
	if not gs.has("moss_met"):
		await UI.say(NAME, "The moss spirit lives in the Moonleaf Grove, northeast across the pond. Say hello for me!")
		return
	if gs.leaves() < GameState.LEAF_IDS.size():
		await UI.say(NAME, "The moonleaves that glow brightest are ready. You have %d of 3 so far." % gs.leaves())
		return
	if not gs.has("leaves_returned"):
		gs.return_leaves()
		react("happy")
		UI.quest_complete("A Little Help")
		await UI.say(NAME, "Three perfect moonleaves! They smell like rain on a warm night.")
		await UI.say(NAME, "Would you brew them? The kettle is right here on the counter. Our fox friend has been waiting all evening.")
		return
	if not gs.has("tea_brewed"):
		await UI.say(NAME, "The kettle's just there on the counter. Give it a try.")
		return
	if not gs.has("tea_served"):
		await UI.say(NAME, "That smells lovely. Bring a cup to the little fox beside the stall.")
		return
	await _shop()


func _shop() -> void:
	var line := _hint()
	while true:
		var fishing := game_node("fishing")
		var busy: bool = fishing != null and fishing.is_active()
		var options := ["Buy bait · %d coin" % GameState.BAIT_COST]
		var enabled := [GameState.can_buy_bait() and not busy]
		var recovery := GameState.recovery_available()
		if recovery:
			options.append("Ask for a spare bait")
			enabled.append(true)
		options.append("Goodbye")
		enabled.append(true)
		var pick := await UI.choose(NAME, line, options, enabled)
		if pick == 0:
			var result := GameState.buy_bait()
			if not result["ok"]:
				line = "Ah, you'll need a coin for that."
				continue
			Sfx.play("coin")
			if result["rod_loaned"]:
				UI.toast("Received: fishing rod (on loan)", UI.GOLD)
				await UI.say(NAME, "Here's your bait, wrapped in a leaf. And take this rod. It's a loan, so keep it as long as you like.")
				if not GameState.has("blue_met"):
					await UI.say(NAME, "Have you met the blue spirit on the dock? I think they're hoping to see a Moonfin.")
			line = "One bait, wrapped in a leaf. Anything else?"
		elif recovery and pick == 1:
			if GameState.give_recovery_bait():
				Sfx.play("coin")
				line = "Here, this one's on the house. The pond is generous tonight."
		else:
			break


func _hint() -> String:
	var gs := GameState
	if not gs.has("first_moonfin_released"):
		if not gs.has("blue_met"):
			return "Thank you for helping. The blue spirit on the dock seems to be waiting for someone. Bait is 1 coin if you'd like to fish."
		if gs.bait() < 1:
			return "You'll want bait before you fish. One coin each."
		return "The dock is southeast across the pond. Cast from the very end. Good luck!"
	if gs.lit() < GameState.LANTERN_IDS.size():
		return "A wish lantern! Light the two dock lanterns first, then it can fly."
	if not gs.has("ending_complete"):
		return "The blue spirit is waiting to send off the wish lantern with you."
	return "Stay as long as you like. The tea's always warm, and the Moonfins are always curious."


func _build_placeholder(v: Node3D) -> void:
	var skin := PH.mat(Color("eec4a0"), 0.7)
	var navy := PH.mat(Color("243a5e"), 0.9)
	var hair := PH.mat(Color("2f2f6e"), 0.75)
	var cream := PH.mat(Color("efe2c6"), 0.9)
	var ochre := PH.mat(Color("c98e3a"), 0.95)
	var boot := PH.mat(Color("6b4630"), 0.7)
	var dark := PH.mat(Color("1d1a22"), 0.4)
	for side in [-1.0, 1.0]:
		PH.box(v, Vector3(0.12, 0.13, 0.22), Vector3(0.1 * side, 0.065, 0.03), boot)
		PH.cyl(v, 0.065, 0.07, 0.35, Vector3(0.1 * side, 0.3, 0), PH.mat(Color("b9ab92")))
	PH.cyl(v, 0.21, 0.37, 0.95, Vector3(0, 0.78, 0), navy, Vector3.ZERO, 20)
	PH.box(v, Vector3(0.36, 0.62, 0.03), Vector3(0, 0.82, 0.27), cream, Vector3(-9, 0, 0))
	PH.sphere(v, 0.22, Vector3(0, 1.25, 0), navy, Vector3(1.12, 0.62, 0.92))
	PH.torus(v, 0.08, 0.16, Vector3(0, 1.34, 0.01), ochre)
	PH.box(v, Vector3(0.09, 0.32, 0.04), Vector3(0.07, 1.12, 0.18), ochre, Vector3(-12, 0, 6))
	PH.sphere(v, 0.14, Vector3(0, 1.5, 0), skin)
	PH.sphere(v, 0.155, Vector3(0, 1.555, -0.02), hair, Vector3(1.06, 0.86, 1.06))
	PH.sphere(v, 0.1, Vector3(0.0, 1.6, 0.085), hair, Vector3(1.35, 0.5, 0.6))
	for side in [-1.0, 1.0]:
		PH.sphere(v, 0.018, Vector3(0.05 * side, 1.5, 0.128), dark, Vector3.ONE, 8)
		PH.sphere(v, 0.022, Vector3(0.085 * side, 1.465, 0.112), PH.mat(Color("e6a3a0"), 0.8), Vector3(1, 0.6, 0.4), 8)
		PH.limb(v, Vector3(0.24 * side, 1.24, 0.0), Vector3(0.19 * side, 1.02, 0.24), 0.06, 0.05, navy)
		PH.sphere(v, 0.045, Vector3(0.18 * side, 1.0, 0.27), skin, Vector3.ONE, 10)
