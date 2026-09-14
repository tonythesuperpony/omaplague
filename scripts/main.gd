extends Node

@onready var world_map: Node2D = $WorldMap
@onready var hud: CanvasLayer = $HUD
@onready var country_panel: PanelContainer = $CountryPanel
@onready var evolution_screen: Control = $EvolutionScreen
@onready var setup_screen: Control = $SetupScreen
@onready var game_over_modal: PanelContainer = $GameOverModal

var sim_timer: float = 0.0

func _ready():
	world_map.country_selected.connect(_on_country_selected)
	hud.open_evolution_requested.connect(_on_open_evolution)
	evolution_screen.back_requested.connect(_on_close_evolution)
	setup_screen.game_started.connect(_on_game_started)
	game_over_modal.restart_requested.connect(_on_restart_requested)
	
	# Start with Setup Screen visible
	country_panel.hide()
	evolution_screen.hide()
	game_over_modal.hide()
	setup_screen.show()

func _process(delta: float):
	if not GameState.is_playing or GameState.game_over or not GameState.patient_zero_selected:
		return
		
	var speed = GameState.sim_speed
	if speed > 0.0:
		sim_timer += delta * speed
		# At 1x speed, 1 day = 0.9 seconds
		if sim_timer >= 0.9:
			sim_timer = 0.0
			GameState.advance_day()

func _on_country_selected(cid: String):
	country_panel.display_country(cid)

func _on_open_evolution():
	country_panel.hide()
	evolution_screen.open()

func _on_close_evolution():
	evolution_screen.hide()

func _on_game_started():
	setup_screen.hide()

func _on_restart_requested():
	country_panel.hide()
	evolution_screen.hide()
	setup_screen.show()
