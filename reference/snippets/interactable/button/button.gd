extends Interactable

## The text displayed when the player focuces on the button
@export var hover_text:String = ""
## The text that displays when the player interacts with the button
@export var interaction_text:String = ""
## If true the key the player has mapped to the "interact" action will be displayed
@export var show_interaction_key:bool = false

@onready var display_layer:CanvasLayer = $CanvasLayer
@onready var text_label:Label = %Label

func focus():
	if show_interaction_key:
		text_label.text = Interactable._get_interaction_key() + " " + hover_text
	else:
		text_label.text = hover_text
	display_layer.visible = true

func unfocus():
	display_layer.visible = false

func interact(caller:Node):
	
	text_label.text = interaction_text
	display_layer.visible = true
