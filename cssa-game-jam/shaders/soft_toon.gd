class_name SoftToon
extends RefCounted

## SoftToon helper utility for cel shading and ink outlines.
## Based on Soft Toon by Francisco Cidade (CC0).

const TOON_SHADER: Shader = preload("res://shaders/soft_toon.gdshader")
const OUTLINE_SHADER: Shader = preload("res://shaders/soft_toon_outline.gdshader")
const SCREEN_SHADER: Shader = preload("res://shaders/soft_toon_screen.gdshader")
const SCREEN_PASS_SCENE: PackedScene = preload("res://effects/toon_screen_pass.tscn")

## Creates a new toon ShaderMaterial with soft_toon_outline.gdshader in its next_pass.
static func make(texture: Texture2D = null, color: Color = Color.WHITE, bands: int = 3, outline_width: float = 2.0) -> ShaderMaterial:
	var outline_mat := ShaderMaterial.new()
	outline_mat.shader = OUTLINE_SHADER
	outline_mat.set_shader_parameter("outline_color", Color(0.1, 0.07, 0.12, 1.0))
	outline_mat.set_shader_parameter("outline_width", outline_width)

	var mat := ShaderMaterial.new()
	mat.shader = TOON_SHADER
	mat.next_pass = outline_mat
	mat.set_shader_parameter("albedo", color)
	if texture != null:
		mat.set_shader_parameter("albedo_texture", texture)
	mat.set_shader_parameter("bands", bands)
	return mat

## Adds a screen-space ink outline & grading quad to the specified Camera3D.
static func add_screen_pass(camera: Camera3D) -> MeshInstance3D:
	if not camera: return null
	for child in camera.get_children():
		if child.name == "ToonScreenPass" or child.is_in_group("toon_screen_pass"):
			return child as MeshInstance3D
	var quad: MeshInstance3D = SCREEN_PASS_SCENE.instantiate()
	quad.name = "ToonScreenPass"
	camera.add_child(quad)
	return quad

## Sets a shader parameter on all toon ShaderMaterials under the given node.
static func set_param(node: Node, param: StringName, value: Variant) -> void:
	if not node: return
	if node is MeshInstance3D:
		var mi: MeshInstance3D = node
		_apply_param(mi.material_override, param, value)
		for i in range(mi.get_surface_override_material_count()):
			_apply_param(mi.get_surface_override_material(i), param, value)
		if mi.mesh:
			for i in range(mi.mesh.get_surface_count()):
				_apply_param(mi.mesh.surface_get_material(i), param, value)
	for child in node.get_children():
		set_param(child, param, value)

static func _apply_param(mat: Material, param: StringName, value: Variant) -> void:
	if not mat: return
	if mat is ShaderMaterial:
		var sm: ShaderMaterial = mat
		if sm.shader == TOON_SHADER or sm.shader == OUTLINE_SHADER or sm.shader == SCREEN_SHADER:
			sm.set_shader_parameter(param, value)
	if mat.next_pass:
		_apply_param(mat.next_pass, param, value)

## Converts lit StandardMaterial3D instances under node to toon ShaderMaterials.
static func convert(node: Node) -> void:
	if not node: return
	if node is MeshInstance3D:
		var mi: MeshInstance3D = node
		if mi.material_override is StandardMaterial3D:
			mi.material_override = _convert_material(mi.material_override as StandardMaterial3D)
		for i in range(mi.get_surface_override_material_count()):
			var s_mat: Material = mi.get_surface_override_material(i)
			if s_mat is StandardMaterial3D:
				mi.set_surface_override_material(i, _convert_material(s_mat as StandardMaterial3D))
	for child in node.get_children():
		convert(child)

static func _convert_material(std: StandardMaterial3D) -> ShaderMaterial:
	if not std or std.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED:
		return null
	var mat := make(std.albedo_texture, std.albedo_color)
	if std.emission_enabled:
		mat.set_shader_parameter("emission", std.emission * std.emission_energy_multiplier)
	if std.vertex_color_use_as_albedo:
		mat.set_shader_parameter("use_vertex_color", true)
	mat.set_shader_parameter("uv_scale", Vector2(std.uv1_scale.x, std.uv1_scale.y))
	mat.set_shader_parameter("uv_offset", Vector2(std.uv1_offset.x, std.uv1_offset.y))
	return mat
