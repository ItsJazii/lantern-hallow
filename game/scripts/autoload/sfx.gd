extends Node
## Audio playback: pooled one-shots, positional cues, ambience and music loops.
## Clips live in res://assets/audio/<name>.wav; a missing clip is silently skipped
## so the game stays runnable while audio is being replaced. A cue with numbered
## takes (<name>_1.wav, <name>_2.wav, ...) plays a random take each time, never
## the same one twice in a row.

const DIR := "res://assets/audio/"
const POOL_SIZE := 12

var _streams := {}
var _variants := {}
var _last_variant := {}
var _pool: Array[AudioStreamPlayer] = []
var _next_free := {}
var _music_a: AudioStreamPlayer
var _music_b: AudioStreamPlayer
var _music_active: AudioStreamPlayer
var _music_name := ""
var _ambience: AudioStreamPlayer
var _music_tween: Tween


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in POOL_SIZE:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_pool.append(p)
	_music_a = _make_player("Music")
	_music_b = _make_player("Music")
	_music_active = _music_a
	_ambience = _make_player("Ambience")
	_music_a.finished.connect(_on_music_finished)
	_music_b.finished.connect(_on_music_finished)


func _make_player(bus: String) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.bus = bus
	add_child(p)
	return p


## How many numbered takes a cue has (0 when it is a single clip).
func variant_count(clip: String) -> int:
	if not _variants.has(clip):
		var n := 0
		while ResourceLoader.exists(DIR + "%s_%d.wav" % [clip, n + 1]):
			n += 1
		_variants[clip] = n
	return _variants[clip]


func has_clip(clip: String) -> bool:
	return variant_count(clip) > 0 or ResourceLoader.exists(DIR + clip + ".wav")


## Picks the take to play for a cue.
func _resolve(clip: String) -> String:
	var n := variant_count(clip)
	if n == 0:
		return clip
	var i := randi() % n + 1
	if n > 1 and i == int(_last_variant.get(clip, 0)):
		i = i % n + 1
	_last_variant[clip] = i
	return "%s_%d" % [clip, i]


func get_stream(clip: String) -> AudioStream:
	if _streams.has(clip):
		return _streams[clip]
	var path := DIR + clip + ".wav"
	var s: AudioStream = null
	if ResourceLoader.exists(path):
		s = load(path)
		if clip.begins_with("loop_") or clip == "music_main":
			_make_looping(s)
	_streams[clip] = s
	return s


func _make_looping(s: AudioStream) -> void:
	var wav := s as AudioStreamWAV
	if wav == null:
		return
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_begin = 0
	wav.loop_end = int(wav.get_length() * wav.mix_rate)


## Returns false when the cue is still cooling down (prevents chirp spam).
func _cooled(clip: String, cooldown: float) -> bool:
	if cooldown <= 0.0:
		return true
	var now := Time.get_ticks_msec() / 1000.0
	if now < float(_next_free.get(clip, 0.0)):
		return false
	_next_free[clip] = now + cooldown
	return true


func play(clip: String, volume_db := 0.0, pitch := 1.0, cooldown := 0.0) -> void:
	var s := get_stream(_resolve(clip))
	if s == null or not _cooled(clip, cooldown):
		return
	var player: AudioStreamPlayer = _pool[0]
	for p in _pool:
		if not p.playing:
			player = p
			break
	player.stream = s
	player.volume_db = volume_db
	player.pitch_scale = pitch
	player.play()


func play_at(clip: String, pos: Vector3, volume_db := 0.0, pitch := 1.0, cooldown := 0.0) -> void:
	var s := get_stream(_resolve(clip))
	var scene := get_tree().current_scene
	if s == null or scene == null or not _cooled(clip, cooldown):
		return
	var p := AudioStreamPlayer3D.new()
	p.stream = s
	p.bus = "SFX"
	p.volume_db = volume_db
	p.pitch_scale = pitch
	p.unit_size = 6.0
	p.max_distance = 45.0
	scene.add_child(p)
	p.global_position = pos
	p.finished.connect(p.queue_free)
	p.play()


## A positional loop owned by `parent` (pond water, kettle simmer).
func attach_loop(clip: String, parent: Node3D, volume_db := 0.0, unit_size := 5.0) -> AudioStreamPlayer3D:
	var s := get_stream(clip)
	if s == null:
		return null
	var p := AudioStreamPlayer3D.new()
	p.stream = s
	p.bus = "Ambience"
	p.volume_db = volume_db
	p.unit_size = unit_size
	p.max_distance = 40.0
	parent.add_child(p)
	p.play()
	return p


func play_ambience(clip: String, volume_db := -4.0) -> void:
	var s := get_stream(clip)
	if s == null or (_ambience.playing and _ambience.stream == s):
		return
	_ambience.stream = s
	_ambience.volume_db = volume_db
	_ambience.play()


func play_music(clip: String, fade := 2.5) -> void:
	if clip == _music_name and _music_active.playing:
		return
	var s := get_stream(clip)
	if s == null:
		return
	_music_name = clip
	var old := _music_active
	var new := _music_b if _music_active == _music_a else _music_a
	_music_active = new
	new.stream = s
	new.volume_db = -40.0
	new.play()
	if _music_tween:
		_music_tween.kill()
	_music_tween = create_tween().set_parallel(true)
	_music_tween.tween_property(new, "volume_db", 0.0, fade)
	if old.playing:
		_music_tween.tween_property(old, "volume_db", -40.0, fade)
		_music_tween.chain().tween_callback(old.stop)


func stop_all() -> void:
	for p in _pool:
		p.stop()


func _on_music_finished() -> void:
	# The ending variation is a one-shot; drift back to the garden loop after it.
	if _music_name == "music_ending":
		play_music("music_main", 4.0)
