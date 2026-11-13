class_name Interactable
extends StaticBody3D

var interaction_id: String = ""
var prompt: String = "Interact"

func configure(id: String, text: String, size: Vector3) -> void:
	interaction_id = id
	prompt = text
	collision_layer = 16
	collision_mask = 0
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collider.shape = shape
	add_child(collider)

func focus() -> String:
	return "[E] " + prompt

func unfocus() -> void:
	pass
