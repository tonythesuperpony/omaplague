extends Area2D

signal popped(type: String, country_id: String)

var bubble_type: String = "dna" # "infection", "dna", "cure"
var country_id: String = ""
var life_time: float = 14.0
var elapsed: float = 0.0
var base_scale: Vector2 = Vector2(0.7, 0.7)
var initial_pos: Vector2

@onready var sprite: Sprite2D = $Sprite2D
@onready var collision: CollisionShape2D = $CollisionShape2D

func setup(p_type: String, p_pos: Vector2, p_country_id: String):
	bubble_type = p_type
	position = p_pos
	initial_pos = p_pos
	country_id = p_country_id
	scale = Vector2.ZERO
	# Critical: raise above world map and vehicles so clicks land here first
	z_index = 50

func _ready():
	var icon_path = "res://assets/icons/dna_bubble.png"
	if bubble_type == "infection":
		icon_path = "res://assets/icons/infection_bubble.png"
	elif bubble_type == "cure":
		icon_path = "res://assets/icons/cure_bubble.png"
		
	if ResourceLoader.exists(icon_path):
		sprite.texture = load(icon_path)
		
	# Pop-in tween
	var tween = create_tween()
	tween.tween_property(self, "scale", base_scale, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	
	# Connect input signal
	input_event.connect(_on_input_event)
	
	# Ensure the bubble input is handled before anything else beneath it
	set_process_input(true)

func _process(delta: float):
	elapsed += delta
	# Floating bobbing motion
	position = initial_pos + Vector2(0, sin(elapsed * 3.2) * 5.5)
	
	# Gentle pulsing scale
	var pulse = 1.0 + sin(elapsed * 4.8) * 0.07
	scale = base_scale * pulse
	
	# Auto fade out near end of life
	if elapsed >= life_time - 2.0:
		modulate.a = clamp((life_time - elapsed) / 2.0, 0.0, 1.0)
	if elapsed >= life_time:
		queue_free()

func _on_input_event(_viewport, event, _shape_idx):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		get_viewport().set_input_as_handled()
		pop()

func pop():
	GameState.pop_bubble(bubble_type, country_id)
	
	# Create floating feedback text
	var ft_script = load("res://scripts/floating_text.gd")
	var ft = Node2D.new()
	ft.set_script(ft_script)
	
	var txt = "+2 DNA"
	var col = Color(1.0, 0.75, 0.1)
	if bubble_type == "infection":
		txt = "INFECTED!"
		col = Color(1.0, 0.3, 0.3)
	elif bubble_type == "cure":
		txt = "CURE DELAYED!"
		col = Color(0.2, 0.85, 1.0)
		
	ft.setup(txt, col, global_position)
	get_parent().add_child(ft)
	
	# Quick burst pop animation
	var tween = create_tween()
	tween.tween_property(self, "scale", base_scale * 1.6, 0.09)
	tween.parallel().tween_property(self, "modulate:a", 0.0, 0.1)
	tween.tween_callback(queue_free)
