extends Node2D

var vehicle_type: String = "air" # "air" or "sea"
var start_pos: Vector2
var end_pos: Vector2
var control_point: Vector2
var travel_time: float = 4.0
var elapsed: float = 0.0
var is_infected: bool = false

var trail_points: Array[Vector2] = []
const MAX_TRAIL: int = 18

var sprite: Sprite2D

func setup(p_type: String, p_start: Vector2, p_end: Vector2, p_infected: bool):
	vehicle_type = p_type
	start_pos = p_start
	end_pos = p_end
	is_infected = p_infected
	
	# Calculate arched control point for smooth quadratic bezier curve
	var mid = (start_pos + end_pos) * 0.5
	var diff = end_pos - start_pos
	var normal = diff.orthogonal().normalized()
	var dist = start_pos.distance_to(end_pos)
	
	# Arc upward or downward depending on heading
	var arc_height = dist * (0.18 if vehicle_type == "air" else 0.12)
	if normal.y > 0 and vehicle_type == "air":
		normal = -normal
	control_point = mid + normal * arc_height
	
	travel_time = clamp(dist / 180.0, 2.8, 6.5)

func _ready():
	sprite = Sprite2D.new()
	var path = ""
	if vehicle_type == "air":
		path = "res://assets/icons/airplane.png"
		sprite.scale = Vector2(0.24, 0.24)
	else:
		path = "res://assets/icons/boat.png"
		sprite.scale = Vector2(0.32, 0.32)
		
	if ResourceLoader.exists(path):
		sprite.texture = load(path)
		
	if is_infected:
		sprite.modulate = Color(1.0, 0.2, 0.2, 1.0)
	else:
		sprite.modulate = Color(0.95, 0.98, 1.0, 0.9)
	add_child(sprite)

func _eval_bezier(s: float) -> Vector2:
	var q0 = start_pos.lerp(control_point, s)
	var q1 = control_point.lerp(end_pos, s)
	return q0.lerp(q1, s)

func _process(delta: float):
	if GameState.sim_speed > 0.0:
		elapsed += delta * GameState.sim_speed
	var t = clamp(elapsed / travel_time, 0.0, 1.0)
	
	# Quadratic Bezier position
	var current = _eval_bezier(t)
	
	# Compute forward heading direction
	var next_t = min(1.0, t + 0.02)
	var next_pos = _eval_bezier(next_t)
	
	if next_pos != current:
		var angle = (next_pos - current).angle()
		if vehicle_type == "air":
			sprite.rotation = angle + PI * 0.5
		else:
			sprite.rotation = angle
			
	position = current
	trail_points.push_front(current)
	if trail_points.size() > MAX_TRAIL:
		trail_points.pop_back()
		
	queue_redraw()
	
	if t >= 1.0:
		queue_free()

func _draw():
	var t = clamp(elapsed / travel_time, 0.0, 1.0)
	if t <= 0.005:
		return
		
	if is_infected:
		# Pulsing beacon at the infected origin country
		var local_start = start_pos - position
		var origin_pulse = sin(elapsed * 8.0) * 0.35 + 0.65
		draw_circle(local_start, 4.5, Color(1.0, 0.15, 0.15, 0.85 * origin_pulse))
		draw_circle(local_start, 2.0, Color(1.0, 0.95, 0.95, 0.95))
		
		# Flowing red dashed infection carrier beam strictly trailing behind the vehicle
		var steps = 36
		var current_steps = int(t * float(steps))
		var dash_phase = int(elapsed * 24.0)
		
		var prev_point = local_start
		for s in range(1, current_steps + 1):
			var s_val = min(t, float(s) / float(steps))
			var pt = _eval_bezier(s_val) - position
			
			# Animated dashed segment (draw 2, skip 1)
			if (s + dash_phase) % 3 != 0:
				# Glowing red outer halo
				draw_line(prev_point, pt, Color(1.0, 0.08, 0.08, 0.40), 4.5)
				# Bright core dashed red flow line
				draw_line(prev_point, pt, Color(1.0, 0.25, 0.25, 0.95), 2.2)
				
			prev_point = pt
			
		# Connect smoothly to the vehicle sprite center (Vector2.ZERO)
		if prev_point != Vector2.ZERO:
			draw_line(prev_point, Vector2.ZERO, Color(1.0, 0.25, 0.25, 0.95), 2.2)
	else:
		# Standard uninfected vehicle faint wake/contrail
		if trail_points.size() >= 2:
			var base_col = Color(0.85, 0.95, 1.0) if vehicle_type == "air" else Color(0.5, 0.85, 1.0)
			for i in range(trail_points.size() - 1):
				var p1 = trail_points[i] - position
				var p2 = trail_points[i + 1] - position
				var progress = float(i) / float(trail_points.size())
				var alpha = (1.0 - progress) * (0.45 if vehicle_type == "air" else 0.35)
				var col = base_col
				col.a = alpha
				draw_line(p1, p2, col, 1.5 - progress * 0.5)
