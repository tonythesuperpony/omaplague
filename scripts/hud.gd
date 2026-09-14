extends CanvasLayer

signal open_evolution_requested()
signal open_world_requested()

@onready var date_label: Label = $TopBar/Margin/HBox/DateLabel
@onready var news_container: Control = $TopBar/Margin/HBox/NewsContainer
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

# Marquee news system
var breaking_queue: Array[String] = []
var is_showing_breaking: bool = false
var marquee_x: float = 0.0
var marquee_speed: float = 90.0
var funny_index: int = 0

var funny_news_pool: Array[String] = [
	"Tony the Pony confirms: 'If your country is infected, simply run: omarchy restart shell.'",
	"Tony the Pony releases new update for Omaplague; world scientists question his credentials.",
	"Tony the Pony spotted galloping across Hyprland at 240Hz with zero frame drops.",
	"Omarchy Linux users report their system is so hardened, real biological pathogens fail to compile.",
	"Mass panic averted as Omarchy users refuse to quarantine until all dotfiles are committed.",
	"Tony the Pony seen in Bio-Lab drinking espresso and muttering about Wayland fractional scaling.",
	"Omarchy developer declares global pathogen 'an undocumented feature of natural selection'.",
	"Arch Linux user informs emergency room triage nurse: 'I use Arch, by the way.'",
	"Tony the Pony announces: 'Next patch will add more boats and planes to the global simulation.'",
	"WHO strictly advises all citizens to avoid touching grass until further notice.",
	"Global toilet paper reserves drop to absolute zero for no scientific reason whatsoever.",
	"Conspiracy theorists claim pathogen was created by keyboard manufacturers to sell more switches.",
	"World leaders hold emergency summit to debate dark mode versus light mode in quarantine bunkers.",
	"Doctors recommend wearing two masks, three gloves, and active noise-canceling headphones.",
	"Scientists discover opening 100 browser tabs increases ambient body temperature by 1.2 degrees.",
	"Local man claims eating raw garlic and arguing on social media makes him completely immune.",
	"Stock markets crash after leading tech CEO accidentally deletes production database.",
	"International health organization urges everyone to stay inside and play more video games.",
	"Supermarket runs out of pasta; civilization officially considered on the brink of collapse.",
	"Tony the Pony voted 'Most Likely to Accidentally End Humanity in a Video Game'.",
	"Meteorologists predict a 70% chance of rain and a 100% chance of impending doom."
]

func _ready():
	# Shuffle news pool for variety
	funny_news_pool.shuffle()
	
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
	
	# Initialize first marquee message
	marquee_x = 20.0
	news_label.position.x = marquee_x
	news_label.text = "/// SELECT PATIENT ZERO ON THE WORLD MAP TO BEGIN OUTBREAK ///"
	news_label.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4, 1.0))

func _process(delta: float):
	# Marquee scrolling
	var container_w = news_container.size.x
	if container_w <= 10.0:
		container_w = 400.0
		
	marquee_x -= delta * marquee_speed
	news_label.position.x = marquee_x
	
	# When scrolled off the left edge, load the next headline
	if marquee_x < -news_label.size.x:
		_load_next_headline(container_w)
			
	patient_zero_hint.visible = not GameState.patient_zero_selected
	if patient_zero_hint.visible:
		var a = 0.7 + sin(Time.get_ticks_msec() * 0.006) * 0.3
		patient_zero_hint.modulate.a = a

func _load_next_headline(container_w: float):
	marquee_x = container_w + 30.0
	news_label.position.x = marquee_x
	
	if breaking_queue.size() > 0:
		is_showing_breaking = true
		var headline = breaking_queue.pop_front()
		news_label.text = "🚨 BREAKING NEWS: %s 🚨" % headline.to_upper()
		news_label.add_theme_color_override("font_color", Color(1.0, 0.25, 0.25, 1.0))
		marquee_speed = 105.0
	else:
		is_showing_breaking = false
		var headline = funny_news_pool[funny_index % funny_news_pool.size()]
		funny_index += 1
		news_label.text = "/// %s ///" % headline
		news_label.add_theme_color_override("font_color", Color(0.85, 0.92, 1.0, 0.95))
		marquee_speed = 85.0

func _on_news_added(headline: String):
	breaking_queue.append(headline)
	# If currently showing idle sarcastic news, immediately cut to breaking news!
	if not is_showing_breaking:
		var container_w = news_container.size.x
		if container_w <= 10.0:
			container_w = 400.0
		_load_next_headline(container_w)
		AudioManager.play_sfx("alert")

func show_hover_info(cid: String, screen_pos: Vector2):
	var cdata = DataManager.get_country(cid)
	var cstate = GameState.country_states.get(cid, {})
	if cdata.is_empty():
		hover_card.hide()
		return
		
	hover_title.text = cdata.get("name", cid).to_upper()
	var pop = cstate.get("population", cdata.get("population", 0))
	hover_pop.text = "Population: %s" % _format_number(pop)
	
	var climate = cdata.get("climate", "temperate").capitalize()
	var wealth = cdata.get("wealth", "medium").capitalize()
	var density = cdata.get("density", "normal").capitalize()
	hover_traits.text = "%s  •  %s  •  %s" % [climate, wealth, density]
	
	var is_inf = cstate.get("is_infected", false)
	if is_inf:
		var inf = cstate.get("infected", 0)
		var dead = cstate.get("dead", 0)
		var air_open = cstate.get("airport_open", true)
		var sea_open = cstate.get("seaport_open", true)
		
		var ports_str = "Air: %s  Sea: %s" % [
			"OPEN" if air_open else "CLOSED",
			"OPEN" if sea_open else "CLOSED"
		]
		hover_status.text = "Infected: %s  |  Dead: %s  |  %s" % [
			_format_number(inf),
			_format_number(dead),
			ports_str
		]
		hover_status.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
	else:
		hover_status.text = "Status: HEALTHY (Uninfected)"
		hover_status.add_theme_color_override("font_color", Color(0.3, 0.85, 0.5))
		
	if not GameState.patient_zero_selected:
		hover_prompt.text = "CLICK TO INFECT PATIENT ZERO HERE"
		hover_prompt.show()
	else:
		hover_prompt.text = "CLICK TO VIEW DETAILED COUNTRY DOSSIER"
		hover_prompt.show()
		
	var card_w = 320.0
	var card_h = 130.0
	var vp_size = get_viewport().get_visible_rect().size
	var target_x = screen_pos.x + 18.0
	var target_y = screen_pos.y + 18.0
	
	if target_x + card_w > vp_size.x - 12.0:
		target_x = screen_pos.x - card_w - 18.0
	if target_y + card_h > vp_size.y - 80.0:
		target_y = screen_pos.y - card_h - 18.0
		
	target_x = clamp(target_x, 12.0, vp_size.x - card_w - 12.0)
	target_y = clamp(target_y, 55.0, vp_size.y - card_h - 75.0)
	
	hover_card.position = Vector2(target_x, target_y)
	hover_card.show()

func hide_hover_info():
	hover_card.hide()

func _set_sim_speed(s: float):
	GameState.sim_speed = s
	_update_speed_buttons(s)
	AudioManager.play_sfx("click")

func _update_speed_buttons(current_speed: float):
	btn_pause.modulate = Color(1.3, 0.5, 0.5) if current_speed == 0.0 else Color(0.7, 0.7, 0.7)
	btn_1x.modulate = Color(0.4, 0.9, 1.2) if current_speed == 1.0 else Color(0.7, 0.7, 0.7)
	btn_2x.modulate = Color(0.4, 0.9, 1.2) if current_speed == 2.0 else Color(0.7, 0.7, 0.7)
	btn_3x.modulate = Color(0.4, 0.9, 1.2) if current_speed == 4.0 else Color(0.7, 0.7, 0.7)

func _update_stats():
	if not is_inside_tree():
		return
	date_label.text = GameState.get_date_string()
	pop_label.text = "Healthy: " + _format_number(max(0, GameState.world_population - GameState.world_infected - GameState.world_dead))
	inf_label.text = "Infected: " + _format_number(GameState.world_infected)
	dead_label.text = "Dead: " + _format_number(GameState.world_dead)
	
	cure_bar.value = GameState.cure_progress * 100.0
	cure_label.text = "Cure: %d%%" % int(GameState.cure_progress * 100.0)

func _on_dna_changed(new_dna: int, _delta: int):
	dna_label.text = str(new_dna) + " DNA"

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
