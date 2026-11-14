class_name ItemData
extends Resource

@export var id: String = "apple"
@export var display_name: String = "Apple"
@export_multiline var description: String = "Loud, nutritious contraband."
@export var price: int = 5
@export var minimum_grade: int = 1
@export var spawn_weight: float = 1.0
@export var food: float = 0.0
@export var eating_noise: float = 40.0
@export var impact_noise: float = 25.0
@export var mass: float = 0.5
@export_enum("food", "speed", "tomato", "rock", "rocket") var effect: String = "food"
@export var sound: String = "chew"
## The complete editable throwable scene (mesh, collider, and behaviour).
@export var scene: PackedScene
