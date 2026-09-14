extends Node2D

var vehicle_type: String = "air" # "air" or "sea"
var start_pos: Vector2
var end_pos: Vector2
var control_point: Vector2
var travel_time: float = 4.0
var elapsed: float = 0.0
var is_infected: bool = false

var trail_points: Array[Vector2] = []
const MAX_TRAIL: int = 15

var sprite: Sprite2D

func setup(p_type: String, p_start: Vector2, p_end: Vector2, p_infected: bool):
	vehicle_type = p_type
	start_pos = p_start
	end_pos = p_end
	is_infected = p_infected
	
	# Calculate arched control point for bezier curve
	var mid = (start_pos + end_pos) * 0.5
	var normal = (end_pos - start_pos).orthogonal().normalized()
	# Arc upward or downward depending on distance
	var dist = start_pos.distance_to(end_pos)
	control_point = mid - normal * (dist * 0.22)
	
	travel_time = clamp(dist / 220.0, 2.5, 6.0)

func _ready():
	sprite = Sprite2D.new()
	var icon_name = "airplane" if vehicle_type == "air" else "ship"
	var path = "res://assets/icons/" + icon_name + ".png"
	if ResourceLoader.exists(path):
		sprite.texture = load(path)
	sprite.scale = Vector2(0.28, 0.28)
	if is_infected:
		sprite.modulate = Color(1.0, 0.25, 0.25)
	else:
		sprite.modulate = Color(0.9, 0.95, 1.0, 0.85)
	add_child(sprite)

func _process(delta: float):
	elapsed += delta
	var t = clamp(elapsed / travel_time, 0.0, 1.0)
	
	# Quadratic Bezier
	var q0 = start_pos.lerp(control_point, t)
	var q1 = control_point.lerp(end_pos, t)
	var current = q0.lerp(q1, t)
	
	# Compute heading direction
	var next_t = min(1.0, t + 0.02)
	var next_q0 = start_pos.lerp(control_point, next_t)
	var next_q1 = control_point.lerp(end_pos, next_t)
	var next_pos = next_q0.lerp(next_q1, next_t)
	
	if next_pos != current:
		sprite.rotation = (next_pos - current).angle() + (PI * 0.5 if vehicle_type == "air" else 0.0)
		
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
	var trail_color = Color(1.0, 0.3, 0.3, 0.4) if is_infected else Color(0.4, 0.8, 1.0, 0.3)
	for i in range(trail_points.size() - 1):
		var p1 = to_local(trail_points[i])
		var p2 = to_local(trail_points[i + 1])
		var alpha = (1.0 - float(i) / float(trail_points.size())) * 0.5
		var col = trail_color
		col.a = alpha
		draw_line(p1, p2, col, 1.5)
