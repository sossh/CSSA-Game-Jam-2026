@tool
extends "res://assets/models/school_kit/merge_static_meshes.gd"

## Keep the baked wood grain on a separate surface from books and metal.
const LIGHT_WOOD_SHADER := preload("res://assets/models/school_kit/light_furniture_wood.gdshader")
const LIGHT_WOOD_MATERIALS: Array[String] = [
	"Weathered school furniture wood",
	"Furniture worn wood variation",
	"Teacher desk | worn walnut",
	"Teacher desk | drawer interior",
	"Cabinet | aged walnut",
	"Cabinet | dark edge wood",
	"Cabinet | interior timber",
]

func _material_key(material: Material) -> String:
	var key := super._material_key(material)
	var base := material as BaseMaterial3D
	if base and base.albedo_texture and _is_furniture_wood(base):
		return key + "|light_wood"
	return key

func _smooth(material: Material) -> Material:
	var base := material as BaseMaterial3D
	if base and base.albedo_texture and _is_furniture_wood(base):
		var wood := ShaderMaterial.new()
		wood.shader = LIGHT_WOOD_SHADER
		wood.set_shader_parameter("wood_atlas", base.albedo_texture)
		wood.set_shader_parameter("wood_roughness", base.roughness)
		return wood
	return super._smooth(material)

func _is_furniture_wood(material: BaseMaterial3D) -> bool:
	# GLTF material names can include Blender's numeric suffixes.
	for name in LIGHT_WOOD_MATERIALS:
		if material.resource_name.begins_with(name):
			return true
	return false
