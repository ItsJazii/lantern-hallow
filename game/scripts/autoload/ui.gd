extends CanvasLayer
## All 2D presentation, built in code so it persists as an autoload across
## restarts: HUD (quest card, coins and bait, interaction prompt, toasts,
## fishing card), dialogue, title menu, welcome cards, pause, settings,
## the Garden Journal and the ending screen.
##
## The look follows the UI concepts: parchment cards with brass rivets and a
## green ribbon, moss-green buttons with gold trim, serif type. Menus never
## use painted backdrops: the live garden is always what sits behind them.
##
## Conversations are coroutines:
##   UI.open_conversation()
##   await UI.say("Keeper", "Hello!")
##   var pick := await UI.choose("Keeper", "Anything else?", ["Buy", "Bye"])
##   UI.close_conversation()
## Esc skips the rest of a conversation; say() then returns at once and
## choose() returns -1, so callers commit state before talking.

signal _advanced
signal _chosen(index: int)
## Lets animated NPCs switch to their talk animation while they speak.
signal line_shown(speaker: String)
signal conversation_closed
## The player chose to go from the title into the garden.
signal enter_garden

# Colour tokens other scripts pass to toast(); mapped to inks that read on paper.
const NAVY := Color("17283f")
const CREAM := Color("f3e4c7")
const GOLD := Color("f2b65d")
const LAVENDER := Color("b9b3ec")
const MUTED := Color(0.95, 0.9, 0.8, 0.6)

const INK := Color("22303f")
const INK_SOFT := Color("5b5444")
const INK_GOLD := Color("8a5c16")
const INK_LAVENDER := Color("54498a")
const LEAF_TINT := Color(0.29, 0.4, 0.24)
const PAPER_TEXT := Color("f6ecd2")
const UI_DIR := "res://assets/ui/"

const QUESTS := [
	{"title": "A Little Help", "flag": "leaves_returned", "model": "moonleaf", "glow": 0.5,
		"text": "Gather three glowing moonleaves from the moss spirit's grove for the tea keeper."},
	{"title": "Tea for a Friend", "flag": "tea_served", "model": "teacup", "glow": 0.0,
		"text": "Brew moonleaf tea at the stall and share a cup with the little fox."},
	{"title": "A Moonfin Wish", "flag": "first_moonfin_released", "model": "moonfin", "glow": 0.35,
		"text": "Catch a Moonfin at the pond and keep it in the basket on the dock."},
	{"title": "Light the Evening", "flag": "ending_complete", "model": "wish_lantern", "glow": 1.2,
		"text": "Light the dock lanterns and send a wish lantern up over the water."},
]

var conversation_open := false
var hud_visible := true
## Debug tools turn this off so captures and tests never stop on focus loss.
var pause_on_focus_loss := true

var _serif: SystemFont
var _serif_bold: SystemFont
var _theme: Theme
var _tex := {}

var _root: Control
var _hud: Control
var _dot: Panel
var _prompt_box: PanelContainer
var _prompt_key: PanelContainer
var _prompt_label: Label
var _prompt_text := ""
var _quest_card: PanelContainer
var _quest_label: Label
var _objective_label: Label
var _tracker_label: Label
var _counts_panel: PanelContainer
var _coins_label: Label
var _bait_label: Label
var _toasts: VBoxContainer
var _fish_card: PanelContainer
var _fish_title: Label
var _fish_action: Label
var _fish_key := ""
var _fish_bobber: TextureRect
var _fish_bar: Control
var _fish_fill: ColorRect

var _dialog: PanelContainer
var _speaker_label: Label
var _text_label: Label
var _choices_box: VBoxContainer
var _continue_hint: Control
var _mode := ""
var _skip := false
var _opened_ms := 0
var _type_tween: Tween

var _title: Control
var _title_menu: Control
var _title_continue: Button
var _title_continue_sub: Label
var _title_enter: Button
var _welcome_new: Control
var _welcome_back: Control
var _confirm_new: Control
var _back_thumb: TextureRect
var _back_quest: Label
var _back_coins: Label
var _back_bait: Label
var _welcome_after_reload := false

var _pause_root: Control
var _resume_button: Button
var _cancel_fish_button: Button

var _settings_root: Control
var _settings_tabs: Array[Button] = []
var _settings_pages: Array[Control] = []
var _settings_caption: Label
var _settings_from := ""
var _settings_refreshers: Array[Callable] = []

var _journal_root: Control
var _map: GardenMap
var _journal_rows: Array[Button] = []
var _journal_title: Label
var _journal_text: Label
var _journal_view: ModelView
var _journal_count: Label

var _ending_root: Control
var _ending_keep: Button

var _fade: ColorRect
var _loading: Control
var _thumb_pending := false


func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_theme()
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.theme = _theme
	add_child(_root)
	_build_hud(_root)
	_build_dialog(_root)
	_build_title(_root)
	_build_pause(_root)
	_build_settings(_root)
	_build_journal(_root)
	_map = GardenMap.new()
	_root.add_child(_map)
	_map.build(self)
	_build_ending(_root)
	_fade = ColorRect.new()
	_fade.color = Color(NAVY, 0.0)
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_fade)
	_build_loading(_root)
	GameState.changed.connect(refresh_objective)
	GameState.changed.connect(_queue_thumbnail)
	refresh_objective()


# --- Public API ------------------------------------------------------------------

func set_prompt(text: String, key_badge := true) -> void:
	var key := ("1" if key_badge else "0") + text
	if key == _prompt_text:
		return
	_prompt_text = key
	_prompt_box.visible = text != ""
	_prompt_label.text = text
	_prompt_key.visible = key_badge


## The fishing card ("A little tug!" / "Reel in"). Empty title hides it.
func set_fishing_card(title: String, action := "", progress := -1.0, tension := 0.0) -> void:
	_fish_bar.visible = progress >= 0.0
	if progress >= 0.0:
		_fish_fill.anchor_right = clampf(progress, 0.0, 1.0)
		_fish_fill.color = Color("5f8a46").lerp(Color("d0703a"), smoothstep(0.55, 1.0, tension))
	var key := title + "|" + action
	if key == _fish_key:
		return
	_fish_key = key
	_fish_card.visible = title != ""
	_fish_title.text = title
	_fish_action.text = action
	_fish_bobber.visible = action == "Strike"
	if title != "":
		_fish_card.pivot_offset = _fish_card.size * 0.5
		_fish_card.scale = Vector2.ONE * 0.85
		_fish_card.create_tween().tween_property(_fish_card, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func set_dot_active(active: bool) -> void:
	_dot.scale = Vector2.ONE * (1.6 if active else 1.0)
	_dot.modulate.a = 1.0 if active else 0.65


func set_hud_visible(v: bool) -> void:
	hud_visible = v
	_hud.visible = v


func toast(text: String, color := CREAM, duration := 3.2) -> void:
	var panel := _chip()
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	panel.add_child(row)
	row.add_child(_icon_rect("leaf", 26, LEAF_TINT if color != GOLD else Color.WHITE, "leaf_gold" if color == GOLD else "leaf_cream"))
	var label := _label(22, _paper_ink(color))
	label.text = text
	row.add_child(label)
	panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	panel.modulate.a = 0.0
	_toasts.add_child(panel)
	var t := panel.create_tween()
	t.tween_property(panel, "modulate:a", 1.0, 0.25)
	t.tween_interval(duration)
	t.tween_property(panel, "modulate:a", 0.0, 0.6)
	t.tween_callback(panel.queue_free)


func quest_complete(title: String) -> void:
	Sfx.play("quest_complete")
	toast("Quest complete · %s" % title, GOLD, 4.0)


func refresh_objective() -> void:
	if _quest_label == null:
		return
	var o := Objectives.current()
	_quest_label.text = str(o["quest"])
	_objective_label.text = o["text"]
	_tracker_label.text = o["tracker"]
	_tracker_label.visible = o["tracker"] != ""
	_counts_panel.visible = GameState.shop_unlocked()
	_coins_label.text = "%d coin%s" % [GameState.coins(), "" if GameState.coins() == 1 else "s"]
	_bait_label.text = "%d bait" % GameState.bait()
	if _journal_root and _journal_root.visible:
		_refresh_journal()


func open_conversation() -> void:
	conversation_open = true
	_skip = false
	set_prompt("")
	var p := _player()
	if p:
		p.lock("dialogue")


func close_conversation() -> void:
	conversation_open = false
	_skip = false
	_mode = ""
	_dialog.hide()
	_clear_choices()
	var p := _player()
	if p:
		p.unlock("dialogue")
	_update_mouse()
	conversation_closed.emit()


func say(speaker: String, text: String) -> void:
	if _skip or not conversation_open:
		return
	_show_line(speaker, text)
	_mode = "say"
	_continue_hint.show()
	await _advanced


func choose(speaker: String, text: String, options: Array, enabled: Array = []) -> int:
	if _skip or not conversation_open:
		return -1
	_show_line(speaker, text)
	_continue_hint.hide()
	_clear_choices()
	var first_focus: Button = null
	for i in options.size():
		var b := _choice_button(i, str(options[i]))
		b.disabled = i < enabled.size() and not bool(enabled[i])
		b.pressed.connect(_on_choice.bind(i))
		_choices_box.add_child(b)
		if first_focus == null and not b.disabled:
			first_focus = b
	_mode = "choose"
	_update_mouse()
	if first_focus:
		first_focus.grab_focus.call_deferred()
	var picked: int = await _chosen
	_clear_choices()
	_update_mouse()
	return picked


## Called by the player on E. Finishes typing, advances, or confirms a choice.
func advance() -> void:
	if Time.get_ticks_msec() - _opened_ms < 160:
		return
	if _type_tween and _type_tween.is_running():
		_type_tween.kill()
		_text_label.visible_ratio = 1.0
		return
	if _mode == "say":
		_mode = ""
		_advanced.emit()
	elif _mode == "choose":
		var focus := get_viewport().gui_get_focus_owner() as Button
		if focus and focus.get_parent() == _choices_box and not focus.disabled:
			focus.pressed.emit()


func skip_conversation() -> void:
	_skip = true
	if _mode == "say":
		_mode = ""
		_advanced.emit()
	elif _mode == "choose":
		_mode = ""
		_chosen.emit(-1)


## Title menu over the live garden. main.gd owns the drifting camera.
func open_title() -> void:
	_hide_loading()
	set_hud_visible(false)
	_title.show()
	_title.modulate.a = 0.0
	_title.create_tween().tween_property(_title, "modulate:a", 1.0, 1.4)
	if _welcome_after_reload:
		_welcome_after_reload = false
		_show_title_page(_welcome_new)
	else:
		_show_title_page(_title_menu)
	_update_mouse()


## Kept for older callers: the title is now an interactive menu.
func show_title(_duration := 6.0) -> void:
	open_title()


func hide_title() -> void:
	_title.hide()
	_update_mouse()


func is_title_open() -> bool:
	return _title.visible


func fade_in(duration := 1.2) -> void:
	_fade.color.a = 1.0
	_fade.create_tween().tween_property(_fade, "color:a", 0.0, duration)


func open_pause() -> void:
	if get_tree().paused or _title.visible or _ending_root.visible:
		return
	_capture_thumbnail()
	get_tree().paused = true
	_pause_root.show()
	var fishing := get_tree().get_first_node_in_group("fishing")
	_cancel_fish_button.visible = fishing != null and fishing.can_cancel()
	_resume_button.grab_focus.call_deferred()
	Sfx.play("ui_tick", -6.0)
	_update_mouse()


func close_pause() -> void:
	_pause_root.hide()
	_settings_root.hide()
	_journal_root.hide()
	get_tree().paused = false
	Settings.save_settings()
	_update_mouse()


func open_journal() -> void:
	if get_tree().paused or _title.visible or _ending_root.visible or conversation_open:
		return
	get_tree().paused = true
	_journal_root.show()
	_refresh_journal()
	var current := _current_quest_index()
	_select_quest(current)
	_journal_rows[current].grab_focus.call_deferred()
	Sfx.play("ui_tick", -6.0)
	_update_mouse()


## The garden map: a fresh top-down render with you and your goal marked.
func open_map() -> void:
	if get_tree().paused or _title.visible or _ending_root.visible or conversation_open:
		return
	get_tree().paused = true
	_map.open()
	Sfx.play("ui_tick", -6.0)
	_update_mouse()


func close_map() -> void:
	_map.hide()
	get_tree().paused = false
	_update_mouse()


func close_journal() -> void:
	_journal_root.hide()
	get_tree().paused = false
	_update_mouse()


## Shown once the finale finishes: keep exploring or go back to the title.
func show_ending() -> void:
	set_hud_visible(false)
	var p := _player()
	if p:
		p.lock("ending")
	_ending_root.show()
	_ending_root.modulate.a = 0.0
	_ending_root.create_tween().tween_property(_ending_root, "modulate:a", 1.0, 1.6)
	_ending_keep.grab_focus.call_deferred()
	_update_mouse()


## Clears transient presentation on restart; progress is handled by GameState.
func reset_for_restart() -> void:
	skip_conversation()
	close_conversation()
	set_prompt("")
	set_fishing_card("")
	for c in _toasts.get_children():
		c.queue_free()
	_pause_root.hide()
	_settings_root.hide()
	_journal_root.hide()
	_map.hide()
	_ending_root.hide()
	set_hud_visible(true)


# --- Input -------------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		if _settings_root.visible:
			_close_settings()
		elif _journal_root.visible:
			close_journal()
		elif _map.visible:
			close_map()
		elif _pause_root.visible:
			close_pause()
		elif _title.visible:
			if not _title_menu.visible:
				_show_title_page(_title_menu)
		elif _ending_root.visible:
			pass
		elif conversation_open:
			skip_conversation()
		else:
			open_pause()
	elif event.is_action_pressed("journal"):
		get_viewport().set_input_as_handled()
		if _journal_root.visible:
			close_journal()
		else:
			open_journal()
	elif event.is_action_pressed("map"):
		get_viewport().set_input_as_handled()
		if _map.visible:
			close_map()
		else:
			open_map()
	elif event.is_action_pressed("toggle_hud") and not get_tree().paused and not _title.visible:
		set_hud_visible(not hud_visible)
	elif event.is_action_pressed("fullscreen"):
		Settings.set_fullscreen(not Settings.fullscreen)
		_refresh_settings()
	elif _mode == "choose" and event is InputEventKey and event.pressed and not event.echo:
		var idx: int = (event as InputEventKey).physical_keycode - KEY_1
		if idx >= 0 and idx < _choices_box.get_child_count():
			var b := _choices_box.get_child(idx) as Button
			if b and not b.disabled:
				b.pressed.emit()
	elif event is InputEventMouseButton and event.pressed and not _menu_open() and _mode != "choose":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _notification(what: int) -> void:
	# Losing window focus pauses the game so nothing advances unseen.
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and pause_on_focus_loss and _pause_root and not get_tree().paused:
		if get_tree().current_scene and get_tree().current_scene.name == "Main" and not _title.visible:
			open_pause()


func update_mouse() -> void:
	_update_mouse()


func _menu_open() -> bool:
	return get_tree().paused or _title.visible or _ending_root.visible or _settings_root.visible


func _update_mouse() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var free := _menu_open() or _mode == "choose"
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if free else Input.MOUSE_MODE_CAPTURED


func _player() -> Node:
	return get_tree().get_first_node_in_group("player")


# --- Dialogue internals ---------------------------------------------------------------

func _show_line(speaker: String, text: String) -> void:
	_opened_ms = Time.get_ticks_msec()
	_speaker_label.text = speaker
	_speaker_label.visible = speaker != ""
	_text_label.text = text
	_text_label.visible_ratio = 0.0
	_dialog.show()
	if _type_tween:
		_type_tween.kill()
	_type_tween = create_tween()
	_type_tween.tween_property(_text_label, "visible_ratio", 1.0, clampf(text.length() * 0.018, 0.25, 1.6))
	Sfx.play("blip", -10.0, randf_range(0.95, 1.08), 0.12)
	line_shown.emit(speaker)


func _clear_choices() -> void:
	for c in _choices_box.get_children():
		_choices_box.remove_child(c)
		c.queue_free()


func _on_choice(i: int) -> void:
	if _mode != "choose":
		return
	_mode = ""
	Sfx.play("ui_tick", -6.0)
	_chosen.emit(i)


# --- Title flow -------------------------------------------------------------------------

func _show_title_page(page: Control) -> void:
	for p in [_title_menu, _welcome_new, _welcome_back, _confirm_new]:
		(p as Control).visible = p == page
	if page == _title_menu:
		var has_save := FileAccess.file_exists(GameState.save_path) and GameState.has("keeper_met")
		_title_continue.visible = has_save
		_title_continue_sub.text = str(Objectives.current()["quest"])
		(_title_continue if has_save else _title_enter).grab_focus.call_deferred()
	elif page == _welcome_back:
		_back_quest.text = "Current quest: %s" % Objectives.current()["quest"]
		_back_coins.text = "%d coins" % GameState.coins()
		_back_bait.text = "%d bait" % GameState.bait()
		var img := Image.load_from_file("user://thumb.png") if FileAccess.file_exists("user://thumb.png") else null
		_back_thumb.texture = ImageTexture.create_from_image(img) if img else null
		_back_thumb.get_parent().visible = img != null
		_focus_first(page)
	else:
		_focus_first(page)


func _focus_first(page: Control) -> void:
	var b := _find_button(page)
	if b:
		b.grab_focus.call_deferred()


func _find_button(n: Node) -> Button:
	for c in n.get_children():
		if c is Button and (c as Button).visible:
			return c
		var found := _find_button(c)
		if found:
			return found
	return null


func _on_continue() -> void:
	_show_title_page(_welcome_back)


func _on_enter_game() -> void:
	if GameState.has("keeper_met"):
		_show_title_page(_confirm_new)
	else:
		_show_title_page(_welcome_new)


func _on_new_garden() -> void:
	# Fresh progress needs a fresh world, so reload and land on the welcome card.
	GameState.reset_progress()
	if FileAccess.file_exists("user://thumb.png"):
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://thumb.png"))
	_welcome_after_reload = true
	await _show_loading()
	_title.hide()
	get_tree().reload_current_scene()


func _on_enter_garden() -> void:
	Sfx.play("ui_tick", -4.0)
	var t := _title.create_tween()
	t.tween_property(_title, "modulate:a", 0.0, 0.6)
	t.tween_callback(_title.hide)
	t.tween_callback(_update_mouse)
	enter_garden.emit()


func return_to_title() -> void:
	await _show_loading()
	reset_for_restart()
	get_tree().paused = false
	Settings.save_settings()
	if GameState.autosave:
		GameState.save_game()
	get_tree().reload_current_scene()


# --- Settings -----------------------------------------------------------------------------

func _open_settings(from: String) -> void:
	_settings_from = from
	if from == "title":
		_title_menu.hide()
	_settings_root.show()
	_refresh_settings()
	_select_tab(0)
	_update_mouse()


func _close_settings() -> void:
	Settings.save_settings()
	_settings_root.hide()
	if _settings_from == "pause":
		_resume_button.grab_focus.call_deferred()
	elif _settings_from == "title":
		_show_title_page(_title_menu)
	_update_mouse()


func _select_tab(i: int) -> void:
	for k in _settings_tabs.size():
		_settings_tabs[k].button_pressed = k == i
		_settings_pages[k].visible = k == i
	_settings_caption.text = ["Find your comfortable sound.", "Make the garden fit your screen.", "Move at your own pace."][i]
	_settings_tabs[i].grab_focus.call_deferred()


func _reset_settings() -> void:
	for k in _settings_tabs.size():
		if _settings_tabs[k].button_pressed:
			match k:
				0:
					Settings.reset_audio()
				1:
					Settings.reset_display()
				2:
					Settings.reset_controls()
	_refresh_settings()


func _refresh_settings() -> void:
	for r in _settings_refreshers:
		r.call()


# --- Journal ------------------------------------------------------------------------------

func _current_quest_index() -> int:
	for i in QUESTS.size():
		if not GameState.has(QUESTS[i]["flag"]):
			return i
	return QUESTS.size() - 1


func _refresh_journal() -> void:
	var current := _current_quest_index()
	var done := 0
	for i in QUESTS.size():
		var complete := GameState.has(QUESTS[i]["flag"])
		if complete:
			done += 1
		var row := _journal_rows[i]
		var status: Label = row.get_meta("status")
		var check: TextureRect = row.get_meta("check")
		check.visible = complete
		status.text = "Complete" if complete else ("Current quest" if i == current else "Later")
		row.set_meta("later", not complete and i != current)
	_journal_count.text = "%d of %d quests complete" % [done, QUESTS.size()]
	_refresh_rows(_journal_rows)


func _select_quest(i: int) -> void:
	var q: Dictionary = QUESTS[i]
	_journal_title.text = q["title"]
	_journal_text.text = q["text"]
	_journal_view.show_model(q["model"], float(q["glow"]), Color(0.7, 0.85, 1.0) if q["model"] == "moonfin" else Color(1.0, 0.78, 0.5))


# --- Thumbnail (welcome back card) -----------------------------------------------------------

func _queue_thumbnail() -> void:
	if _thumb_pending:
		return
	_thumb_pending = true
	get_tree().create_timer(1.0, true).timeout.connect(_capture_thumbnail)


## Renders what the player currently sees (no UI) into user://thumb.png.
func _capture_thumbnail() -> void:
	_thumb_pending = false
	if DisplayServer.get_name() == "headless" or not pause_on_focus_loss or _title.visible:
		return
	var p := _player() as Player
	if p == null or p.camera == null or not p.camera.is_current():
		return
	var vp := SubViewport.new()
	vp.size = Vector2i(480, 300)
	vp.world_3d = get_viewport().world_3d
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	var cam := Camera3D.new()
	cam.fov = p.camera.fov
	cam.far = p.camera.far
	vp.add_child(cam)
	add_child(vp)
	cam.global_transform = p.camera.global_transform
	cam.make_current()
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img := vp.get_texture().get_image()
	if img:
		img.save_png("user://thumb.png")
	vp.queue_free()


# --- Loading card ----------------------------------------------------------------------------

## A calm card while the garden is (re)built, drawn before the work starts.
func _show_loading() -> void:
	_loading.modulate.a = 0.0
	_loading.show()
	var t := _loading.create_tween()
	t.tween_property(_loading, "modulate:a", 1.0, 0.35)
	await t.finished
	await RenderingServer.frame_post_draw


func _hide_loading() -> void:
	if not _loading.visible:
		return
	var t := _loading.create_tween()
	t.tween_interval(0.2)
	t.tween_property(_loading, "modulate:a", 0.0, 0.8)
	t.tween_callback(_loading.hide)


func _build_loading(root: Control) -> void:
	var bg := ColorRect.new()
	bg.color = Color("0b1422")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(bg)
	_loading = bg
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.add_child(center)
	var v := _vbox(14)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(v)
	var lamp := _icon_rect("lantern", 110)
	lamp.custom_minimum_size = Vector2(170, 120)
	lamp.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(lamp)
	var l := _scene_heading("Preparing your garden…", 40)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(l)
	var d := _divider(260, Color(1.6, 1.4, 1.0))
	v.add_child(d)
	bg.hide()


# --- Construction: theme and primitives ---------------------------------------------------

func _t(tex_name: String) -> Texture2D:
	if not _tex.has(tex_name):
		_tex[tex_name] = load(UI_DIR + tex_name + ".png")
	return _tex[tex_name]


func _box(tex_name: String, margin: int, pad: int, content: Vector4, modulate_color := Color.WHITE) -> StyleBoxTexture:
	var sb := StyleBoxTexture.new()
	sb.texture = _t(tex_name)
	sb.set_texture_margin_all(margin + pad)
	sb.set_expand_margin_all(pad)
	sb.content_margin_left = content.x
	sb.content_margin_top = content.y
	sb.content_margin_right = content.z
	sb.content_margin_bottom = content.w
	sb.modulate_color = modulate_color
	return sb


func _build_theme() -> void:
	_serif = SystemFont.new()
	_serif.font_names = PackedStringArray(["Constantia", "Palatino Linotype", "Georgia", "Noto Serif", "Serif"])
	_serif.font_weight = 400
	_serif.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
	_serif_bold = SystemFont.new()
	_serif_bold.font_names = _serif.font_names
	_serif_bold.font_weight = 700
	_serif_bold.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
	_theme = Theme.new()
	_theme.default_font = _serif
	_theme.default_font_size = 24
	_theme.set_color("font_color", "Label", INK)

	var pad := Vector4(26, 12, 26, 14)
	_theme.set_stylebox("normal", "Button", _box("btn_paper", 20, 6, pad))
	_theme.set_stylebox("hover", "Button", _box("btn_green_hover", 20, 6, pad))
	_theme.set_stylebox("pressed", "Button", _box("btn_green_press", 20, 6, pad))
	_theme.set_stylebox("hover_pressed", "Button", _box("btn_green_press", 20, 6, pad))
	_theme.set_stylebox("focus", "Button", _box("btn_green", 20, 6, pad))
	_theme.set_stylebox("disabled", "Button", _box("btn_paper", 20, 6, pad, Color(1, 1, 1, 0.5)))
	_theme.set_font("font", "Button", _serif_bold)
	_theme.set_font_size("font_size", "Button", 26)
	_theme.set_color("font_color", "Button", INK)
	for c in ["font_hover_color", "font_focus_color", "font_pressed_color", "font_hover_pressed_color"]:
		_theme.set_color(c, "Button", PAPER_TEXT)
	_theme.set_color("font_disabled_color", "Button", Color(INK, 0.4))
	_theme.set_color("icon_normal_color", "Button", LEAF_TINT)
	for c in ["icon_hover_color", "icon_focus_color", "icon_pressed_color", "icon_hover_pressed_color"]:
		_theme.set_color(c, "Button", Color("efe2c0"))
	_theme.set_constant("h_separation", "Button", 18)
	_theme.set_constant("icon_max_width", "Button", 34)

	# Primary buttons are always green; focus adds a warm gold halo.
	_theme.set_type_variation("Primary", "Button")
	_theme.set_stylebox("normal", "Primary", _box("btn_green", 20, 6, pad))
	var halo := StyleBoxFlat.new()
	halo.draw_center = false
	halo.set_border_width_all(3)
	halo.border_color = Color("ffd884")
	halo.set_corner_radius_all(10)
	halo.set_expand_margin_all(4)
	halo.shadow_color = Color(1.0, 0.8, 0.4, 0.35)
	halo.shadow_size = 8
	_theme.set_stylebox("focus", "Primary", halo)
	_theme.set_color("font_color", "Primary", PAPER_TEXT)
	_theme.set_color("icon_normal_color", "Primary", Color("efe2c0"))

	# Tabs: paper when idle, green when selected.
	_theme.set_type_variation("Tab", "Button")
	_theme.set_stylebox("pressed", "Tab", _box("btn_green", 20, 6, pad))
	_theme.set_stylebox("hover_pressed", "Tab", _box("btn_green", 20, 6, pad))
	_theme.set_stylebox("focus", "Tab", StyleBoxEmpty.new())
	_theme.set_color("font_focus_color", "Tab", INK)
	_theme.set_color("font_pressed_color", "Tab", PAPER_TEXT)

	# Sliders and checkboxes.
	var track := _box("slider_track", 7, 0, Vector4(0, 6, 0, 6))
	_theme.set_stylebox("slider", "HSlider", track)
	var fill := _box("slider_fill", 7, 0, Vector4(0, 6, 0, 6))
	_theme.set_stylebox("grabber_area", "HSlider", fill)
	_theme.set_stylebox("grabber_area_highlight", "HSlider", fill)
	_theme.set_icon("grabber", "HSlider", _t("slider_grabber"))
	_theme.set_icon("grabber_highlight", "HSlider", _t("slider_grabber"))
	_theme.set_stylebox("focus", "HSlider", StyleBoxEmpty.new())
	_theme.set_icon("checked", "CheckBox", _t("check_on"))
	_theme.set_icon("unchecked", "CheckBox", _t("check_off"))
	for s in ["normal", "hover", "pressed", "hover_pressed", "focus"]:
		_theme.set_stylebox(s, "CheckBox", StyleBoxEmpty.new())
	_theme.set_font("font", "CheckBox", _serif)
	_theme.set_font_size("font_size", "CheckBox", 23)
	for c in ["font_color", "font_hover_color", "font_focus_color", "font_pressed_color", "font_hover_pressed_color"]:
		_theme.set_color(c, "CheckBox", INK)
	_theme.set_constant("h_separation", "CheckBox", 14)


func _card(ribbon := true, content := Vector4(40, 34, 40, 34)) -> PanelContainer:
	var p := PanelContainer.new()
	if ribbon:
		content.x = maxf(content.x, 84)
	p.add_theme_stylebox_override("panel", _box("card", 44, 18, content))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if ribbon:
		p.draw.connect(_draw_ribbon.bind(p))
	return p


func _draw_ribbon(p: Control) -> void:
	p.draw_texture(_t("ribbon"), Vector2(4, -16))


func _chip() -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", _box("chip", 20, 6, Vector4(24, 10, 24, 12)))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p


func _label(size: int, color := INK, bold := false) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if bold:
		l.add_theme_font_override("font", _serif_bold)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


## Big cream heading that sits directly on the scene (title, welcome, ending).
func _scene_heading(text: String, size: int) -> Label:
	var l := _label(size, Color("f7ecd4"), true)
	l.text = text
	l.add_theme_color_override("font_shadow_color", Color(0.02, 0.04, 0.08, 0.75))
	l.add_theme_constant_override("shadow_offset_x", 0)
	l.add_theme_constant_override("shadow_offset_y", 3)
	l.add_theme_constant_override("shadow_outline_size", 10)
	return l


func _icon_rect(_kind: String, size: float, tint := Color.WHITE, tex_name := "") -> TextureRect:
	var r := TextureRect.new()
	r.texture = _t(tex_name if tex_name != "" else _kind)
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.custom_minimum_size = Vector2(size, size)
	r.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	r.modulate = tint
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


func _divider(width := 300.0, tint := Color.WHITE) -> TextureRect:
	var r := TextureRect.new()
	r.texture = _t("divider")
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.custom_minimum_size = Vector2(width, 22)
	r.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	r.modulate = tint
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


func _key(text: String, size := 20) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", _box("key", 12, 0, Vector4(11, 3, 11, 6)))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var l := _label(size, Color("f2e8cc"), true)
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	p.add_child(l)
	return p


func _button(parent: Control, text: String, cb: Callable, primary := false, icon := "leaf_cream") -> Button:
	var b := Button.new()
	b.text = text
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	if primary:
		b.theme_type_variation = "Primary"
	if icon != "":
		b.icon = _t(icon)
		b.expand_icon = false
	b.custom_minimum_size = Vector2(0, 66)
	b.pressed.connect(cb)
	b.pressed.connect(Sfx.play.bind("ui_tick", -6.0))
	b.mouse_entered.connect(b.grab_focus)
	parent.add_child(b)
	return b


## A dialogue choice: number keycap plus text, inside a paper/green plate.
func _choice_button(i: int, text: String) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(620, 60)
	b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	b.focus_mode = Control.FOCUS_ALL
	var row := HBoxContainer.new()
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 18
	row.offset_right = -18
	row.add_theme_constant_override("separation", 18)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(row)
	row.add_child(_key(str(i + 1)))
	var l := _label(24, INK, true)
	l.text = text
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(l)
	b.set_meta("label", l)
	b.focus_entered.connect(_refresh_choice_labels, CONNECT_DEFERRED)
	b.focus_exited.connect(_refresh_choice_labels, CONNECT_DEFERRED)
	b.mouse_entered.connect(b.grab_focus)
	return b


func _refresh_choice_labels() -> void:
	for c in _choices_box.get_children():
		var b := c as Button
		if b and b.has_meta("label"):
			var l: Label = b.get_meta("label")
			l.add_theme_color_override("font_color", PAPER_TEXT if b.has_focus() else INK)


## Recolours labels inside custom-content buttons to match their plate.
func _refresh_rows(rows: Array) -> void:
	for c in rows:
		var b := c as Button
		if b == null or not is_instance_valid(b) or not b.has_meta("labels"):
			continue
		var lit := b.has_focus() or b.is_hovered()
		var later := bool(b.get_meta("later", false))
		for l in b.get_meta("labels"):
			var lab := l as Label
			var base: Color = lab.get_meta("base", INK)
			lab.add_theme_color_override("font_color", PAPER_TEXT if lit else (Color(base, 0.55) if later else base))
		for r in b.get_meta("icons", []):
			(r as TextureRect).modulate = Color("efe2c0") if lit else (Color(LEAF_TINT, 0.5) if later else LEAF_TINT)


func _paper_ink(color: Color) -> Color:
	if color == GOLD:
		return INK_GOLD
	if color == LAVENDER:
		return INK_LAVENDER
	return INK


func _full_rect_margin(left: int, top: int, right: int, bottom: int) -> MarginContainer:
	var m := MarginContainer.new()
	m.set_anchors_preset(Control.PRESET_FULL_RECT)
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	m.add_theme_constant_override("margin_left", left)
	m.add_theme_constant_override("margin_top", top)
	m.add_theme_constant_override("margin_right", right)
	m.add_theme_constant_override("margin_bottom", bottom)
	return m


## Anchors `c` to a preset point and offsets it by `r` (relative to that point).
func _set_centered(c: Control, r: Rect2, preset: Control.LayoutPreset) -> void:
	c.set_anchors_preset(preset)
	c.offset_left = r.position.x
	c.offset_top = r.position.y
	c.offset_right = r.position.x + r.size.x
	c.offset_bottom = r.position.y + r.size.y


func _spacer(h: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


func _hspacer() -> Control:
	var c := Control.new()
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


func _vbox(sep: int) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", sep)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return v


func _hbox(sep: int) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", sep)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return h


func _vignette(parent: Control, width: float) -> void:
	var v := TextureRect.new()
	v.texture = _t("vignette")
	v.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	v.stretch_mode = TextureRect.STRETCH_SCALE
	v.anchor_bottom = 1.0
	v.offset_right = width
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(v)


# --- Construction: HUD ------------------------------------------------------------------------

func _build_hud(root: Control) -> void:
	_hud = Control.new()
	_hud.set_anchors_preset(Control.PRESET_FULL_RECT)
	_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_hud)

	_dot = Panel.new()
	var dot_sb := StyleBoxFlat.new()
	dot_sb.bg_color = Color("f7ecd4")
	dot_sb.set_corner_radius_all(4)
	dot_sb.shadow_color = Color(0, 0, 0, 0.4)
	dot_sb.shadow_size = 2
	_dot.add_theme_stylebox_override("panel", dot_sb)
	_dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_set_centered(_dot, Rect2(-4, -4, 8, 8), Control.PRESET_CENTER)
	_dot.pivot_offset = Vector2(4, 4)
	_dot.modulate.a = 0.65
	_hud.add_child(_dot)

	# Interaction prompt: a parchment pill below the dot.
	var prompt_anchor := CenterContainer.new()
	_set_centered(prompt_anchor, Rect2(-500, 120, 1000, 80), Control.PRESET_CENTER)
	prompt_anchor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.add_child(prompt_anchor)
	_prompt_box = _chip()
	var prow := _hbox(14)
	_prompt_box.add_child(prow)
	_prompt_key = _key("E", 22)
	prow.add_child(_prompt_key)
	_prompt_label = _label(25, INK, true)
	prow.add_child(_prompt_label)
	prow.add_child(_icon_rect("leaf", 26, LEAF_TINT, "leaf_cream"))
	_prompt_box.hide()
	prompt_anchor.add_child(_prompt_box)

	# Quest card, top-left.
	var tl := _full_rect_margin(40, 40, 40, 40)
	_hud.add_child(tl)
	var tl_col := _vbox(0)
	tl.add_child(tl_col)
	_quest_card = _card(true, Vector4(84, 26, 40, 28))
	_quest_card.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	tl_col.add_child(_quest_card)
	var qrow := _hbox(18)
	_quest_card.add_child(qrow)
	qrow.add_child(_icon_rect("leaf", 50, LEAF_TINT, "leaf_cream"))
	var qv := _vbox(2)
	qrow.add_child(qv)
	_quest_label = _label(32, INK, true)
	qv.add_child(_quest_label)
	_objective_label = _label(22, INK_SOFT)
	_objective_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_objective_label.custom_minimum_size = Vector2(400, 0)
	qv.add_child(_objective_label)
	_tracker_label = _label(22, INK_GOLD, true)
	qv.add_child(_tracker_label)

	# Coins and bait, top-right.
	var tr := _full_rect_margin(40, 40, 40, 40)
	_hud.add_child(tr)
	var tr_row := _hbox(0)
	tr_row.alignment = BoxContainer.ALIGNMENT_END
	tr_row.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	tr.add_child(tr_row)
	_counts_panel = _card(false, Vector4(30, 18, 30, 20))
	tr_row.add_child(_counts_panel)
	var crow := _hbox(12)
	_counts_panel.add_child(crow)
	crow.add_child(_icon_rect("coin", 38))
	_coins_label = _label(24, INK)
	crow.add_child(_coins_label)
	var sep := ColorRect.new()
	sep.color = Color(0.55, 0.45, 0.3, 0.5)
	sep.custom_minimum_size = Vector2(2, 34)
	sep.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	crow.add_child(_spacer(0))
	crow.add_child(sep)
	crow.add_child(_spacer(0))
	crow.add_child(_icon_rect("bait", 40))
	_bait_label = _label(24, INK)
	crow.add_child(_bait_label)

	# Toasts, top-center.
	_toasts = _vbox(10)
	_set_centered(_toasts, Rect2(-520, 44, 1040, 0), Control.PRESET_CENTER_TOP)
	root.add_child(_toasts)

	# Fishing card, lower center.
	# Low on screen so the catch itself stays in view.
	var fish_anchor := CenterContainer.new()
	_set_centered(fish_anchor, Rect2(-300, -330, 600, 300), Control.PRESET_CENTER_BOTTOM)
	fish_anchor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.add_child(fish_anchor)
	_fish_card = _card(false, Vector4(48, 30, 48, 34))
	fish_anchor.add_child(_fish_card)
	var fv := _vbox(4)
	fv.alignment = BoxContainer.ALIGNMENT_CENTER
	_fish_card.add_child(fv)
	_fish_title = _label(38, INK, true)
	_fish_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	fv.add_child(_fish_title)
	_fish_bobber = _icon_rect("bobber", 120)
	_fish_bobber.custom_minimum_size = Vector2(220, 104)
	_fish_bobber.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	fv.add_child(_fish_bobber)
	var plate := PanelContainer.new()
	plate.add_theme_stylebox_override("panel", _box("btn_green", 20, 6, Vector4(30, 10, 34, 12)))
	plate.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fv.add_child(plate)
	var prow2 := _hbox(16)
	plate.add_child(prow2)
	prow2.add_child(_key("E", 22))
	var or_label := _label(18, Color("e3d6b4"))
	or_label.text = "/"
	prow2.add_child(or_label)
	prow2.add_child(_key("RMB", 18))
	_fish_action = _label(27, PAPER_TEXT, true)
	prow2.add_child(_fish_action)
	# Reel progress (green), turning orange as the line strains.
	_fish_bar = Panel.new()
	var bar_sb := StyleBoxFlat.new()
	bar_sb.bg_color = Color(0.25, 0.2, 0.14, 0.55)
	bar_sb.set_corner_radius_all(6)
	_fish_bar.add_theme_stylebox_override("panel", bar_sb)
	_fish_bar.custom_minimum_size = Vector2(320, 14)
	_fish_bar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_fish_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fv.add_child(_fish_bar)
	_fish_fill = ColorRect.new()
	_fish_fill.anchor_bottom = 1.0
	_fish_fill.anchor_right = 0.0
	_fish_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fish_bar.add_child(_fish_fill)
	_fish_bar.hide()
	_fish_card.hide()


# --- Construction: dialogue -------------------------------------------------------------------

func _build_dialog(root: Control) -> void:
	var area := _full_rect_margin(40, 40, 40, 50)
	root.add_child(area)
	var column := _vbox(0)
	column.alignment = BoxContainer.ALIGNMENT_END
	area.add_child(column)
	_dialog = _card(true, Vector4(84, 30, 48, 30))
	_dialog.mouse_filter = Control.MOUSE_FILTER_STOP
	_dialog.custom_minimum_size = Vector2(1000, 0)
	_dialog.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	column.add_child(_dialog)
	var h := _hbox(24)
	_dialog.add_child(h)
	var em := _icon_rect("emblem", 96)
	em.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	h.add_child(em)
	var v := _vbox(8)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(v)
	_speaker_label = _label(34, INK, true)
	v.add_child(_speaker_label)
	_text_label = _label(25, INK_SOFT)
	_text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text_label.custom_minimum_size = Vector2(760, 0)
	v.add_child(_text_label)
	_choices_box = _vbox(8)
	v.add_child(_choices_box)
	var hint := _hbox(10)
	hint.alignment = BoxContainer.ALIGNMENT_END
	hint.add_child(_key("E", 17))
	var h1 := _label(19, INK_SOFT)
	h1.text = "Continue    "
	hint.add_child(h1)
	hint.add_child(_key("Esc", 17))
	var h2 := _label(19, INK_SOFT)
	h2.text = "Close"
	hint.add_child(h2)
	_continue_hint = hint
	v.add_child(hint)
	_dialog.hide()


# --- Construction: title and welcome cards -------------------------------------------------------

func _build_title(root: Control) -> void:
	_title = Control.new()
	_title.set_anchors_preset(Control.PRESET_FULL_RECT)
	_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_title)
	_vignette(_title, 980)

	# Main menu.
	_title_menu = _left_column(_title, 470)
	var crest := _icon_rect("lantern", 120)
	crest.custom_minimum_size = Vector2(200, 130)
	crest.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_title_menu.add_child(crest)
	var name_label := _scene_heading("Lantern\nHollow", 104)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_constant_override("line_spacing", -22)
	_title_menu.add_child(name_label)
	_title_menu.add_child(_divider(320, Color(1.6, 1.4, 1.0)))
	var sub := _scene_heading("A quiet little adventure", 27)
	sub.add_theme_font_override("font", _serif)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_menu.add_child(sub)
	_title_menu.add_child(_spacer(26))
	var buttons := _vbox(14)
	_title_menu.add_child(buttons)
	_title_continue = _button(buttons, "", _on_continue, true)
	_title_continue.custom_minimum_size = Vector2(0, 92)
	var cv := _vbox(0)
	cv.set_anchors_preset(Control.PRESET_FULL_RECT)
	cv.offset_left = 78
	cv.alignment = BoxContainer.ALIGNMENT_CENTER
	_title_continue.add_child(cv)
	var cl := _label(32, PAPER_TEXT, true)
	cl.text = "Continue"
	cv.add_child(cl)
	_title_continue_sub = _label(20, Color("e3d6b4"))
	cv.add_child(_title_continue_sub)
	_title_enter = _button(buttons, "Enter Game", _on_enter_game)
	_button(buttons, "Settings", _open_settings.bind("title"), false, "gear")
	_button(buttons, "Quit", get_tree().quit)
	_title_menu.add_child(_spacer(20))
	_title_menu.add_child(_divider(300, Color(1.6, 1.4, 1.0)))
	var foot := _scene_heading("Your garden is waiting.", 24)
	foot.add_theme_font_override("font", _serif)
	foot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_menu.add_child(foot)

	# First visit: welcome plus controls.
	_welcome_new = _left_column(_title, 520)
	var wh := _scene_heading("Welcome to\nLantern Hollow", 80)
	wh.add_theme_constant_override("line_spacing", -14)
	_welcome_new.add_child(wh)
	var wd := _divider(300, Color(1.6, 1.4, 1.0))
	wd.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_welcome_new.add_child(wd)
	var ws := _scene_heading("Take your time. The garden will wait.", 26)
	ws.add_theme_font_override("font", _serif)
	_welcome_new.add_child(ws)
	_welcome_new.add_child(_spacer(18))
	var wc := _card(true, Vector4(84, 30, 40, 34))
	_welcome_new.add_child(wc)
	var wv := _vbox(10)
	wc.add_child(wv)
	var whr := _hbox(10)
	wv.add_child(whr)
	var visit := _label(27, INK, true)
	visit.text = "Visit the Keeper\nby the old tree."
	visit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	whr.add_child(visit)
	whr.add_child(_icon_rect("leaf", 46, LEAF_TINT, "leaf_cream"))
	for row in [[["W", "A", "S", "D"], "Move"], [["Mouse"], "Look"], [["Space"], "Jump"], [["E"], "Interact"], [["J"], "Journal"], [["M"], "Map"], [["Esc"], "Pause"]]:
		var line := ColorRect.new()
		line.color = Color(0.55, 0.45, 0.3, 0.3)
		line.custom_minimum_size = Vector2(0, 1)
		wv.add_child(line)
		var r := _hbox(6)
		wv.add_child(r)
		var keys := _hbox(4)
		keys.custom_minimum_size = Vector2(190, 0)
		for k in row[0]:
			keys.add_child(_key(k, 19))
		r.add_child(keys)
		var act := _label(23, INK_SOFT)
		act.text = row[1]
		r.add_child(act)
	wv.add_child(_spacer(8))
	_button(wv, "Enter Garden", _on_enter_garden, true)

	# Returning: snapshot of where they left off.
	_welcome_back = _left_column(_title, 560)
	var bc := _card(true, Vector4(84, 30, 44, 34))
	_welcome_back.add_child(bc)
	var bv := _vbox(10)
	bc.add_child(bv)
	var bh := _label(56, INK, true)
	bh.text = "Welcome back"
	bh.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bv.add_child(bh)
	bv.add_child(_divider(260))
	var bs := _label(23, INK_SOFT)
	bs.text = "Your garden is waiting."
	bs.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bv.add_child(bs)
	var info := PanelContainer.new()
	info.add_theme_stylebox_override("panel", _box("btn_paper", 20, 6, Vector4(14, 14, 20, 14)))
	info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bv.add_child(info)
	var ih := _hbox(18)
	info.add_child(ih)
	var frame := PanelContainer.new()
	var fsb := StyleBoxFlat.new()
	fsb.bg_color = Color("6b5232")
	fsb.set_border_width_all(3)
	fsb.border_color = Color("b48a4a")
	fsb.set_corner_radius_all(4)
	frame.add_theme_stylebox_override("panel", fsb)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ih.add_child(frame)
	_back_thumb = TextureRect.new()
	_back_thumb.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_back_thumb.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_back_thumb.custom_minimum_size = Vector2(190, 128)
	frame.add_child(_back_thumb)
	var iv := _vbox(4)
	iv.alignment = BoxContainer.ALIGNMENT_CENTER
	ih.add_child(iv)
	var lh := _label(28, INK, true)
	lh.text = "Lantern Hollow"
	iv.add_child(lh)
	_back_quest = _label(20, INK_SOFT)
	iv.add_child(_back_quest)
	var cb := _hbox(8)
	iv.add_child(cb)
	cb.add_child(_icon_rect("coin", 28))
	_back_coins = _label(20, INK_SOFT)
	cb.add_child(_back_coins)
	cb.add_child(_spacer(0))
	cb.add_child(_icon_rect("bait", 30))
	_back_bait = _label(20, INK_SOFT)
	cb.add_child(_back_bait)
	bv.add_child(_spacer(4))
	_button(bv, "Return to Garden", _on_enter_garden, true)
	var back := _button(bv, "Back", _show_title_page.bind(_title_menu))
	back.custom_minimum_size = Vector2(300, 60)
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER

	# Starting over when a save exists.
	_confirm_new = _left_column(_title, 520)
	var nc := _card(true, Vector4(84, 30, 44, 34))
	_confirm_new.add_child(nc)
	var nv := _vbox(12)
	nc.add_child(nv)
	var nh := _label(44, INK, true)
	nh.text = "A new garden?"
	nv.add_child(nh)
	nv.add_child(_divider(260))
	var nt := _label(23, INK_SOFT)
	nt.text = "Starting fresh replaces your current progress. Your settings are kept."
	nt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	nt.custom_minimum_size = Vector2(380, 0)
	nv.add_child(nt)
	nv.add_child(_spacer(4))
	_button(nv, "Start fresh", _on_new_garden, true)
	_button(nv, "Back", _show_title_page.bind(_title_menu))
	_title.hide()


## A vertical stack anchored to the left third of the screen, centered vertically.
func _left_column(parent: Control, width: float) -> VBoxContainer:
	var holder := _full_rect_margin(120, 50, 0, 50)
	parent.add_child(holder)
	var row := _hbox(0)
	holder.add_child(row)
	var v := _vbox(10)
	v.custom_minimum_size = Vector2(width, 0)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	row.add_child(v)
	return v


# --- Construction: pause --------------------------------------------------------------------------

func _build_pause(root: Control) -> void:
	_pause_root = ColorRect.new()
	(_pause_root as ColorRect).color = Color(0.02, 0.04, 0.08, 0.28)
	_pause_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(_pause_root)
	_vignette(_pause_root, 760)
	var col := _left_column(_pause_root, 480)
	var card := _card(true, Vector4(84, 30, 44, 30))
	col.add_child(card)
	var v := _vbox(12)
	card.add_child(v)
	var icons := _hbox(10)
	icons.alignment = BoxContainer.ALIGNMENT_CENTER
	icons.add_child(_icon_rect("leaf", 44, LEAF_TINT, "leaf_cream"))
	v.add_child(icons)
	var title := _label(50, INK, true)
	title.text = "A quiet moment"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(title)
	v.add_child(_divider(240))
	var sub := _label(21, INK_SOFT)
	sub.text = "Lantern Hollow"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(sub)
	v.add_child(_spacer(4))
	_resume_button = _button(v, "Resume", close_pause, true)
	_button(v, "Settings", _open_settings.bind("pause"), false, "gear")
	_button(v, "Journal", _pause_to_journal)
	_cancel_fish_button = _button(v, "Reel in the line", _on_cancel_fishing)
	_button(v, "Return to Title", return_to_title)
	v.add_child(_divider(240))
	var hint := _hbox(10)
	hint.alignment = BoxContainer.ALIGNMENT_CENTER
	hint.add_child(_key("Esc", 17))
	var hl := _label(20, INK_SOFT)
	hl.text = "Resume"
	hint.add_child(hl)
	v.add_child(hint)
	_pause_root.hide()


func _pause_to_journal() -> void:
	_pause_root.hide()
	get_tree().paused = false
	open_journal()


func _on_cancel_fishing() -> void:
	var fishing := get_tree().get_first_node_in_group("fishing")
	if fishing and fishing.can_cancel():
		fishing.cancel()
	close_pause()


# --- Construction: settings -------------------------------------------------------------------------

func _build_settings(root: Control) -> void:
	_settings_root = ColorRect.new()
	(_settings_root as ColorRect).color = Color(0.02, 0.04, 0.08, 0.35)
	_settings_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(_settings_root)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_settings_root.add_child(center)
	var card := _card(true, Vector4(84, 30, 50, 34))
	card.custom_minimum_size = Vector2(900, 0)
	center.add_child(card)
	var v := _vbox(14)
	card.add_child(v)
	var head := _hbox(14)
	v.add_child(head)
	head.add_child(_icon_rect("leaf", 46, LEAF_TINT, "leaf_cream"))
	var title := _label(52, INK, true)
	title.text = "Settings"
	head.add_child(title)
	head.add_child(_hspacer())
	head.add_child(_key("Esc", 18))
	var close := _label(22, INK_SOFT)
	close.text = "Close"
	head.add_child(close)
	var tabs := _hbox(10)
	v.add_child(tabs)
	var group := ButtonGroup.new()
	for i in 3:
		var t := Button.new()
		t.text = ["Sound", "Display", "Controls"][i]
		t.theme_type_variation = "Tab"
		t.toggle_mode = true
		t.button_group = group
		t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		t.custom_minimum_size = Vector2(0, 58)
		if i == 0:
			t.icon = _t("leaf_cream")
		t.pressed.connect(_select_tab.bind(i))
		tabs.add_child(t)
		_settings_tabs.append(t)
	var line := ColorRect.new()
	line.color = Color(0.6, 0.48, 0.28, 0.45)
	line.custom_minimum_size = Vector2(0, 2)
	v.add_child(line)

	var sound := _vbox(16)
	v.add_child(sound)
	for pair in [["Master", "Master Volume"], ["Music", "Music"], ["Ambience", "Ambience"], ["SFX", "Effects"]]:
		_volume_row(sound, pair[0], pair[1])
	_settings_pages.append(sound)

	var display := _vbox(16)
	v.add_child(display)
	_check_row(display, "Fullscreen", Settings.set_fullscreen, func() -> bool: return Settings.fullscreen)
	_check_row(display, "Vertical sync", Settings.set_vsync, func() -> bool: return Settings.vsync)
	_check_row(display, "Show quest card and coins", set_hud_visible, func() -> bool: return hud_visible)
	_settings_pages.append(display)

	var controls := _vbox(12)
	v.add_child(controls)
	_slider_row(controls, "Mouse sensitivity", 0.05, 1.0, Settings.set_sensitivity, func() -> float: return Settings.mouse_sensitivity)
	_check_row(controls, "Invert look up and down", Settings.set_invert_y, func() -> bool: return Settings.invert_y)
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 18)
	grid.add_theme_constant_override("v_separation", 10)
	grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	controls.add_child(grid)
	for pair in [["W A S D", "Move"], ["Mouse", "Look"], ["Space", "Jump"], ["E", "Interact"], ["J", "Journal"], ["M", "Map"], ["H", "Hide HUD"], ["Esc", "Pause"], ["F11", "Fullscreen"], ["1 2 3", "Choose"]]:
		var keys := _hbox(4)
		keys.alignment = BoxContainer.ALIGNMENT_END
		keys.custom_minimum_size = Vector2(150, 0)
		for k in str(pair[0]).split(" "):
			keys.add_child(_key(k, 18))
		grid.add_child(keys)
		var l := _label(22, INK_SOFT)
		l.text = pair[1]
		l.custom_minimum_size = Vector2(190, 0)
		grid.add_child(l)
	_settings_pages.append(controls)

	v.add_child(_divider(260))
	_settings_caption = _label(21, INK_SOFT)
	_settings_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_settings_caption)
	var foot := _hbox(14)
	v.add_child(foot)
	var reset := _button(foot, "Reset", _reset_settings)
	reset.custom_minimum_size = Vector2(220, 62)
	foot.add_child(_hspacer())
	var done := _button(foot, "Done", _close_settings, true)
	done.custom_minimum_size = Vector2(260, 62)
	_settings_root.hide()


func _volume_row(parent: Control, bus: String, text: String) -> void:
	_slider_row(parent, text, 0.0, 1.0, _set_bus_volume.bind(bus), func() -> float: return float(Settings.volumes[bus]))


func _set_bus_volume(value: float, bus: String) -> void:
	Settings.set_volume(bus, value)


func _slider_row(parent: Control, text: String, lo: float, hi: float, setter: Callable, getter: Callable) -> void:
	var row := _hbox(18)
	parent.add_child(row)
	var l := _label(24, INK)
	l.text = text
	l.custom_minimum_size = Vector2(230, 0)
	row.add_child(l)
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = 0.01
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	s.custom_minimum_size = Vector2(0, 36)
	row.add_child(s)
	var pct := _label(22, INK_SOFT)
	pct.custom_minimum_size = Vector2(70, 0)
	pct.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(pct)
	s.value_changed.connect(setter)
	s.value_changed.connect(_set_percent.bind(pct, lo, hi))
	_settings_refreshers.append(_refresh_slider.bind(s, getter, pct, lo, hi))


func _refresh_slider(s: HSlider, getter: Callable, pct: Label, lo: float, hi: float) -> void:
	s.set_value_no_signal(getter.call())
	_set_percent(s.value, pct, lo, hi)


func _set_percent(value: float, pct: Label, lo: float, hi: float) -> void:
	pct.text = "%d%%" % roundi((value - lo) / (hi - lo) * 100.0) if lo == 0.0 else "%d%%" % roundi(value * 100.0)


func _check_row(parent: Control, text: String, setter: Callable, getter: Callable) -> void:
	var c := CheckBox.new()
	c.text = text
	c.toggled.connect(setter)
	parent.add_child(c)
	_settings_refreshers.append(_refresh_check.bind(c, getter))


func _refresh_check(c: CheckBox, getter: Callable) -> void:
	c.set_pressed_no_signal(getter.call())


# --- Construction: journal ---------------------------------------------------------------------------

func _build_journal(root: Control) -> void:
	_journal_root = ColorRect.new()
	(_journal_root as ColorRect).color = Color(0.02, 0.04, 0.08, 0.35)
	_journal_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(_journal_root)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_journal_root.add_child(center)
	var book := TextureRect.new()
	book.texture = _t("book")
	book.custom_minimum_size = Vector2(1048, 688)
	book.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(book)
	book.draw.connect(_draw_book_ribbon.bind(book))

	# Left page: quest list.
	var left := _vbox(12)
	left.position = Vector2(100, 70)
	left.size = Vector2(390, 560)
	book.add_child(left)
	var lt := _label(46, INK, true)
	lt.text = "Garden Journal"
	lt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	left.add_child(lt)
	left.add_child(_divider(240))
	left.add_child(_spacer(4))
	for i in QUESTS.size():
		var b := Button.new()
		b.custom_minimum_size = Vector2(390, 84)
		b.mouse_entered.connect(b.grab_focus)
		b.focus_entered.connect(_select_quest.bind(i))
		var row := _hbox(14)
		row.set_anchors_preset(Control.PRESET_FULL_RECT)
		row.offset_left = 22
		row.offset_right = -16
		b.add_child(row)
		var leaf := _icon_rect("leaf", 38, LEAF_TINT, "leaf_cream")
		row.add_child(leaf)
		var tv := _vbox(0)
		tv.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_child(tv)
		var tl := _label(25, INK, true)
		tl.text = QUESTS[i]["title"]
		tl.set_meta("base", INK)
		tv.add_child(tl)
		var sr := _hbox(6)
		tv.add_child(sr)
		var check := _icon_rect("check", 20)
		sr.add_child(check)
		var status := _label(18, INK_SOFT)
		status.set_meta("base", INK_SOFT)
		sr.add_child(status)
		b.set_meta("labels", [tl, status])
		b.set_meta("icons", [leaf])
		b.set_meta("status", status)
		b.set_meta("check", check)
		for sig in [b.focus_entered, b.focus_exited, b.mouse_entered, b.mouse_exited]:
			(sig as Signal).connect(_refresh_rows.bind(_journal_rows), CONNECT_DEFERRED)
		left.add_child(b)
		_journal_rows.append(b)

	# Right page: the selected quest with its real model.
	var right := _vbox(10)
	right.position = Vector2(560, 64)
	right.size = Vector2(420, 560)
	book.add_child(right)
	_journal_title = _label(40, INK, true)
	_journal_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	right.add_child(_journal_title)
	right.add_child(_divider(220))
	_journal_view = ModelView.new(Vector2i(420, 250))
	right.add_child(_journal_view)
	_journal_text = _label(24, INK)
	_journal_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_journal_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_journal_text.custom_minimum_size = Vector2(420, 90)
	right.add_child(_journal_text)
	right.add_child(_divider(220))
	var foot := _hbox(10)
	foot.alignment = BoxContainer.ALIGNMENT_CENTER
	right.add_child(foot)
	_journal_count = _label(20, INK_SOFT)
	foot.add_child(_journal_count)
	foot.add_child(_spacer(0))
	foot.add_child(_key("J", 18))
	var cl := _label(20, INK_SOFT)
	cl.text = "Close"
	foot.add_child(cl)
	_journal_root.hide()


func _draw_book_ribbon(book: Control) -> void:
	book.draw_texture(_t("ribbon"), Vector2(56, 10))


# --- Construction: ending -----------------------------------------------------------------------------

func _build_ending(root: Control) -> void:
	_ending_root = Control.new()
	_ending_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ending_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_ending_root)
	_vignette(_ending_root, 1000)
	var col := _left_column(_ending_root, 640)
	var h := _scene_heading("The garden glows again", 74)
	col.add_child(h)
	var d := _divider(320, Color(1.6, 1.4, 1.0))
	d.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	col.add_child(d)
	var s := _scene_heading("A little kindness goes a long way.", 29)
	s.add_theme_font_override("font", _serif)
	col.add_child(s)
	col.add_child(_spacer(14))
	var chip := _chip()
	chip.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	col.add_child(chip)
	var cr := _hbox(12)
	chip.add_child(cr)
	var lamp := _icon_rect("lantern", 40)
	lamp.custom_minimum_size = Vector2(52, 40)
	cr.add_child(lamp)
	var cl := _label(25, INK, true)
	cl.text = "All four quests complete"
	cr.add_child(cl)
	col.add_child(_spacer(10))
	var bv := _vbox(14)
	bv.custom_minimum_size = Vector2(420, 0)
	bv.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	col.add_child(bv)
	_ending_keep = _button(bv, "Keep Exploring", _keep_exploring, true)
	_button(bv, "Return to Title", return_to_title)
	_ending_root.hide()


func _keep_exploring() -> void:
	var t := _ending_root.create_tween()
	t.tween_property(_ending_root, "modulate:a", 0.0, 0.6)
	t.tween_callback(_ending_root.hide)
	t.tween_callback(_update_mouse)
	set_hud_visible(true)
	var p := _player()
	if p:
		p.unlock("ending")
