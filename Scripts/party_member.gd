extends Sprite2D
class_name PartyMember

## Base identity/stats template for this member, including how much health
## and attack damage they gain per level. This member's level always matches
## the player's current level (no separate exp tracking needed).
@export var data: PartyMemberData

# Effective (level-adjusted) stats, computed in _ready() from data + the
# player's current level. Kept as plain properties so the rest of the
# encounter code can keep reading member.max_health / member.attack_damage /
# etc. exactly as before.
var member_name: String = "Member"
var max_health: float = 100.0
var attack_damage: float = 8.0
var attack_interval: float = 1.5

@onready var portrait_sprite: Sprite2D
@onready var health_bar: ProgressBar
@onready var attack_timer_bar: ProgressBar
@onready var attack_sprite: Sprite2D
@onready var member_area: Area2D

var current_health: float
var time_since_attack: float = 0.0
var is_selected: bool = false
var selected_texture: Texture2D
var unselected_texture: Texture2D

func _ready() -> void:
	_apply_data_and_level()
	current_health = max_health
	if health_bar:
		health_bar.max_value = max_health
		health_bar.value = current_health

## Pulls base identity/stats from the assigned PartyMemberData resource and
## applies bonus health/damage for every level above 1, matching the
## player's current level.
func _apply_data_and_level() -> void:
	if not data:
		return
	member_name = data.member_name
	attack_interval = data.attack_interval
	
	var level = GameState.player_level
	max_health = data.get_leveled_max_health(level)
	attack_damage = data.get_leveled_attack_damage(level)

func take_damage(damage: float) -> void:
	current_health -= damage
	if current_health < 0:
		current_health = 0
	if health_bar:
		health_bar.value = current_health
	
	if current_health <= 0:
		on_defeated()

func heal(amount: float) -> void:
	current_health += amount
	if current_health > max_health:
		current_health = max_health
	if health_bar:
		health_bar.value = current_health

func select() -> void:
	is_selected = true
	if selected_texture:
		texture = selected_texture

func deselect() -> void:
	is_selected = false
	if unselected_texture:
		texture = unselected_texture

func on_defeated() -> void:
	print(member_name + " defeated!")

func is_alive() -> bool:
	return current_health > 0

func can_attack(delta: float) -> bool:
	if not is_alive():
		return false
	time_since_attack += delta
	
	# Update the attack timer bar
	if attack_timer_bar:
		attack_timer_bar.value = time_since_attack
	
	if time_since_attack >= attack_interval:
		time_since_attack = 0.0
		if attack_timer_bar:
			attack_timer_bar.value = 0.0
		return true
	return false

func perform_attack_animation() -> void:
	if not attack_sprite:
		return
		
	attack_sprite.visible = true
	var attack_tween = create_tween()
	attack_tween.tween_property(attack_sprite, "position", Vector2(40, -70), 0.2)
	attack_tween.tween_property(attack_sprite, "position", Vector2(0, -40), 0.2)
	attack_tween.tween_callback(func(): attack_sprite.visible = false)
