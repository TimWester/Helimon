extends CharacterBody2D

var speed = 200.0

# Player Stats (editable in Inspector)
@export_group("Player Stats")
@export var max_health: float = 100.0
@export var max_mana: float = 50.0
@export var base_damage: float = 10.0
@export var spirit: float = 5.0

# Stat gains and exp requirements for leveling up from level 1 to level 10.
# Each array has 9 entries: index 0 = reaching level 2, index 1 = reaching
# level 3, ... index 8 = reaching level 10. Edit these values in the
# Inspector to tune how much each level up grants.
@export_group("Leveling")
@export var max_level: int = 10
@export var health_gain_per_level: Array[float] = [10.0, 10.0, 15.0, 15.0, 20.0, 20.0, 25.0, 25.0, 30.0]
@export var mana_gain_per_level: Array[float] = [5.0, 5.0, 8.0, 8.0, 10.0, 10.0, 12.0, 12.0, 15.0]
@export var damage_gain_per_level: Array[float] = [2.0, 3.0, 3.0, 4.0, 4.0, 5.0, 5.0, 6.0, 6.0]
@export var spirit_gain_per_level: Array[float] = [1.0, 1.0, 1.0, 2.0, 2.0, 2.0, 3.0, 3.0, 3.0]
@export var exp_required_per_level: Array[float] = [100.0, 150.0, 220.0, 300.0, 400.0, 520.0, 660.0, 820.0, 1000.0]

@onready var animated_sprite = $AnimatedSprite2D
@onready var animation_player = $AnimationPlayer

func _ready() -> void:
	# Only seed GameState with the starting stats once per game session, so
	# levels gained during play aren't wiped out every time the overworld
	# scene reloads (e.g. after returning from an encounter).
	if not GameState.stats_initialized:
		GameState.player_max_health = max_health
		GameState.player_current_health = max_health
		GameState.player_max_mana = max_mana
		GameState.player_current_mana = max_mana
		GameState.player_base_damage = base_damage
		GameState.player_spirit = spirit
		GameState.player_exp_to_next_level = exp_required_per_level[0] if exp_required_per_level.size() > 0 else 100.0
		GameState.stats_initialized = true
	
	# Leveling configuration can be tweaked live in the Inspector, so keep
	# GameState's copy in sync every time the player node loads.
	GameState.set_leveling_data(max_level, health_gain_per_level, mana_gain_per_level, damage_gain_per_level, spirit_gain_per_level, exp_required_per_level)

func _physics_process(_delta: float) -> void:
	var input_velocity = Vector2.ZERO
	
	if Input.is_key_pressed(KEY_W):
		input_velocity.y -= 1
		if animated_sprite.sprite_frames and animated_sprite.sprite_frames.has_animation("walk_up"):
			animated_sprite.play("walk_up")
	elif Input.is_key_pressed(KEY_S):
		input_velocity.y += 1
		if animated_sprite.sprite_frames and animated_sprite.sprite_frames.has_animation("walk_down"):
			animated_sprite.play("walk_down")
	elif Input.is_key_pressed(KEY_A):
		input_velocity.x -= 1
		if animated_sprite.sprite_frames and animated_sprite.sprite_frames.has_animation("walk_left"):
			animated_sprite.play("walk_left")
	elif Input.is_key_pressed(KEY_D):
		input_velocity.x += 1
		if animated_sprite.sprite_frames and animated_sprite.sprite_frames.has_animation("walk_right"):
			animated_sprite.play("walk_right")
	else:
		# Stop animation when not moving
		if animated_sprite.is_playing():
			animated_sprite.stop()
	
	# Apply deadzone to filter controller drift
	if abs(input_velocity.x) < 0.2:
		input_velocity.x = 0
	if abs(input_velocity.y) < 0.2:
		input_velocity.y = 0
	
	if input_velocity.length() > 0:
		input_velocity = input_velocity.normalized()
	
	velocity = input_velocity * speed
	move_and_slide()
