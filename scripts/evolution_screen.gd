extends CanvasLayer

signal back_requested()

@onready var root_control: Control = $Root
@onready var tab_trans: Button = $Root/VBox/TopBar/HBox/TabTrans
@onready var tab_symp: Button = $Root/VBox/TopBar/HBox/TabSymp
@onready var tab_abil: Button = $Root/VBox/TopBar/HBox/TabAbil
@onready var btn_back: Button = $Root/VBox/TopBar/HBox/BtnBack
@onready var btn_back_bottom: Button = $Root/VBox/BottomMeters/HBox/BtnBackBottom
@onready var dna_label: Label = $Root/VBox/TopBar/HBox/DnaLabel

@onready var tree_canvas: Control = $Root/VBox/MainArea/TreeCanvas

# Details panel
@onready var detail_name: Label = $Root/VBox/MainArea/DetailsPanel/Margin/VBox/NameLabel
@onready var detail_cost: Label = $Root/VBox/MainArea/DetailsPanel/Margin/VBox/CostLabel
@onready var detail_desc: Label = $Root/VBox/MainArea/DetailsPanel/Margin/VBox/DescLabel
@onready var detail_stats: Label = $Root/VBox/MainArea/DetailsPanel/Margin/VBox/StatsLabel
@onready var btn_evolve: Button = $Root/VBox/MainArea/DetailsPanel/Margin/VBox/BtnEvolve
@onready var btn_devolve: Button = $Root/VBox/MainArea/DetailsPanel/Margin/VBox/BtnDevolve

# Meters
@onready var bar_inf: ProgressBar = $Root/VBox/BottomMeters/HBox/InfBox/Bar
@onready var bar_sev: ProgressBar = $Root/VBox/BottomMeters/HBox/SevBox/Bar
@onready var bar_let: ProgressBar = $Root/VBox/BottomMeters/HBox/LetBox/Bar

var current_category: String = "transmission"
var selected_upgrade_id: String = ""

var upgrade_buttons: Dictionary = {}

func _ready():
	tab_trans.pressed.connect(func(): _switch_tab("transmission"))
	tab_symp.pressed.connect(func(): _switch_tab("symptom"))
	tab_abil.pressed.connect(func(): _switch_tab("ability"))
	
	btn_back.pressed.connect(close)
	btn_back_bottom.pressed.connect(close)
	
	btn_evolve.pressed.connect(_on_evolve_pressed)
	btn_devolve.pressed.connect(_on_devolve_pressed)
	
	GameState.stats_updated.connect(_refresh_ui)
	GameState.dna_changed.connect(func(_d, _delta): _refresh_ui())
	
	tree_canvas.draw.connect(_on_tree_canvas_draw)

func _unhandled_input(event: InputEvent):
	if visible and event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE or event.keycode == KEY_B:
			close()
			get_viewport().set_input_as_handled()

func open():
	show()
	_switch_tab(current_category)

func close():
	hide()
	back_requested.emit()
	AudioManager.play_sfx("click")

func _switch_tab(cat: String):
	current_category = cat
	selected_upgrade_id = ""
	
	tab_trans.modulate = Color(1.2, 1.2, 1.2) if cat == "transmission" else Color(0.7, 0.7, 0.7)
	tab_symp.modulate = Color(1.2, 1.2, 1.2) if cat == "symptom" else Color(0.7, 0.7, 0.7)
	tab_abil.modulate = Color(1.2, 1.2, 1.2) if cat == "ability" else Color(0.7, 0.7, 0.7)
	
	_rebuild_tree()
	_refresh_ui()

func _rebuild_tree():
	for child in tree_canvas.get_children():
		child.queue_free()
	upgrade_buttons.clear()
	
	var cat_upgrades = []
	for u in DataManager.upgrades:
		if u.get("category") == current_category:
			cat_upgrades.append(u)
			
	var grid_origin = Vector2(80, 50)
	var cell_size = Vector2(170, 90)
	
	for u in cat_upgrades:
		var grid = u.get("grid", [0, 0])
		var pos = grid_origin + Vector2(grid[1] * cell_size.x, grid[0] * cell_size.y)
		
		var btn = Button.new()
		btn.custom_minimum_size = Vector2(140, 60)
		btn.position = pos
		btn.text = "%s\n%d DNA" % [u["name"], u["cost"]]
		btn.add_theme_font_size_override("font_size", 13)
		
		var uid = u["id"]
		btn.pressed.connect(func(): _select_upgrade(uid))
		
		tree_canvas.add_child(btn)
		upgrade_buttons[uid] = btn
		
	tree_canvas.queue_redraw()

func _select_upgrade(uid: String):
	selected_upgrade_id = uid
	AudioManager.play_sfx("click")
	_refresh_details()

func _refresh_ui():
	if not visible:
		return
		
	dna_label.text = "DNA Points: %d" % GameState.dna_points
	
	# Update Meters
	bar_inf.value = clamp(GameState.current_infectivity * 100.0, 0.0, 100.0)
	bar_sev.value = clamp(GameState.current_severity * 100.0, 0.0, 100.0)
	bar_let.value = clamp(GameState.current_lethality * 100.0, 0.0, 100.0)
	
	# Update Node Buttons styling
	for uid in upgrade_buttons:
		var btn = upgrade_buttons[uid]
		var u = DataManager.get_upgrade(uid)
		var is_evolved = GameState.purchased_upgrades.has(uid)
		
		var can_evolve = true
		for p in u.get("prereq", []):
			if not GameState.purchased_upgrades.has(p):
				can_evolve = false
				break
				
		if is_evolved:
			btn.text = "%s\n[EVOLVED]" % u["name"]
			btn.modulate = Color(1.0, 0.35, 0.35)
		elif can_evolve:
			btn.text = "%s\n%d DNA" % [u["name"], u["cost"]]
			if GameState.dna_points >= u["cost"]:
				btn.modulate = Color(0.4, 1.0, 0.4)
			else:
				btn.modulate = Color(1.0, 0.85, 0.3)
		else:
			btn.text = "%s\n[LOCKED]" % u["name"]
			btn.modulate = Color(0.4, 0.45, 0.5)
			
	tree_canvas.queue_redraw()
	_refresh_details()

func _refresh_details():
	if selected_upgrade_id == "":
		detail_name.text = "SELECT A MUTATION"
		detail_cost.text = ""
		detail_desc.text = "Select any trait node from the tree to view its bio-stats and evolve it."
		detail_stats.text = ""
		btn_evolve.disabled = true
		btn_devolve.disabled = true
		return
		
	var u = DataManager.get_upgrade(selected_upgrade_id)
	if u.is_empty():
		return
		
	detail_name.text = u.get("name", "").to_upper()
	detail_cost.text = "Cost: %d DNA" % u.get("cost", 0)
	detail_desc.text = u.get("description", "")
	
	var stat_str = "Stats: "
	if u.get("infectivity", 0.0) > 0:
		stat_str += "+%d%% Infectivity  " % int(u["infectivity"] * 100.0)
	if u.get("severity", 0.0) > 0:
		stat_str += "+%d%% Severity  " % int(u["severity"] * 100.0)
	if u.get("lethality", 0.0) > 0:
		stat_str += "+%d%% Lethality  " % int(u["lethality"] * 100.0)
	detail_stats.text = stat_str
	
	var is_evolved = GameState.purchased_upgrades.has(selected_upgrade_id)
	var can_evolve = true
	for p in u.get("prereq", []):
		if not GameState.purchased_upgrades.has(p):
			can_evolve = false
			break
			
	btn_evolve.visible = not is_evolved
	btn_devolve.visible = is_evolved
	
	btn_evolve.disabled = not (can_evolve and GameState.dna_points >= u.get("cost", 0))
	btn_devolve.disabled = not is_evolved

func _on_evolve_pressed():
	if selected_upgrade_id != "":
		GameState.buy_upgrade(selected_upgrade_id)
		_refresh_ui()

func _on_devolve_pressed():
	if selected_upgrade_id != "":
		GameState.devolve_upgrade(selected_upgrade_id)
		_refresh_ui()

func _on_tree_canvas_draw():
	for uid in upgrade_buttons:
		var u = DataManager.get_upgrade(uid)
		var btn = upgrade_buttons[uid]
		var btn_center = btn.position + btn.custom_minimum_size * 0.5
		
		for pid in u.get("prereq", []):
			if upgrade_buttons.has(pid):
				var pbtn = upgrade_buttons[pid]
				var pcenter = pbtn.position + pbtn.custom_minimum_size * 0.5
				
				var is_connected = GameState.purchased_upgrades.has(pid)
				var line_col = Color(0.9, 0.3, 0.3, 0.8) if is_connected else Color(0.25, 0.35, 0.45, 0.5)
				var line_w = 2.5 if is_connected else 1.5
				tree_canvas.draw_line(pcenter, btn_center, line_col, line_w)
