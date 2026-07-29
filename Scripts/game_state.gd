extends Node

## Global stat scaling configuration
## Edit these values in the Inspector (select GameState autoload) to adjust how stats scale/convert
@export_group("Stat Configuration")
## How much mana regeneration per spirit point per second (1.0 = 1 mana/sec per spirit)
@export var spirit_to_mana_multiplier: float = 1.0
## Cast time reduction percentage per haste point (1.0 = 1% faster per haste)
@export var haste_cast_speed_per_point: float = 2.5
## Cooldown reduction percentage per haste point (0.5 = 0.5% faster per haste)
@export var haste_cooldown_per_point: float = 2.5

# Track which enemy node was encountered
var current_enemy_path: NodePath = NodePath()
var enemy_defeated: bool = false
var player_return_position: Vector2 = Vector2.ZERO

# Stats/appearance of the specific overworld enemy that was walked into,
# carried over so the encounter scene can configure itself for that enemy
# instead of being locked to a single hardcoded enemy type.
var encounter_enemy_max_health: float = 100.0
var encounter_enemy_attack_damage: float = 5.0
var encounter_enemy_attack_interval: float = 1.0
var encounter_enemy_exp_reward: float = 30.0
var encounter_enemy_texture: Texture2D = null
var encounter_enemy_attack_sheet: Texture2D = null
var encounter_enemy_attack_frame_count: int = 5
var encounter_enemy_projectile_sheet: Texture2D = null
var encounter_enemy_projectile_frame_count: int = 3
var encounter_enemy_is_aoe: bool = false

# Item reward from the current encounter
var encounter_item_rewards: Array[Item] = []

# Player inventory and equipment
# Fixed-size bag with one entry per visual slot (null = empty slot), so
# items keep their position instead of shifting when others are removed.
const INVENTORY_SIZE: int = 20
var player_inventory: Array[Item] = []
# Maps gear slot name (e.g. "Necklace", "Ring1") to the Item equipped there
var player_equipped_slots: Dictionary = {}

func _ready() -> void:
	_ensure_inventory_capacity()

func _ensure_inventory_capacity() -> void:
	while player_inventory.size() < INVENTORY_SIZE:
		player_inventory.append(null)

# Player stats
var stats_initialized: bool = false
var player_max_health: float = 100.0
var player_current_health: float = 100.0
var player_max_mana: float = 50.0
var player_current_mana: float = 50.0
var player_base_damage: float = 10.0
var player_spirit: float = 5.0
var player_haste: float = 0.0  # Reduces cast time and cooldowns
var player_level: int = 1
var player_current_exp: float = 0.0
var player_exp_to_next_level: float = 100.0

# Leveling configuration (populated from the Player node's Inspector values).
# Each array covers levels 2 through max_level: index 0 = reaching level 2, etc.
var player_max_level: int = 10
var level_health_gains: Array[float] = []
var level_mana_gains: Array[float] = []
var level_damage_gains: Array[float] = []
var level_spirit_gains: Array[float] = []
var level_haste_gains: Array[float] = []
var level_exp_requirements: Array[float] = []

func set_enemy(
	enemy_node_path: NodePath,
	player_position: Vector2,
	max_health: float = 100.0,
	attack_damage: float = 5.0,
	attack_interval: float = 1.0,
	exp_reward: float = 30.0,
	texture: Texture2D = null,
	attack_sheet: Texture2D = null,
	attack_frame_count: int = 5,
	projectile_sheet: Texture2D = null,
	projectile_frame_count: int = 3,
	item_rewards: Array[Item] = [],
	is_aoe: bool = false
) -> void:
	current_enemy_path = enemy_node_path
	player_return_position = player_position
	enemy_defeated = false
	encounter_enemy_max_health = max_health
	encounter_enemy_attack_damage = attack_damage
	encounter_enemy_attack_interval = attack_interval
	encounter_enemy_exp_reward = exp_reward
	encounter_enemy_texture = texture
	encounter_enemy_attack_sheet = attack_sheet
	encounter_enemy_attack_frame_count = attack_frame_count
	encounter_enemy_projectile_sheet = projectile_sheet
	encounter_enemy_projectile_frame_count = projectile_frame_count
	encounter_item_rewards = item_rewards.duplicate()
	encounter_enemy_is_aoe = is_aoe

func mark_enemy_defeated() -> void:
	enemy_defeated = true

func should_remove_enemy() -> bool:
	return enemy_defeated and not current_enemy_path.is_empty()

func get_enemy_path() -> NodePath:
	return current_enemy_path

func get_player_position() -> Vector2:
	return player_return_position

func clear() -> void:
	current_enemy_path = NodePath()
	enemy_defeated = false
	player_return_position = Vector2.ZERO

# Called when returning to the start menu after a defeat so New Game
# re-seeds stats from the Player node's Inspector defaults.
func reset_run() -> void:
	clear()
	stats_initialized = false
	player_level = 1
	player_current_exp = 0.0
	player_exp_to_next_level = 100.0
	encounter_enemy_texture = null
	encounter_enemy_attack_sheet = null
	encounter_enemy_projectile_sheet = null
	encounter_item_rewards.clear()
	player_inventory.clear()
	_ensure_inventory_capacity()
	player_equipped_slots.clear()

func set_leveling_data(max_lvl: int, health_gains: Array[float], mana_gains: Array[float], damage_gains: Array[float], spirit_gains: Array[float], haste_gains: Array[float], exp_requirements: Array[float]) -> void:
	player_max_level = max_lvl
	level_health_gains = health_gains
	level_mana_gains = mana_gains
	level_damage_gains = damage_gains
	level_spirit_gains = spirit_gains
	level_haste_gains = haste_gains
	level_exp_requirements = exp_requirements

# Grants experience to the player, applying as many level ups as the exp
# earns (in case a single reward crosses more than one threshold).
# Returns the number of levels gained.
func add_experience(amount: float) -> int:
	player_current_exp += amount
	var levels_gained = 0
	
	while player_level < player_max_level and player_current_exp >= player_exp_to_next_level and player_exp_to_next_level > 0:
		player_current_exp -= player_exp_to_next_level
		player_level += 1
		levels_gained += 1
		_apply_level_up_stats(player_level)
		_update_exp_requirement()
	
	# Cap exp display once max level is reached
	if player_level >= player_max_level:
		player_current_exp = 0.0
	
	return levels_gained

func _apply_level_up_stats(new_level: int) -> void:
	# Index 0 of the gain arrays corresponds to reaching level 2
	var index = new_level - 2
	
	if index >= 0 and index < level_health_gains.size():
		player_max_health += level_health_gains[index]
	if index >= 0 and index < level_mana_gains.size():
		player_max_mana += level_mana_gains[index]
	if index >= 0 and index < level_damage_gains.size():
		player_base_damage += level_damage_gains[index]
	if index >= 0 and index < level_spirit_gains.size():
		player_spirit += level_spirit_gains[index]
	if index >= 0 and index < level_haste_gains.size():
		player_haste += level_haste_gains[index]
	
	# Fully restore health and mana on level up
	player_current_health = player_max_health
	player_current_mana = player_max_mana

func _update_exp_requirement() -> void:
	# Index 0 of the exp requirement array is the exp needed to go from
	# level 1 to level 2, index (player_level - 1) is the exp needed to go
	# from the current level to the next one.
	var index = player_level - 1
	if index >= 0 and index < level_exp_requirements.size():
		player_exp_to_next_level = level_exp_requirements[index]

## Add an item to the player's inventory, placing it in the first empty slot
func add_item_to_inventory(item: Item) -> void:
	if not item:
		return
	_ensure_inventory_capacity()
	var empty_index = player_inventory.find(null)
	if empty_index != -1:
		player_inventory[empty_index] = item
	else:
		player_inventory.append(item)

## Returns the gear slot name this item's EquipSlot type belongs in.
## These match the actual node names in the EquipmentPanel scene (e.g. "NecklaceSlot").
## For rings, finds the first free Ring slot (or Ring1Slot if all are full).
func find_slot_for_item(item: Item) -> String:
	if not item:
		return ""
	match item.equip_slot:
		Item.EquipSlot.NECKLACE:
			return "NecklaceSlot"
		Item.EquipSlot.HELM:
			return "HelmSlot"
		Item.EquipSlot.HAND:
			return "HandSlot"
		Item.EquipSlot.SHOULDER:
			return "ShoulderSlot"
		Item.EquipSlot.TORSO:
			return "TorsoSlot"
		Item.EquipSlot.LEGS:
			return "LegsSlot"
		Item.EquipSlot.BOOTS:
			return "BootsSlot"
		Item.EquipSlot.RING:
			for ring_slot in ["Ring1Slot", "Ring2Slot", "Ring3Slot", "Ring4Slot"]:
				if not player_equipped_slots.has(ring_slot):
					return ring_slot
			return "Ring1Slot"
		_:
			return ""

## Returns the slot name this item is currently equipped in, or "" if it isn't.
func get_slot_for_item(item: Item) -> String:
	for slot_name in player_equipped_slots.keys():
		if player_equipped_slots[slot_name] == item:
			return slot_name
	return ""

## Returns the item currently equipped in the given slot, or null.
func get_equipped_item(slot_name: String) -> Item:
	return player_equipped_slots.get(slot_name, null)

## Equip an item into its matching gear slot, applying its stat bonuses and
## removing it from the bag. If another item already occupies that slot, it
## is unequipped first and returned to the bag.
func equip_item(item: Item, from_slot_index: int = -1) -> void:
	if not item or is_item_equipped(item):
		return
	var slot_name = find_slot_for_item(item)
	if slot_name == "":
		return

	if player_equipped_slots.has(slot_name):
		var old_item: Item = player_equipped_slots[slot_name]
		if old_item:
			old_item.remove_stats()
			add_item_to_inventory(old_item)

	player_equipped_slots[slot_name] = item
	item.apply_stats()
	# Clear the item's bag slot (set to null) rather than erase, so the
	# other items don't shift position.
	# Use the provided slot index if available (for duplicate items),
	# otherwise search for it
	var bag_index = from_slot_index if from_slot_index != -1 else player_inventory.find(item)
	if bag_index != -1 and bag_index < player_inventory.size():
		player_inventory[bag_index] = null

## Unequip an item, remove its stat bonuses, free up its gear slot, and
## return it to the bag.
func unequip_item(item: Item) -> void:
	var slot_name = get_slot_for_item(item)
	if slot_name != "":
		player_equipped_slots.erase(slot_name)
		item.remove_stats()
		add_item_to_inventory(item)

## Unequip whatever item is in the given gear slot and return it to the bag.
func unequip_slot(slot_name: String) -> void:
	if player_equipped_slots.has(slot_name):
		var item: Item = player_equipped_slots[slot_name]
		player_equipped_slots.erase(slot_name)
		if item:
			item.remove_stats()
			add_item_to_inventory(item)

## Check if an item is currently equipped in any gear slot
func is_item_equipped(item: Item) -> bool:
	return item in player_equipped_slots.values()
