extends Node

const ROCKET_VENDING := "vending:rocket"
const VENDING_MACHINES := ["vending", "vending:2", ROCKET_VENDING]
const FALCON_STOCK := ["rocket", "rocket_second_stage", "rocket_fairing"]

var items: Dictionary = {}

func _ready() -> void:
	for filename in ResourceLoader.list_directory("res://items/data"):
		if filename.ends_with(".tres"):
			var data: ItemData = load("res://items/data/" + filename)
			items[data.id] = data

func get_item(id: String) -> ItemData:
	return items.get(id, items.get("apple"))

func sells(item_id: String, machine_id: String) -> bool:
	return machine_id in VENDING_MACHINES and items.has(item_id) and (item_id in FALCON_STOCK) == (machine_id == ROCKET_VENDING)

func stock(machine_id: String = "vending") -> Array:
	if machine_id == ROCKET_VENDING:
		return FALCON_STOCK.map(get_item)
	var result := items.values().filter(func(data: ItemData): return sells(data.id, machine_id))
	result.sort_custom(func(a, b): return a.price < b.price if a.price != b.price else a.id < b.id)
	return result

func random_item(grade: int, only_food: bool = false) -> String:
	var candidates: Array = []
	var total := 0.0
	for data: ItemData in items.values():
		if data.minimum_grade <= grade and data.spawn_weight > 0 and (not only_food or data.food > 0):
			total += data.spawn_weight
			candidates.append([total, data.id])
	var roll := randf() * total
	for candidate in candidates:
		if roll <= candidate[0]: return candidate[1]
	return "apple"
