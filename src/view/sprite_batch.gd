# SPDX-FileCopyrightText: 2026 Wavelens GmbH <info@wavelens.io>
#
# SPDX-License-Identifier: MIT

class_name SpriteBatch
extends MultiMeshInstance3D
## Camera-facing instances (quads, or ribbon strips bent by the shader) drawn in one call; rebuilt every frame from a flat instance buffer.

const STRIDE := 20
const WORLD_BOUNDS := AABB(Vector3(-200, -200, -200), Vector3(400, 400, 400))

var _buffer := PackedFloat32Array()
var _count := 0


func _init(shader: Shader, mesh: Mesh = null) -> void:
	var material := ShaderMaterial.new()
	material.shader = shader
	if mesh == null:
		mesh = QuadMesh.new()
		mesh.size = Vector2.ONE
	multimesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	multimesh.use_custom_data = true
	multimesh.mesh = mesh
	material_override = material
	custom_aabb = WORLD_BOUNDS
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


static func strip(segments: int) -> ArrayMesh:
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	for i in segments + 1:
		uvs.append_array([Vector2(float(i) / segments, 0.0), Vector2(float(i) / segments, 1.0)])
		if i < segments:
			indices.append_array([2 * i, 2 * i + 1, 2 * i + 3, 2 * i, 2 * i + 3, 2 * i + 2])
	var vertices := PackedVector3Array()
	vertices.resize(uvs.size())
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


func begin() -> void:
	_count = 0


func add(at: Vector3, radius: float, color: Color, custom: Color = Color(0, 0, 0, 0)) -> void:
	var i := _reserve()
	var size := radius * 2.0
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
	_tint(i, color, custom)


func add_frame(basis: Basis, origin: Vector3, color: Color, custom: Color = Color(0, 0, 0, 0)) -> void:
	var i := _reserve()
	for row in 3:
		_buffer[i + row * 4] = basis.x[row]
		_buffer[i + row * 4 + 1] = basis.y[row]
		_buffer[i + row * 4 + 2] = basis.z[row]
		_buffer[i + row * 4 + 3] = origin[row]
	_tint(i, color, custom)


func _reserve() -> int:
	if (_count + 1) * STRIDE > _buffer.size():
		_buffer.resize(maxi(64, (_count + 1) * 2) * STRIDE)
	_count += 1
	return (_count - 1) * STRIDE


func _tint(i: int, color: Color, custom: Color) -> void:
	_buffer[i + 12] = color.r
	_buffer[i + 13] = color.g
	_buffer[i + 14] = color.b
	_buffer[i + 15] = color.a
	_buffer[i + 16] = custom.r
	_buffer[i + 17] = custom.g
	_buffer[i + 18] = custom.b
	_buffer[i + 19] = custom.a


func mirror(source: SpriteBatch) -> void:
	_buffer = source._buffer
	_count = source._count
	commit()


func commit() -> void:
	var capacity := _buffer.size() / STRIDE
	if multimesh.instance_count != capacity:
		multimesh.instance_count = capacity
	if capacity > 0:
		multimesh.buffer = _buffer
	multimesh.visible_instance_count = _count
