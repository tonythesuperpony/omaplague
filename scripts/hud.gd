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

# Hover Info Card
@onready var hover_card: PanelContainer = $HoverCard
@onready var hover_title: Label = $HoverCard/Margin/VBox/HoverTitle
@onready var hover_pop: Label = $HoverCard/Margin/VBox/HoverPop
@onready var hover_traits: Label = $HoverCard/Margin/VBox/HoverTraits
@onready var hover_status: Label = $HoverCard/Margin/VBox/HoverStatus
@onready var hover_prompt: Label = $HoverCard/Margin/VBox/HoverPrompt

var news_queue: Array[String] = []
var news_timer: float = 0.0

func _ready():
	GameState.stats_updated.connect(_update_stats)
	GameState.dna_changed.connect(_on_dna_changed)
	GameState.news_added.connect(_on_news_added)
	
	# Load real control icons
	if ResourceLoader.exists("res://assets/icons/pause.png"):
		btn_pause.icon = load("res://assets/icons/pause.png")
		btn_pause.text = ""
		btn_pause.expand_icon = true
	if ResourceLoader.exists("res://assets/icons/play.png"):
		btn_1x.icon = load("res://assets/icons/play.png")
		btn_1x.text = ""
		btn_1x.expand_icon = true
	if ResourceLoader.exists("res://assets/icons/speed_2x.png"):
		btn_2x.icon = load("res://assets/icons/speed_2x.png")
		btn_2x.text = ""
		btn_2x.expand_icon = true
	if ResourceLoader.exists("res://assets/icons/speed_3x.png"):
		btn_3x.icon = load("res://assets/icons/speed_3x.png")
		btn_3x.text = ""
		btn_3x.expand_icon = true
		
	btn_pause.pressed.connect(func(): _set_sim_speed(0.0))
	btn_1x.pressed.connect(func(): _set_sim_speed(1.0))
	btn_2x.pressed.connect(func(): _set_sim_speed(2.0))
	btn_3x.pressed.connect(func(): _set_sim_speed(4.0))
	
	btn_disease.pressed.connect(func(): open_evolution_requested.emit())
	btn_spore.pressed.connect(_on_spore_pressed)
	
	hover_card.hide()
	
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
		var a = 0.7 + sin(Time.get_ticks_msec() * 0.006) * 0.3
		patient_zero_hint.modulate.a = a

func show_hover_info(cid: String, screen_pos: Vector2):
	var cdata = DataManager.get_country(cid)
	var cstate = GameState.country_states.get(cid, {})
	if cdata.is_empty():
		hover_card.hide()
		return
		
	hover_title.text = cdata.get("name", cid).to_upper()
	var pop = cdata.get("population", 1000000)
	hover_pop.text = "Population: " + _format_number(pop)
	
	var climate = cdata.get("climate", "balanced").capitalize()
	var wealth = cdata.get("wealth", "balanced").capitalize()
	var density = cdata.get("density", "balanced").capitalize()
	hover_traits.text = "%s | %s | %s" % [climate, wealth, density]
	
	var inf = cstate.get("infected", 0)
	var dead = cstate.get("dead", 0)
	if inf == 0 and dead == 0:
		hover_status.text = "Status: Healthy"
		hover_status.add_theme_color_override("font_color", Color(0.4, 0.9, 0.5))
	else:
		hover_status.text = "Infected: %s | Dead: %s" % [_format_number(inf), _format_number(dead)]
		hover_status.add_theme_color_override("font_color", Color(1.0, 0.35, 0.35))
		
	if not GameState.patient_zero_selected:
		hover_prompt.text = "[CLICK TO INFECT PATIENT ZERO]"
		hover_prompt.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	else:
		hover_prompt.text = "[CLICK TO OPEN DOSSIER]"
		hover_prompt.add_theme_color_override("font_color", Color(0.4, 0.8, 1.0))
		
	hover_card.show()
	
	# Position near cursor with clamping
	var vp_size = hover_card.get_viewport_rect().size
	var target_x = screen_pos.x + 18.0
	var target_y = screen_pos.y + 18.0
	if target_x + hover_card.size.x > vp_size.x - 10:
		target_x = screen_pos.x - hover_card.size.x - 18.0
	if target_y + hover_card.size.y > vp_size.y - 70:
		target_y = screen_pos.y - hover_card.size.y - 18.0
	hover_card.position = Vector2(target_x, target_y)

func hide_hover_info():
	hover_card.hide()

func _set_sim_speed(speed: float):
	GameState.sim_speed = speed
	_update_speed_buttons(speed)
	AudioManager.play_sfx("click")

func _update_speed_buttons(speed: float):
	btn_pause.modulate = Color(1.0, 0.5, 0.5) if speed == 0.0 else Color(0.65, 0.65, 0.65)
	btn_1x.modulate = Color(0.4, 1.0, 0.4) if speed == 1.0 else Color(0.65, 0.65, 0.65)
	btn_2x.modulate = Color(0.4, 1.0, 0.4) if speed == 2.0 else Color(0.65, 0.65, 0.65)
	btn_3x.modulate = Color(0.4, 1.0, 0.4) if speed == 4.0 else Color(0.65, 0.65, 0.65)

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
