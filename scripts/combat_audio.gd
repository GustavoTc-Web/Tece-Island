extends Node

var volume := 0.3
var muted := false
var preferences_path := "user://audio-preferences.cfg"
var voices: Array[AudioStreamPlayer] = []
var sounds := {}
var last_played := {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var prefs := ConfigFile.new()
	if prefs.load(preferences_path) == OK:
		volume = clampf(float(prefs.get_value("sound", "volume", 0.3)), 0, 1)
		muted = bool(prefs.get_value("sound", "muted", false))
	for kind in ["swing", "arrow", "shot", "impact", "blocked", "damage", "objective"]:
		sounds[kind] = tone(kind)
	for i in range(4):
		var voice := AudioStreamPlayer.new()
		add_child(voice)
		voices.append(voice)

func configure(level: float, silent: bool) -> void:
	volume = clampf(level, 0, 1)
	muted = silent
	for voice in voices: voice.volume_db = linear_to_db(maxf(volume, 0.0001))
	if muted or volume == 0:
		for voice in voices: voice.stop()
	var prefs := ConfigFile.new()
	prefs.set_value("sound", "volume", volume)
	prefs.set_value("sound", "muted", muted)
	prefs.save(preferences_path)

func play(kind: String) -> bool:
	if DisplayServer.get_name() == "headless": return false
	if muted or volume <= 0 or not sounds.has(kind): return false
	var now := Time.get_ticks_msec()
	if now - int(last_played.get(kind, -1000)) < 90: return false
	for voice in voices:
		if voice.playing: continue
		last_played[kind] = now
		voice.stream = sounds[kind]
		voice.volume_db = linear_to_db(volume)
		voice.play()
		return true
	return false

func _exit_tree() -> void:
	for voice in voices:
		voice.stop()
		voice.stream = null

func tone(kind: String) -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 22050
	var frequencies := {"swing": 180, "arrow": 640, "shot": 90, "impact": 320, "blocked": 120, "damage": 210, "objective": 880}
	var count := 2646 if kind == "damage" else 1764
	var bytes := PackedByteArray()
	bytes.resize(count * 2)
	for i in range(count):
		var t := float(i) / count
		var frequency := float(frequencies[kind]) * (1.0 - t * 0.45)
		var wave := sin(TAU * frequency * i / stream.mix_rate)
		wave += sin(TAU * frequency * 2.7 * i / stream.mix_rate) * 0.25
		bytes.encode_s16(i * 2, int(wave * (1 - t) * 0.18 * 32767))
	stream.data = bytes
	return stream
