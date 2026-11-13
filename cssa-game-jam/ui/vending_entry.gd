extends Button

@export var item_id: String = "apple"

func refresh(code: int) -> void:
	var data: ItemData = ItemDB.get_item(item_id)
	disabled = data.minimum_grade > Game.grade
	text = "A%02d • ₿%d • %s" % [code, data.price, data.display_name]
	if disabled: text += " [GRADE %d]" % data.minimum_grade
	tooltip_text = data.description

func purchase() -> void:
	Game.request("buy", {"item": item_id})
