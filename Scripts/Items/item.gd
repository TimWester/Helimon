extends Resource
class_name Item

## Base class for all items in the game.
## Items can be stored in inventory, equipped, and provide various effects.

@export_group("Item Properties")
@export var item_name: String = "Unknown Item"
@export_multiline var description: String = "A mysterious item."
@export var icon: Texture2D = preload("res://Sprites/UI/ItemPlaceholder.png")

@export_group("Item Type")
## PARTY_EQUIPMENT items equip onto a party member's card in the Party panel
## (Weapon/Cape/Trinket slots) instead of the player's own Equipment panel.
enum ItemType { EQUIPMENT, CONSUMABLE, QUEST, PARTY_EQUIPMENT }
@export var item_type: ItemType = ItemType.EQUIPMENT

## Which gear slot this item equips into. NONE means it can't be equipped
## in the Equipment panel (e.g. consumables/quest items). WEAPON/CAPE/TRINKET
## are for PARTY_EQUIPMENT items and equip into a party member's card instead.
enum EquipSlot { NONE, NECKLACE, HELM, HAND, SHOULDER, RING, TORSO, LEGS, BOOTS, WEAPON, CAPE, TRINKET }
@export var equip_slot: EquipSlot = EquipSlot.NONE

## Determines the color of this item's name in tooltips, following common
## RPG rarity color conventions.
enum ItemRarity { COMMON, UNCOMMON, RARE, EPIC, LEGENDARY }
@export var rarity: ItemRarity = ItemRarity.COMMON

@export_group("Equipment Stats")
## Spirit bonus when this item is equipped (affects mana regeneration)
@export var spirit_bonus: float = 0.0
## Max health bonus when this item is equipped
@export var health_bonus: float = 0.0
## Max mana bonus when this item is equipped
@export var mana_bonus: float = 0.0
## Damage bonus when this item is equipped
@export var damage_bonus: float = 0.0
## Haste bonus when this item is equipped (reduces cast time and cooldowns)
@export var haste_bonus: float = 0.0

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
	if haste_bonus != 0.0:
		stats.append("+" + str(int(haste_bonus)) + " Haste")
	
	if stats.size() > 0:
		return "\n".join(stats)
	return "No stat bonuses"

## Returns the hex color for this item's rarity, used to tint its name in tooltips.
func get_rarity_color() -> String:
	match rarity:
		ItemRarity.COMMON:
			return "#FFFFFF"  # White
		ItemRarity.UNCOMMON:
			return "#1EFF00"  # Green
		ItemRarity.RARE:
			return "#0070DD"  # Blue
		ItemRarity.EPIC:
			return "#A335EE"  # Purple
		ItemRarity.LEGENDARY:
			return "#FF8000"  # Orange
		_:
			return "#FFFFFF"

## Returns the display name for this item's rarity tier.
func get_rarity_name() -> String:
	match rarity:
		ItemRarity.COMMON:
			return "Common"
		ItemRarity.UNCOMMON:
			return "Uncommon"
		ItemRarity.RARE:
			return "Rare"
		ItemRarity.EPIC:
			return "Epic"
		ItemRarity.LEGENDARY:
			return "Legendary"
		_:
			return "Common"

## Returns the display name for this item's equipment slot type.
func get_slot_name() -> String:
	match equip_slot:
		EquipSlot.NONE:
			return ""
		EquipSlot.NECKLACE:
			return "Necklace"
		EquipSlot.HELM:
			return "Helm"
		EquipSlot.HAND:
			return "Hand"
		EquipSlot.SHOULDER:
			return "Shoulder"
		EquipSlot.RING:
			return "Ring"
		EquipSlot.TORSO:
			return "Torso"
		EquipSlot.LEGS:
			return "Legs"
		EquipSlot.BOOTS:
			return "Boots"
		EquipSlot.WEAPON:
			return "Weapon"
		EquipSlot.CAPE:
			return "Cape"
		EquipSlot.TRINKET:
			return "Trinket"
		_:
			return ""

## Builds the full BBCode tooltip text for this item: name tinted by rarity,
## rarity label (if not Common), description, colored stat bonuses, and an
## equip/unequip hint. Intended for a RichTextLabel with bbcode_enabled = true.
func get_tooltip_text() -> String:
	var lines: PackedStringArray = []
	var rarity_color = get_rarity_color()
	
	# First line: item name on left, slot type on right
	var slot_name = get_slot_name()
	if slot_name != "":
		# Calculate spacing to push slot name to the right (approximate)
		var name_length = item_name.length()
		var spaces_needed = max(1, 30 - name_length)
		var spacing = " ".repeat(spaces_needed)
		lines.append("[color=%s]%s[/color]%s[color=#999999]%s[/color]" % [rarity_color, item_name, spacing, slot_name])
	else:
		lines.append("[color=%s]%s[/color]" % [rarity_color, item_name])
	
	if rarity != ItemRarity.COMMON:
		lines.append("[color=%s]%s[/color]" % [rarity_color, get_rarity_name()])
	lines.append("")
	
	if description and description.strip_edges() != "":
		lines.append("[color=#CCCCCC]%s[/color]" % description.strip_edges())
		lines.append("")
	
	var stats_text = get_stats_text()
	if stats_text == "No stat bonuses":
		lines.append("[color=#888888]%s[/color]" % stats_text)
	else:
		lines.append("[color=#32CD32]%s[/color]" % stats_text)  # Bright green for bonuses
	
	if equip_slot != EquipSlot.NONE:
		lines.append("")
		if item_type == ItemType.PARTY_EQUIPMENT:
			lines.append("[color=#77AAFF]Party Member Equipment[/color]")
		if GameState.is_item_equipped(self) or GameState.is_party_item_equipped(self):
			lines.append("[color=#AAAAAA]Right-click to unequip[/color]")
		else:
			lines.append("[color=#AAAAAA]Right-click to equip[/color]")
	
	return "\n".join(lines)

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
	if haste_bonus != 0.0:
		GameState.player_haste += haste_bonus

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
	if haste_bonus != 0.0:
		GameState.player_haste -= haste_bonus
