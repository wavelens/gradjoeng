class_name RibbonBatch
extends MeshInstance3D
## Camera-facing strips (trails, orbits, links) rebuilt every frame into one surface.

var _eye := Vector3.ZERO
var _vertices := PackedVector3Array()
var _colors := PackedColorArray()
var _uvs := PackedVector2Array()
var _mesh := ArrayMesh.new()


func _init(shader: Shader) -> void:
	var material := ShaderMaterial.new()
	material.shader = shader
	mesh = _mesh
	material_override = material
	custom_aabb = SpriteBatch.WORLD_BOUNDS
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func begin(eye: Vector3) -> void:
	_eye = eye
	_vertices.clear()
	_colors.clear()
	_uvs.clear()


func strip(points: PackedVector3Array, color: Color, width: float, closed: bool = false, taper: bool = false) -> void:
	var count := points.size()
	if count < 2:
		return
	var segments := count if closed else count - 1
	for i in segments:
		var fade_from := float(i) / segments if taper else 1.0
		var fade_to := float(i + 1) / segments if taper else 1.0
		segment(points[i], points[(i + 1) % count], color * Color(1, 1, 1, fade_from), color * Color(1, 1, 1, fade_to), width * maxf(fade_from, 0.2), width * maxf(fade_to, 0.2), Vector2(float(i) / segments, float(i + 1) / segments))


func segment(from: Vector3, to: Vector3, color_from: Color, color_to: Color, width_from: float, width_to: float = -1.0, along: Vector2 = Vector2(0, 1)) -> void:
	var side := (to - from).cross(_eye - from).normalized() * 0.5
	var from_side := side * width_from
	var to_side := side * (width_from if width_to < 0.0 else width_to)
	_vertices.append_array([from - from_side, from + from_side, to + to_side, from - from_side, to + to_side, to - to_side])
	_colors.append_array([color_from, color_from, color_to, color_from, color_to, color_to])
	_uvs.append_array([Vector2(along.x, 0), Vector2(along.x, 1), Vector2(along.y, 1), Vector2(along.x, 0), Vector2(along.y, 1), Vector2(along.y, 0)])


func dashed(from: Vector3, to: Vector3, color: Color, width: float, dash: float, gap: float) -> void:
	var length := from.distance_to(to)
	var start := 0.0
	while start < length:
		segment(from.lerp(to, start / length), from.lerp(to, minf(start + dash, length) / length), color, color, width)
		start += dash + gap


func commit() -> void:
	_mesh.clear_surfaces()
	if _vertices.is_empty():
		return
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = _vertices
	arrays[Mesh.ARRAY_COLOR] = _colors
	arrays[Mesh.ARRAY_TEX_UV] = _uvs
	_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
