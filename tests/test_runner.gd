extends Node

func _ready():
	print("--- Starting Omaplague Automated Simulation Test ---")
	
	# Wait a frame for autoloads
	await get_tree().process_frame
	
	# 1. Test Setup Game
	print("[1] Initializing New Game (Pathogen: Virus, Difficulty: Normal)...")
	GameState.setup_new_game("Omega-X", "virus", "normal")
	
	assert(GameState.disease_name == "Omega-X")
	assert(GameState.disease_type == "virus")
	assert(GameState.world_population > 7000000000)
	print("    World Population: %s across %d regions" % [str(GameState.world_population), GameState.country_states.size()])
	
	# 2. Test Patient Zero
	print("[2] Infecting Patient Zero in China (CHN)...")
	var ok = GameState.start_patient_zero("CHN")
	assert(ok == true)
	assert(GameState.country_states["CHN"]["infected"] > 0)
	print("    Patient zero placed. DNA points: %d" % GameState.dna_points)
	
	# 3. Simulate Early Phase
	print("[3] Simulating days 1 to 40...")
	for d in range(40):
		GameState.advance_day()
		
		# Evolve Air 1 and Water 1 when affordable
		if GameState.dna_points >= 10 and not GameState.purchased_upgrades.has("trans_air_1"):
			GameState.buy_upgrade("trans_air_1")
			print("    Evolved: Air 1 on day %d" % GameState.day_count)
		elif GameState.dna_points >= 10 and not GameState.purchased_upgrades.has("trans_water_1"):
			GameState.buy_upgrade("trans_water_1")
			print("    Evolved: Water 1 on day %d" % GameState.day_count)
			
	var infected_countries = 0
	for cid in GameState.country_states:
		if GameState.country_states[cid]["is_infected"]:
			infected_countries += 1
			
	print("    Day 40 Stats:")
	print("    Infected: %d | Dead: %d | Countries Infected: %d/%d | Cure: %d%%" % [
		GameState.world_infected, GameState.world_dead, infected_countries, GameState.country_states.size(), int(GameState.cure_progress * 100.0)
	])
	
	# 4. Simulate Mid/Late Phase with Lethality Upgrades
	print("[4] Evolving symptoms and simulating days 41 to 100...")
	GameState.dna_points += 50 # grant DNA to test lethal symptoms
	GameState.buy_upgrade("symp_cough")
	GameState.buy_upgrade("symp_sneezing")
	GameState.buy_upgrade("symp_fever")
	GameState.buy_upgrade("symp_edema")
	GameState.buy_upgrade("symp_organ_failure")
	print("    Evolved: Organ Failure! Current lethality: %f" % GameState.current_lethality)
	
	for d in range(60):
		GameState.advance_day()
		if GameState.game_over:
			break
			
	var final_infected_cnt = 0
	for cid in GameState.country_states:
		if GameState.country_states[cid]["is_infected"]:
			final_infected_cnt += 1
			
	print("    Day %d Stats:" % GameState.day_count)
	print("    Infected: %d | Dead: %d | Countries Infected: %d/%d | Cure: %d%%" % [
		GameState.world_infected, GameState.world_dead, final_infected_cnt, GameState.country_states.size(), int(GameState.cure_progress * 100.0)
	])
	
	assert(final_infected_cnt > 1)
	assert(GameState.world_dead > 0)
	print("--- Automated Simulation Test PASSED Successfully! ---")
	get_tree().quit()
