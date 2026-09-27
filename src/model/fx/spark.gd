class_name Spark
extends RefCounted

const DRAG := 0.12
const GRAVITY := 0.85

var position: Vector3
var velocity: Vector3
var color: Color
var life: float
var size: float
var age := 0.0

var fade: float:
	get:
		return maxf(1.0 - age / life, 0.0)


func _init(p_position: Vector3, p_velocity: Vector3, p_color: Color, p_life: float, p_size: float) -> void:
	position = p_position
	velocity = p_velocity
	color = p_color
	life = p_life
	size = p_size


static func burst(at: Vector3, p_color: Color, count: int, speed: float, p_life: float = 1.2) -> Array:
	var sparks := []
	for i in count:
		var direction := Vector3(randfn(0.0, 1.0), randfn(0.0, 1.0), randfn(0.0, 1.0)).normalized()
		sparks.append(Spark.new(at, direction * randf_range(0.3, 1.0) * speed, p_color, randf_range(0.5, 1.0) * p_life, randf_range(0.05, 0.12)))
	return sparks


func update(dt: float) -> bool:
	age += dt
	velocity = velocity * pow(DRAG, dt) + Vector3.DOWN * GRAVITY * dt
	position += velocity * dt
	return age < life
