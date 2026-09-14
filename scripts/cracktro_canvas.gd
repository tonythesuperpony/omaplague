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
		var is_cyan = (randf() < 0.28)
		particles.append({
			"pos": Vector2(randf() * vp_size.x, randf() * vp_size.y),
			"vel": Vector2((randf() - 0.5) * 32.0, (randf() - 0.5) * 32.0),
			"r": randf() * 1.5 + 0.6,
			"is_cyan": is_cyan
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
		
	# 1. Base dark tactical navy/slate background (matching the vector world map)
	draw_rect(Rect2(Vector2.ZERO, vp_size), Color(0.038, 0.052, 0.082, 1.0))
	
	# 2. Deep tactical radial atmosphere (blending deep indigo to dark void)
	var center = Vector2(vp_size.x * 0.5, vp_size.y * 0.44)
	draw_circle(center, min(vp_size.x, vp_size.y) * 0.80, Color(0.04, 0.08, 0.15, 0.45))
	draw_circle(center, min(vp_size.x, vp_size.y) * 0.52, Color(0.06, 0.12, 0.22, 0.55))
	draw_circle(center, min(vp_size.x, vp_size.y) * 0.28, Color(0.08, 0.15, 0.28, 0.65))
	
	# 3. Moving Tactical Grid (52px spacing, slate-cyan tone)
	var s = 52.0
	var ox = fmod(sim_time * 16.0, s)
	var oy = fmod(sim_time * 8.0, s)
	var grid_col = Color(0.14, 0.22, 0.32, 0.22)
	
	var gx = -s + ox
	while gx < vp_size.x + s:
		draw_line(Vector2(gx, 0), Vector2(gx, vp_size.y), grid_col, 0.85)
		gx += s
		
	var gy = -s + oy
	while gy < vp_size.y + s:
		draw_line(Vector2(0, gy), Vector2(vp_size.x, gy), grid_col, 0.85)
		gy += s
		
	# 4. Hexagonal Network Nodes (dual tone: tactical cyan & crimson)
	for i in range(8):
		var is_crimson = (i % 2 == 1)
		var hex_col = Color(0.85, 0.20, 0.20, 0.25) if is_crimson else Color(0.18, 0.75, 0.88, 0.25)
		var hx = fmod(vp_size.x * (0.08 + i * 0.13) + sim_time * 14.0 * (i + 1), vp_size.x + 140.0) - 70.0
		var hy = vp_size.y * (0.12 + (i % 4) * 0.25)
		var pts = PackedVector2Array()
		for k in range(7):
			var a = PI / 3.0 * k
			pts.append(Vector2(hx + 30.0 * cos(a), hy + 30.0 * sin(a)))
		draw_polyline(pts, hex_col, 1.2)
		
	# 5. Floating Particles (Crimson virus cells & Cyan data packets)
	for p in particles:
		var pcol = Color(0.25, 0.85, 0.95, 0.60) if p.get("is_cyan", false) else Color(0.92, 0.18, 0.22, 0.65)
		draw_circle(p.pos, p.r, pcol)
		
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
			draw_arc(emb_center, pr, 0, TAU, 48, Color(0.2, 0.85, 1.0, pa * 0.7), 1.8)
			draw_arc(emb_center, pr * 0.92, 0, TAU, 48, Color(1.0, 0.2, 0.2, pa), 2.0)
			
		# Sweeping laser scanline over the emblem globe
		var scan_y = emb_center.y + sin(sim_time * 2.6) * (emb_radius * 0.75)
		var scan_half_w = emb_radius * 0.85
		draw_line(Vector2(emb_center.x - scan_half_w, scan_y), Vector2(emb_center.x + scan_half_w, scan_y), Color(1.0, 0.35, 0.35, 0.9), 2.0)
		draw_line(Vector2(emb_center.x - scan_half_w * 0.9, scan_y - 2), Vector2(emb_center.x + scan_half_w * 0.9, scan_y - 2), Color(0.2, 0.8, 0.95, 0.4), 1.0)
		draw_line(Vector2(emb_center.x - scan_half_w * 0.9, scan_y + 2), Vector2(emb_center.x + scan_half_w * 0.9, scan_y + 2), Color(0.2, 0.8, 0.95, 0.4), 1.0)
		
	# 7. Occasional VHS interference glitch lines
	var q = fmod(sim_time * 1000.0, 4400.0)
	if q > 3050.0 and q < 3260.0:
		for i in range(5):
			var ly = randf() * vp_size.y
			draw_rect(Rect2(0, ly, vp_size.x, 1.0 + randf() * 2.0), Color(0.25, 0.75, 0.9, 0.22))
			
	# 8. CRT Scanlines (every 3px)
	var crt_col = Color(0.0, 0.0, 0.0, 0.16)
	var sy = 0.0
	while sy < vp_size.y:
		draw_line(Vector2(0, sy), Vector2(vp_size.x, sy), crt_col, 1.0)
		sy += 3.0
		
	# 9. CRT Vignette borders
	draw_rect(Rect2(0, 0, vp_size.x, 6), Color(0.0, 0.0, 0.0, 0.6))
	draw_rect(Rect2(0, vp_size.y - 6, vp_size.x, 6), Color(0.0, 0.0, 0.0, 0.6))
	draw_rect(Rect2(0, 0, 6, vp_size.y), Color(0.0, 0.0, 0.0, 0.6))
	draw_rect(Rect2(vp_size.x - 6, 0, 6, vp_size.y), Color(0.0, 0.0, 0.0, 0.6))
