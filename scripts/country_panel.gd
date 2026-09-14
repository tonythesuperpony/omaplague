extends PanelContainer

signal closed()

@onready var title_label: Label = $Margin/VBox/TitleLabel
@onready var pop_label: Label = $Margin/VBox/PopGrid/PopVal
@onready var inf_label: Label = $Margin/VBox/PopGrid/InfVal
@onready var dead_label: Label = $Margin/VBox/PopGrid/DeadVal
@onready var healthy_label: Label = $Margin/VBox/PopGrid/HealthyVal

@onready var inf_bar: ProgressBar = $Margin/VBox/InfBar
@onready var dead_bar: ProgressBar = $Margin/VBox/DeadBar

@onready var climate_label: Label = $Margin/VBox/AttrGrid/ClimateVal
@onready var wealth_label: Label = $Margin/VBox/AttrGrid/WealthVal
@onready var density_label: Label = $Margin/VBox/AttrGrid/DensityVal
@onready var humidity_label: Label = $Margin/VBox/AttrGrid/HumidityVal

@onready var air_status: Label = $Margin/VBox/TransitHBox/AirStatus
@onready var sea_status: Label = $Margin/VBox/TransitHBox/SeaStatus
@onready var land_status: Label = $Margin/VBox/TransitHBox/LandStatus

@onready var btn_close: Button = $Margin/VBox/BtnClose

var current_country_id: String = ""

func _ready():
	btn_close.pressed.connect(func():
		hide()
		closed.emit()
	)
	GameState.stats_updated.connect(_refresh)

func display_country(cid: String):
	current_country_id = cid
	show()
	_refresh()

func _refresh():
	if current_country_id == "" or not visible:
		return
	var cdata = DataManager.get_country(current_country_id)
	var cstate = GameState.country_states.get(current_country_id, {})
	if cdata.is_empty() or cstate.is_empty():
		return
		
	title_label.text = cdata.get("name", current_country_id).to_upper()
	
	var pop = cstate.get("population", 1)
	var inf = cstate.get("infected", 0)
	var dead = cstate.get("dead", 0)
	var healthy = cstate.get("healthy", 0)
	
	pop_label.text = _format_number(pop)
	inf_label.text = "%s (%d%%)" % [_format_number(inf), int(float(inf) / float(pop) * 100.0)]
	dead_label.text = "%s (%d%%)" % [_format_number(dead), int(float(dead) / float(pop) * 100.0)]
	healthy_label.text = _format_number(healthy)
	
	inf_bar.value = (float(inf) / float(pop)) * 100.0
	dead_bar.value = (float(dead) / float(pop)) * 100.0
	
	climate_label.text = cdata.get("climate", "balanced").capitalize()
	humidity_label.text = cdata.get("humidity", "balanced").capitalize()
	wealth_label.text = cdata.get("wealth", "balanced").capitalize()
	density_label.text = cdata.get("density", "balanced").capitalize()
	
	if cdata.get("has_airport", false):
		var open = cstate.get("airport_open", true)
		air_status.text = "Air: OPEN" if open else "Air: CLOSED"
		air_status.modulate = Color(0.2, 1.0, 0.4) if open else Color(1.0, 0.3, 0.3)
	else:
		air_status.text = "Air: NONE"
		air_status.modulate = Color(0.5, 0.5, 0.5)
		
	if cdata.get("has_seaport", false):
		var open = cstate.get("seaport_open", true)
		sea_status.text = "Sea: OPEN" if open else "Sea: CLOSED"
		sea_status.modulate = Color(0.2, 1.0, 0.4) if open else Color(1.0, 0.3, 0.3)
	else:
		sea_status.text = "Sea: NONE"
		sea_status.modulate = Color(0.5, 0.5, 0.5)
		
	var b_open = cstate.get("borders_open", true)
	land_status.text = "Land: OPEN" if b_open else "Land: SEALED"
	land_status.modulate = Color(0.2, 1.0, 0.4) if b_open else Color(1.0, 0.3, 0.3)

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
