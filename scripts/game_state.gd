extends Node

signal country_infected(country_id: String, country_data: Dictionary)
signal bubble_spawned(bubble_type: String, world_pos: Vector2, country_id: String)
signal dna_changed(new_dna: int, delta: int)
signal stats_updated()
signal news_added(headline: String)
signal plane_dispatched(from_id: String, to_id: String, is_infected: bool)
signal ship_dispatched(from_id: String, to_id: String, is_infected: bool)
signal game_ended(won: bool, reason: String)

# Game configuration
var disease_name: String = "Omaplague"
var disease_type: String = "bacteria"
var difficulty: String = "normal"

# Disease base stats
var base_infectivity: float = 0.04
var base_severity: float = 0.0
var base_lethality: float = 0.0

# Current calculated stats
var current_infectivity: float = 0.04
var current_severity: float = 0.0
var current_lethality: float = 0.0

# Upgrades and modifiers
var purchased_upgrades: Array = []
var active_modifiers: Dictionary = {
	"cold": 1.0,
	"hot": 1.0,
	"arid": 1.0,
	"humid": 1.0,
	"urban": 1.0,
	"rural": 1.0,
	"rich": 1.0,
	"poor": 1.0,
	"air": 1.0,
	"sea": 1.0,
	"land": 1.0,
	"cure_resist": 0.0,
	"cure_setback": 0.0
}

# Economy
var dna_points: int = 10
var total_dna_earned: int = 0

# Simulation time
var day_count: int = 0
var start_year: int = 2026
var start_month: int = 10
var start_day: int = 12
var is_playing: bool = false
var game_over: bool = false
var sim_speed: float = 1.0 # 0=pause, 1=1x, 2=2x, 4=3x

# Global counters
var world_population: int = 0
var world_infected: int = 0
var world_dead: int = 0
var cure_progress: float = 0.0 # 0.0 to 1.0
var cure_active: bool = false

# Milestones tracked for DNA rewards and news
var reached_milestones: Dictionary = {}
var patient_zero_selected: bool = false

# Country runtime states: id -> dict
var country_states: Dictionary = {}

func _enter_tree():
	_apply_omarchy_font()

func _ready():
	pass

func _apply_omarchy_font():
	var font_path = ""
	var out = []
	var exit_code = OS.execute("fc-match", ["monospace:style=Regular", "-f", "%{file}\n"], out, true)
	if exit_code == 0 and not out.is_empty():
		font_path = out[0].strip_edges()
	if font_path == "" or not FileAccess.file_exists(font_path):
		font_path = "/usr/share/fonts/Adwaita/AdwaitaMono-Regular.ttf"
	
	if FileAccess.file_exists(font_path):
		var font = FontFile.new()
		var err = font.load_dynamic_font(font_path)
		if err == OK:
			ThemeDB.get_default_theme().default_font = font
			ThemeDB.fallback_font = font
			print("GameState: loaded Omarchy font: ", font_path)

func setup_new_game(p_name: String, p_type: String, p_diff: String):
	disease_name = p_name if p_name.strip_edges() != "" else "Omaplague"
	disease_type = p_type
	difficulty = p_diff
	
	# Apply disease type baseline
	var dtype_info = {}
	for dt in DataManager.disease_types:
		if dt["id"] == disease_type:
			dtype_info = dt
			break
			
	base_infectivity = dtype_info.get("base_infectivity", 0.04)
	base_severity = dtype_info.get("base_severity", 0.0)
	base_lethality = dtype_info.get("base_lethality", 0.0)
	
	# Reset states
	purchased_upgrades.clear()
	country_states.clear()
	reached_milestones.clear()
	
	world_population = 0
	world_infected = 0
	world_dead = 0
	cure_progress = 0.0
	cure_active = (disease_type == "nanovirus") # Nano-virus starts with active cure!
	dna_points = 12
	total_dna_earned = 12
	day_count = 0
	is_playing = true
	game_over = false
	patient_zero_selected = false
	
	# Difficulty starting bonus/penalty
	if difficulty == "casual":
		dna_points = 18
		base_infectivity *= 1.3
	elif difficulty == "brutal":
		dna_points = 8
		base_infectivity *= 0.8
	elif difficulty == "mega_brutal":
		dna_points = 6
		base_infectivity *= 0.7
		
	# Populate country states
	for country in DataManager.countries:
		var pop = country.get("population", 1000000)
		country_states[country["id"]] = {
			"population": pop,
			"healthy": pop,
			"infected": 0,
			"dead": 0,
			"is_infected": false,
			"airport_open": country.get("has_airport", false),
			"seaport_open": country.get("has_seaport", false),
			"borders_open": true,
			"cure_contribution": 0.0
		}
		world_population += pop
		
	_recalculate_modifiers()
	stats_updated.emit()
	dna_changed.emit(dna_points, 0)
	news_added.emit("Select Patient Zero to release %s into the population." % disease_name)

func start_patient_zero(country_id: String) -> bool:
	if patient_zero_selected:
		return false
	if not country_states.has(country_id):
		return false
		
	var cstate = country_states[country_id]
	var cdata = DataManager.get_country(country_id)
	
	var initial_infected = 1
	cstate["infected"] = initial_infected
	cstate["healthy"] -= initial_infected
	cstate["is_infected"] = true
	patient_zero_selected = true
	world_infected += initial_infected
	
	add_dna(3)
	country_infected.emit(country_id, cdata)
	AudioManager.play_sfx("alert")
	news_added.emit("First infection of %s detected in %s!" % [disease_name, cdata.get("name", country_id)])
	
	# Spawn initial infection bubble
	var pos = Vector2(cdata.get("map_x", 600), cdata.get("map_y", 300))
	bubble_spawned.emit("infection", pos, country_id)
	
	stats_updated.emit()
	return true

func advance_day():
	if not is_playing or game_over or not patient_zero_selected:
		return
		
	day_count += 1
	
	var day_new_infections = 0
	var day_new_deaths = 0
	
	# Difficulty cure multiplier
	var cure_diff_mult = 1.0
	if difficulty == "casual": cure_diff_mult = 0.5
	elif difficulty == "brutal": cure_diff_mult = 1.5
	elif difficulty == "mega_brutal": cure_diff_mult = 2.2
	
	# 1. Process each country
	for cid in country_states:
		var state = country_states[cid]
		var cdata = DataManager.get_country(cid)
		
		if state["infected"] > 0:
			# Calculate country-specific infectivity multiplier
			var country_inf_mult = current_infectivity
			
			# Climate resistance
			var climate = cdata.get("climate", "balanced")
			if climate == "cold":
				country_inf_mult *= active_modifiers["cold"]
			elif climate == "hot":
				country_inf_mult *= active_modifiers["hot"]
				
			# Humidity
			var humidity = cdata.get("humidity", "balanced")
			if humidity == "arid":
				country_inf_mult *= active_modifiers["arid"]
			elif humidity == "humid":
				country_inf_mult *= active_modifiers["humid"]
				
			# Wealth vs Drug resistance
			var wealth = cdata.get("wealth", "balanced")
			if wealth == "rich":
				country_inf_mult *= (0.45 * active_modifiers["rich"])
			elif wealth == "poor":
				country_inf_mult *= (1.2 * active_modifiers["poor"])
				
			# Density
			var density = cdata.get("density", "balanced")
			if density == "urban":
				country_inf_mult *= active_modifiers["urban"]
			elif density == "rural":
				country_inf_mult *= active_modifiers["rural"]
				
			# Border closures check
			if not state["borders_open"]:
				country_inf_mult *= 0.5
				
			# Compute daily new infections with logistic curve
			var healthy_ratio = float(state["healthy"]) / float(state["population"])
			var inf_count = state["infected"]
			
			var effective_spread = country_inf_mult * 0.4
			var new_inf = int(inf_count * effective_spread * healthy_ratio)
			
			# Ensure at least minimal spread if healthy population exists
			if new_inf == 0 and state["healthy"] > 0 and randf() < country_inf_mult * 2.0:
				new_inf = randi_range(1, 3)
				
			if new_inf > state["healthy"]:
				new_inf = state["healthy"]
				
			state["infected"] += new_inf
			state["healthy"] -= new_inf
			day_new_infections += new_inf
			
			# Calculate deaths
			if current_lethality > 0:
				var death_rate = current_lethality * 0.08
				var new_deaths = int(state["infected"] * death_rate)
				if new_deaths == 0 and randf() < death_rate * 3.0:
					new_deaths = 1
				if new_deaths > state["infected"]:
					new_deaths = state["infected"]
					
				state["dead"] += new_deaths
				state["infected"] -= new_deaths
				day_new_deaths += new_deaths
				
			# Check country border & port closures
			var inf_ratio = float(state["infected"] + state["dead"]) / float(state["population"])
			if inf_ratio > 0.08 or current_severity > 0.15:
				if state["airport_open"] and randf() < 0.04:
					state["airport_open"] = false
					news_added.emit("%s has closed its airports to contain infection." % cdata.get("name", cid))
				if state["seaport_open"] and randf() < 0.03:
					state["seaport_open"] = false
					news_added.emit("%s has closed all seaports." % cdata.get("name", cid))
				if state["borders_open"] and (inf_ratio > 0.18 or current_severity > 0.25) and randf() < 0.05:
					state["borders_open"] = false
					news_added.emit("%s has sealed all land borders!" % cdata.get("name", cid))
					
			# Cross-border spread attempts
			var connections = cdata.get("connections", {})
			# Land spread
			if state["borders_open"] and inf_ratio > 0.005:
				var land_neighbors = connections.get("land", [])
				for target_id in land_neighbors:
					if country_states.has(target_id) and not country_states[target_id]["is_infected"]:
						var land_chance = 0.04 * active_modifiers["land"] * current_infectivity * 5.0
						if randf() < land_chance:
							infect_country(target_id, "land")
							
			# Air spread (dispatch plane!)
			if state["airport_open"] and inf_ratio > 0.002:
				var air_routes = connections.get("air", [])
				if air_routes.size() > 0 and randf() < (0.03 * active_modifiers["air"]):
					var target_id = air_routes[randi() % air_routes.size()]
					var target_open = country_states.has(target_id) and country_states[target_id]["airport_open"]
					var is_inf_flight = randf() < (inf_ratio * 4.0 + 0.1)
					plane_dispatched.emit(cid, target_id, is_inf_flight)
					if target_open and is_inf_flight and not country_states[target_id]["is_infected"]:
						# Delayed infection upon flight landing (done after short delay or probability)
						if randf() < 0.35:
							infect_country(target_id, "air")
							
			# Sea spread (dispatch ship!)
			if state["seaport_open"] and inf_ratio > 0.003:
				var sea_routes = connections.get("sea", [])
				if sea_routes.size() > 0 and randf() < (0.02 * active_modifiers["sea"]):
					var target_id = sea_routes[randi() % sea_routes.size()]
					var target_open = country_states.has(target_id) and country_states[target_id]["seaport_open"]
					var is_inf_ship = randf() < (inf_ratio * 3.0 + 0.15)
					ship_dispatched.emit(cid, target_id, is_inf_ship)
					if target_open and is_inf_ship and not country_states[target_id]["is_infected"]:
						if randf() < 0.4:
							infect_country(target_id, "sea")
							
			# Periodic orange DNA bubble spawn
			if randf() < 0.008:
				var pos = Vector2(cdata.get("map_x", 600), cdata.get("map_y", 300))
				# Offset slightly
				pos += Vector2(randf_range(-25, 25), randf_range(-25, 25))
				bubble_spawned.emit("dna", pos, cid)

	# 2. Update totals
	world_infected += day_new_infections - day_new_deaths
	world_dead += day_new_deaths
	if world_infected < 0: world_infected = 0
	
	# 3. Cure progression
	if not cure_active:
		# Check if cure should activate
		if current_severity > 0.05 or world_dead > 500 or world_infected > 500000:
			cure_active = true
			AudioManager.play_sfx("cure_warn")
			news_added.emit("WHO puts %s on global threat watchlist. Research initiated!" % disease_name)
			
	if cure_active and not game_over:
		# Research speed scales with global severity and rich countries
		var research_power = 0.0
		for cid in country_states:
			var s = country_states[cid]
			var cd = DataManager.get_country(cid)
			var health_ratio = float(s["healthy"]) / float(s["population"])
			if health_ratio > 0.1: # Only countries with surviving infrastructure contribute
				var wealth_factor = 1.0
				if cd.get("wealth") == "rich": wealth_factor = 3.0
				elif cd.get("wealth") == "balanced": wealth_factor = 1.5
				research_power += wealth_factor * health_ratio
				
		var base_daily_cure = 0.0003 * cure_diff_mult
		# Severity accelerates cure research
		base_daily_cure *= (1.0 + current_severity * 6.0)
		# Genetic hardening reduces cure speed
		base_daily_cure *= (1.0 - active_modifiers["cure_resist"])
		
		var delta_cure = base_daily_cure * (research_power / max(1.0, float(country_states.size())))
		cure_progress += delta_cure
		
		# Cure milestones & Blue Bubble spawning
		if randf() < 0.02 and cure_progress > 0.15:
			# Pick a leading research country
			var candidates = ["USA", "GBR", "DEU", "FRA", "JPN", "CHN"]
			var host = candidates[randi() % candidates.size()]
			var cd = DataManager.get_country(host)
			var pos = Vector2(cd.get("map_x", 600), cd.get("map_y", 300))
			bubble_spawned.emit("cure", pos, host)
			
		if cure_progress >= 0.25 and not reached_milestones.has("cure_25"):
			reached_milestones["cure_25"] = true
			news_added.emit("Cure research reaches 25%. Global teams synthesize antibody trials.")
		elif cure_progress >= 0.50 and not reached_milestones.has("cure_50"):
			reached_milestones["cure_50"] = true
			news_added.emit("Cure research reaches 50%! Human clinical testing underway.")
		elif cure_progress >= 0.75 and not reached_milestones.has("cure_75"):
			reached_milestones["cure_75"] = true
			news_added.emit("Cure research reaches 75%! Mass manufacture preparation begins.")
		elif cure_progress >= 1.0:
			cure_progress = 1.0
			trigger_defeat("Humanity successfully manufactured and deployed the cure.")
			
	# 4. Spontaneous Virus mutation
	if disease_type == "virus" and randf() < 0.015:
		_trigger_random_free_mutation()
		
	# 5. Check Milestones & Win/Loss Conditions
	_check_milestones()
	_check_game_over_conditions()
	
	stats_updated.emit()

func infect_country(target_id: String, vector: String) -> bool:
	if not country_states.has(target_id):
		return false
	var state = country_states[target_id]
	if state["is_infected"]:
		return false
		
	state["is_infected"] = true
	state["infected"] = randi_range(2, 10)
	state["healthy"] -= state["infected"]
	world_infected += state["infected"]
	
	var cdata = DataManager.get_country(target_id)
	country_infected.emit(target_id, cdata)
	AudioManager.play_sfx("alert")
	
	var bonus_dna = 2
	add_dna(bonus_dna)
	
	# Spawn red infection bubble
	var pos = Vector2(cdata.get("map_x", 600), cdata.get("map_y", 300))
	bubble_spawned.emit("infection", pos, target_id)
	
	news_added.emit("%s has spread to %s via %s transit!" % [disease_name, cdata.get("name", target_id), vector])
	return true

func spore_burst():
	# Special Fungus ability: infect an uninfected country at random
	var uninfected = []
	for cid in country_states:
		if not country_states[cid]["is_infected"]:
			uninfected.append(cid)
	if uninfected.size() > 0:
		var target = uninfected[randi() % uninfected.size()]
		infect_country(target, "fungal spore burst")
		news_added.emit("Fungal spores burst into jet stream, infecting %s!" % DataManager.get_country(target).get("name", target))

func add_dna(amount: int):
	dna_points += amount
	total_dna_earned += amount
	dna_changed.emit(dna_points, amount)

func spend_dna(amount: int) -> bool:
	if dna_points >= amount:
		dna_points -= amount
		dna_changed.emit(dna_points, -amount)
		return true
	return false

func buy_upgrade(upgrade_id: String) -> bool:
	if purchased_upgrades.has(upgrade_id):
		return false
	var udata = DataManager.get_upgrade(upgrade_id)
	if udata.is_empty():
		return false
		
	# Check prerequisites
	var prereqs = udata.get("prereq", [])
	for p in prereqs:
		if not purchased_upgrades.has(p):
			return false
			
	var cost = udata.get("cost", 10)
	if spend_dna(cost):
		purchased_upgrades.append(upgrade_id)
		_recalculate_modifiers()
		AudioManager.play_sfx("evolve")
		
		# Check if upgrade has immediate effect
		var mods = udata.get("modifiers", {})
		if mods.has("cure_setback"):
			var setback = mods["cure_setback"]
			cure_progress = max(0.0, cure_progress - setback)
			news_added.emit("Genetic Reshuffle reshuffles DNA: Global cure set back by %d%%!" % int(setback * 100))
			
		stats_updated.emit()
		return true
	return false

func devolve_upgrade(upgrade_id: String) -> bool:
	if not purchased_upgrades.has(upgrade_id):
		return false
		
	# Check if another purchased upgrade depends on this
	for u in DataManager.upgrades:
		if purchased_upgrades.has(u["id"]):
			if upgrade_id in u.get("prereq", []):
				return false # Cannot devolve prerequisite
				
	var udata = DataManager.get_upgrade(upgrade_id)
	var devolve_cost = 0
	for dt in DataManager.disease_types:
		if dt["id"] == disease_type:
			devolve_cost = dt.get("devolve_cost", 0)
			break
			
	if devolve_cost > 0:
		if dna_points < devolve_cost:
			return false
		spend_dna(devolve_cost)
	else:
		# Refund 2 DNA
		add_dna(2)
		
	purchased_upgrades.erase(upgrade_id)
	_recalculate_modifiers()
	AudioManager.play_sfx("click")
	stats_updated.emit()
	return true

func _recalculate_modifiers():
	current_infectivity = base_infectivity
	current_severity = base_severity
	current_lethality = base_lethality
	
	# Reset active modifiers
	active_modifiers = {
		"cold": 1.0,
		"hot": 1.0,
		"arid": 1.0,
		"humid": 1.0,
		"urban": 1.0,
		"rural": 1.0,
		"rich": 1.0,
		"poor": 1.0,
		"air": 1.0,
		"sea": 1.0,
		"land": 1.0,
		"cure_resist": 0.0,
		"cure_setback": 0.0
	}
	
	for uid in purchased_upgrades:
		var u = DataManager.get_upgrade(uid)
		current_infectivity += u.get("infectivity", 0.0)
		current_severity += u.get("severity", 0.0)
		current_lethality += u.get("lethality", 0.0)
		
		var mods = u.get("modifiers", {})
		for mkey in mods:
			if active_modifiers.has(mkey):
				if mkey in ["cure_resist", "cure_setback"]:
					active_modifiers[mkey] += mods[mkey]
				else:
					active_modifiers[mkey] *= mods[mkey]

func pop_bubble(type: String, cid: String):
	if type == "infection":
		AudioManager.play_sfx("alert")
		# Red bubbles popped already grant initial DNA
	elif type == "dna":
		AudioManager.play_sfx("dna_pop")
		add_dna(randi_range(1, 2))
	elif type == "cure":
		AudioManager.play_sfx("pop")
		cure_progress = max(0.0, cure_progress - 0.015)

func _trigger_random_free_mutation():
	var unevolved_symptoms = []
	for u in DataManager.upgrades:
		if u.get("category") == "symptom" and not purchased_upgrades.has(u["id"]):
			# Check prereqs
			var can_mutate = true
			for p in u.get("prereq", []):
				if not purchased_upgrades.has(p):
					can_mutate = false
					break
			if can_mutate:
				unevolved_symptoms.append(u)
				
	if unevolved_symptoms.size() > 0:
		var picked = unevolved_symptoms[randi() % unevolved_symptoms.size()]
		purchased_upgrades.append(picked["id"])
		_recalculate_modifiers()
		AudioManager.play_sfx("evolve")
		news_added.emit("Viral Mutation: %s spontaneously mutated %s for free!" % [disease_name, picked["name"]])

func _check_milestones():
	var total_affected = world_infected + world_dead
	if total_affected >= 1000 and not reached_milestones.has("inf_1k"):
		reached_milestones["inf_1k"] = true
		add_dna(2)
		news_added.emit("%s surpasses 1,000 recorded infections." % disease_name)
	elif total_affected >= 100000 and not reached_milestones.has("inf_100k"):
		reached_milestones["inf_100k"] = true
		add_dna(3)
		news_added.emit("%s has infected over 100,000 people globally." % disease_name)
	elif total_affected >= 10000000 and not reached_milestones.has("inf_10m"):
		reached_milestones["inf_10m"] = true
		add_dna(4)
		news_added.emit("Pandemic Alert: %s has infected over 10 Million people!" % disease_name)
	elif total_affected >= 500000000 and not reached_milestones.has("inf_500m"):
		reached_milestones["inf_500m"] = true
		add_dna(5)
		news_added.emit("Global Catastrophe: Over 500 Million people infected.")
	elif total_affected >= 3000000000 and not reached_milestones.has("inf_3b"):
		reached_milestones["inf_3b"] = true
		add_dna(6)
		news_added.emit("Half of Earth's population has contracted %s." % disease_name)
		
	if world_dead >= 1 and not reached_milestones.has("first_death"):
		reached_milestones["first_death"] = true
		news_added.emit("First fatality recorded from %s complications." % disease_name)
	elif world_dead >= 1000000 and not reached_milestones.has("death_1m"):
		reached_milestones["death_1m"] = true
		news_added.emit("Global death toll from %s passes 1 Million." % disease_name)

func _check_game_over_conditions():
	if world_dead >= world_population:
		trigger_victory()
	elif world_infected == 0 and world_dead > 0 and day_count > 10:
		trigger_defeat("The pathogen has died out with no remaining hosts.")

func trigger_victory():
	if game_over: return
	game_over = true
	is_playing = false
	AudioManager.play_sfx("victory")
	news_added.emit("TOTAL EXTINCTION: Humanity has been wiped out by %s!" % disease_name)
	game_ended.emit(true, "%s has successfully eradicated all human life on Earth." % disease_name)

func trigger_defeat(reason: String):
	if game_over: return
	game_over = true
	is_playing = false
	AudioManager.play_sfx("game_over")
	news_added.emit("DEFEAT: %s" % reason)
	game_ended.emit(false, reason)

func get_formatted_date() -> String:
	var months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
	var d = start_day + day_count
	var m = start_month
	var y = start_year
	
	# Simple calendar progression
	while d > 30:
		d -= 30
		m += 1
		if m > 12:
			m = 1
			y += 1
	return "%02d %s %d" % [d, months[m - 1], y]

func get_date_string() -> String:
	return get_formatted_date()
