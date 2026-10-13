extends Node
## Debug tool: drives a complete playthrough inside the real scene and checks
## the brief's acceptance rules (order, idempotent rewards, economy, fishing
## interruptions, save/load, restart). Never touches the real save file.
##   godot --headless --path game -- --autotest

var _checks := 0
var _failures: Array[String] = []
var player: Player
var scene: Node


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_run()


func _run() -> void:
	GameState.autosave = false
	GameState.save_path = "user://autotest_save.json"
	GameState.data = GameState.defaults()
	GameState.changed.emit()
	Engine.time_scale = 2.0
	await _wait(0.5)
	scene = get_tree().current_scene
	player = get_tree().get_first_node_in_group("player") as Player

	var keeper := _n("Props/TeaStall/Keeper")
	var kettle := _n("Props/TeaStall/Kettle")
	var cup := _n("Props/TeaStall/Teacup")
	var fox := _n("Props/TeaStall/Fox")
	var moss := _n("Grove/MossSpirit")
	var leaf_a := _n("Grove/MoonleafA")
	var leaf_b := _n("Grove/MoonleafB")
	var leaf_c := _n("Grove/MoonleafC")
	var blue := _n("Props/Dock/BlueSpirit")
	var lantern_w := _n("Props/Dock/DockLanternWest")
	var lantern_e := _n("Props/Dock/DockLanternEast")
	var bench := _n("Bench")
	var fishing := _n("Fishing") as FishingController
	var gs := GameState

	_check(Objectives.current()["quest"] == "Arrival", "fresh objective is Arrival")

	# Wrong-order interactions give hints and change nothing.
	await _talk(moss)
	_check(not gs.has("moss_met"), "moss before keeper does not start the quest")
	await _use(leaf_a)
	_check(gs.leaves() == 0, "leaves can't be gathered before meeting moss")
	await _use(kettle)
	_check(not gs.has("tea_brewed"), "kettle before leaves does nothing")
	fishing.autoplay = true
	fishing.try_start(player)
	_check(not fishing.is_active(), "no fishing before tea")

	# Q1.
	await _talk(keeper)
	_check(gs.has("keeper_met"), "keeper met")
	await _talk(moss)
	_check(gs.has("moss_met"), "moss met")
	await _use(leaf_a)
	await _use(leaf_a)
	_check(gs.leaves() == 1, "same leaf counts once")
	await _use(leaf_b)
	await _use(leaf_c)
	_check(gs.leaves() == 3, "three unique leaves")
	await _talk(keeper)
	_check(gs.has("leaves_returned"), "leaves returned")

	# Q2.
	await _use(fox)
	_check(not gs.has("tea_served"), "fox can't be served before brewing")
	await _use(kettle)
	_check(gs.has("tea_brewed"), "tea brewed")
	_check(not player.is_locked(), "player unlocked after brewing")
	await _use(kettle)
	await _use(cup)
	_check(gs.has("tea_served") and gs.coins() == 3, "serving tea pays 3 coins")
	_check(fox.get("_cup").visible and int(fox.get("_sips_left")) == 4, "the fox's cup is full after serving")
	for i in 4:
		fox.call("_sip")
	await _wait(1.5)
	_check(not fox.get("_tea").visible and float(fox.get("_cup_time")) > 0.0, "the fox drinks the cup dry")
	await _use(fox)
	await _use(cup)
	_check(gs.coins() == 3, "tea reward is paid once")

	# Q3 prerequisites, in either order.
	fishing.try_start(player)
	_check(not fishing.is_active(), "no fishing before meeting blue")
	await _talk(blue)
	_check(gs.has("blue_met"), "blue met")
	fishing.try_start(player)
	_check(not fishing.is_active(), "no fishing without rod/bait")
	await _shop(keeper, [0])
	_check(gs.coins() == 2 and gs.bait() == 1 and gs.has("has_rod"), "first bait costs 1 and lends the rod")

	# Cancel before reveal costs nothing.
	fishing.try_start(player)
	_check(fishing.is_active(), "fishing starts")
	for i in 3:
		fishing.handle_action()
	await _until(func() -> bool: return fishing.state == FishingController.State.WAITING, 5.0)
	_check(fishing.state == FishingController.State.WAITING, "spamming E during cast is ignored")
	fishing.cancel()
	_check(not fishing.is_active() and gs.bait() == 1 and gs.coins() == 2, "cancel is free")
	_check(not player.is_locked() and player.action_handler == null, "cancel restores movement")

	# Pause freezes the wait timer.
	fishing.try_start(player)
	await _until(func() -> bool: return fishing.state == FishingController.State.WAITING, 5.0)
	get_tree().paused = true
	await get_tree().create_timer(9.0, true, false, true).timeout
	_check(fishing.state == FishingController.State.WAITING, "paused wait does not advance")
	get_tree().paused = false

	# Full catch and release.
	await _until(func() -> bool: return fishing.state == FishingController.State.BITE, 9.0)
	_check(fishing.state == FishingController.State.BITE, "bite arrives and waits")
	await _wait(3.0)
	_check(fishing.state == FishingController.State.BITE, "bite persists without input")
	fishing.handle_action()
	fishing.handle_action()
	await _until(func() -> bool: return fishing.state == FishingController.State.CATCH_REVEAL, 4.0)
	_check(fishing.state == FishingController.State.CATCH_REVEAL, "reel leads to reveal")
	_check(not fishing.can_cancel(), "no cancel at reveal")
	fishing.handle_action()
	for i in 4:
		fishing.handle_action()
	await _until(func() -> bool: return not fishing.is_active(), 4.0)
	await _pump()
	_check(gs.coins() == 4 and gs.bait() == 0, "after tea, buy, release: 4 coins / 0 bait")
	_check(gs.has("first_moonfin_released") and gs.has("wish_lantern_owned"), "first release grants the wish lantern")
	_check(int(gs.data["release_count"]) == 1, "exactly one release committed")
	fishing._commit(fishing._session - 1)
	fishing.handle_action()
	_check(gs.coins() == 4 and gs.bait() == 0, "stale commit / extra E change nothing")
	_check(not player.is_locked(), "player free after fishing")
	fishing.try_start(player)
	_check(not fishing.is_active(), "no cast with zero bait")

	# Save / load round trip.
	gs.save_game()
	var snapshot := gs.data.duplicate(true)
	gs.data["coins"] = 99
	gs.load_game()
	_check(gs.data == snapshot, "save/load round trip")

	# Q4.
	await _use(lantern_w)
	await _use(lantern_w)
	_check(gs.lit() == 1, "a lantern lights once")
	await _talk(blue)
	_check(not gs.has("ending_complete"), "ending needs both lanterns")
	await _use(lantern_e)
	_check(gs.lit() == 2, "both lanterns lit")
	await _talk(blue)
	_check(gs.has("ending_complete"), "ending complete")
	await _wait(7.0)
	await _until(func() -> bool: return UI._ending_root.visible, 6.0)
	_check(UI._ending_root.visible, "ending screen appears")
	UI._keep_exploring()
	await _wait(0.8)
	_check(not player.is_locked(), "keep exploring returns control")

	# Fishing stays available after the ending.
	await _shop(keeper, [0])
	fishing.try_start(player)
	await _until(func() -> bool: return fishing.state == FishingController.State.BITE, 10.0)
	fishing.handle_action()
	await _until(func() -> bool: return fishing.state == FishingController.State.CATCH_REVEAL, 4.0)
	fishing.handle_action()
	await _until(func() -> bool: return not fishing.is_active(), 4.0)
	await _pump()
	_check(gs.coins() == 5 and gs.bait() == 0 and int(gs.data["release_count"]) == 2, "repeat fishing after ending")

	# Real fishing input: aim, cast, miss a bite, strike the next, hold to reel.
	fishing.autoplay = false
	gs.data["bait"] = gs.bait() + 1
	fishing.try_start(player)
	await _until(func() -> bool: return fishing.get("_rod_ready"), 3.0)
	_check(fishing.state == FishingController.State.AIMING, "rod up and waiting to cast")
	fishing.handle_action()
	await _until(func() -> bool: return fishing.state == FishingController.State.WAITING, 4.0)
	_check(fishing.state == FishingController.State.WAITING, "cast lands in the pond")
	fishing._timer.start(0.05)
	await _until(func() -> bool: return fishing.state == FishingController.State.BITE, 2.0)
	await _wait(2.2)
	_check(fishing.state == FishingController.State.WAITING, "a missed bite only nibbles")
	fishing._timer.start(0.05)
	await _until(func() -> bool: return fishing.state == FishingController.State.BITE, 2.0)
	fishing.handle_action()
	_check(fishing.state == FishingController.State.REELING, "strike hooks the fish")
	Input.action_press("interact")
	await _until(func() -> bool: return fishing.state == FishingController.State.CATCH_REVEAL, 15.0)
	Input.action_release("interact")
	_check(fishing.state == FishingController.State.CATCH_REVEAL, "holding reels the fish in")
	fishing.handle_action()
	await _until(func() -> bool: return not fishing.is_active(), 4.0)
	fishing.autoplay = true

	# Bench (once the catch has fully settled and the player is free).
	await _until(func() -> bool: return not player.is_locked(), 4.0)
	await _use(bench)
	_check(player.frozen and player.action_handler != null, "bench seats the player")
	player._on_action()
	await _wait(1.0)
	_check(not player.frozen and not player.is_locked() and player.action_handler == null, "standing up restores control")

	# Walking from the shore straight onto the dock deck.
	var dock := get_tree().current_scene.get_node("Props/Dock") as Node3D
	player.global_position = dock.global_transform * Vector3(0, 0.3, Prop.DOCK_HALF_LEN + 1.8)
	await _wait(0.4)
	var look := dock.global_transform * Vector3(0, 0.5, 0)
	var ang := player.look_angles_to(look)
	player.set_view(ang.x, 0.0)
	Input.action_press("move_forward")
	await _wait(2.4)
	Input.action_release("move_forward")
	var on_deck := dock.global_transform.affine_inverse() * player.global_position
	_check(on_deck.z < Prop.DOCK_HALF_LEN - 0.6 and on_deck.y > 0.0, "player walks onto the dock")

	# Footfalls match the ground: boards on the dock, earth on the path, lawn
	# elsewhere; and every surface has its recorded takes.
	var on_wood: String = player._surface()
	Input.action_press("jump")
	await _wait(0.1)
	Input.action_release("jump")
	await _wait(1.0)
	var path_p := Layout.loop_point(0.0)
	player.global_position = Vector3(path_p.x, Layout.ground_height(path_p) + 0.2, path_p.y)
	await _wait(0.3)
	var on_path: String = player._surface()
	var lawn := Vector2.ZERO
	for i in 400:
		var c := Vector2(randf_range(-25.0, 25.0), randf_range(-20.0, 30.0))
		if Layout.path_factor(c) < 0.05 and Layout.pond_k(c) > 1.6 and Layout.stream_distance(c) > 5.0 and Layout.distance_to_any_path(c) > 3.0:
			lawn = c
			break
	player.global_position = Vector3(lawn.x, Layout.ground_height(lawn) + 0.2, lawn.y)
	await _wait(0.3)
	var on_lawn: String = player._surface()
	_check(on_wood == "wood" and on_path == "dirt" and on_lawn == "grass", "footstep surfaces: dock %s, path %s, lawn %s" % [on_wood, on_path, on_lawn])
	var takes_ok := true
	for cue in ["step_grass", "step_dirt", "step_sand", "step_wood", "step_stone", "jump_grass", "jump_wood", "land_grass", "land_wood", "sit", "splash", "plop", "thrash", "whoosh", "frog", "owl"]:
		if Sfx.variant_count(cue) < 1:
			takes_ok = false
			push_error("missing takes for " + cue)
	_check(takes_ok and Sfx.has_clip("loop_reel") and Sfx.has_clip("line_out"), "recorded sound takes are all present")

	# Recovery bait only while both are zero.
	gs.data["coins"] = 0
	gs.data["bait"] = 0
	_check(gs.recovery_available(), "recovery offered at 0/0")
	_check(gs.give_recovery_bait(), "recovery gives bait")
	_check(not gs.give_recovery_bait() and gs.bait() == 1, "recovery can't repeat")

	# Hostile save data is sanitized.
	var dirty := GameState.sanitize({"coins": -5, "bait": "x", "collected_leaf_ids": ["moonleaf_a", "moonleaf_a", "bogus"], "keeper_met": 1})
	_check(dirty["coins"] == 0 and dirty["bait"] == 0 and (dirty["collected_leaf_ids"] as Array).size() == 1 and dirty["keeper_met"] == true, "sanitize")

	# Restart resets progress.
	gs.reset_progress()
	_check(gs.data == GameState.defaults(), "restart resets progress")
	_check(Objectives.current()["quest"] == "Arrival", "objective back to Arrival")

	Engine.time_scale = 1.0
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://autotest_save.json"))
	print("")
	for f in _failures:
		print("  FAIL: ", f)
	print("AUTOTEST %s: %d/%d checks passed" % ["PASS" if _failures.is_empty() else "FAIL", _checks - _failures.size(), _checks])
	get_tree().quit(0 if _failures.is_empty() else 1)


# --- helpers ---------------------------------------------------------------------

func _n(path: String) -> Node:
	return scene.get_node(path)


func _check(ok: bool, label: String) -> void:
	_checks += 1
	if not ok:
		_failures.append(label)
		print("  FAIL: ", label)
	else:
		print("  ok:   ", label)


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds, true, false, false).timeout


func _until(cond: Callable, timeout: float) -> void:
	var t := 0.0
	while not cond.call() and t < timeout:
		await _wait(0.1)
		t += 0.1


## Advances any open conversation, answering choices with `picks` in order
## (falling back to the last option, usually "Goodbye").
func _pump(picks: Array = []) -> void:
	var guard := 0
	await _wait(0.05)
	while UI.conversation_open and guard < 80:
		guard += 1
		await _wait(0.25)
		if UI._mode == "choose":
			var count := UI._choices_box.get_child_count()
			var pick: int = picks.pop_front() if not picks.is_empty() else count - 1
			UI._on_choice(pick)
		else:
			UI.advance()
			await _wait(0.2)
			UI.advance()


func _talk(npc: Node) -> void:
	npc.interact(player)
	await _pump()


func _use(node: Node) -> void:
	node.interact(player)
	await _wait(0.1)
	await _until(func() -> bool: return not player.is_locked() or UI.conversation_open, 5.0)
	await _pump()


func _shop(keeper: Node, picks: Array) -> void:
	keeper.interact(player)
	await _pump(picks.duplicate())
