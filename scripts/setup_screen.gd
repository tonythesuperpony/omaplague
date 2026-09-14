extends CanvasLayer

signal game_started()

enum Mode { CRACKTRO, SETUP }
var current_mode: Mode = Mode.CRACKTRO

# ─── CANVAS & CRACKTRO REFERENCES ─────────────────────────
@onready var cracktro_canvas: Control = $CracktroCanvas
@onready var cracktro_ui: Control = $CracktroUI
@onready var emblem: TextureRect = $CracktroUI/Emblem
@onready var wordmark: TextureRect = $CracktroUI/Wordmark
@onready var ticker_bar: Panel = $CracktroUI/TickerBar
@onready var ticker_label: Label = $CracktroUI/TickerBar/TickerLabel
@onready var prompt_label: Label = $CracktroUI/PromptLabel
@onready var flash_overlay: ColorRect = $FlashOverlay

# ─── SETUP REFERENCES ────────────────────────────────────
@onready var setup_ui: Control = $SetupUI
@onready var name_edit: LineEdit = $SetupUI/Panel/Margin/VBox/NameBox/LineEdit
@onready var type_container: HBoxContainer = $SetupUI/Panel/Margin/VBox/TypeBox/TypeHBox
@onready var type_desc: Label = $SetupUI/Panel/Margin/VBox/TypeBox/TypeDesc
@onready var diff_container: HBoxContainer = $SetupUI/Panel/Margin/VBox/DiffBox/DiffHBox
@onready var diff_desc: Label = $SetupUI/Panel/Margin/VBox/DiffBox/DiffDesc
@onready var btn_start: Button = $SetupUI/Panel/Margin/VBox/BtnStart
@onready var btn_intro: Button = $SetupUI/Panel/Margin/VBox/HeaderHBox/BtnIntro
@onready var btn_next_track: Button = $CracktroUI/BtnNextTrack

# ─── SIMULATION & ANIMATION STATE ────────────────────────
var sim_time: float = 0.0
var flash_alpha: float = 0.0

# Ticker
var ticker_offset: float = 0.0
var ticker_text: String = "[ OMAPLAGUE ]  ////  INFECT • EVOLVE • DOMINATE  ////  NO CURE // NO ESCAPE  ////  THE WORLD IS YOUR PETRI DISH  ////  PRESS ANY KEY  ////  OMAPLAGUE v1.00  ////  CRACKED BY OMARCHY CREW  ////  GREETINGS TO ALL BIO-ENGINEERS WORLDWIDE  ////  "

# Wordmark glitch timer
var wordmark_glitch_timer: float = 0.0
var wordmark_base_pos: Vector2 = Vector2.ZERO

# Pathogen & Difficulty Selection
var selected_type: String = "bacteria"
var selected_diff: String = "normal"
var type_buttons: Dictionary = {}
var diff_buttons: Dictionary = {}

var diff_info: Dictionary = {
	"casual": "CASUAL: Sick people are given hugs. Nobody washes their hands. Doctors work 3 days a week. Cure research is extremely slow.",
	"normal": "NORMAL: Compulsory hand washing. Sick people are ignored. Doctors work 5 days a week. Standard medical and border response.",
	"brutal": "BRUTAL: Compulsive hygiene. Sick people quarantined immediately. Doctors work 24/7. Airports and ports shut down rapidly.",
	"mega_brutal": "MEGA-BRUTAL: Genetic drift escalates mutation costs. Medical checks everywhere. Humanity's cure effort never rests."
}

func _ready():
	cracktro_canvas.emblem_node = emblem
	_setup_types()
	_setup_diffs()
	
	btn_start.pressed.connect(_on_start_pressed)
	if btn_intro:
		btn_intro.pressed.connect(_transition_to_cracktro)
	if btn_next_track:
		btn_next_track.pressed.connect(_on_next_track_pressed)
	
	ticker_label.text = ticker_text + ticker_text
	_set_mode(Mode.CRACKTRO)
	AudioManager.play_random_intro_music()

func _unhandled_input(event: InputEvent):
	if not visible:
		return
	if current_mode == Mode.CRACKTRO:
		if event is InputEventKey and event.pressed:
			_transition_to_setup()
			get_viewport().set_input_as_handled()
		elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			# Don't transition if clicking the next-track button
			if btn_next_track and btn_next_track.get_global_rect().has_point(event.position):
				return
			_transition_to_setup()
			get_viewport().set_input_as_handled()

func _on_next_track_pressed():
	AudioManager.skip_track()
	get_viewport().set_input_as_handled()

func _process(delta: float):
	sim_time += delta
	
	# ─── Cracktro Specific Updates ───────────────────────
	if current_mode == Mode.CRACKTRO:
		# Ticker horizontal scroll
		ticker_offset -= delta * 135.0
		ticker_label.position.x = ticker_offset
		if ticker_offset < -ticker_label.size.x * 0.5:
			ticker_offset = 0.0
			
		# Prompt pulsing
		prompt_label.modulate.a = 0.45 + sin(sim_time * 5.0) * 0.45 + 0.1
		
		# Emblem scale breathing
		var emblem_scale = 1.0 + sin(sim_time * 2.8) * 0.035
		emblem.scale = Vector2(emblem_scale, emblem_scale)
		
		# Wordmark glitch jitter
		wordmark_glitch_timer += delta
		if wordmark_base_pos == Vector2.ZERO and wordmark.position != Vector2.ZERO:
			wordmark_base_pos = wordmark.position
		
		var q = fmod(wordmark_glitch_timer, 3.8)
		if q > 3.2 and q < 3.35:
			wordmark.position = wordmark_base_pos + Vector2(sin(sim_time * 50.0) * 6.0, (randf() - 0.5) * 3.0)
			wordmark.modulate = Color(1.3, 0.7, 0.7, 1.0)
		else:
			if wordmark_base_pos != Vector2.ZERO:
				wordmark.position = wordmark_base_pos
			wordmark.modulate = Color(1.0, 1.0, 1.0, 1.0)
			
	# ─── Flash Overlay Fade ──────────────────────────────
	if flash_alpha > 0.0:
		flash_alpha = max(0.0, flash_alpha - delta * 4.5)
		flash_overlay.color = Color(1.0, 0.95, 0.95, flash_alpha)
		flash_overlay.visible = (flash_alpha > 0.01)

# ─── MODE SWITCHING & TRANSITIONS ─────────────────────────
func _set_mode(new_mode: Mode):
	current_mode = new_mode
	if cracktro_canvas:
		cracktro_canvas.is_cracktro_active = (current_mode == Mode.CRACKTRO)
		
	if current_mode == Mode.CRACKTRO:
		cracktro_ui.show()
		setup_ui.hide()
	else:
		cracktro_ui.hide()
		setup_ui.show()
		_select_type(selected_type)
		_select_diff(selected_diff)

func _transition_to_setup():
	if current_mode == Mode.SETUP:
		return
	AudioManager.play_sfx("alert")
	_trigger_flash()
	_set_mode(Mode.SETUP)

func _transition_to_cracktro():
	AudioManager.play_sfx("click")
	_trigger_flash()
	_set_mode(Mode.CRACKTRO)

func _trigger_flash():
	flash_alpha = 0.88
	flash_overlay.color = Color(1.0, 0.95, 0.95, flash_alpha)
	flash_overlay.visible = true

# ─── SETUP / VIRUS CONFIGURATION LOGIC ───────────────────
func _setup_types():
	for child in type_container.get_children():
		child.queue_free()
	type_buttons.clear()
	
	var icons = {
		"bacteria": "🦠",
		"virus": "🧬",
		"fungus": "🍄",
		"parasite": "🪱",
		"nanovirus": "⚡"
	}
	
	for dtype in DataManager.disease_types:
		var btn = Button.new()
		btn.custom_minimum_size = Vector2(138, 50)
		var ico = icons.get(dtype["id"], "☣")
		btn.text = "%s %s" % [ico, dtype["name"].to_upper()]
		btn.add_theme_font_size_override("font_size", 13)
		
		var tid = dtype["id"]
		btn.pressed.connect(func(): _select_type(tid))
		type_container.add_child(btn)
		type_buttons[tid] = btn
		
	_select_type("bacteria")

func _select_type(tid: String):
	selected_type = tid
	AudioManager.play_sfx("click")
	
	for id in type_buttons:
		if id == tid:
			type_buttons[id].modulate = Color(1.4, 0.4, 0.4, 1.0)
		else:
			type_buttons[id].modulate = Color(0.65, 0.65, 0.65, 0.85)
		
	for dtype in DataManager.disease_types:
		if dtype["id"] == tid:
			var desc = dtype.get("description", "")
			var mut = int(dtype.get("mutation_rate", 0.0) * 100.0)
			var inf = int(dtype.get("base_infectivity", 0.0) * 100.0)
			type_desc.text = "%s\n[ Base Infectivity: +%d%%  •  Mutation Rate: %d%%  •  Devolve Cost: %d DNA ]" % [
				desc, inf, mut, dtype.get("devolve_cost", 0)
			]
			break

func _setup_diffs():
	for child in diff_container.get_children():
		child.queue_free()
	diff_buttons.clear()
	
	var diffs = [
		{"id": "casual", "name": "CASUAL"},
		{"id": "normal", "name": "NORMAL"},
		{"id": "brutal", "name": "BRUTAL"},
		{"id": "mega_brutal", "name": "MEGA-BRUTAL"}
	]
	
	for d in diffs:
		var btn = Button.new()
		btn.custom_minimum_size = Vector2(130, 44)
		btn.text = d["name"]
		btn.add_theme_font_size_override("font_size", 13)
		
		var did = d["id"]
		btn.pressed.connect(func(): _select_diff(did))
		diff_container.add_child(btn)
		diff_buttons[did] = btn
		
	_select_diff("normal")

func _select_diff(did: String):
	selected_diff = did
	AudioManager.play_sfx("click")
	
	for id in diff_buttons:
		if id == did:
			diff_buttons[id].modulate = Color(0.3, 0.85, 1.3, 1.0)
		else:
			diff_buttons[id].modulate = Color(0.65, 0.65, 0.65, 0.85)
		
	diff_desc.text = diff_info.get(did, "")

func _on_start_pressed():
	var dname = name_edit.text.strip_edges()
	if dname == "":
		dname = "Omaplague"
	AudioManager.stop_intro_music(1.2)
	GameState.setup_new_game(dname, selected_type, selected_diff)
	AudioManager.play_sfx("evolve")
	hide()
	game_started.emit()

func show_cracktro():
	_set_mode(Mode.CRACKTRO)
	AudioManager.play_random_intro_music()
	show()
