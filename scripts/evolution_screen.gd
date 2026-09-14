extends CanvasLayer

signal back_requested()

@onready var root_control: Control = $Root
@onready var tab_trans: Button = $Root/VBox/TopBar/Margin/HBox/TabRow/TabTrans
@onready var tab_symp: Button = $Root/VBox/TopBar/Margin/HBox/TabRow/TabSymp
@onready var tab_abil: Button = $Root/VBox/TopBar/Margin/HBox/TabRow/TabAbil
@onready var btn_back: Button = $Root/VBox/TopBar/Margin/HBox/BtnBack
@onready var dna_label: Label = $Root/VBox/TopBar/Margin/HBox/DnaLabel

@onready var scroll_container: ScrollContainer = $Root/VBox/MainArea/ScrollContainer
@onready var tree_canvas: Control = $Root/VBox/MainArea/ScrollContainer/TreeCanvas

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
	
	# Highlight active tab
	for tab in [tab_trans, tab_symp, tab_abil]:
		tab.modulate = Color(1.0, 1.0, 1.0, 1.0)
		tab.add_theme_color_override("font_color", Color(0.6, 0.7, 0.8, 0.75))
	var active_tab = tab_trans
	if cat == "symptom": active_tab = tab_symp
	elif cat == "ability": active_tab = tab_abil
	active_tab.modulate = Color(1.0, 1.0, 1.0, 1.0)
	active_tab.add_theme_color_override("font_color", Color(1.0, 0.35, 0.35, 1.0))
	
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
	
	var btn_size = Vector2(150, 80)
	var cell_size = Vector2(185, 120)
	
	# Determine bounds of grid across all upgrades in this category
	var min_gx = 999
	var max_gx = -999
	var min_gy = 999
	var max_gy = -999
	for u in cat_upgrades:
		var grid = u.get("grid", [0, 0])
		min_gy = min(min_gy, grid[0])
		max_gy = max(max_gy, grid[0])
		min_gx = min(min_gx, grid[1])
		max_gx = max(max_gx, grid[1])
		
	if min_gx > max_gx:
		min_gx = 0; max_gx = 0; min_gy = 0; max_gy = 0
		
	var grid_span_x = max_gx - min_gx
	var grid_span_y = max_gy - min_gy
	var cluster_w = grid_span_x * cell_size.x + btn_size.x
	var cluster_h = grid_span_y * cell_size.y + btn_size.y
	
	# Compute available canvas area inside scroll container
	var avail_w = scroll_container.size.x
	var avail_h = scroll_container.size.y
	if avail_w < 200.0:
		avail_w = 880.0
	if avail_h < 200.0:
		avail_h = 560.0
		
	var origin_x = max(30.0, (avail_w - cluster_w) * 0.5)
	var origin_y = max(30.0, (avail_h - cluster_h) * 0.5)
	
	# Set tree_canvas size to at least fill the container (so center calculation holds)
	var total_w = max(avail_w, origin_x + cluster_w + 40.0)
	var total_h = max(avail_h, origin_y + cluster_h + 40.0)
	tree_canvas.custom_minimum_size = Vector2(total_w, total_h)
	
	for u in cat_upgrades:
		var grid = u.get("grid", [0, 0])
		var col = grid[1] - min_gx
		var row = grid[0] - min_gy
		var pos = Vector2(origin_x + col * cell_size.x, origin_y + row * cell_size.y)
		
		var btn = Button.new()
		btn.custom_minimum_size = btn_size
		btn.size = btn_size
		btn.position = pos
		btn.text = "%s\n%d DNA" % [u["name"], u["cost"]]
		btn.add_theme_font_size_override("font_size", 11)
		btn.tooltip_text = u.get("description", "")
		
		# Load upgrade icon — strip trailing _1/_2 so variants share the same icon file
		var uid = u["id"]
		var icon_base = uid
		for suffix in ["_1", "_2"]:
			if icon_base.ends_with(suffix):
				icon_base = icon_base.substr(0, icon_base.length() - 2)
				break
		var icon_path = "res://assets/icons/upgrades/%s.png" % icon_base
		if ResourceLoader.exists(icon_path):
			var tex = load(icon_path) as Texture2D
			if tex:
				btn.icon = tex
				btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
				btn.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
				btn.expand_icon = false
				btn.add_theme_constant_override("icon_max_width", 36)
				btn.add_theme_constant_override("icon_margin_left", 0)
				btn.add_theme_constant_override("icon_margin_right", 0)
		
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
		
	dna_label.text = "🧬 %d DNA" % GameState.dna_points
	
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
			btn.text = "%s\n✓ EVOLVED" % u["name"]
			btn.modulate = Color(1.0, 0.38, 0.38)
		elif can_evolve:
			btn.text = "%s\n%d DNA" % [u["name"], u["cost"]]
			if GameState.dna_points >= u["cost"]:
				btn.modulate = Color(0.45, 1.0, 0.45)
			else:
				btn.modulate = Color(1.0, 0.88, 0.3)
		else:
			btn.text = "%s\n🔒 LOCKED" % u["name"]
			btn.modulate = Color(0.38, 0.44, 0.5)
			
		# Highlight selected
		if uid == selected_upgrade_id:
			btn.modulate = btn.modulate * 1.3
			
	tree_canvas.queue_redraw()
	_refresh_details()

func _refresh_details():
	if selected_upgrade_id == "":
		detail_name.text = "SELECT A MUTATION"
		detail_cost.text = ""
		detail_desc.text = "Tap any trait node in the tree to inspect and evolve it.\nGreen = affordable  •  Yellow = insufficient DNA  •  Gray = locked"
		detail_stats.text = ""
		btn_evolve.disabled = true
		btn_devolve.disabled = true
		return
		
	var u = DataManager.get_upgrade(selected_upgrade_id)
	if u.is_empty():
		return
		
	detail_name.text = u.get("name", "").to_upper()
	
	var cost = u.get("cost", 0)
	detail_cost.text = "Cost: %d DNA  (Available: %d)" % [cost, GameState.dna_points]
	detail_desc.text = u.get("description", "")
	
	var stat_parts = []
	if u.get("infectivity", 0.0) > 0:
		stat_parts.append("+%d%% Infectivity" % int(u["infectivity"] * 100.0))
	if u.get("severity", 0.0) > 0:
		stat_parts.append("+%d%% Severity" % int(u["severity"] * 100.0))
	if u.get("lethality", 0.0) > 0:
		stat_parts.append("+%d%% Lethality" % int(u["lethality"] * 100.0))
	if u.get("cure_resist", 0.0) > 0:
		stat_parts.append("-%d%% Cure Speed" % int(u["cure_resist"] * 100.0))
	var mods = u.get("modifiers", {})
	if mods.get("air", 0.0) > 0:
		stat_parts.append("+%.0f%% Air" % (mods["air"] * 100.0 - 100.0))
	if mods.get("sea", 0.0) > 0:
		stat_parts.append("+%.0f%% Sea" % (mods["sea"] * 100.0 - 100.0))
	if mods.get("land", 0.0) > 0:
		stat_parts.append("+%.0f%% Land" % (mods["land"] * 100.0 - 100.0))
	detail_stats.text = "  •  ".join(stat_parts) if stat_parts else "No direct stat changes"
	
	var is_evolved = GameState.purchased_upgrades.has(selected_upgrade_id)
	var can_evolve = true
	for p in u.get("prereq", []):
		if not GameState.purchased_upgrades.has(p):
			can_evolve = false
			break
			
	btn_evolve.visible = not is_evolved
	btn_devolve.visible = is_evolved
	
	var affordable = GameState.dna_points >= cost
	btn_evolve.disabled = not (can_evolve and affordable)
	if not can_evolve:
		btn_evolve.text = "🔒 PREREQUISITES NOT MET"
	elif not affordable:
		btn_evolve.text = "❌ NOT ENOUGH DNA (%d/%d)" % [GameState.dna_points, cost]
	else:
		btn_evolve.text = "⚡ EVOLVE (%d DNA)" % cost
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
				
				var is_parent_evolved = GameState.purchased_upgrades.has(pid)
				var is_child_evolved = GameState.purchased_upgrades.has(uid)
				
				var line_col: Color
				var line_w: float
				if is_parent_evolved and is_child_evolved:
					line_col = Color(1.0, 0.35, 0.35, 0.9)
					line_w = 2.5
				elif is_parent_evolved:
					line_col = Color(0.45, 1.0, 0.5, 0.7)
					line_w = 2.0
				else:
					line_col = Color(0.25, 0.32, 0.42, 0.45)
					line_w = 1.5
				tree_canvas.draw_line(pcenter, btn_center, line_col, line_w)
