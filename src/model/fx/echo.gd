class_name Echo
extends RefCounted

var source: Callable
var target: Callable
var color: Color
var strength: float
var duration: float
var on_arrive: Callable
var age := 0.0

var progress: float:
	get:
		return minf(age / duration, 1.0)

var position: Vector3:
	get:
		return (source.call() as Vector3).lerp(target.call(), Electron.ease_in_out(progress))


func _init(p_source: Callable, p_target: Callable, p_color: Color, p_strength: float, p_duration: float, p_on_arrive: Callable = Callable()) -> void:
	source = p_source
	target = p_target
	color = p_color
	strength = p_strength
	duration = p_duration
	on_arrive = p_on_arrive


func update(dt: float) -> bool:
	age += dt
	if age < duration:
		return true
	if on_arrive.is_valid():
		on_arrive.call()
	return false
