@tool
class_name StudentVisual
extends Node3D

@export var tint: Color = Color(0.62, 0.65, 0.8):
	set(value):
		tint = value
		if is_node_ready(): set_color(tint)

func _ready() -> void:
	set_color(tint)

## Geometry and materials live in student_visual.tscn; only the peer tint varies.
func set_color(color: Color) -> void:
	for part: MeshInstance3D in [$Torso, $Head, $LeftArm, $RightArm, $LeftLeg, $RightLeg]:
		var material: StandardMaterial3D = part.material_override
		material.albedo_color = color
		if part == $Head: material.albedo_color = color.lightened(0.25)
		elif part in [$LeftLeg, $RightLeg]: material.albedo_color = color.darkened(0.25)
