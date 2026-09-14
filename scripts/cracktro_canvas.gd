extends Control

var sim_time: float = 0.0
var particles: Array[Dictionary] = []
const PARTICLE_COUNT: int = 180

# Reference to emblem for laser scanline
var emblem_node: Control = null
var is_cracktro_active: bool = true

func _ready():
	_init_particles()

func _init_particles():
	particles.clear()
	var vp_size = get_viewport_rect().size
	if vp_size == Vector2.ZERO:
		vp_size = Vector2(1280, 720)
	for i in range(PARTICLE_COUNT):
		particles.append({
			"pos": Vector2(randf() * vp_size.x, randf() * vp_size.y),
			"vel": Vector2((randf() - 0.5) * 32.0, (randf() - 0.5) * 32.0),
			"r": randf() * 1.5 + 0.6
		})

func _process(delta: float):
	sim_time += delta
	var vp_size = get_viewport_rect().size
	
	# Update particles
	for p in particles:
		p.pos += p.vel * delta
		if p.pos.x < 0: p.pos.x = vp_size.x
		elif p.pos.x > vp_size.x: p.pos.x = 0
		if p.pos.y < 0: p.pos.y = vp_size.y
		elif p.pos.y > vp_size.y: p.pos.y = 0
		
	queue_redraw()

func _draw():
	var vp_size = get_viewport_rect().size
	if vp_size == Vector2.ZERO:
		vp_size = Vector2(1280, 720)
		
	# 1. Base dark background
	draw_rect(Rect2(Vector2.ZERO, vp_size), Color(0.012, 0.002, 0.002, 1.0))
	
	# 2. Radial vignette / glow approximation
	var center = Vector2(vp_size.x * 0.5, vp_size.y * 0.44)
	draw_circle(center, min(vp_size.x, vp_size.y) * 0.75, Color(0.12, 0.0, 0.0, 0.35))
	draw_circle(center, min(vp_size.x, vp_size.y) * 0.50, Color(0.16, 0.0, 0.0, 0.50))
	draw_circle(center, min(vp_size.x, vp_size.y) * 0.28, Color(0.22, 0.0, 0.0, 0.65))
	
	# 3. Moving Technical Grid (52px spacing)
	var s = 52.0
	var ox = fmod(sim_time * 16.0, s)
	var oy = fmod(sim_time * 8.0, s)
	var grid_col = Color(0.48, 0.0, 0.0, 0.14)
	
	var gx = -s + ox
	while gx < vp_size.x + s:
		draw_line(Vector2(gx, 0), Vector2(gx, vp_size.y), grid_col, 1.0)
		gx += s
		
	var gy = -s + oy
	while gy < vp_size.y + s:
		draw_line(Vector2(0, gy), Vector2(vp_size.x, gy), grid_col, 1.0)
		gy += s
		
	# 4. Hexagonal Network Nodes
	var hex_col = Color(0.65, 0.0, 0.0, 0.22)
	for i in range(8):
		var hx = fmod(vp_size.x * (0.08 + i * 0.13) + sim_time * 14.0 * (i + 1), vp_size.x + 140.0) - 70.0
		var hy = vp_size.y * (0.12 + (i % 4) * 0.25)
		var pts = PackedVector2Array()
		for k in range(7):
			var a = PI / 3.0 * k
			pts.append(Vector2(hx + 30.0 * cos(a), hy + 30.0 * sin(a)))
		draw_polyline(pts, hex_col, 1.2)
		
	# 5. Floating Particles
	for p in particles:
		draw_circle(p.pos, p.r, Color(0.95, 0.14, 0.14, 0.55))
		
	# 6. Cracktro-only emblem laser scan & radar pulse
	if is_cracktro_active and emblem_node != null and emblem_node.visible:
		var emb_rect = emblem_node.get_global_rect()
		var emb_center = emb_rect.position + emb_rect.size * 0.5
		var emb_radius = emb_rect.size.x * 0.38
		
		# Radar pulse
		var pulse_t = fmod(sim_time, 2.9) / 2.9
		if pulse_t > 0.60 and pulse_t < 0.85:
			var pr = 20.0 + (pulse_t - 0.60) * 220.0
			var pa = (1.0 - (pulse_t - 0.60) / 0.25) * 0.85
			draw_arc(emb_center, pr, 0, TAU, 48, Color(1.0, 0.18, 0.18, pa), 2.2)
			
		# Sweeping laser scanline over the emblem globe
		var scan_y = emb_center.y + sin(sim_time * 2.6) * (emb_radius * 0.75)
		var scan_half_w = emb_radius * 0.85
		draw_line(Vector2(emb_center.x - scan_half_w, scan_y), Vector2(emb_center.x + scan_half_w, scan_y), Color(1.0, 0.4, 0.4, 0.85), 2.0)
		draw_line(Vector2(emb_center.x - scan_half_w * 0.9, scan_y - 2), Vector2(emb_center.x + scan_half_w * 0.9, scan_y - 2), Color(1.0, 0.2, 0.2, 0.35), 1.0)
		draw_line(Vector2(emb_center.x - scan_half_w * 0.9, scan_y + 2), Vector2(emb_center.x + scan_half_w * 0.9, scan_y + 2), Color(1.0, 0.2, 0.2, 0.35), 1.0)
		
	# 7. Occasional VHS interference glitch lines
	var q = fmod(sim_time * 1000.0, 4400.0)
	if q > 3050.0 and q < 3260.0:
		for i in range(6):
			var ly = randf() * vp_size.y
			draw_rect(Rect2(0, ly, vp_size.x, 1.0 + randf() * 2.5), Color(0.95, 0.15, 0.15, 0.28))
			
	# 8. CRT Scanlines (every 3px)
	var crt_col = Color(0.0, 0.0, 0.0, 0.18)
	var sy = 0.0
	while sy < vp_size.y:
		draw_line(Vector2(0, sy), Vector2(vp_size.x, sy), crt_col, 1.0)
		sy += 3.0
		
	# 9. CRT Vignette borders
	draw_rect(Rect2(0, 0, vp_size.x, 6), Color(0.0, 0.0, 0.0, 0.6))
	draw_rect(Rect2(0, vp_size.y - 6, vp_size.x, 6), Color(0.0, 0.0, 0.0, 0.6))
	draw_rect(Rect2(0, 0, 6, vp_size.y), Color(0.0, 0.0, 0.0, 0.6))
	draw_rect(Rect2(vp_size.x - 6, 0, 6, vp_size.y), Color(0.0, 0.0, 0.0, 0.6))
