extends Node2D
class_name SpellBar

## Auto-arranges Ability children into a grid relative to this node's position.
## Place SpellSlots where you want the grid to start — that position is kept at runtime.
@export_group("Layout")
@export var columns: int = 6
@export var slot_size: Vector2 = Vector2(52, 52)
@export var spacing: Vector2 = Vector2(10, 10)
@export var auto_layout_on_ready: bool = true

func _ready() -> void:
	if auto_layout_on_ready:
		layout_spells()
	# Re-layout if spells are added/removed while editing or at runtime
	child_order_changed.connect(layout_spells)

func layout_spells() -> void:
	var index := 0
	for child in get_children():
		if not (child is Ability):
			continue
		var col := index % columns
		var row := int(index / float(columns))
		# Grid starts at this node's origin (0,0) — first spell stays where SpellSlots is placed
		child.position = Vector2(
			col * (slot_size.x + spacing.x),
			row * (slot_size.y + spacing.y)
		)
		index += 1

func get_abilities() -> Array[Ability]:
	var result: Array[Ability] = []
	for child in get_children():
		if child is Ability:
			result.append(child)
	return result
