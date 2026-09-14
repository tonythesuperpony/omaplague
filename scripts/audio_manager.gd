extends Node

var sounds: Dictionary = {}
var audio_players: Array[AudioStreamPlayer] = []
const POOL_SIZE: int = 8

var music_player: AudioStreamPlayer
var intro_tracks: Array[String] = [
	"res://assets/music/intro_1.ogg",
	"res://assets/music/intro_2.ogg",
	"res://assets/music/intro_3.ogg",
	"res://assets/music/intro_4.ogg"
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

var current_track_index: int = 0
var is_intro_music_active: bool = false

func play_random_intro_music():
	is_intro_music_active = true
	current_track_index = randi() % intro_tracks.size()
	_play_current_intro_track()

func _play_current_intro_track():
	if not is_intro_music_active:
		return
	if music_player == null:
		music_player = AudioStreamPlayer.new()
		music_player.bus = "Master"
		add_child(music_player)
		
	if not music_player.finished.is_connected(_on_intro_music_finished):
		music_player.finished.connect(_on_intro_music_finished)
		
	var track = intro_tracks[current_track_index % intro_tracks.size()]
	current_track_path = track
	if ResourceLoader.exists(track):
		var stream = load(track)
		music_player.stream = stream
		music_player.volume_db = -2.5
		music_player.play()
		print("AudioManager: playing intro track [%d/%d] -> %s" % [current_track_index + 1, intro_tracks.size(), track])

func _on_intro_music_finished():
	if not is_intro_music_active:
		return
	# Loop to next song in rotation
	current_track_index = (current_track_index + 1) % intro_tracks.size()
	print("AudioManager: intro track finished, rotating to next song: index %d" % current_track_index)
	_play_current_intro_track()

func stop_intro_music(fade_out_sec: float = 1.0):
	is_intro_music_active = false
	if music_player and music_player.playing:
		var tween = create_tween()
		tween.tween_property(music_player, "volume_db", -40.0, fade_out_sec)
		tween.tween_callback(music_player.stop)
