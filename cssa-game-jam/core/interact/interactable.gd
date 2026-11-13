class_name Interactable
extends StaticBody3D

@export var interaction_id: String = ""
@export var prompt: String = "Interact"

func focus() -> String:
	return "[E] " + prompt

func unfocus() -> void:
	pass
