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
@export var color: Color = Color.GREEN
@export var size: Vector3 = Vector3(0.22, 0.22, 0.22)
@export_enum("food", "speed", "tomato", "rock", "drug", "cushion", "gun", "rocket", "pop_rocks", "loot_box", "firework", "knife", "nerf") var effect: String = "food"
@export var uses: int = 1
@export var sound: String = "chew"
@export var model: PackedScene
