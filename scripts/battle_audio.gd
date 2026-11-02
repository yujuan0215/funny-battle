extends Node
## Small original synthesized cues, cached once and mixed with bounded polyphony.
static var muted := false
var _voices: Array[AudioStreamPlayer] = []
var _clips: Dictionary = {}
var _voice := 0
var _last: Dictionary = {}

func _ready() -> void:
	for id in ["place", "warn", "hit", "hurt", "counter", "start", "win", "lose", "spring", "phase"]:
		_clips[id] = load("res://assets/audio/" + id + ".wav")
	for i in 6:
		var player := AudioStreamPlayer.new()
		player.volume_db = -12
		add_child(player)
		_voices.append(player)

func toggle_mute() -> void:
	muted = not muted
	if muted:
		for player in _voices:
			player.stop()

func cue(id: String) -> void:
	if muted or not _clips.has(id) or DisplayServer.get_name() == "headless":
		return
	var now := Time.get_ticks_msec()
	if now - int(_last.get(id, -1000)) < 90:
		return
	_last[id] = now
	var player := _voices[_voice % _voices.size()]
	_voice += 1
	player.stream = _clips[id]
	player.play()
