extends Npc
## The moss spirit in the grove: starts the moonleaf gathering.

const NAME := "Moss Spirit"


func get_prompt() -> String:
	return "Talk to the moss spirit"


func interact(_player: Player) -> void:
	cheer()
	Sfx.play_at("moss_chirp", global_position + Vector3.UP * 0.4, 0.0, randf_range(0.95, 1.1), 0.5)
	talk_start()
	await _conversation()
	talk_end()


func _conversation() -> void:
	var gs := GameState
	if not gs.has("keeper_met"):
		await UI.say(NAME, "Oh, hello! The tea keeper under the giant tree was hoping someone would visit. Say hello to them first?")
		return
	if not gs.has("moss_met"):
		gs.meet_moss()
		await UI.say(NAME, "Mm? The keeper sent you? Just three leaves, please. The rest are still dreaming.")
		await UI.say(NAME, "Pick the ones that glow the brightest.")
		return
	var left := GameState.LEAF_IDS.size() - gs.leaves()
	if left > 0:
		await UI.say(NAME, "%d more, please. Look for the brightest glow." % left)
	elif not gs.has("leaves_returned"):
		await UI.say(NAME, "Thank you! Take them to the keeper while they're fresh.")
	else:
		await UI.say(NAME, "The grove feels lighter tonight. Thank you, friend.")


func _setup() -> void:
	super._setup()
	# Soft warm fill so the spirit reads against the dark grove.
	PH.omni(self, Vector3(0.0, 1.1, 0.9), Color("ffd9a0"), 0.7, 3.0)


func _build_placeholder(v: Node3D) -> void:
	var body := PH.mat(Color("7f8b3f"), 0.95)
	var moss := PH.mat(Color("5f7a34"), 1.0)
	var leaf := PH.mat(Color("79a447"), 0.8)
	var dark := PH.mat(Color("1b1a17"), 0.35)
	var blush := PH.mat(Color("e9a3a0"), 0.8)
	PH.sphere(v, 0.28, Vector3(0, 0.31, 0), body, Vector3(1.0, 1.06, 0.95))
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 9:
		var a := rng.randf() * TAU
		var h := rng.randf_range(0.15, 0.5)
		PH.sphere(v, rng.randf_range(0.05, 0.08), Vector3(cos(a) * 0.24, h, sin(a) * 0.22 - 0.03), moss, Vector3(1, 0.6, 1), 10)
	for side in [-1.0, 1.0]:
		PH.cyl(v, 0.012, 0.015, 0.1, Vector3(0.09 * side, 0.61, 0), PH.mat(Color("5c6e2c")), Vector3(0, 0, -18 * side))
		var ear := PH.sphere(v, 0.1, Vector3(0.14 * side, 0.74, 0), leaf, Vector3(0.75, 1.6, 0.25), 12)
		ear.rotation_degrees = Vector3(0, 0, -28 * side)
		PH.sphere(v, 0.028, Vector3(0.08 * side, 0.37, 0.25), dark, Vector3.ONE, 10)
		PH.sphere(v, 0.03, Vector3(0.15 * side, 0.3, 0.235), blush, Vector3(1, 0.6, 0.35), 8)
		PH.sphere(v, 0.06, Vector3(0.11 * side, 0.04, 0.06), body, Vector3(1, 0.6, 1.2), 10)
		PH.sphere(v, 0.05, Vector3(0.26 * side, 0.26, 0.06), body, Vector3(0.8, 1.2, 0.9), 10)
	PH.sphere(v, 0.025, Vector3(0, 0.3, 0.262), PH.mat(Color("3b2a22"), 0.6), Vector3(1.6, 0.5, 0.4), 8)
