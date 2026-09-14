extends Node

var sounds: Dictionary = {}
var audio_players: Array[AudioStreamPlayer] = []
const POOL_SIZE: int = 8

var music_player: AudioStreamPlayer
var intro_tracks: Array[String] = [
	"res://assets/music/intro_1.ogg",
	"res://assets/music/intro_2.ogg",
	"res://assets/music/intro_3.ogg"
]
var current_track_path: String = ""

func _ready():
	_load_sounds()
	for i in range(POOL_SIZE):
		var p = AudioStreamPlayer.new()
		add_child(p)
		audio_players.append(p)
		
	music_player = AudioStreamPlayer.new()
	music_player.bus = "Master"
	add_child(music_player)

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

func play_random_intro_music():
	if music_player == null:
		music_player = AudioStreamPlayer.new()
		add_child(music_player)
		
	if music_player.playing:
		return
		
	var track = intro_tracks[randi() % intro_tracks.size()]
	current_track_path = track
	if ResourceLoader.exists(track):
		var stream = load(track)
		music_player.stream = stream
		music_player.volume_db = -2.5
		music_player.play()
		print("AudioManager: playing random intro music track -> ", track)

func stop_intro_music(fade_out_sec: float = 1.0):
	if music_player and music_player.playing:
		var tween = create_tween()
		tween.tween_property(music_player, "volume_db", -40.0, fade_out_sec)
		tween.tween_callback(music_player.stop)
