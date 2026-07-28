extends Node

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

# Player stats
var stats_initialized: bool = false
var player_max_health: float = 100.0
var player_current_health: float = 100.0
var player_max_mana: float = 50.0
var player_current_mana: float = 50.0
var player_base_damage: float = 10.0
var player_spirit: float = 5.0
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
var level_exp_requirements: Array[float] = []

func set_enemy(enemy_node_path: NodePath, player_position: Vector2, max_health: float = 100.0, attack_damage: float = 5.0, attack_interval: float = 1.0, exp_reward: float = 30.0, texture: Texture2D = null) -> void:
	current_enemy_path = enemy_node_path
	player_return_position = player_position
	enemy_defeated = false
	encounter_enemy_max_health = max_health
	encounter_enemy_attack_damage = attack_damage
	encounter_enemy_attack_interval = attack_interval
	encounter_enemy_exp_reward = exp_reward
	encounter_enemy_texture = texture

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

func set_leveling_data(max_lvl: int, health_gains: Array[float], mana_gains: Array[float], damage_gains: Array[float], spirit_gains: Array[float], exp_requirements: Array[float]) -> void:
	player_max_level = max_lvl
	level_health_gains = health_gains
	level_mana_gains = mana_gains
	level_damage_gains = damage_gains
	level_spirit_gains = spirit_gains
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
