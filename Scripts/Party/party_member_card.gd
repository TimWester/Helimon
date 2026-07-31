extends Control
class_name PartyMemberCard

## Displays one party member's portrait, name, level, health bar, equipment
## slots, and stats inside the overworld "Party" panel. Every visual piece
## is a real child node laid out in Scenes/Party/party_member_card.tscn with
## manual offsets (no containers), so every element can be freely dragged
## around and restyled in the editor, just like PlayerHUD.

@onready var portrait_texture: TextureRect = $Header/PortraitFrame/PortraitTexture
@onready var name_label: Label = $Header/NameLabel
@onready var level_label: Label = $Header/LevelLabel
@onready var health_bar: ProgressBar = $Header/HealthBar
@onready var health_label: Label = $Header/HealthBar/HealthLabel
@onready var damage_label: Label = $DamageLabel

## Fills in this card's nodes from the given party member template, using the
## player's current level to compute the member's leveled stats (party
## members always match the player's level).
func setup(data: PartyMemberData) -> void:
	if not data:
		return

	portrait_texture.texture = data.portrait
	name_label.text = data.member_name
	level_label.text = "Lv. " + str(GameState.player_level)

	var leveled_max_health = data.get_leveled_max_health(GameState.player_level)
	var leveled_attack_damage = data.get_leveled_attack_damage(GameState.player_level)

	health_bar.max_value = leveled_max_health
	health_bar.value = leveled_max_health
	health_label.text = str(int(leveled_max_health)) + " / " + str(int(leveled_max_health))

	damage_label.text = "Attack Damage: " + str(int(leveled_attack_damage))
