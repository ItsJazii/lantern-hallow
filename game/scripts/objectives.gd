class_name Objectives
## Derives the current quest title, objective text, and tracker from
## committed state, so it is always correct right after a load.


static func current() -> Dictionary:
	var gs := GameState
	if not gs.has("keeper_met"):
		return _o("Arrival", "Cross the bridge and say hello at the tea stall under the giant tree.")
	if not gs.has("moss_met"):
		return _o("A Little Help", "Find the moss spirit in the Moonleaf Grove, across the pond to the northeast.")
	if gs.leaves() < GameState.LEAF_IDS.size():
		return _o("A Little Help", "Gather the glowing moonleaves in the grove.", "%d / 3" % gs.leaves())
	if not gs.has("leaves_returned"):
		return _o("A Little Help", "Bring the moonleaves back to the tea keeper.", "3 / 3")
	if not gs.has("tea_brewed"):
		return _o("Tea for a Friend", "Brew moonleaf tea at the kettle on the counter.")
	if not gs.has("tea_served"):
		return _o("Tea for a Friend", "Serve the tea to the little fox beside the stall.")
	if not gs.has("first_moonfin_released"):
		var steps: Array[String] = []
		if not gs.has("blue_met"):
			steps.append("Talk to the blue spirit on the pond dock.")
		if gs.bait() < 1:
			steps.append("Buy bait from the tea keeper (1 coin).")
		if steps.is_empty():
			steps.append("Fish from the end of the dock and keep your Moonfin in the basket.")
		return _o("A Moonfin Wish", "\n".join(steps))
	if gs.lit() < GameState.LANTERN_IDS.size():
		return _o("Light the Evening", "Light the two lanterns at the end of the dock.", "%d / 2" % gs.lit())
	if not gs.has("ending_complete"):
		return _o("Light the Evening", "Release the wish lantern with the blue spirit.", "2 / 2")
	var tracker := ""
	if gs.charms() > 0:
		tracker = "Charms %d / 3" % gs.charms()
	return _o("Free Time", "Fish, sit on the bench, or wander the garden.", tracker)


static func _o(quest: String, text: String, tracker := "") -> Dictionary:
	return {"quest": quest, "text": text, "tracker": tracker}
