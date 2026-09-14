extends CanvasLayer

signal open_evolution_requested()
signal open_world_requested()
signal open_about_requested()

@onready var date_label: Label = $TopBar/Margin/HBox/DateLabel
@onready var news_container: PanelContainer = $TopBar/Margin/HBox/NewsContainer
@onready var news_badge: Label = $TopBar/Margin/HBox/NewsContainer/Margin/HBox/NewsBadge
@onready var news_viewport: Control = $TopBar/Margin/HBox/NewsContainer/Margin/HBox/NewsViewport
@onready var news_label: Label = $TopBar/Margin/HBox/NewsContainer/Margin/HBox/NewsViewport/NewsLabel

@onready var btn_pause: Button = $TopBar/Margin/HBox/SpeedBox/BtnPause
@onready var btn_1x: Button = $TopBar/Margin/HBox/SpeedBox/Btn1x
@onready var btn_2x: Button = $TopBar/Margin/HBox/SpeedBox/Btn2x
@onready var btn_3x: Button = $TopBar/Margin/HBox/SpeedBox/Btn3x
@onready var btn_about: Button = $TopBar/Margin/HBox/BtnAbout

@onready var btn_disease: Button = $BottomBar/Margin/HBox/BtnDisease
@onready var btn_pop_all: Button = $BottomBar/Margin/HBox/BtnPopAll
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
enum NewsMode {
	NORMAL_MARQUEE,
	BREAKING_ALERT
}

var current_news_mode: NewsMode = NewsMode.NORMAL_MARQUEE
var breaking_queue: Array[String] = []

# Continuous Marquee Ribbon
const SEPARATOR: String = "   ◆   "
var active_items: Array[String] = []
var scroll_pos: float = 0.0
var marquee_speed: float = 85.0
var funny_index: int = 0

# Breaking News State
var breaking_text: String = ""
var breaking_x: float = 0.0
var breaking_speed: float = 240.0

var funny_news_pool: Array[String] = [
	# Tony the Pony (Creator of Omaplague)
	"Tony the Pony confirms: 'If your country is infected, simply run: omarchy restart shell.'",
	"Tony the Pony releases new update for Omaplague; world scientists question his veterinary credentials.",
	"Tony the Pony spotted galloping across Hyprland at 240Hz with zero frame drops.",
	"Tony the Pony declares: 'All bugs in the pathogen simulation are intentional artistic features.'",
	"Tony the Pony claims the cure to the pathogen is simply recompiling the kernel with -O3.",
	"Tony the Pony awarded Nobel Prize in Pandemics; immediately devolves Insomnia for 2 DNA points.",
	"Tony the Pony spotted fleeing to Greenland in a fishing boat; refused entry due to closed seaports.",
	"Tony the Pony reminds citizens: 'Wash your hooves, stay hydrated, and always git push before evacuating.'",
	"Tony the Pony voted 'Most Likely to Accidentally End Humanity in a Video Game' by 9 out of 10 doctors.",
	"Tony the Pony rejects WHO quarantine treaty: 'My pathogen has full sudo privileges on this planet.'",
	"Tony the Pony announces: 'Boats and airplanes now travel 10% faster thanks to Arch Linux networking optimizations.'",
	"Tony the Pony seen debugging global infection rates using print statements in terminal.",
	"Tony the Pony clarifies: 'No real ponies were harmed in the making of this global apocalyptic event.'",
	"Tony the Pony spotted testing experimental vaccines on rubber ducks in his bathroom.",
	"Tony the Pony advises world leaders: 'Have you tried turning the planet off and on again?'",
	"Tony the Pony spotted editing DNA nucleotides directly inside Neovim with zero plugins.",
	"Tony the Pony promises: 'If humanity survives, next update will feature hyper-realistic boat animations.'",
	"Tony the Pony lights a cigarette and cracks a cold beer while reviewing global fatality dashboards.",
	"Tony the Pony caught renaming the pathogen 'btw' so he can say he spreads Arch, by the way.",
	"Tony the Pony insists the global death counter is just a high score and he is currently winning.",
	"Tony the Pony seen arguing with a WHO scientist about whether tabs or spaces spread disease faster.",
	"Tony the Pony opens Discord, pings @everyone about the apocalypse, then immediately mutes the server.",
	"Tony the Pony denies involvement in the outbreak: 'I was just pushing to main. It's not my fault main is Earth.'",
	"Tony the Pony's git commit message: 'fix: minor pandemic, should be stable now — please test in prod.'",
	"Tony the Pony sets out-of-office reply: 'Currently spreading disease, will respond when cure hits 99%.'",
	"Tony the Pony's dotfiles found to contain 14 lines of weaponized RNA encoded in bash aliases.",
	"Tony the Pony issues hotfix for the human respiratory system; changelog reads: 'misc improvements'.",

	# Omarchy & Linux / Hacker Culture
	"Omarchy Linux users report their system is so hardened, real biological pathogens fail to compile.",
	"Mass panic averted as Omarchy users refuse to evacuate bunkers until all dotfiles are committed.",
	"Omarchy developer declares global outbreak 'an undocumented feature of natural selection'.",
	"Arch Linux user informs emergency room triage nurse: 'I use Arch, by the way.'",
	"Omarchy theming engine releases new biohazard palette; users praise the high contrast ratio.",
	"Systemd service 'pandemic.service' fails with status=255; global sysadmins reboot the planet.",
	"Scientists attempt to sandbox the disease inside Docker; container escapes and infects Iceland.",
	"Wayland protocol committee still debating whether hand washing should be handled client-side.",
	"Vim user quarantined for 3 weeks simply because they cannot figure out how to :wq.",
	"Hyprland blur shader applied to biohazard microscope lenses; doctors admire the smooth aesthetic.",
	"Local developer claims rewriting the human immune system in Rust will eliminate all coughing bugs.",
	"Sysadmin attempts to terminate pandemic with 'killall -9 virus'; accidentally turns off sun.",
	"pacman -Syu accidentally upgrades human DNA to version 2.0; users report unexpected extra limbs.",
	"Omarchy user sets wallpaper to pure void black to save 0.0001 watts of battery during apocalypse.",
	"Neovim user writes 400-line Lua config to automatically track pathogen mutations in real time.",
	"Kernel developers reject global vaccine patch: 'Does not adhere to Linux kernel coding style conventions.'",
	"Emergency broadcast interrupted by Omarchy user asking how to center a floating window.",
	"Global supercomputer quarantined after trying to compile Gentoo from source during outbreak.",
	"Omarchy rolling release update ships new animation curve for the apocalypse notification popup.",
	"Hyprland window rules updated to float all quarantine zone maps with rounded corners.",
	"Omarchy user refuses government shelter: 'I need a Wayland compositor and they only have X11.'",
	"Local sysadmin claims he has been socially distancing since he first discovered tiling window managers.",
	"Omarchy fuzzy launcher now includes 'end civilization' in autocomplete after recent database update.",
	"Omarchy bar widget updated: now displays global infection percentage next to CPU usage and battery.",
	"Discord user changes status to 'infected' and somehow gets 40 clown reacts within three minutes.",
	"Omarchy user remaps Escape key to 'deny quarantine order' and accidentally triggers international incident.",
	"Hyprland animation plugin causes borders of infected countries to slide in with a satisfying ease curve.",
	"Omarchy night light mode now activated globally; scientists confirm it has zero effect on the pandemic.",
	"Omarchy user files bug report: 'fullscreen game briefly shows desktop; unacceptable during apocalypse.'",
	"Git blame reveals Patient Zero's first infection was introduced in a 3am commit with the message 'wip'.",
	"Omarchy terminal emulator benchmarked as fastest way to read death toll statistics in the known universe.",
	"Developer submits PR to add dark mode to global emergency alert system; maintainers request more tests.",

	# Sarcastic World News & Pandemic Absurdity
	"WHO strictly advises all citizens to avoid touching grass until further notice.",
	"Global toilet paper reserves drop to absolute zero for no scientific reason whatsoever.",
	"World leaders hold emergency virtual summit to debate dark mode versus light mode in fallout bunkers.",
	"Conspiracy theorists claim pathogen was engineered by mechanical keyboard makers to sell clicky switches.",
	"Doctors recommend wearing two masks, three gloves, and active noise-canceling headphones.",
	"Supermarkets run out of pasta; civilization officially considered on the brink of total collapse.",
	"Local man claims eating raw garlic and arguing on Reddit makes him 100% immune.",
	"Scientists discover having 150 open browser tabs increases ambient body temperature by 2.4 degrees.",
	"Stock markets crash after leading tech CEO accidentally drops production database into the Pacific Ocean.",
	"Meteorologists predict a 70% chance of acid rain and a 100% chance of impending doom.",
	"Global coffee shortage feared; tech workforce threatens total cessation of all cognitive activity.",
	"World Bank introduces new global currency backed entirely by hand sanitizer and canned beans.",
	"Astronauts on International Space Station look down at Earth and decide to cancel their return ticket.",
	"Scientists confirm introverts have already been successfully quarantining for the past fifteen years.",
	"Antarctica reports zero infections; local penguins express smug satisfaction to reporters.",
	"Madagascar seals all shipping ports after hearing someone sneeze on an overseas podcast.",
	"Greenland remains cold, isolated, and stubbornly free of disease despite all biological logic.",
	"Self-help guru urges public to 'manifest wellness and positive cellular energy' during apocalypse.",
	"Fast food chain unveils 'Biohazard Meal' with complimentary surgical mask and extra fries.",
	"Gym enthusiasts spotted doing pull-ups on traffic lights as indoor fitness centers shut down.",
	"Scientists baffled as infected country continues to post hot takes on social media between symptoms.",
	"Global cruise industry releases new itinerary: 'Seven Days of Floating in International Waters Hoping for the Best.'",
	"Pharmaceutical CEO takes out full-page ad to say he is 'very concerned' and has purchased a second yacht.",
	"Emergency app downloaded 2 billion times; crashes immediately on first government notification.",
	"Influencer documents quarantine experience with ring light, sponsored supplements, and zero self-awareness.",
	"Island nation celebrates zero infections; immediately overrun by journalists asking how they did it.",
	"Health minister holds press conference, coughs once, and ends the briefing without further comment.",
	"Global supply chain collapses as world realizes everything was made in one warehouse in one city.",
	"Epidemiologists exhausted after being asked to explain exponential growth for the forty-seventh time this week.",
	"Scientists discover the pathogen cannot survive a passive-aggressive Discord message thread.",
	"United Nations holds emergency session; adjourns after forty minutes without reaching a decision.",
	"World's leading virologist admits he has been pronouncing 'pathogen' wrong for thirty years.",
	"Government urges citizens to remain calm while simultaneously purchasing underground bunker.",
	"Airport duty-free shops report record sales of whiskey as travellers consider their life choices.",
	"Last functioning social media platform collapses under weight of seventeen billion pandemic hot takes.",
	"Billionaire announces plan to colonize Mars; scientists note it is a sensible time to bring this up.",
	"Global shortage of latex gloves traced back to single factory worker who called in sick three weeks ago.",
	"Hospitals introduce triage category 'probably fine, just panicking' to manage overwhelming demand.",
	"Funeral industry reports unprecedented backlog; introduces express cremation subscription service.",
	"World record set for longest unbroken chain of 'unprecedented events' in a single calendar year.",
	"Scientists confirm the virus has no opinion on whether pineapple belongs on pizza.",
	"Last international flight departs carrying seventeen epidemiologists, a goat, and a crate of hand sanitizer.",
	"Small town declares itself independent nation to avoid WHO travel restrictions; immediately regrets it.",
	"Man stockpiling bottled water for apocalypse discovers he has been accidentally stockpiling sparkling water.",
	"Governments worldwide synchronize messaging: 'Everything is fine' translated into two hundred languages.",
	"Military deployed to enforce lockdown; immediately confused by instructions to stand two metres apart.",
	"Nation that mocked other countries for pandemic response now quietly googles 'how to pandemic response'.",
	"Researchers discover that doing absolutely nothing was statistically the second best pandemic strategy.",
]


func _ready():
	funny_news_pool.shuffle()
	
	# Initial seed for continuous marquee ribbon (6-8 items ahead)
	for i in range(8):
		active_items.append(funny_news_pool[funny_index % funny_news_pool.size()])
		funny_index += 1
		
	_set_badge_normal()
	_update_marquee_text()
	scroll_pos = 0.0
	news_label.position.x = 0.0
	
	GameState.stats_updated.connect(_update_stats)
	GameState.dna_changed.connect(_on_dna_changed)
	GameState.news_added.connect(_on_news_added)
	GameState.speed_changed.connect(_update_speed_buttons)
	GameState.bubble_count_changed.connect(_update_bubble_count)
	
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
	btn_pop_all.pressed.connect(_on_pop_all_pressed)
	btn_spore.pressed.connect(_on_spore_pressed)
	btn_about.pressed.connect(func(): open_about_requested.emit())
	
	hover_card.hide()
	
	_update_stats()
	_update_speed_buttons(GameState.sim_speed)
	_update_bubble_count(0)
	
	btn_spore.visible = (GameState.disease_type == "fungus")

func _process(delta: float):
	if btn_pop_all and not btn_pop_all.disabled:
		var pulse = sin(Time.get_ticks_msec() * 0.007) * 0.15 + 0.85
		btn_pop_all.modulate = Color(1.0, pulse, pulse, 1.0)
		
	if current_news_mode == NewsMode.NORMAL_MARQUEE:
		# If breaking news is queued, immediately interrupt the marquee
		if breaking_queue.size() > 0:
			_start_next_breaking_news()
			return
			
		scroll_pos += delta * marquee_speed
		news_label.position.x = -scroll_pos
		
		# Seamless recycling: when the leading headline has fully scrolled off, pop and append
		if active_items.size() > 0:
			var leading_segment = active_items[0] + SEPARATOR
			var leading_w = _get_text_width(leading_segment)
			if scroll_pos >= leading_w:
				scroll_pos -= leading_w
				active_items.pop_front()
				active_items.append(funny_news_pool[funny_index % funny_news_pool.size()])
				funny_index += 1
				_update_marquee_text()
				news_label.position.x = -scroll_pos
	else:
		# BREAKING_ALERT mode: pulse badge and scroll breaking headline across viewport
		var pulse = sin(Time.get_ticks_msec() * 0.01) * 0.5 + 0.5
		news_badge.modulate = Color(1.0, 0.4 + pulse * 0.6, 0.4 + pulse * 0.6)
		
		breaking_x -= delta * breaking_speed
		news_label.position.x = breaking_x
		
		var full_w = _get_text_width(breaking_text)
		if breaking_x < -full_w - 30.0:
			if breaking_queue.size() > 0:
				_start_next_breaking_news()
			else:
				_return_to_normal_marquee()
			
	patient_zero_hint.visible = not GameState.patient_zero_selected
	if patient_zero_hint.visible:
		var a = 0.7 + sin(Time.get_ticks_msec() * 0.006) * 0.3
		patient_zero_hint.modulate.a = a

func _update_marquee_text():
	news_label.text = SEPARATOR.join(active_items) + SEPARATOR

func _get_text_width(txt: String) -> float:
	var font = news_label.get_theme_font("font")
	if font == null:
		font = ThemeDB.fallback_font
	var font_size = news_label.get_theme_font_size("font_size")
	if font_size <= 0:
		font_size = 13
	if font != null:
		return font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	return float(txt.length()) * 8.5

func _start_next_breaking_news():
	if breaking_queue.is_empty():
		_return_to_normal_marquee()
		return
		
	current_news_mode = NewsMode.BREAKING_ALERT
	var raw_headline = breaking_queue.pop_front()
	
	# Determine context-aware prefix label and its emoji bookend
	var prefix = "🚨 BREAKING NEWS:"
	var emoji = "🚨"
	var lower = raw_headline.to_lower()
	if "airport" in lower:
		prefix = "✈️ AIRPORT CLOSURE:"; emoji = "✈️"
	elif "seaport" in lower or "port" in lower:
		prefix = "⚓ PORT LOCKDOWN:"; emoji = "⚓"
	elif "border" in lower:
		prefix = "🚧 BORDER SEALED:"; emoji = "🚧"
	elif "cure" in lower:
		prefix = "🧪 CURE ALERT:"; emoji = "🧪"
	elif "first infection" in lower or "patient zero" in lower:
		prefix = "☣️ OUTBREAK DETECTED:"; emoji = "☣️"
	elif "spore" in lower:
		prefix = "🍄 SPORE BURST:"; emoji = "🍄"
	elif "extinction" in lower or "defeat" in lower:
		prefix = "💀 GLOBAL CATASTROPHE:"; emoji = "💀"
	elif "mutated" in lower or "mutation" in lower:
		prefix = "🧬 VIRAL MUTATION:"; emoji = "🧬"

	# Strip any pre-existing "Breaking News:" prefix the game may have already added
	var clean_headline = raw_headline.strip_edges()
	for pfx in ["Breaking News: ", "Breaking News:", "BREAKING NEWS: ", "BREAKING NEWS:", "BREAKING: "]:
		if clean_headline.begins_with(pfx):
			clean_headline = clean_headline.substr(pfx.length()).strip_edges()
			break

	breaking_text = "%s  %s  %s" % [prefix, clean_headline.to_upper(), emoji]
	news_label.text = breaking_text
	news_label.add_theme_color_override("font_color", Color(1.0, 0.35, 0.35, 1.0))
	
	var vp_w = news_viewport.size.x
	if vp_w <= 10.0:
		vp_w = 600.0
	breaking_x = vp_w + 20.0
	news_label.position.x = breaking_x
	_set_badge_breaking()
	AudioManager.play_sfx("alert")

func _return_to_normal_marquee():
	current_news_mode = NewsMode.NORMAL_MARQUEE
	_set_badge_normal()
	news_label.add_theme_color_override("font_color", Color(0.85, 0.94, 1.0, 0.95))
	_update_marquee_text()
	scroll_pos = 0.0
	news_label.position.x = 0.0

func _set_badge_normal():
	news_badge.text = " 🌐 WIRE "
	news_badge.modulate = Color(1.0, 1.0, 1.0, 1.0)
	news_badge.add_theme_color_override("font_color", Color(0.36, 0.88, 0.82, 1.0))
	var sb = news_badge.get_theme_stylebox("normal")
	if sb is StyleBoxFlat:
		sb.bg_color = Color(0.08, 0.15, 0.24, 0.95)
		sb.border_color = Color(0.2, 0.4, 0.6, 0.75)

func _set_badge_breaking():
	news_badge.text = " 🚨 BREAKING "
	news_badge.add_theme_color_override("font_color", Color(1.0, 0.95, 0.7, 1.0))
	var sb = news_badge.get_theme_stylebox("normal")
	if sb is StyleBoxFlat:
		sb.bg_color = Color(0.65, 0.12, 0.12, 0.95)
		sb.border_color = Color(0.95, 0.3, 0.3, 0.9)

func _on_news_added(headline: String):
	# Cap the queue so a burst of infections doesn't lock the ticker in breaking mode
	if breaking_queue.size() < 3:
		breaking_queue.append(headline)
	if current_news_mode == NewsMode.NORMAL_MARQUEE:
		_start_next_breaking_news()

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
	GameState.set_sim_speed(s)
	AudioManager.play_sfx("click")

func _on_pop_all_pressed():
	GameState.pop_all_bubbles_requested.emit()
	AudioManager.play_sfx("click")

func _update_bubble_count(count: int):
	if btn_pop_all:
		if count > 0:
			btn_pop_all.disabled = false
			btn_pop_all.text = "💥 POP ALL"
			btn_pop_all.modulate.a = 1.0
		else:
			btn_pop_all.disabled = true
			btn_pop_all.text = "💥 POP ALL"
			btn_pop_all.modulate.a = 0.45


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
