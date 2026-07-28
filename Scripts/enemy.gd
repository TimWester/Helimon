extends Area2D

# Each overworld enemy can have its own stats, exp reward, and even its own
# encounter appearance, so different monsters can be placed around the maze
# instead of every encounter being identical.
@export_group("Enemy Stats")
@export var max_health: float = 100.0
@export var attack_damage: float = 5.0
@export var attack_interval: float = 1.0
@export var exp_reward: float = 30.0
## Optional. If left empty, this enemy's own overworld sprite texture is used
## for the enlarged encounter sprite as well.
@export var encounter_sprite: Texture2D

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	if body.name == "Player":
		var sprite_to_use = encounter_sprite
		if not sprite_to_use:
			var own_sprite: Sprite2D = get_node_or_null("Sprite2D")
			if own_sprite:
				sprite_to_use = own_sprite.texture
		
		# Store this enemy's path, the player's position, and this enemy's
		# stats before switching to the (shared) encounter scene
		GameState.set_enemy(get_path(), body.global_position, max_health, attack_damage, attack_interval, exp_reward, sprite_to_use)
		get_tree().call_deferred("change_scene_to_file", "res://Scenes/encounter_scene.tscn")
