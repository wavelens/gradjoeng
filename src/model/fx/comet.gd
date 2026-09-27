class_name Comet
extends RefCounted

const TRAIL := 14

var source: Callable
var target: Callable
var color: Color
var size: float
var duration: float
var bend: float
var on_arrive: Callable
var age := 0.0
var trail := PackedVector3Array()

var progress: float:
	get:
		return minf(age / duration, 1.0)

var position: Vector3:
	get:
		var start: Vector3 = source.call()
		var end: Vector3 = target.call()
		var span := end - start
		var side := span.cross(Vector3.UP)
		var control := (start + end) / 2.0 + side * bend + Vector3.UP * absf(bend) * span.length() * 0.5
		var t := Electron.ease_in_out(progress)
		return start.lerp(control, t).lerp(control.lerp(end, t), t)


func _init(p_source: Callable, p_target: Callable, p_color: Color, p_size: float, p_duration: float, p_bend: float, p_on_arrive: Callable = Callable()) -> void:
	source = p_source
	target = p_target
	color = p_color
	size = p_size
	duration = p_duration
	bend = p_bend
	on_arrive = p_on_arrive


func update(dt: float) -> bool:
	age += dt
	trail.append(position)
	if trail.size() > TRAIL:
		trail.remove_at(0)
	if age < duration:
		return true
	if on_arrive.is_valid():
		on_arrive.call()
	return false
