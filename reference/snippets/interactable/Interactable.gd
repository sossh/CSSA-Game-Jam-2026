class_name Interactable
extends StaticBody3D

signal interacted(body)

func focus():
	# Logic for highlighting (e.g., showing a mesh outline)
	print("Looking at object")

func unfocus():
	# Logic for removing highlight
	print("Looking away")

func interact(caller:Node):
	# Logic for the actual action
	print("Interacted!")
	interacted.emit(caller)
