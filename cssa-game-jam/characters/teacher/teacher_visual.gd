extends Node3D
class_name TeacherVisual

@export var animation_player: AnimationPlayer
@export var shotgun: Node3D
@export var coffee_mug: Node3D

func set_gun_visible(is_gun_visible: bool) -> void:
	if shotgun:
		shotgun.visible = is_gun_visible
	elif has_node("GeneralSkeleton/RightHandAttachment/Shotgun"):
		get_node("GeneralSkeleton/RightHandAttachment/Shotgun").visible = is_gun_visible

func set_coffee_mug_visible(is_mug_visible: bool) -> void:
	if coffee_mug:
		coffee_mug.visible = is_mug_visible
	elif has_node("GeneralSkeleton/LeftHandAttachment/CoffeeMug"):
		get_node("GeneralSkeleton/LeftHandAttachment/CoffeeMug").visible = is_mug_visible
