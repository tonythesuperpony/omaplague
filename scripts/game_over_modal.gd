extends CanvasLayer

signal restart_requested()

@onready var title_label: Label = $PanelContainer/Margin/VBox/TitleLabel
@onready var reason_label: Label = $PanelContainer/Margin/VBox/ReasonLabel
@onready var stats_label: Label = $PanelContainer/Margin/VBox/StatsLabel
@onready var btn_restart: Button = $PanelContainer/Margin/VBox/BtnRestart

func _ready():
	hide()
	GameState.game_ended.connect(_on_game_ended)
	btn_restart.pressed.connect(func():
		hide()
		restart_requested.emit()
	)

func _on_game_ended(won: bool, reason: String):
	show()
	if won:
		title_label.text = "HUMAN EXTINCTION - VICTORY"
		title_label.add_theme_color_override("font_color", Color(1.0, 0.25, 0.25))
	else:
		title_label.text = "DEFEAT - PATHOGEN ELIMINATED"
		title_label.add_theme_color_override("font_color", Color(0.2, 0.8, 1.0))
		
	reason_label.text = reason
	
	var stats = "OUTBREAK REPORT:\n"
	stats += "Days Elapsed: %d\n" % GameState.day_count
	stats += "World Population: %s\n" % _format_number(GameState.world_population)
	stats += "Total Deaths: %s\n" % _format_number(GameState.world_dead)
	stats += "Final Cure Progress: %d%%\n" % int(GameState.cure_progress * 100.0)
	stats += "Total DNA Harvested: %d" % GameState.total_dna_earned
	stats_label.text = stats

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
