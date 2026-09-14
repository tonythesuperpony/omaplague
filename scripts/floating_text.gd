extends Node2D

var velocity: Vector2 = Vector2(0, -60)
var life_time: float = 1.0
var elapsed: float = 0.0
var label: Label

func setup(text: String, color: Color, start_pos: Vector2):
	position = start_pos
	label = Label.new()
	label.text = text
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	label.add_theme_constant_override("outline_size", 4)
	add_child(label)

func _process(delta: float):
	elapsed += delta
	position += velocity * delta
	modulate.a = clamp(1.0 - (elapsed / life_time), 0.0, 1.0)
	if elapsed >= life_time:
		queue_free()
