class_name SpriteBatch
extends MultiMeshInstance3D
## Camera-facing quads drawn in one call; rebuilt every frame from a flat instance buffer.

const STRIDE := 20
const WORLD_BOUNDS := AABB(Vector3(-200, -200, -200), Vector3(400, 400, 400))

var _buffer := PackedFloat32Array()
var _count := 0


func _init(shader: Shader) -> void:
	var material := ShaderMaterial.new()
	material.shader = shader
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	multimesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	multimesh.use_custom_data = true
	multimesh.mesh = quad
	material_override = material
	custom_aabb = WORLD_BOUNDS
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func begin() -> void:
	_count = 0


func add(at: Vector3, radius: float, color: Color, custom: Color = Color(0, 0, 0, 0)) -> void:
	if (_count + 1) * STRIDE > _buffer.size():
		_buffer.resize(maxi(64, (_count + 1) * 2) * STRIDE)
	var size := radius * 2.0
	var i := _count * STRIDE
	_buffer[i] = size
	_buffer[i + 1] = 0.0
	_buffer[i + 2] = 0.0
	_buffer[i + 3] = at.x
	_buffer[i + 4] = 0.0
	_buffer[i + 5] = size
	_buffer[i + 6] = 0.0
	_buffer[i + 7] = at.y
	_buffer[i + 8] = 0.0
	_buffer[i + 9] = 0.0
	_buffer[i + 10] = size
	_buffer[i + 11] = at.z
	_buffer[i + 12] = color.r
	_buffer[i + 13] = color.g
	_buffer[i + 14] = color.b
	_buffer[i + 15] = color.a
	_buffer[i + 16] = custom.r
	_buffer[i + 17] = custom.g
	_buffer[i + 18] = custom.b
	_buffer[i + 19] = custom.a
	_count += 1


func commit() -> void:
	var capacity := _buffer.size() / STRIDE
	if multimesh.instance_count != capacity:
		multimesh.instance_count = capacity
	if capacity > 0:
		multimesh.buffer = _buffer
	multimesh.visible_instance_count = _count
