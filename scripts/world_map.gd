extends Node2D

signal country_selected(country_id: String)
signal country_hovered(country_id: String)

@onready var map_sprite: Sprite2D = $MapSprite
@onready var vehicles_node: Node2D = $Vehicles
@onready var bubbles_node: Node2D = $Bubbles
@onready var effects_node: Node2D = $Effects

var mask_image: Image
var hovered_country_id: String = ""
var selected_country_id: String = ""

# Camera zoom & pan
var zoom_level: float = 1.0
var min_zoom: float = 0.75
var max_zoom: float = 2.5
var is_dragging: bool = false
var drag_start: Vector2 = Vector2.ZERO

var pulse_time: float = 0.0

func _ready():
	# Load mask image for pixel-perfect picking
	var mask_tex_path = "res://assets/region_mask.png"
	if ResourceLoader.exists(mask_tex_path):
		var tex = load(mask_tex_path) as Texture2D
		if tex:
			mask_image = tex.get_image()
			print("Region mask loaded: %dx%d" % [mask_image.get_width(), mask_image.get_height()])
			
	GameState.plane_dispatched.connect(_on_plane_dispatched)
	GameState.ship_dispatched.connect(_on_ship_dispatched)
	GameState.bubble_spawned.connect(_on_bubble_spawned)

func _process(delta: float):
	pulse_time += delta
	queue_redraw()

func _input(event: InputEvent):
	# Pan with right mouse or middle click
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT or event.button_index == MOUSE_BUTTON_MIDDLE:
			if event.pressed:
				is_dragging = true
				drag_start = event.position - position
			else:
				is_dragging = false
				
		# Zoom with mouse wheel
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom_at(event.position, 1.1)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom_at(event.position, 0.9)
			
		elif event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			_handle_left_click(event.position)
			
	elif event is InputEventMouseMotion:
		if is_dragging:
			position = event.position - drag_start
			_clamp_position()
		else:
			_handle_mouse_hover(event.position)

func _zoom_at(mouse_pos: Vector2, factor: float):
	var new_zoom = clamp(zoom_level * factor, min_zoom, max_zoom)
	if new_zoom != zoom_level:
		var mouse_world = (mouse_pos - position) / zoom_level
		zoom_level = new_zoom
		scale = Vector2(zoom_level, zoom_level)
		position = mouse_pos - mouse_world * zoom_level
		_clamp_position()

func _clamp_position():
	# Prevent dragging map out of view
	var vp_size = get_viewport_rect().size
	var map_size = Vector2(1920, 975) * zoom_level
	position.x = clamp(position.x, vp_size.x - map_size.x, 0.0)
	position.y = clamp(position.y, vp_size.y - map_size.y, 0.0)

func _handle_mouse_hover(screen_pos: Vector2):
	var world_p = (screen_pos - position) / zoom_level
	var cid = _get_country_at_pos(world_p)
	if cid != hovered_country_id:
		hovered_country_id = cid
		country_hovered.emit(hovered_country_id)

func _handle_left_click(screen_pos: Vector2):
	var world_p = (screen_pos - position) / zoom_level
	var cid = _get_country_at_pos(world_p)
	if cid != "":
		if not GameState.patient_zero_selected:
			GameState.start_patient_zero(cid)
		else:
			selected_country_id = cid
			country_selected.emit(cid)
			AudioManager.play_sfx("click")

func _get_country_at_pos(p: Vector2) -> String:
	if mask_image == null:
		return ""
	var ix = int(p.x)
	var iy = int(p.y)
	if ix >= 0 and ix < mask_image.get_width() and iy >= 0 and iy < mask_image.get_height():
		var col = mask_image.get_pixel(ix, iy)
		var reg_idx = col.r8
		if reg_idx > 0:
			var cdata = DataManager.get_country_by_index(reg_idx)
			return cdata.get("id", "")
	return ""

func _draw():
	# Draw infected countries status, rings, and infection spread
	for cid in GameState.country_states:
		var state = GameState.country_states[cid]
		if state["infected"] > 0 or state["dead"] > 0:
			var cdata = DataManager.get_country(cid)
			var center = Vector2(cdata.get("map_x", 0), cdata.get("map_y", 0))
			if center == Vector2.ZERO:
				continue
				
			var pop = float(state["population"])
			var inf_ratio = clamp(float(state["infected"]) / pop, 0.0, 1.0)
			var dead_ratio = clamp(float(state["dead"]) / pop, 0.0, 1.0)
			
			# Pulse animation
			var pulse = sin(pulse_time * 4.0 + center.x * 0.1) * 0.15 + 1.0
			var base_r = clamp(12.0 + log(state["infected"] + 1) * 2.2, 10.0, 42.0)
			var r = base_r * pulse
			
			# Outer danger halo
			var halo_col = Color(1.0, 0.15, 0.15, 0.22 * inf_ratio + 0.12)
			draw_circle(center, r * 1.5, halo_col)
			
			# Pulsing infection ring
			var ring_col = Color(1.0, 0.2, 0.2, 0.75)
			draw_arc(center, r, 0, TAU, 32, ring_col, 1.8)
			
			# Core: red if living infected, black/dark if high death
			var core_col = Color(0.9, 0.1, 0.1, 0.7)
			if dead_ratio > 0.4:
				core_col = core_col.lerp(Color(0.1, 0.05, 0.05, 0.85), dead_ratio)
			draw_circle(center, r * 0.55, core_col)
			
			# Highlight selected country
			if cid == selected_country_id:
				draw_arc(center, r * 1.8, 0, TAU, 32, Color(1.0, 1.0, 1.0, 0.9), 2.5)

func _on_plane_dispatched(from_id: String, to_id: String, is_infected: bool):
	var from_data = DataManager.get_country(from_id)
	var to_data = DataManager.get_country(to_id)
	if from_data.is_empty() or to_data.is_empty():
		return
	var p1 = Vector2(from_data.get("map_x", 0), from_data.get("map_y", 0))
	var p2 = Vector2(to_data.get("map_x", 0), to_data.get("map_y", 0))
	
	var script_res = load("res://scripts/transit_vehicle.gd")
	var vehicle = Node2D.new()
	vehicle.set_script(script_res)
	vehicle.setup("air", p1, p2, is_infected)
	vehicles_node.add_child(vehicle)

func _on_ship_dispatched(from_id: String, to_id: String, is_infected: bool):
	var from_data = DataManager.get_country(from_id)
	var to_data = DataManager.get_country(to_id)
	if from_data.is_empty() or to_data.is_empty():
		return
	var p1 = Vector2(from_data.get("map_x", 0), from_data.get("map_y", 0))
	var p2 = Vector2(to_data.get("map_x", 0), to_data.get("map_y", 0))
	
	var script_res = load("res://scripts/transit_vehicle.gd")
	var vehicle = Node2D.new()
	vehicle.set_script(script_res)
	vehicle.setup("sea", p1, p2, is_infected)
	vehicles_node.add_child(vehicle)

func _on_bubble_spawned(type: String, world_pos: Vector2, cid: String):
	var bubble_scene = load("res://scenes/bubble.tscn")
	var bubble = bubble_scene.instantiate()
	bubble.setup(type, world_pos, cid)
	bubbles_node.add_child(bubble)
