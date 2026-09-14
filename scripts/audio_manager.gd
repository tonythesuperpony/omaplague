extends Node

var sounds: Dictionary = {}
var audio_players: Array[AudioStreamPlayer] = []
const POOL_SIZE: int = 8

func _ready():
	_load_sounds()
	for i in range(POOL_SIZE):
		var p = AudioStreamPlayer.new()
		add_child(p)
		audio_players.append(p)

func _load_sounds():
	var sound_names = ["pop", "dna_pop", "evolve", "alert", "cure_warn", "click", "victory", "game_over"]
	for sname in sound_names:
		var path = "res://assets/sounds/" + sname + ".wav"
		if ResourceLoader.exists(path):
			sounds[sname] = load(path)

func play_sfx(name: String, volume_db: float = 0.0):
	if not sounds.has(name):
		return
	for p in audio_players:
		if not p.playing:
			p.stream = sounds[name]
			p.volume_db = volume_db
			p.play()
			return
	# If all busy, use first
	audio_players[0].stream = sounds[name]
	audio_players[0].volume_db = volume_db
	audio_players[0].play()
