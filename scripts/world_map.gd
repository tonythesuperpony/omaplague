extends Node2D

signal country_selected(country_id: String)
signal country_hovered(country_id: String, screen_pos: Vector2)
signal country_unhovered()

@onready var vehicles_node: Node2D = $Vehicles
@onready var bubbles_node: Node2D = $Bubbles
@onready var effects_node: Node2D = $Effects

# Country polygon caches
# Structure: cid -> Array of PackedVector2Array
var country_polys: Dictionary = {}
# Structure: cid -> Rect2 (bounding box for ultra-fast culling)
var country_bounds: Dictionary = {}

var hovered_country_id: String = ""
var selected_country_id: String = ""

# Camera zoom & pan
var zoom_level: float = 0.95
var min_zoom: float = 0.65
var max_zoom: float = 3.5
var is_dragging: bool = false
var drag_start: Vector2 = Vector2.ZERO

var pulse_time: float = 0.0
const MAP_WIDTH: float = 1920.0
const MAP_HEIGHT: float = 975.0

func _ready():
	_build_vector_cache()
	
	GameState.plane_dispatched.connect(_on_plane_dispatched)
	GameState.ship_dispatched.connect(_on_ship_dispatched)
	GameState.bubble_spawned.connect(_on_bubble_spawned)
	
	# Center map initially in viewport
	var vp_size = get_viewport_rect().size
	position = (vp_size - Vector2(MAP_WIDTH, MAP_HEIGHT) * zoom_level) * 0.5
	scale = Vector2(zoom_level, zoom_level)

func _build_vector_cache():
	country_polys.clear()
	country_bounds.clear()
	
	for cid in DataManager.country_polygons:
		var raw_polys = DataManager.country_polygons[cid]
		var packed_list: Array[PackedVector2Array] = []
		
		var min_x = 99999.0
		var max_x = -99999.0
		var min_y = 99999.0
		var max_y = -99999.0
		
		for poly in raw_polys:
			if poly.size() < 3:
				continue
			var varr = PackedVector2Array()
			for pt in poly:
				var v = Vector2(pt[0], pt[1])
				varr.append(v)
				if v.x < min_x: min_x = v.x
				if v.x > max_x: max_x = v.x
				if v.y < min_y: min_y = v.y
				if v.y > max_y: max_y = v.y
			packed_list.append(varr)
			
		country_polys[cid] = packed_list
		country_bounds[cid] = Rect2(min_x, min_y, max_x - min_x, max_y - min_y)
		
	print("Built vector cache for %d regions" % country_polys.size())

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
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			_zoom_at(event.position, 1.15)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			_zoom_at(event.position, 0.87)
			
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
	var vp_size = get_viewport_rect().size
	var map_size = Vector2(MAP_WIDTH, MAP_HEIGHT) * zoom_level
	# Allow some margin for panning
	var margin_x = vp_size.x * 0.4
	var margin_y = vp_size.y * 0.4
	position.x = clamp(position.x, vp_size.x - map_size.x - margin_x, margin_x)
	position.y = clamp(position.y, vp_size.y - map_size.y - margin_y, margin_y)

func _handle_mouse_hover(screen_pos: Vector2):
	var world_p = (screen_pos - position) / zoom_level
	var cid = _get_country_at_pos(world_p)
	if cid != hovered_country_id:
		hovered_country_id = cid
		if hovered_country_id != "":
			country_hovered.emit(hovered_country_id, screen_pos)
		else:
			country_unhovered.emit()
		queue_redraw()
	elif hovered_country_id != "":
		# Update screen pos for tooltip
		country_hovered.emit(hovered_country_id, screen_pos)

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
		queue_redraw()

func _get_country_at_pos(p: Vector2) -> String:
	# Check point in all country polygons with bounding-box pre-filtering
	for cid in country_bounds:
		var bbox: Rect2 = country_bounds[cid]
		# Expand bounding box slightly for easier clicking
		if bbox.has_point(p):
			var plist = country_polys[cid]
			for poly in plist:
				if Geometry2D.is_point_in_polygon(p, poly):
					return cid
	return ""

func _draw():
	# 1. Flat dark ocean background
	draw_rect(Rect2(0, 0, MAP_WIDTH, MAP_HEIGHT), Color(0.05, 0.08, 0.13, 1.0))
	
	# 2. Latitude & Longitude grid lines
	var grid_col = Color(0.1, 0.16, 0.25, 0.4)
	for y in [180.0, 360.0, 540.0, 720.0, 900.0]:
		draw_line(Vector2(0, y), Vector2(MAP_WIDTH, y), grid_col, 1.0)
	for x in [320.0, 640.0, 960.0, 1280.0, 1600.0]:
		draw_line(Vector2(x, 0), Vector2(x, MAP_HEIGHT), grid_col, 1.0)
		
	# 3. Render all country vector polygons
	for cid in country_polys:
		var is_hovered = (cid == hovered_country_id)
		var is_selected = (cid == selected_country_id)
		
		# Determine colors based on infection & state
		var fill_color = Color(0.11, 0.16, 0.23, 1.0) # Base dark slate
		var border_color = Color(0.18, 0.27, 0.38, 1.0) # Base border
		var border_width = 1.0
		
		if GameState.country_states.has(cid):
			var state = GameState.country_states[cid]
			var pop = float(state["population"])
			var inf_ratio = clamp(float(state["infected"]) / max(1.0, pop * 0.4), 0.0, 1.0)
			var dead_ratio = clamp(float(state["dead"]) / max(1.0, pop), 0.0, 1.0)
			
			if state["infected"] > 0:
				var inf_red = Color(0.85, 0.18, 0.18, 1.0)
				fill_color = fill_color.lerp(inf_red, inf_ratio * 0.85 + 0.15)
				border_color = Color(0.8, 0.2, 0.2, 0.8)
				
			if state["dead"] > 0:
				var dead_black = Color(0.25, 0.06, 0.06, 1.0)
				fill_color = fill_color.lerp(dead_black, dead_ratio)
				
		if is_hovered:
			# Luminous glowing cyan hover
			fill_color = fill_color.lerp(Color(0.12, 0.75, 0.65, 1.0), 0.55)
			border_color = Color(0.3, 1.0, 0.8, 1.0)
			border_width = 2.4
		elif is_selected:
			# Bright gold selection
			border_color = Color(1.0, 0.85, 0.2, 1.0)
			border_width = 2.6
			
		var plist = country_polys[cid]
		for poly in plist:
			draw_colored_polygon(poly, fill_color)
			# Closed polyline for crisp border
			var closed = PackedVector2Array(poly)
			closed.append(poly[0])
			draw_polyline(closed, border_color, border_width, true)

	# 4. Render infection danger rings & centers
	for cid in GameState.country_states:
		var state = GameState.country_states[cid]
		if state["infected"] > 0 or state["dead"] > 0:
			var cdata = DataManager.get_country(cid)
			var center = Vector2(cdata.get("map_x", 0), cdata.get("map_y", 0))
			if center == Vector2.ZERO:
				continue
				
			var pop = float(state["population"])
			var inf_ratio = clamp(float(state["infected"]) / pop, 0.0, 1.0)
			var pulse = sin(pulse_time * 4.0 + center.x * 0.1) * 0.15 + 1.0
			var r = clamp(10.0 + log(state["infected"] + 1) * 2.0, 8.0, 36.0) * pulse
			
			# Outer danger halo
			draw_circle(center, r * 1.4, Color(1.0, 0.15, 0.15, 0.25 * inf_ratio + 0.1))
			# Pulsing ring
			draw_arc(center, r, 0, TAU, 28, Color(1.0, 0.3, 0.3, 0.85), 1.6)
			# Core
			draw_circle(center, r * 0.45, Color(0.9, 0.1, 0.1, 0.8))

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
