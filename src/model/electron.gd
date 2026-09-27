class_name Electron
extends RefCounted

const HOP_TIME := 0.9
const TRAIL := 22

var host: String
var anchor: Callable
var orbit: Orbit
var position: Vector3
var hop: float
var origin: Vector3
var trail := PackedVector3Array()


func _init(p_host: String, p_anchor: Callable, p_orbit: Orbit, p_position: Vector3, p_hop: float = 1.0) -> void:
	host = p_host
	anchor = p_anchor
	orbit = p_orbit
	position = p_position
	origin = p_position
	hop = p_hop


static func ease_in_out(t: float) -> float:
	return t * t * (3.0 - 2.0 * t)


func jump(p_host: String, p_anchor: Callable, p_orbit: Orbit, hold: float = 0.0) -> void:
	host = p_host
	anchor = p_anchor
	orbit = p_orbit
	origin = position
	hop = -hold / HOP_TIME


func update(dt: float) -> void:
	orbit.advance(dt)
	var target: Vector3 = anchor.call() + orbit.current()
	hop = minf(hop + dt / HOP_TIME, 1.0)
	position = origin.lerp(target, ease_in_out(maxf(hop, 0.0)))
	trail.append(position)
	if trail.size() > TRAIL:
		trail.remove_at(0)
