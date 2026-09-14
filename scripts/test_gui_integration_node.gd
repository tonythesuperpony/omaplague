extends Node

func _ready():
	print("=== Running Omaplague Full GUI & World Map Integration Test ===")
	
	# Load and instantiate Main scene
	var main_scene = load("res://scenes/main.tscn")
	if not main_scene:
		print("FAILED: Could not load main.tscn")
		get_tree().quit(1)
		return
		
	var main = main_scene.instantiate()
	add_child(main)
	
	# Give 1 frame to initialize
	await get_tree().process_frame
	
	var world_map = main.get_node("WorldMap")
	var hud = main.get_node("HUD")
	var setup_screen = main.get_node("SetupScreen")
	var cpanel = main.get_node("CountryPanel")
	var evolution = main.get_node("EvolutionScreen")
	
	print("[1] Verifying World Map & Datasets...")
	assert(DataManager.countries.size() == 176, "Countries count mismatch")
	assert(world_map.country_polys.size() == 176, "Polygon cache size mismatch")
	print("    Successfully verified 176 countries loaded and cached!")
	
	print("[2] Starting Game from Setup Screen...")
	GameState.setup_new_game("OmaVirus", "virus", "normal")
	setup_screen.game_started.emit()
	await get_tree().process_frame
	
	assert(world_map.is_interactive == true, "World map should be interactive after game start")
	print("    Game started successfully. Map is interactive.")
	
	print("[3] Testing Point Hover Across All Continents...")
	var test_targets = ["USA", "GBR", "DEU", "CHN", "JPN", "BRA", "AUS", "EGY", "ZAF", "RUS"]
	for tid in test_targets:
		var cdata = DataManager.get_country(tid)
		var world_pos = Vector2(cdata["map_x"], cdata["map_y"])
		var screen_pos = world_pos * world_map.zoom_level + world_map.position
		world_map._handle_mouse_hover(screen_pos)
		assert(world_map.hovered_country_id == tid, "Hover detection failed for " + tid)
	print("    All continent targets correctly detected on hover!")
	
	print("[4] Releasing Patient Zero in China (CHN)...")
	var chn_data = DataManager.get_country("CHN")
	var chn_screen = Vector2(chn_data["map_x"], chn_data["map_y"]) * world_map.zoom_level + world_map.position
	world_map._handle_left_click(chn_screen)
	assert(GameState.patient_zero_selected == true, "Patient zero should be selected")
	assert(GameState.country_states["CHN"]["is_infected"] == true, "China should be infected")
	print("    Patient zero placed in China! Initial infected: %d" % GameState.country_states["CHN"]["infected"])
	
	print("[5] Testing Ambient and Transit Traffic Generation...")
	var vehicle_count_initial = world_map.vehicles_node.get_child_count()
	# Simulate 10 traffic spawns
	for i in range(10):
		world_map._spawn_ambient_traffic()
	var vehicle_count_after = world_map.vehicles_node.get_child_count()
	print("    Spawned transit vehicles: %d active on map" % vehicle_count_after)
	assert(vehicle_count_after > vehicle_count_initial, "Vehicles should be spawned on map")
	
	print("[6] Simulating 15 Days of Spread and Transit Motion...")
	for day in range(15):
		GameState.advance_day()
		# Process vehicles
		for v in world_map.vehicles_node.get_children():
			v._process(0.1)
		world_map.queue_redraw()
		await get_tree().process_frame
		
	var inf_cnt = 0
	for cid in GameState.country_states:
		if GameState.country_states[cid]["is_infected"]:
			inf_cnt += 1
	print("    Day 15 World Stats: %d infected across %d countries" % [GameState.world_infected, inf_cnt])
	
	print("[7] Testing Country Dossier Panel Selection...")
	# Click on USA to open dossier
	var usa_data = DataManager.get_country("USA")
	var usa_screen = Vector2(usa_data["map_x"], usa_data["map_y"]) * world_map.zoom_level + world_map.position
	world_map._handle_left_click(usa_screen)
	await get_tree().process_frame
	assert(cpanel.visible == true, "Country panel should open on click")
	assert(cpanel.current_country_id == "USA", "Country panel should display USA")
	print("    Country dossier opened for USA! Population: %s" % cpanel.pop_label.text)
	
	# Close panel via ESC simulation
	cpanel.close()
	await get_tree().process_frame
	assert(cpanel.visible == false, "Country panel should close")
	assert(world_map.is_interactive == true, "World map should regain interactivity")
	print("    Country panel closed. Map interactivity restored.")
	
	print("[8] Testing Evolution Screen Layering...")
	hud.open_evolution_requested.emit()
	await get_tree().process_frame
	assert(evolution.visible == true, "Evolution screen should open")
	assert(world_map.is_interactive == false, "World map should be inactive during evolution")
	
	evolution.back_requested.emit()
	await get_tree().process_frame
	assert(evolution.visible == false, "Evolution screen should close")
	assert(world_map.is_interactive == true, "World map should be active again")
	print("    Evolution screen opened and returned to map cleanly.")
	
	print("[9] Testing Continuous Satirical Marquee & Breaking News...")
	hud.breaking_queue.clear()
	hud._return_to_normal_marquee()
	assert(hud.current_news_mode == 0, "Should be in NORMAL_MARQUEE mode")
	assert(hud.active_items.size() == 8, "Should have 8 active marquee items seeded")
	assert(hud.news_badge.text == " 🌐 WIRE ", "Badge should be WIRE")
	
	# Simulate 30 frames of continuous scrolling
	for frame in range(30):
		hud._process(0.016)
	assert(hud.scroll_pos > 0, "Marquee scroll position should advance")
	print("    Continuous marquee scrolling smoothly. Text preview: %s..." % hud.news_label.text.substr(0, 60))
	
	# Test breaking news event emission
	GameState.news_added.emit("First infection of Omaplague detected in Brazil!")
	assert(hud.current_news_mode == 1, "Should transition to BREAKING_ALERT mode on real news")
	assert(hud.news_badge.text == " 🚨 BREAKING ", "Badge should show BREAKING alert")
	assert("BRAZIL" in hud.news_label.text, "Breaking headline should display Brazil event")
	print("    Breaking news interrupt triggered successfully: %s" % hud.news_label.text)
	
	# Simulate frames until breaking news pass finishes
	for frame in range(2000):
		hud._process(0.016)
		if hud.current_news_mode == 0:
			break
	assert(hud.current_news_mode == 0, "Should return to NORMAL_MARQUEE after breaking news")
	assert(hud.news_badge.text == " 🌐 WIRE ", "Badge should return to WIRE")
	print("    Marquee resumed continuous satirical stream after breaking news!")
	
	print("=== ALL INTEGRATION TESTS PASSED SUCCESSFULLY! ===")
	get_tree().quit(0)
