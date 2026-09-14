extends Node

@onready var world_map: Node2D = $WorldMap
@onready var hud: CanvasLayer = $HUD
@onready var country_panel: CanvasLayer = $CountryPanel
@onready var evolution_screen: CanvasLayer = $EvolutionScreen
@onready var setup_screen: CanvasLayer = $SetupScreen
@onready var game_over_modal: CanvasLayer = $GameOverModal

var sim_timer: float = 0.0

func _ready():
	# Set ocean-matching background clear color (eliminates gray on zoom out)
	RenderingServer.set_default_clear_color(Color(0.04, 0.07, 0.12, 1.0))
	
	# Apply the current Omarchy/system font dynamically
	_apply_system_font()
	
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

# ─── Omarchy System Font Integration ──────────────────────────────
# Resolves the current Omarchy monospace font (via fontconfig/omarchy font current)
# and applies it to ThemeDB.get_default_theme().default_font and ThemeDB.fallback_font.
func _apply_system_font():
	var font_path = _resolve_system_font_path()
	if font_path == "" or not FileAccess.file_exists(font_path):
		font_path = "/usr/share/fonts/Adwaita/AdwaitaMono-Regular.ttf"
	
	if not FileAccess.file_exists(font_path):
		push_warning("Omaplague: system font not found at: %s" % font_path)
		return
	
	var font = FontFile.new()
	var err = font.load_dynamic_font(font_path)
	if err != OK:
		push_warning("Omaplague: failed to load font: %s" % font_path)
		return
	
	ThemeDB.get_default_theme().default_font = font
	ThemeDB.fallback_font = font
	ThemeDB.fallback_font_size = 14
	
	var theme = Theme.new()
	theme.default_font = font
	theme.default_font_size = 14
	get_tree().root.theme = theme
	print("Omaplague: active Omarchy font applied -> %s" % font_path)

func _resolve_system_font_path() -> String:
	# Omarchy canonical source of truth is fontconfig 'monospace' (set by omarchy font set)
	var fcmatch_out = []
	var exit = OS.execute("fc-match", ["monospace:style=Regular", "-f", "%{file}\n"], fcmatch_out, true)
	if exit == 0 and not fcmatch_out.is_empty():
		var resolved = fcmatch_out[0].strip_edges()
		if FileAccess.file_exists(resolved):
			return resolved
	
	# Fallback check for omarchy font list standard locations
	var candidates = [
		"/usr/share/fonts/Adwaita/AdwaitaMono-Regular.ttf",
		"/usr/share/fonts/TTF/JetBrainsMonoNerdFont-Regular.ttf",
		"/usr/share/fonts/liberation/LiberationMono-Regular.ttf"
	]
	for c in candidates:
		if FileAccess.file_exists(c):
			return c
	return ""
