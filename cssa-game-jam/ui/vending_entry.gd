extends Button

@export var item_id: String = "apple"

var vending_machine_id := "vending"

func refresh(code: int, machine_id: String) -> void:
	vending_machine_id = machine_id
	var data: ItemData = ItemDB.get_item(item_id)
	text = "A%02d • ₿%d • %s" % [code, data.price, data.display_name]
	tooltip_text = data.description

func purchase() -> void:
	Game.request("buy", {"item": item_id, "machine": vending_machine_id})
