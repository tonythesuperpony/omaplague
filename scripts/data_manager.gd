extends Node

var countries: Array = []
var upgrades: Array = []
var disease_types: Array = []
var news_headlines: Array = []

var country_by_id: Dictionary = {}
var country_by_idx: Dictionary = {}
var upgrade_by_id: Dictionary = {}

func _ready():
	_load_countries()
	_load_upgrades()
	_load_disease_types()
	_load_news()

func _load_countries():
	var file = FileAccess.open("res://data/countries.json", FileAccess.READ)
	if file:
		var json_string = file.get_as_text()
		var json = JSON.new()
		var error = json.parse(json_string)
		if error == OK:
			countries = json.get_data()
			for c in countries:
				country_by_id[c["id"]] = c
				if c.has("region_index"):
					country_by_idx[c["region_index"]] = c
			print("Loaded %d countries" % countries.size())
		file.close()

func _load_upgrades():
	var file = FileAccess.open("res://data/upgrades.json", FileAccess.READ)
	if file:
		var json_string = file.get_as_text()
		var json = JSON.new()
		var error = json.parse(json_string)
		if error == OK:
			upgrades = json.get_data()
			for u in upgrades:
				upgrade_by_id[u["id"]] = u
			print("Loaded %d upgrades" % upgrades.size())
		file.close()

func _load_disease_types():
	var file = FileAccess.open("res://data/disease_types.json", FileAccess.READ)
	if file:
		var json = JSON.new()
		if json.parse(file.get_as_text()) == OK:
			disease_types = json.get_data()
			print("Loaded %d disease types" % disease_types.size())
		file.close()

func _load_news():
	var file = FileAccess.open("res://data/news_headlines.json", FileAccess.READ)
	if file:
		var json = JSON.new()
		if json.parse(file.get_as_text()) == OK:
			news_headlines = json.get_data()
			print("Loaded %d news headlines" % news_headlines.size())
		file.close()

func get_country(id: String) -> Dictionary:
	return country_by_id.get(id, {})

func get_country_by_index(idx: int) -> Dictionary:
	return country_by_idx.get(idx, {})

func get_upgrade(id: String) -> Dictionary:
	return upgrade_by_id.get(id, {})

