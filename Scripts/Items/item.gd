extends Resource
class_name Item

## Base class for all items in the game.
## Items can be stored in inventory, equipped, and provide various effects.

@export_group("Item Properties")
@export var item_name: String = "Unknown Item"
@export_multiline var description: String = "A mysterious item."
@export var icon: Texture2D = preload("res://Sprites/UI/ItemPlaceholder.png")

@export_group("Item Type")
enum ItemType { EQUIPMENT, CONSUMABLE, QUEST }
@export var item_type: ItemType = ItemType.EQUIPMENT

## Which gear slot this item equips into. NONE means it can't be equipped
## in the Equipment panel (e.g. consumables/quest items).
enum EquipSlot { NONE, NECKLACE, HELM, HAND, SHOULDER, RING, TORSO, LEGS, BOOTS }
@export var equip_slot: EquipSlot = EquipSlot.NONE

@export_group("Equipment Stats")
## Spirit bonus when this item is equipped (affects mana regeneration)
@export var spirit_bonus: float = 0.0
## Max health bonus when this item is equipped
@export var health_bonus: float = 0.0
## Max mana bonus when this item is equipped
@export var mana_bonus: float = 0.0
## Damage bonus when this item is equipped
@export var damage_bonus: float = 0.0

## Returns a formatted description of the item's stats for tooltips
func get_stats_text() -> String:
	var stats: PackedStringArray = []
	
	if spirit_bonus != 0.0:
		stats.append("+" + str(int(spirit_bonus)) + " Spirit")
	if health_bonus != 0.0:
		stats.append("+" + str(int(health_bonus)) + " Health")
	if mana_bonus != 0.0:
		stats.append("+" + str(int(mana_bonus)) + " Mana")
	if damage_bonus != 0.0:
		stats.append("+" + str(int(damage_bonus)) + " Damage")
	
	if stats.size() > 0:
		return "\n".join(stats)
	return "No stat bonuses"

## Apply this item's stats to the player (when equipped)
func apply_stats() -> void:
	if spirit_bonus != 0.0:
		GameState.player_spirit += spirit_bonus
	if health_bonus != 0.0:
		GameState.player_max_health += health_bonus
		GameState.player_current_health = min(GameState.player_current_health + health_bonus, GameState.player_max_health)
	if mana_bonus != 0.0:
		GameState.player_max_mana += mana_bonus
		GameState.player_current_mana = min(GameState.player_current_mana + mana_bonus, GameState.player_max_mana)
	if damage_bonus != 0.0:
		GameState.player_base_damage += damage_bonus

## Remove this item's stats from the player (when unequipped)
func remove_stats() -> void:
	if spirit_bonus != 0.0:
		GameState.player_spirit -= spirit_bonus
	if health_bonus != 0.0:
		GameState.player_max_health -= health_bonus
		GameState.player_current_health = min(GameState.player_current_health, GameState.player_max_health)
	if mana_bonus != 0.0:
		GameState.player_max_mana -= mana_bonus
		GameState.player_current_mana = min(GameState.player_current_mana, GameState.player_max_mana)
	if damage_bonus != 0.0:
		GameState.player_base_damage -= damage_bonus
