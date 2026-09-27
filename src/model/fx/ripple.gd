class_name Ripple
extends RefCounted

var anchor: Callable
var color: Color
var radius: float
var life: float
var width: float
var age := 0.0

var fade: float:
	get:
		return maxf(1.0 - age / life, 0.0)

var current_radius: float:
	get:
		return radius * (1.0 - pow(1.0 - minf(age / life, 1.0), 3.0))


func _init(p_anchor: Callable, p_color: Color, p_radius: float, p_life: float, p_width: float = 0.05) -> void:
	anchor = p_anchor
	color = p_color
	radius = p_radius
	life = p_life
	width = p_width


func update(dt: float) -> bool:
	age += dt
	return age < life
