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
	
	# Calculate arched control point for smooth bezier curve
	var mid = (start_pos + end_pos) * 0.5
	var diff = end_pos - start_pos
	var normal = diff.orthogonal().normalized()
	var dist = start_pos.distance_to(end_pos)
	
	# Arc upward or downward depending on heading
	var arc_height = dist * (0.18 if vehicle_type == "air" else 0.12)
	# Arch northward or southward
	if normal.y > 0 and vehicle_type == "air":
		normal = -normal
	control_point = mid + normal * arc_height
	
	travel_time = clamp(dist / 180.0, 2.5, 6.5)

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

func _process(delta: float):
	elapsed += delta
	var t = clamp(elapsed / travel_time, 0.0, 1.0)
	
	# Quadratic Bezier position
	var q0 = start_pos.lerp(control_point, t)
	var q1 = control_point.lerp(end_pos, t)
	var current = q0.lerp(q1, t)
	
	# Compute forward heading direction
	var next_t = min(1.0, t + 0.02)
	var next_q0 = start_pos.lerp(control_point, next_t)
	var next_q1 = control_point.lerp(end_pos, next_t)
	var next_pos = next_q0.lerp(next_q1, next_t)
	
	if next_pos != current:
		var angle = (next_pos - current).angle()
		# airplane.png points straight UP (angle offset +PI/2), boat points to the right (+X)
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
	if trail_points.size() < 2:
		return
		
	var base_col = Color(1.0, 0.25, 0.25) if is_infected else (Color(0.85, 0.95, 1.0) if vehicle_type == "air" else Color(0.5, 0.85, 1.0))
	
	for i in range(trail_points.size() - 1):
		var p1 = to_local(trail_points[i])
		var p2 = to_local(trail_points[i + 1])
		var progress = float(i) / float(trail_points.size())
		var alpha = (1.0 - progress) * (0.55 if vehicle_type == "air" else 0.45)
		var col = base_col
		col.a = alpha
		var width = (1.8 - progress * 0.8) if vehicle_type == "air" else (2.4 - progress * 1.2)
		draw_line(p1, p2, col, width)
