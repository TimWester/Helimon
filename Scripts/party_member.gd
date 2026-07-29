extends Sprite2D
class_name PartyMember

@export var member_name: String = "Member"
@export var max_health: float = 100.0
@export var attack_damage: float = 8.0
@export var attack_interval: float = 1.5

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
	current_health = max_health
	if health_bar:
		health_bar.max_value = max_health
		health_bar.value = current_health

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
