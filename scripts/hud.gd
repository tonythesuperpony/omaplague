extends CanvasLayer

signal open_evolution_requested()
signal open_world_requested()

@onready var date_label: Label = $TopBar/Margin/HBox/DateLabel
@onready var news_label: Label = $TopBar/Margin/HBox/NewsContainer/NewsLabel
@onready var btn_pause: Button = $TopBar/Margin/HBox/SpeedBox/BtnPause
@onready var btn_1x: Button = $TopBar/Margin/HBox/SpeedBox/Btn1x
@onready var btn_2x: Button = $TopBar/Margin/HBox/SpeedBox/Btn2x
@onready var btn_3x: Button = $TopBar/Margin/HBox/SpeedBox/Btn3x

@onready var btn_disease: Button = $BottomBar/Margin/HBox/BtnDisease
@onready var dna_label: Label = $BottomBar/Margin/HBox/BtnDisease/DnaBadge/DnaLabel
@onready var pop_label: Label = $BottomBar/Margin/HBox/StatsBox/PopLabel
@onready var inf_label: Label = $BottomBar/Margin/HBox/StatsBox/InfLabel
@onready var dead_label: Label = $BottomBar/Margin/HBox/StatsBox/DeadLabel
@onready var cure_bar: ProgressBar = $BottomBar/Margin/HBox/CureBox/CureBar
@onready var cure_label: Label = $BottomBar/Margin/HBox/CureBox/CureLabel

@onready var patient_zero_hint: Panel = $PatientZeroHint
@onready var btn_spore: Button = $BtnSpore

var news_queue: Array[String] = []
var news_timer: float = 0.0

func _ready():
	GameState.stats_updated.connect(_update_stats)
	GameState.dna_changed.connect(_on_dna_changed)
	GameState.news_added.connect(_on_news_added)
	
	btn_pause.pressed.connect(func(): _set_sim_speed(0.0))
	btn_1x.pressed.connect(func(): _set_sim_speed(1.0))
	btn_2x.pressed.connect(func(): _set_sim_speed(2.0))
	btn_3x.pressed.connect(func(): _set_sim_speed(4.0))
	
	btn_disease.pressed.connect(func(): open_evolution_requested.emit())
	btn_spore.pressed.connect(_on_spore_pressed)
	
	_update_stats()
	_update_speed_buttons(1.0)
	
	btn_spore.visible = (GameState.disease_type == "fungus")

func _process(delta: float):
	if news_queue.size() > 0:
		news_timer += delta
		if news_timer > 5.0:
			news_timer = 0.0
			news_label.text = news_queue.pop_front()
			
	patient_zero_hint.visible = not GameState.patient_zero_selected
	if patient_zero_hint.visible:
		# Pulsing opacity
		var a = 0.7 + sin(Time.get_ticks_msec() * 0.005) * 0.3
		patient_zero_hint.modulate.a = a

func _set_sim_speed(speed: float):
	GameState.sim_speed = speed
	_update_speed_buttons(speed)
	AudioManager.play_sfx("click")

func _update_speed_buttons(speed: float):
	btn_pause.modulate = Color(1, 0.4, 0.4) if speed == 0.0 else Color(0.7, 0.7, 0.7)
	btn_1x.modulate = Color(0.4, 1.0, 0.4) if speed == 1.0 else Color(0.7, 0.7, 0.7)
	btn_2x.modulate = Color(0.4, 1.0, 0.4) if speed == 2.0 else Color(0.7, 0.7, 0.7)
	btn_3x.modulate = Color(0.4, 1.0, 0.4) if speed == 4.0 else Color(0.7, 0.7, 0.7)

func _update_stats():
	date_label.text = GameState.get_formatted_date()
	dna_label.text = str(GameState.dna_points) + " DNA"
	
	pop_label.text = "Healthy: " + _format_number(GameState.world_population - GameState.world_infected - GameState.world_dead)
	inf_label.text = "Infected: " + _format_number(GameState.world_infected)
	dead_label.text = "Dead: " + _format_number(GameState.world_dead)
	
	cure_bar.value = GameState.cure_progress * 100.0
	cure_label.text = "Cure: %d%%" % int(GameState.cure_progress * 100.0)

func _on_dna_changed(new_dna: int, _delta: int):
	dna_label.text = str(new_dna) + " DNA"

func _on_news_added(headline: String):
	news_label.text = headline
	news_timer = 0.0

func _on_spore_pressed():
	if GameState.dna_points >= 4:
		GameState.spend_dna(4)
		GameState.spore_burst()
		AudioManager.play_sfx("evolve")
	else:
		GameState.news_added.emit("Need 4 DNA points for Spore Burst!")

func _format_number(n: int) -> String:
	var s = str(n)
	var res = ""
	var cnt = 0
	for i in range(s.length() - 1, -1, -1):
		res = s[i] + res
		cnt += 1
		if cnt % 3 == 0 and i > 0:
			res = "," + res
	return res
