class_name Orbit
extends RefCounted

const KEPLER := 1.0

var radius: float
var speed: float
var phase: float
var normal: Vector3
var _u: Vector3
var _v: Vector3


func _init(p_radius: float, inclination: float, node: float, p_speed: float, p_phase: float = 0.0) -> void:
	radius = p_radius
	speed = p_speed
	phase = p_phase
	_u = Vector3(cos(node), 0.0, sin(node))
	normal = Vector3.UP.rotated(_u, inclination)
	_v = normal.cross(_u).normalized()


static func kepler_speed(p_radius: float, direction: int) -> float:
	return direction * KEPLER / sqrt(maxf(p_radius, 0.1))


func advance(dt: float) -> void:
	phase += speed * dt


func frame() -> Basis:
	return Basis(_u * radius, normal, _v * radius)


func offset(angle: float) -> Vector3:
	return (_u * cos(angle) + _v * sin(angle)) * radius


func current() -> Vector3:
	return offset(phase)


func same_path(other: Orbit) -> bool:
	return is_equal_approx(radius, other.radius) and normal.is_equal_approx(other.normal) and is_equal_approx(speed, other.speed)
