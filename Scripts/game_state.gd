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

# True while an NPC dialogue window is open in the overworld, so the player
# script can pause movement while talking.
var dialogue_active: bool = false

# Persistent overworld state: every enemy defeated and every chest opened so
# far this play session, tracked by their NodePath in the main scene. These
# survive scene reloads (e.g. returning from an encounter) so the world stays
# exactly as the player left it, aside from whatever they just interacted with.
var defeated_enemy_paths: Array[NodePath] = []
var opened_chest_paths: Array[NodePath] = []

# Party roster: which party members the player currently has recruited,
# tracked so the "Party" panel in the overworld can show exactly who/how many
# the player owns. Starts with the one default member that's already
# fighting alongside the player in encounters.
var party_roster: Array[PartyMemberData] = [
	preload("res://Resources/PartyMembers/member1.tres")
]

## Adds a new party member to the roster (e.g. after a future recruitment event).
func add_party_member(data: PartyMemberData) -> void:
	if data and not party_roster.has(data):
		party_roster.append(data)

# Party member equipment: maps a PartyMemberData resource to a Dictionary of
# gear slot name (e.g. "WeaponSlot") -> the Item equipped there. Mirrors
# player_equipped_slots below, but scoped per member so each roster member
# keeps their own independent gear.
var party_equipped_slots: Dictionary = {}  # PartyMemberData -> Dictionary[String, Item]

const PARTY_TRINKET_SLOTS: Array[String] = ["Trinket1Slot", "Trinket2Slot"]

func _get_party_slot_dict(member_data: PartyMemberData) -> Dictionary:
	if not party_equipped_slots.has(member_data):
		party_equipped_slots[member_data] = {}
	return party_equipped_slots[member_data]

## Returns the gear slot node name this item's EquipSlot type belongs in on a
## party member's card (e.g. "WeaponSlot"). For trinkets, finds the first
## free trinket slot (or Trinket1Slot if both are full).
func find_party_slot_for_item(member_data: PartyMemberData, item: Item) -> String:
	if not item:
		return ""
	var slots = _get_party_slot_dict(member_data)
	match item.equip_slot:
		Item.EquipSlot.WEAPON:
			return "WeaponSlot"
		Item.EquipSlot.CAPE:
			return "CapeSlot"
		Item.EquipSlot.TRINKET:
			for trinket_slot in PARTY_TRINKET_SLOTS:
				if not slots.has(trinket_slot):
					return trinket_slot
			return PARTY_TRINKET_SLOTS[0]
		_:
			return ""

## Returns true if the given gear slot node name is a valid destination for
## this item's EquipSlot type on a party member's card (e.g. a trinket may go
## into either trinket slot, but a weapon may only go into WeaponSlot).
func is_valid_party_equip_slot(slot_name: String, item: Item) -> bool:
	if not item or item.equip_slot == Item.EquipSlot.NONE:
		return false
	match item.equip_slot:
		Item.EquipSlot.WEAPON:
			return slot_name == "WeaponSlot"
		Item.EquipSlot.CAPE:
			return slot_name == "CapeSlot"
		Item.EquipSlot.TRINKET:
			return slot_name in PARTY_TRINKET_SLOTS
		_:
			return false

## Returns the item currently equipped in the given slot for the given party member, or null.
func get_party_equipped_item(member_data: PartyMemberData, slot_name: String) -> Item:
	return _get_party_slot_dict(member_data).get(slot_name, null)

## Checks whether an item is currently equipped on any party member (across the whole roster).
func is_party_item_equipped(item: Item) -> bool:
	for member_data in party_equipped_slots.keys():
		if item in party_equipped_slots[member_data].values():
			return true
	return false

## Equip an item into a party member's matching gear slot (auto-picked via find_party_slot_for_item).
func equip_party_item(member_data: PartyMemberData, item: Item, from_slot_index: int = -1) -> void:
	if not item or is_party_item_equipped(item):
		return
	var slot_name = find_party_slot_for_item(member_data, item)
	if slot_name == "":
		return
	equip_party_item_to_slot(member_data, item, slot_name, from_slot_index)

## Equip an item into a specific party gear slot (e.g. a particular trinket
## slot chosen via drag-and-drop). Rejects the equip if the slot doesn't
## match the item's EquipSlot type. If another item already occupies that
## slot, it's unequipped and swapped into the bag slot the new item came from.
func equip_party_item_to_slot(member_data: PartyMemberData, item: Item, slot_name: String, from_slot_index: int = -1) -> void:
	if not item or not is_valid_party_equip_slot(slot_name, item):
		return
	
	var slots = _get_party_slot_dict(member_data)
	var old_item: Item = slots.get(slot_name, null)
	slots[slot_name] = item
	
	# Clear the item's bag slot (set to null) rather than erase, so the
	# other items don't shift position.
	var bag_index = from_slot_index if from_slot_index != -1 else player_inventory.find(item)
	if bag_index != -1 and bag_index < player_inventory.size():
		player_inventory[bag_index] = null
	
	if old_item and old_item != item:
		# Swap the previously equipped item into the exact bag slot the new
		# item vacated, if it's free; otherwise fall back to any free slot.
		if bag_index != -1 and bag_index < player_inventory.size() and player_inventory[bag_index] == null:
			player_inventory[bag_index] = old_item
		else:
			add_item_to_inventory(old_item)

## Unequip whatever item is in the given party gear slot and return it to the bag.
func unequip_party_slot(member_data: PartyMemberData, slot_name: String) -> void:
	var slots = _get_party_slot_dict(member_data)
	if slots.has(slot_name):
		var item: Item = slots[slot_name]
		slots.erase(slot_name)
		if item:
			add_item_to_inventory(item)

## Unequip whatever item is in the given party gear slot directly into a
## specific bag slot (used when dragging an equipped item onto an empty bag slot).
func unequip_party_slot_to_bag_index(member_data: PartyMemberData, slot_name: String, bag_index: int) -> void:
	var slots = _get_party_slot_dict(member_data)
	if not slots.has(slot_name):
		return
	var item: Item = slots[slot_name]
	slots.erase(slot_name)
	if not item:
		return
	if bag_index >= 0 and bag_index < player_inventory.size() and player_inventory[bag_index] == null:
		player_inventory[bag_index] = item
	else:
		add_item_to_inventory(item)

## Swap a party-equipped item with an item sitting in a specific bag slot
## (used when dragging a bag item onto an occupied, compatible party gear slot).
func swap_party_equipment_with_bag_item(member_data: PartyMemberData, slot_name: String, bag_index: int) -> void:
	var slots = _get_party_slot_dict(member_data)
	if not slots.has(slot_name):
		return
	if bag_index < 0 or bag_index >= player_inventory.size():
		return
	var equipped_item: Item = slots[slot_name]
	var bag_item: Item = player_inventory[bag_index]
	if not bag_item or not equipped_item:
		return
	slots[slot_name] = bag_item
	player_inventory[bag_index] = equipped_item

## Move an already-equipped item from one party gear slot to another - either
## on the same member (e.g. Trinket1 -> Trinket2) or between two different
## members. If the destination already holds an item, the two simply swap places.
func move_party_equipped_item(source_member: PartyMemberData, source_slot: String, target_member: PartyMemberData, target_slot: String) -> void:
	if source_member == target_member and source_slot == target_slot:
		return
	var source_slots = _get_party_slot_dict(source_member)
	var source_item: Item = source_slots.get(source_slot, null)
	if not source_item:
		return
	var target_slots = _get_party_slot_dict(target_member)
	var target_item: Item = target_slots.get(target_slot, null)
	
	target_slots[target_slot] = source_item
	if target_item:
		source_slots[source_slot] = target_item
	else:
		source_slots.erase(source_slot)

## Total health/attack-damage bonus this member currently gets from equipped
## PartyEquipment items (Weapon/Cape/Trinket), added on top of their leveled
## base stats. Called from PartyMemberData.get_leveled_max_health/attack_damage.
func get_party_equipment_health_bonus(member_data: PartyMemberData) -> float:
	var total = 0.0
	for item in _get_party_slot_dict(member_data).values():
		if item:
			total += item.health_bonus
	return total

func get_party_equipment_damage_bonus(member_data: PartyMemberData) -> float:
	var total = 0.0
	for item in _get_party_slot_dict(member_data).values():
		if item:
			total += item.damage_bonus
	return total

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
	if not current_enemy_path.is_empty() and not defeated_enemy_paths.has(current_enemy_path):
		defeated_enemy_paths.append(current_enemy_path)

func get_player_position() -> Vector2:
	return player_return_position

## Records that the chest at the given path has been opened, so it stays
## opened even if the overworld scene reloads.
func mark_chest_opened(chest_path: NodePath) -> void:
	if not chest_path.is_empty() and not opened_chest_paths.has(chest_path):
		opened_chest_paths.append(chest_path)

## Returns true if the chest at the given path was already opened this play session.
func is_chest_opened(chest_path: NodePath) -> bool:
	return opened_chest_paths.has(chest_path)

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
	party_equipped_slots.clear()
	defeated_enemy_paths.clear()
	opened_chest_paths.clear()

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

## Returns true if the given gear slot node name is a valid destination for
## this item's EquipSlot type (e.g. a ring may go into any of the 4 ring
## slots, but a necklace may only go into NecklaceSlot). Used to reject
## invalid drag-and-drop drops in the equipment UI.
func is_valid_equip_slot(slot_name: String, item: Item) -> bool:
	if not item or item.equip_slot == Item.EquipSlot.NONE:
		return false
	match item.equip_slot:
		Item.EquipSlot.NECKLACE:
			return slot_name == "NecklaceSlot"
		Item.EquipSlot.HELM:
			return slot_name == "HelmSlot"
		Item.EquipSlot.HAND:
			return slot_name == "HandSlot"
		Item.EquipSlot.SHOULDER:
			return slot_name == "ShoulderSlot"
		Item.EquipSlot.TORSO:
			return slot_name == "TorsoSlot"
		Item.EquipSlot.LEGS:
			return slot_name == "LegsSlot"
		Item.EquipSlot.BOOTS:
			return slot_name == "BootsSlot"
		Item.EquipSlot.RING:
			return slot_name in ["Ring1Slot", "Ring2Slot", "Ring3Slot", "Ring4Slot"]
		_:
			return false

## Equip an item into its matching gear slot (auto-picked via find_slot_for_item),
## applying its stat bonuses and removing it from the bag.
func equip_item(item: Item, from_slot_index: int = -1) -> void:
	if not item or is_item_equipped(item):
		return
	var slot_name = find_slot_for_item(item)
	if slot_name == "":
		return
	equip_item_to_slot(item, slot_name, from_slot_index)

## Equip an item into a specific gear slot (e.g. a particular ring slot chosen
## via drag-and-drop). Rejects the equip if the slot doesn't match the item's
## EquipSlot type. If another item already occupies that slot, it is
## unequipped and swapped into the bag slot the new item came from.
func equip_item_to_slot(item: Item, slot_name: String, from_slot_index: int = -1) -> void:
	if not item or not is_valid_equip_slot(slot_name, item):
		return

	var old_item: Item = player_equipped_slots.get(slot_name, null)

	player_equipped_slots[slot_name] = item
	item.apply_stats()

	# Clear the item's bag slot (set to null) rather than erase, so the
	# other items don't shift position.
	var bag_index = from_slot_index if from_slot_index != -1 else player_inventory.find(item)
	if bag_index != -1 and bag_index < player_inventory.size():
		player_inventory[bag_index] = null

	if old_item and old_item != item:
		old_item.remove_stats()
		# Swap the previously equipped item into the exact bag slot the new
		# item vacated, if it's free; otherwise fall back to any free slot.
		if bag_index != -1 and bag_index < player_inventory.size() and player_inventory[bag_index] == null:
			player_inventory[bag_index] = old_item
		else:
			add_item_to_inventory(old_item)

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

## Unequip whatever item is in the given gear slot directly into a specific
## bag slot (used when dragging an equipped item onto an empty bag slot).
func unequip_slot_to_bag_index(slot_name: String, bag_index: int) -> void:
	if not player_equipped_slots.has(slot_name):
		return
	var item: Item = player_equipped_slots[slot_name]
	player_equipped_slots.erase(slot_name)
	if not item:
		return
	item.remove_stats()
	if bag_index >= 0 and bag_index < player_inventory.size() and player_inventory[bag_index] == null:
		player_inventory[bag_index] = item
	else:
		add_item_to_inventory(item)

## Swap an equipped item with an item sitting in a specific bag slot (used
## when dragging a bag item onto an occupied, compatible gear slot). The
## caller is responsible for checking is_valid_equip_slot first.
func swap_equipment_with_bag_item(slot_name: String, bag_index: int) -> void:
	if not player_equipped_slots.has(slot_name):
		return
	if bag_index < 0 or bag_index >= player_inventory.size():
		return
	var equipped_item: Item = player_equipped_slots[slot_name]
	var bag_item: Item = player_inventory[bag_index]
	if not bag_item or not equipped_item:
		return
	equipped_item.remove_stats()
	bag_item.apply_stats()
	player_equipped_slots[slot_name] = bag_item
	player_inventory[bag_index] = equipped_item

## Move an already-equipped item from one gear slot to another (e.g. Ring1 ->
## Ring3). If the destination already holds an item, the two simply swap
## places. The caller is responsible for checking is_valid_equip_slot first.
func move_equipped_item(source_slot: String, target_slot: String) -> void:
	if source_slot == target_slot:
		return
	var source_item: Item = player_equipped_slots.get(source_slot, null)
	if not source_item:
		return
	var target_item: Item = player_equipped_slots.get(target_slot, null)
	player_equipped_slots[target_slot] = source_item
	if target_item:
		player_equipped_slots[source_slot] = target_item
	else:
		player_equipped_slots.erase(source_slot)

## Check if an item is currently equipped in any gear slot
func is_item_equipped(item: Item) -> bool:
	return item in player_equipped_slots.values()
