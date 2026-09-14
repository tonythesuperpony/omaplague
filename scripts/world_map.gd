extends Node2D

signal country_selected(country_id: String)
signal country_hovered(country_id: String, screen_pos: Vector2)
signal country_unhovered()
signal country_deselected()

@onready var vehicles_node: Node2D = $Vehicles
@onready var bubbles_node: Node2D = $Bubbles
@onready var effects_node: Node2D = $Effects

# Country polygon caches
var country_polys: Dictionary = {}
var country_bounds: Dictionary = {}

var hovered_country_id: String = ""
var selected_country_id: String = ""

# Camera zoom & pan
var zoom_level: float = 0.70
var min_zoom: float = 0.55
var max_zoom: float = 4.0
var is_dragging: bool = false
var drag_start: Vector2 = Vector2.ZERO

var pulse_time: float = 0.0
const MAP_WIDTH: float = 1920.0
const MAP_HEIGHT: float = 960.0

var is_interactive: bool = false

# Textures
var icon_plane: Texture2D
var icon_anchor: Texture2D

# Ambient traffic
var ambient_timer: float = 0.0
const AMBIENT_INTERVAL: float = 0.85

func _ready():
	# Load textures
	if ResourceLoader.exists("res://assets/icons/airplane.png"):
		icon_plane = load("res://assets/icons/airplane.png")
	if ResourceLoader.exists("res://assets/icons/anchor.png"):
		icon_anchor = load("res://assets/icons/anchor.png")
		
	_build_vector_cache()
	
	GameState.plane_dispatched.connect(_on_plane_dispatched)
	GameState.ship_dispatched.connect(_on_ship_dispatched)
	GameState.bubble_spawned.connect(_on_bubble_spawned)
	GameState.pop_all_bubbles_requested.connect(pop_all_bubbles)
	
	# Center map initially in viewport with responsive zoom
	var vp_size = get_viewport_rect().size
	zoom_level = clamp(vp_size.x / MAP_WIDTH * 1.05, 0.65, 0.85)
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
		
	print("Built vector cache for %d countries" % country_polys.size())

func set_interactive(state: bool):
	is_interactive = state
	if not is_interactive and hovered_country_id != "":
		hovered_country_id = ""
		country_unhovered.emit()
		queue_redraw()

func _process(delta: float):
	pulse_time += delta
	
	# Spawn ambient flights and ships continuously when not paused
	if GameState.sim_speed > 0.0:
		ambient_timer += delta * GameState.sim_speed
		if ambient_timer >= AMBIENT_INTERVAL:
			ambient_timer = 0.0
			_spawn_ambient_traffic()
		
	queue_redraw()

func _spawn_ambient_traffic():
	if DataManager.countries.is_empty():
		return
		
	# Pick a random country
	var c1 = DataManager.countries[randi() % DataManager.countries.size()]
	var c1_id = c1.get("id", "")
	var connections = c1.get("connections", {})
	
	# Decide air or sea
	var is_sea = (randf() < 0.42 and c1.get("has_seaport", false))
	var mode = "sea" if is_sea else "air"
	var routes = connections.get(mode, [])
	
	if routes.is_empty():
		if mode == "sea" and not connections.get("air", []).is_empty():
			mode = "air"
			routes = connections.get("air", [])
		else:
			return
			
	if routes.is_empty():
		return
		
	var c2_id = routes[randi() % routes.size()]
	var c2 = DataManager.get_country(c2_id)
	if c2.is_empty():
		return
		
	# Ambient traffic is normal commercial traffic (not infection vectors)
	var is_inf = false
			
	var p1 = Vector2(c1.get("map_x", 0), c1.get("map_y", 0))
	var p2 = Vector2(c2.get("map_x", 0), c2.get("map_y", 0))
	if p1 == Vector2.ZERO or p2 == Vector2.ZERO:
		return
		
	var script_res = load("res://scripts/transit_vehicle.gd")
	var vehicle = Node2D.new()
	vehicle.set_script(script_res)
	vehicle.setup(mode, p1, p2, is_inf)
	vehicles_node.add_child(vehicle)

func _input(event: InputEvent):
	if not is_interactive:
		if hovered_country_id != "":
			hovered_country_id = ""
			country_unhovered.emit()
			queue_redraw()
		return

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
			if not event.is_echo():
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
	var p_min_x = vp_size.x - map_size.x - vp_size.x * 0.35
	var p_max_x = vp_size.x * 0.35
	position.x = clamp(position.x, min(p_min_x, p_max_x), max(p_min_x, p_max_x))
	
	var p_min_y = vp_size.y - map_size.y - vp_size.y * 0.35
	var p_max_y = vp_size.y * 0.35
	position.y = clamp(position.y, min(p_min_y, p_max_y), max(p_min_y, p_max_y))

func _handle_mouse_hover(screen_pos: Vector2):
	if not is_interactive:
		if hovered_country_id != "":
			hovered_country_id = ""
			country_unhovered.emit()
			queue_redraw()
		return
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
		country_hovered.emit(hovered_country_id, screen_pos)

func _handle_left_click(screen_pos: Vector2):
	var world_p = (screen_pos - position) / zoom_level
	
	# PRIORITY: check if click hits any bubble first (in world space)
	# Bubbles have a collision radius of ~34px in sprite space, scaled by their current scale (~0.7)
	# So effective world-space radius ≈ 34 * 0.7 = ~24px — use 30 for generous hit area
	for bubble in bubbles_node.get_children():
		if not bubble.is_queued_for_deletion():
			var dist = world_p.distance_to(bubble.position)
			# Use a generous hit radius (bubble scale * 34 collision radius)
			var hit_radius = 34.0 * bubble.scale.x + 8.0
			if dist <= hit_radius:
				bubble.pop()
				return  # Consumed by bubble — don't process country click
	
	var cid = _get_country_at_pos(world_p)
	if cid != "":
		if not GameState.patient_zero_selected:
			GameState.start_patient_zero(cid)
		else:
			selected_country_id = cid
			country_selected.emit(cid)
			AudioManager.play_sfx("click")
		queue_redraw()
	else:
		# Clicked empty ocean/void — deselect
		if selected_country_id != "":
			selected_country_id = ""
			country_deselected.emit()
			queue_redraw()

func _get_country_at_pos(p: Vector2) -> String:
	# Bounding-box pre-filtering for fast picking
	for cid in country_bounds:
		var bbox: Rect2 = country_bounds[cid]
		if bbox.has_point(p):
			var plist = country_polys[cid]
			for poly in plist:
				if Geometry2D.is_point_in_polygon(p, poly):
					return cid
	return ""

func _draw():
	# 0. Fill beyond-map area with matching ocean dark color (prevents gray border when zoomed out)
	var vp_size = get_viewport_rect().size
	# Draw extra large covering rect in local space (map transform applied by parent)
	draw_rect(Rect2(-2000, -2000, 6000, 5000), Color(0.035, 0.05, 0.08, 1.0))
	
	# 1. Base Map: Sleek tactical vector ocean (omaproton-vpn dark style)
	draw_rect(Rect2(0, 0, MAP_WIDTH, MAP_HEIGHT), Color(0.038, 0.052, 0.082, 1.0))
	
	# 1b. Subtle tactical latitude & longitude grid lines
	var grid_col = Color(0.12, 0.18, 0.26, 0.22)
	# Latitude lines (every 160px = 30 degrees)
	for lat_y in range(160, int(MAP_HEIGHT), 160):
		draw_line(Vector2(0, lat_y), Vector2(MAP_WIDTH, lat_y), grid_col, 0.8)
	# Longitude lines (every 160px = 30 degrees)
	for lon_x in range(160, int(MAP_WIDTH), 160):
		draw_line(Vector2(lon_x, 0), Vector2(lon_x, MAP_HEIGHT), grid_col, 0.8)
		
	# 2. Country Vector Polygons (omaproton-vpn tactical vector style)
	# Every country has a clean, crisp vector landmass fill and sharp border
	var base_land_fill = Color(0.10, 0.14, 0.21, 0.95)
	var base_border = Color(0.22, 0.32, 0.44, 0.60)
	
	for cid in country_polys:
		var is_hovered = (cid == hovered_country_id)
		var is_selected = (cid == selected_country_id)
		var plist = country_polys[cid]
		
		var has_state = GameState.country_states.has(cid)
		var state = GameState.country_states.get(cid, {})
		var inf = state.get("infected", 0) if has_state else 0
		var dead = state.get("dead", 0) if has_state else 0
		var pop = float(state.get("population", 1)) if has_state else 1.0
		var inf_ratio = clamp(float(inf) / max(1.0, pop * 0.45), 0.0, 1.0)
		var dead_ratio = clamp(float(dead) / max(1.0, pop), 0.0, 1.0)
		
		# A. Vector Landmass Fill
		var fill_color = base_land_fill
		if is_hovered:
			fill_color = Color(0.18, 0.75, 0.88, 0.45)
		elif is_selected:
			fill_color = Color(1.0, 0.85, 0.25, 0.38)
		elif dead_ratio > 0.7:
			fill_color = Color(0.18, 0.05, 0.05, 0.92)
		elif inf > 0:
			fill_color = Color(0.85, 0.12, 0.12, clamp(inf_ratio * 0.52 + 0.18, 0.18, 0.75))
			
		for poly in plist:
			draw_colored_polygon(poly, fill_color)
				
		# B. Country Borders
		var border_color = base_border
		var border_width = 0.85
		
		if is_hovered:
			border_color = Color(0.35, 0.95, 1.0, 1.0)
			border_width = 2.2
		elif is_selected:
			border_color = Color(1.0, 0.90, 0.30, 1.0)
			border_width = 2.4
		elif inf > 0:
			border_color = Color(0.95, 0.25, 0.25, 0.85)
			
		for poly in plist:
			var closed = PackedVector2Array(poly)
			closed.append(poly[0])
			draw_polyline(closed, border_color, border_width, true)
			
		# C. Biological Infection Stipple Dots (Plague Inc virus nodes)
		if inf > 0:
			var cdata = DataManager.get_country(cid)
			var stipples = cdata.get("stipple_points", [])
			if not stipples.is_empty():
				var active_dots = int(clamp(inf_ratio * float(stipples.size()) + 1.0, 1.0, float(stipples.size())))
				var pulse = sin(pulse_time * 3.5 + float(active_dots)) * 0.2 + 0.8
				for di in range(min(active_dots, stipples.size())):
					var dpt = Vector2(stipples[di][0], stipples[di][1])
					draw_circle(dpt, 1.6, Color(1.0, 0.18, 0.18, 0.9 * pulse))
					draw_circle(dpt, 3.2, Color(0.9, 0.1, 0.1, 0.28 * pulse))

	# 4. Port Badges (Airports & Seaports)
	for cid in DataManager.countries:
		var cdata = cid
		var c_id = cdata.get("id", "")
		var center = Vector2(cdata.get("map_x", 0), cdata.get("map_y", 0))
		if center == Vector2.ZERO:
			continue
			
		var state = GameState.country_states.get(c_id, {})
		var is_inf = state.get("is_infected", false)
		var is_hov = (c_id == hovered_country_id)
		
		# Show badges when zoomed in or if hovered / infected / major hub
		var should_show = (zoom_level >= 1.15 or is_hov or is_inf or cdata.get("wealth") == "rich" or cdata.get("population", 0) > 40000000)
		if not should_show:
			continue
			
		# Airport Badge
		if cdata.get("has_airport", false) and icon_plane:
			var air_open = state.get("airport_open", true)
			var air_pos = center + Vector2(-9, -6)
			var air_rect = Rect2(air_pos.x - 6, air_pos.y - 6, 12, 12)
			
			var bg_col = Color(0.06, 0.12, 0.18, 0.85)
			var fg_col = Color(1.0, 1.0, 1.0, 0.95)
			if not air_open:
				bg_col = Color(0.6, 0.1, 0.1, 0.9)
				fg_col = Color(1.0, 0.4, 0.4, 0.8)
			elif is_inf:
				bg_col = Color(0.7, 0.18, 0.18, 0.9)
				
			draw_rect(air_rect, bg_col, true)
			draw_rect(air_rect, Color(0.3, 0.6, 0.8, 0.6) if air_open else Color(0.9, 0.2, 0.2, 0.8), false, 1.0)
			draw_texture_rect(icon_plane, Rect2(air_pos.x - 4, air_pos.y - 4, 8, 8), false, fg_col)
			
		# Seaport Badge
		if cdata.get("has_seaport", false) and icon_anchor:
			var sea_open = state.get("seaport_open", true)
			var sea_pos = center + Vector2(9, -6)
			var sea_rect = Rect2(sea_pos.x - 6, sea_pos.y - 6, 12, 12)
			
			var bg_col = Color(0.06, 0.12, 0.18, 0.85)
			var fg_col = Color(1.0, 1.0, 1.0, 0.95)
			if not sea_open:
				bg_col = Color(0.6, 0.1, 0.1, 0.9)
				fg_col = Color(1.0, 0.4, 0.4, 0.8)
			elif is_inf:
				bg_col = Color(0.7, 0.18, 0.18, 0.9)
				
			draw_rect(sea_rect, bg_col, true)
			draw_rect(sea_rect, Color(0.3, 0.6, 0.8, 0.6) if sea_open else Color(0.9, 0.2, 0.2, 0.8), false, 1.0)
			draw_texture_rect(icon_anchor, Rect2(sea_pos.x - 4, sea_pos.y - 4, 8, 8), false, fg_col)

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
	bubble.tree_exited.connect(_on_bubble_tree_exited)
	_notify_bubble_count()

func _on_bubble_tree_exited():
	call_deferred("_notify_bubble_count")

func _notify_bubble_count():
	var count = get_active_bubble_count()
	GameState.bubble_count_changed.emit(count)

func get_active_bubble_count() -> int:
	var c = 0
	for b in bubbles_node.get_children():
		if is_instance_valid(b) and not b.is_queued_for_deletion():
			c += 1
	return c

func pop_all_bubbles():
	var bubbles = []
	for b in bubbles_node.get_children():
		if is_instance_valid(b) and not b.is_queued_for_deletion():
			bubbles.append(b)
	
	if bubbles.is_empty():
		return
		
	# Stagger pops over at most 0.35s for delightful audio-visual cascade
	for i in range(bubbles.size()):
		var b = bubbles[i]
		if is_instance_valid(b) and not b.is_queued_for_deletion():
			if i == 0:
				b.pop()
			else:
				var delay = min(float(i) * 0.035, 0.35)
				var timer = get_tree().create_timer(delay)
				timer.timeout.connect(func():
					if is_instance_valid(b) and not b.is_queued_for_deletion():
						b.pop()
				)

