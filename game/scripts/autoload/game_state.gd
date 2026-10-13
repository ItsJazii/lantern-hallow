extends Node
## Committed game progress. Every public action validates its preconditions,
## applies all of its changes together, saves once, then emits `changed`.
## Transient things (an active fishing cast, dialogue, tweens) never live here.

signal changed

const SCHEMA_VERSION := 1
const LEAF_IDS: Array[String] = ["moonleaf_a", "moonleaf_b", "moonleaf_c"]
const LANTERN_IDS: Array[String] = ["dock_lantern_west", "dock_lantern_east"]
const CHARM_IDS: Array[String] = ["charm_a", "charm_b", "charm_c"]

const TEA_REWARD := 3
const BAIT_COST := 1
const RELEASE_REWARD := 2

var save_path := "user://save.json"
var data: Dictionary = {}
var loaded_existing_save := false
## Tests turn this off so they never touch the player's real save.
var autosave := true


func _ready() -> void:
	data = defaults()
	load_game()


static func defaults() -> Dictionary:
	return {
		"keeper_met": false,
		"moss_met": false,
		"collected_leaf_ids": [],
		"leaves_returned": false,
		"tea_brewed": false,
		"tea_served": false,
		"coins": 0,
		"bait": 0,
		"has_rod": false,
		"blue_met": false,
		"release_count": 0,
		"first_moonfin_released": false,
		"wish_lantern_owned": false,
		"lit_lantern_ids": [],
		"ending_complete": false,
		"charm_ids": [],
	}


# --- Queries -----------------------------------------------------------------

func has(key: String) -> bool:
	return bool(data.get(key, false))


func coins() -> int:
	return int(data["coins"])


func bait() -> int:
	return int(data["bait"])


func leaves() -> int:
	return (data["collected_leaf_ids"] as Array).size()


func lit() -> int:
	return (data["lit_lantern_ids"] as Array).size()


func charms() -> int:
	return (data["charm_ids"] as Array).size()


func is_leaf_collected(id: String) -> bool:
	return id in (data["collected_leaf_ids"] as Array)


func is_lantern_lit(id: String) -> bool:
	return id in (data["lit_lantern_ids"] as Array)


func is_charm_collected(id: String) -> bool:
	return id in (data["charm_ids"] as Array)


func shop_unlocked() -> bool:
	return has("tea_served")


func can_buy_bait() -> bool:
	return shop_unlocked() and coins() >= BAIT_COST


## Safety net for a corrupted or hand-edited save: never part of normal play.
func recovery_available() -> bool:
	return shop_unlocked() and coins() == 0 and bait() == 0


func can_start_fishing() -> bool:
	return has("tea_served") and has("blue_met") and has("has_rod") and bait() >= 1


# --- Actions (each returns true only when it changed something) -------------

func meet_keeper() -> bool:
	if has("keeper_met"):
		return false
	data["keeper_met"] = true
	_commit()
	return true


func meet_moss() -> bool:
	if has("moss_met") or not has("keeper_met"):
		return false
	data["moss_met"] = true
	_commit()
	return true


func collect_leaf(id: String) -> bool:
	if not has("moss_met") or not id in LEAF_IDS or is_leaf_collected(id):
		return false
	(data["collected_leaf_ids"] as Array).append(id)
	_commit()
	return true


func return_leaves() -> bool:
	if has("leaves_returned") or leaves() < LEAF_IDS.size():
		return false
	data["leaves_returned"] = true
	_commit()
	return true


func brew_tea() -> bool:
	if has("tea_brewed") or not has("leaves_returned"):
		return false
	data["tea_brewed"] = true
	_commit()
	return true


func serve_tea() -> bool:
	if has("tea_served") or not has("tea_brewed"):
		return false
	data["tea_served"] = true
	data["coins"] = coins() + TEA_REWARD
	_commit()
	return true


func meet_blue() -> bool:
	if has("blue_met") or not has("tea_served"):
		return false
	data["blue_met"] = true
	_commit()
	return true


## Returns {"ok": bool, "rod_loaned": bool}. Coin and bait change together.
func buy_bait() -> Dictionary:
	if not can_buy_bait():
		return {"ok": false, "rod_loaned": false}
	var loaned := not has("has_rod")
	data["coins"] = coins() - BAIT_COST
	data["bait"] = bait() + 1
	data["has_rod"] = true
	_commit()
	return {"ok": true, "rod_loaned": loaned}


func give_recovery_bait() -> bool:
	if not recovery_available():
		return false
	data["bait"] = 1
	data["has_rod"] = true
	_commit()
	return true


## The single commit point of a fishing session, called once when the release
## animation finishes. Returns {"ok": bool, "first": bool}.
func commit_release() -> Dictionary:
	if not can_start_fishing():
		return {"ok": false, "first": false}
	data["bait"] = bait() - 1
	data["coins"] = coins() + RELEASE_REWARD
	data["release_count"] = int(data["release_count"]) + 1
	var first := false
	if not has("first_moonfin_released"):
		data["first_moonfin_released"] = true
		data["wish_lantern_owned"] = true
		first = true
	_commit()
	return {"ok": true, "first": first}


func light_lantern(id: String) -> bool:
	if not has("wish_lantern_owned") or not id in LANTERN_IDS or is_lantern_lit(id):
		return false
	(data["lit_lantern_ids"] as Array).append(id)
	_commit()
	return true


func complete_ending() -> bool:
	if has("ending_complete") or lit() < LANTERN_IDS.size():
		return false
	data["ending_complete"] = true
	_commit()
	return true


func collect_charm(id: String) -> bool:
	if not id in CHARM_IDS or is_charm_collected(id):
		return false
	(data["charm_ids"] as Array).append(id)
	_commit()
	return true


func reset_progress() -> void:
	data = defaults()
	loaded_existing_save = false
	_commit()


# --- Persistence ---------------------------------------------------------------

func _commit() -> void:
	if autosave:
		save_game()
	changed.emit()


func save_game() -> void:
	var text := JSON.stringify({"schema": SCHEMA_VERSION, "state": data}, "\t")
	var tmp := save_path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		push_warning("Could not write save: %s" % error_string(FileAccess.get_open_error()))
		return
	f.store_string(text)
	f.close()
	# Write-then-rename so a crash mid-write never leaves a half save.
	var err := DirAccess.rename_absolute(ProjectSettings.globalize_path(tmp), ProjectSettings.globalize_path(save_path))
	if err != OK:
		var direct := FileAccess.open(save_path, FileAccess.WRITE)
		if direct:
			direct.store_string(text)
			direct.close()


func load_game() -> void:
	if not FileAccess.file_exists(save_path):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(save_path))
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("Save file unreadable; starting fresh.")
		return
	var state: Variant = (parsed as Dictionary).get("state", {})
	if typeof(state) != TYPE_DICTIONARY:
		return
	data = sanitize(state)
	loaded_existing_save = true
	changed.emit()


## Rebuilds a clean state from untrusted save data: unknown keys are dropped,
## types are coerced, ids are filtered to known targets, counts can't go negative.
static func sanitize(raw: Dictionary) -> Dictionary:
	var out := defaults()
	for key in out.keys():
		if not raw.has(key):
			continue
		var value: Variant = raw[key]
		match typeof(out[key]):
			TYPE_BOOL:
				out[key] = bool(value)
			TYPE_INT:
				if typeof(value) in [TYPE_INT, TYPE_FLOAT]:
					out[key] = maxi(int(value), 0)
			TYPE_ARRAY:
				if typeof(value) == TYPE_ARRAY:
					out[key] = _filter_ids(value, _allowed_ids(key))
	return out


static func _allowed_ids(key: String) -> Array[String]:
	match key:
		"collected_leaf_ids":
			return LEAF_IDS
		"lit_lantern_ids":
			return LANTERN_IDS
		"charm_ids":
			return CHARM_IDS
	return []


static func _filter_ids(values: Array, allowed: Array[String]) -> Array:
	var out := []
	for v in values:
		var s := str(v)
		if s in allowed and not s in out:
			out.append(s)
	return out
