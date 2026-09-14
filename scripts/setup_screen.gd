extends CanvasLayer

signal game_started()

@onready var name_edit: LineEdit = $Panel/Margin/VBox/NameBox/LineEdit
@onready var type_container: HBoxContainer = $Panel/Margin/VBox/TypeBox/TypeHBox
@onready var type_desc: Label = $Panel/Margin/VBox/TypeBox/TypeDesc
@onready var diff_container: HBoxContainer = $Panel/Margin/VBox/DiffBox/DiffHBox
@onready var diff_desc: Label = $Panel/Margin/VBox/DiffBox/DiffDesc
@onready var btn_start: Button = $Panel/Margin/VBox/BtnStart

var selected_type: String = "bacteria"
var selected_diff: String = "normal"

var type_buttons: Dictionary = {}
var diff_buttons: Dictionary = {}

var diff_info: Dictionary = {
	"casual": "Casual: Sick people are given hugs. Nobody washes their hands. Doctors work 3 days a week. Cure research is very slow.",
	"normal": "Normal: Compulsory hand washing. Sick people are ignored. Doctors work 5 days a week. Standard medical response.",
	"brutal": "Brutal: Compulsive hygiene. Sick people quarantined immediately. Doctors work 24/7. Airports and ports shut down quickly.",
	"mega_brutal": "Mega-Brutal: Genetic drift increases evolution costs. Medical checks everywhere. Humanity's cure effort never rests."
}

func _ready():
	_setup_types()
	_setup_diffs()
	btn_start.pressed.connect(_on_start_pressed)

func _setup_types():
	for child in type_container.get_children():
		child.queue_free()
	type_buttons.clear()
	
	for dtype in DataManager.disease_types:
		var btn = Button.new()
		btn.custom_minimum_size = Vector2(140, 48)
		btn.text = dtype["name"].to_upper()
		btn.add_theme_font_size_override("font_size", 14)
		
		var tid = dtype["id"]
		btn.pressed.connect(func(): _select_type(tid))
		type_container.add_child(btn)
		type_buttons[tid] = btn
		
	_select_type("bacteria")

func _select_type(tid: String):
	selected_type = tid
	AudioManager.play_sfx("click")
	
	for id in type_buttons:
		type_buttons[id].modulate = Color(1.2, 0.4, 0.4) if id == tid else Color(0.7, 0.7, 0.7)
		
	for dtype in DataManager.disease_types:
		if dtype["id"] == tid:
			type_desc.text = dtype.get("description", "")
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
		btn.add_theme_font_size_override("font_size", 14)
		
		var did = d["id"]
		btn.pressed.connect(func(): _select_diff(did))
		diff_container.add_child(btn)
		diff_buttons[did] = btn
		
	_select_diff("normal")

func _select_diff(did: String):
	selected_diff = did
	AudioManager.play_sfx("click")
	
	for id in diff_buttons:
		diff_buttons[id].modulate = Color(0.3, 0.8, 1.2) if id == did else Color(0.7, 0.7, 0.7)
		
	diff_desc.text = diff_info.get(did, "")

func _on_start_pressed():
	var dname = name_edit.text.strip_edges()
	if dname == "":
		dname = "Omaplague"
	GameState.setup_new_game(dname, selected_type, selected_diff)
	AudioManager.play_sfx("alert")
	hide()
	game_started.emit()
