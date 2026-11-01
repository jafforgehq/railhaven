extends Node
## Music + ambience + pooled SFX on dedicated buses. Settings persist via ConfigFile.

const SETTINGS_PATH := "user://settings.cfg"
const DIR := "res://assets/audio/"
const EXTS := [".ogg", ".wav", ".mp3"]
const SFX_VOLUME := {"ui_click": -6.0, "ui_open": -8.0, "collect": -4.0, "drone_launch": -8.0,
	"drone_return": -4.0, "alarm": -6.0, "error": -6.0, "whistle": -8.0, "build": -3.0, "upgrade": -3.0}

## Short taps on the phone's haptic motor for the moments that matter (ms).
const HAPTIC := {"build": 30, "upgrade": 25, "goal_complete": 40, "error": 15, "alarm": 60, "whistle": 40, "boost": 35}

var music_on := true
var sfx_on := true
var haptics_on := true

var _music: AudioStreamPlayer
var _ambience: Array[AudioStreamPlayer] = []
var _pool: Array[AudioStreamPlayer] = []
var _cache := {}
var _current_music := ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for bus in ["Music", "SFX", "Ambience"]:
		if AudioServer.get_bus_index(bus) == -1:
			AudioServer.add_bus()
			var i := AudioServer.bus_count - 1
			AudioServer.set_bus_name(i, bus)
			AudioServer.set_bus_send(i, "Master")
	_music = _player("Music")
	for i in 8:
		_pool.append(_player("SFX"))
	for n in ["train_loop", "wind_loop"]:
		var p := _player("Ambience")
		p.stream = _stream(n, true)
		p.volume_db = -14.0 if n == "train_loop" else -20.0
		_ambience.append(p)
	_load_settings()
	_apply()


func _player(bus: String) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.bus = bus
	add_child(p)
	return p


func _stream(name: String, loop := false) -> AudioStream:
	var key := name + ("#loop" if loop else "")
	if _cache.has(key):
		return _cache[key]
	var s: AudioStream = null
	for sub in ["sfx/", "music/"]:
		for e in EXTS:
			var path: String = DIR + sub + name + e
			if ResourceLoader.exists(path):
				s = load(path)
				break
		if s:
			break
	if s and loop:
		if s is AudioStreamWAV:
			s = s.duplicate()
			s.loop_mode = AudioStreamWAV.LOOP_FORWARD
			s.loop_end = int(s.get_length() * s.mix_rate)
		elif "loop" in s:
			s = s.duplicate()
			s.loop = true
	_cache[key] = s
	return s


func play(name: String, pitch_jitter := 0.06) -> void:
	if haptics_on and HAPTIC.has(name) and OS.has_feature("mobile"):
		Input.vibrate_handheld(HAPTIC[name])
	if not sfx_on:
		return
	var s := _stream(name)
	if s == null:
		return
	for p in _pool:
		if not p.playing:
			p.stream = s
			p.volume_db = SFX_VOLUME.get(name, -4.0)
			p.pitch_scale = 1.0 + randf_range(-pitch_jitter, pitch_jitter)
			p.play()
			return


func play_music(name: String) -> void:
	if name == _current_music and _music.playing:
		return
	_current_music = name
	var s := _stream(name, name == "theme")
	if s == null:
		return
	var tw := create_tween()
	if _music.playing:
		tw.tween_property(_music, "volume_db", -40.0, 0.8)
	tw.tween_callback(func():
		_music.stream = s
		_music.volume_db = -40.0
		if music_on:
			_music.play())
	tw.tween_property(_music, "volume_db", -10.0, 1.5)
	if name != "theme":
		# One-shot sting: fall back to the theme when it ends.
		tw.tween_interval(maxf(0.5, s.get_length() - 0.5))
		tw.tween_callback(func(): play_music("theme"))


func set_ambience_intensity(wind: float) -> void:
	if _ambience.size() > 1:
		_ambience[1].volume_db = lerpf(-22.0, -8.0, clampf(wind, 0.0, 1.0))


func set_music(on: bool) -> void:
	music_on = on
	_apply()
	_save_settings()


func set_haptics(on: bool) -> void:
	haptics_on = on
	_save_settings()


func set_sfx(on: bool) -> void:
	sfx_on = on
	_apply()
	_save_settings()


func _apply() -> void:
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Music"), not music_on)
	AudioServer.set_bus_mute(AudioServer.get_bus_index("SFX"), not sfx_on)
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Ambience"), not sfx_on)
	if music_on and _current_music != "" and not _music.playing and _music.stream:
		_music.play()
	for p in _ambience:
		if p.stream and not p.playing:
			p.play()


func _load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) == OK:
		music_on = cfg.get_value("audio", "music", true)
		sfx_on = cfg.get_value("audio", "sfx", true)
		haptics_on = cfg.get_value("audio", "haptics", true)


func _save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "music", music_on)
	cfg.set_value("audio", "sfx", sfx_on)
	cfg.set_value("audio", "haptics", haptics_on)
	if cfg.save(SETTINGS_PATH) != OK:
		push_error("Could not save settings")
