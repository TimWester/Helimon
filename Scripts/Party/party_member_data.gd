extends Resource
class_name PartyMemberData

## Defines a party member the player can have travel with them into
## encounters. Recruiting a new member later is just a matter of creating
## another resource of this type and adding it to GameState.party_roster.

@export_group("Identity")
@export var member_name: String = "Party Member"
@export var portrait: Texture2D

@export_group("Stats")
@export var max_health: float = 100.0
@export var attack_damage: float = 8.0
@export var attack_interval: float = 1.5

## Party members don't gain experience of their own - they simply always
## match the player's current level - but each level above 1 still grants
## bonus health and attack damage, configured here just like the Player
## node's own leveling arrays. Index 0 = bonus for reaching level 2, index 1
## = level 3, etc.
@export_group("Leveling")
@export var health_gain_per_level: Array[float] = [8.0, 8.0, 12.0, 12.0, 16.0, 16.0, 20.0, 20.0, 24.0]
@export var damage_gain_per_level: Array[float] = [1.0, 1.0, 2.0, 2.0, 2.0, 3.0, 3.0, 3.0, 4.0]

## Returns this member's max health at the given level (level 1 = base stats),
## including bonuses from any equipped PartyEquipment items (Weapon/Cape/Trinket).
func get_leveled_max_health(level: int) -> float:
	var total = max_health
	for i in range(min(level - 1, health_gain_per_level.size())):
		total += health_gain_per_level[i]
	total += GameState.get_party_equipment_health_bonus(self)
	return total

## Returns this member's attack damage at the given level (level 1 = base
## stats), including bonuses from any equipped PartyEquipment items.
func get_leveled_attack_damage(level: int) -> float:
	var total = attack_damage
	for i in range(min(level - 1, damage_gain_per_level.size())):
		total += damage_gain_per_level[i]
	total += GameState.get_party_equipment_damage_bonus(self)
	return total
