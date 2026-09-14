extends Node

@onready var world_map: Node2D = $WorldMap
@onready var hud: CanvasLayer = $HUD
@onready var country_panel: CanvasLayer = $CountryPanel
@onready var evolution_screen: CanvasLayer = $EvolutionScreen
@onready var setup_screen: CanvasLayer = $SetupScreen
@onready var game_over_modal: CanvasLayer = $GameOverModal

var sim_timer: float = 0.0

func _ready():
	world_map.country_selected.connect(_on_country_selected)
	world_map.country_hovered.connect(_on_country_hovered)
	world_map.country_unhovered.connect(_on_country_unhovered)
	
	hud.open_evolution_requested.connect(_on_open_evolution)
	evolution_screen.back_requested.connect(_on_close_evolution)
	country_panel.closed.connect(_on_close_country_panel)
	setup_screen.game_started.connect(_on_game_started)
	game_over_modal.restart_requested.connect(_on_restart_requested)
	
	# Start with Setup Screen visible and map non-interactive
	world_map.set_interactive(false)
	hud.hide_hover_info()
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

func _on_country_hovered(cid: String, pos: Vector2):
	if world_map.is_interactive and not evolution_screen.visible and not setup_screen.visible and not country_panel.visible:
		hud.show_hover_info(cid, pos)
	else:
		hud.hide_hover_info()

func _on_country_unhovered():
	hud.hide_hover_info()

func _on_country_selected(cid: String):
	hud.hide_hover_info()
	world_map.set_interactive(false)
	country_panel.display_country(cid)

func _on_close_country_panel():
	world_map.set_interactive(true)

func _on_open_evolution():
	hud.hide_hover_info()
	world_map.set_interactive(false)
	country_panel.hide()
	evolution_screen.open()

func _on_close_evolution():
	evolution_screen.hide()
	world_map.set_interactive(true)

func _on_game_started():
	setup_screen.hide()
	hud.hide_hover_info()
	world_map.set_interactive(true)

func _on_restart_requested():
	country_panel.hide()
	evolution_screen.hide()
	hud.hide_hover_info()
	world_map.set_interactive(false)
	setup_screen.show()
