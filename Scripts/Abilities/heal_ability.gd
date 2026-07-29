extends Ability
class_name HealAbility

@export var heal_amount: float = 10.0

var player_portrait: Sprite2D
var player_health_bar: ProgressBar
var member: PartyMember

func setup(encounter: Node2D, portrait: Sprite2D, health_bar: ProgressBar, party_member: PartyMember) -> void:
	encounter_scene = encounter
	player_portrait = portrait
	player_health_bar = health_bar
	member = party_member

func has_valid_target() -> bool:
	if not encounter_scene:
		return false
	# Check if player or member is selected
	return encounter_scene.is_portrait_selected or (member and member.is_selected)

func perform_effect() -> void:
	if not encounter_scene:
		return
	
	if encounter_scene.is_portrait_selected:
		# Heal player
		encounter_scene.current_health += heal_amount
		if encounter_scene.current_health > encounter_scene.max_health:
			encounter_scene.current_health = encounter_scene.max_health
		player_health_bar.value = encounter_scene.current_health
		encounter_scene.show_heal_number(heal_amount, player_portrait.global_position)
	elif member and member.is_selected:
		# Heal member
		member.heal(heal_amount)
		encounter_scene.show_heal_number(heal_amount, member.global_position)
	
	encounter_scene.play_heal_sound()

func get_tooltip_text() -> String:
	var lines: PackedStringArray = []
	lines.append(ability_name)
	lines.append("")
	if description.strip_edges() != "":
		lines.append(description.strip_edges())
		lines.append("")
	lines.append("Healing: " + str(int(heal_amount)))
	lines.append("Key: " + _get_key_text())
	lines.append("Mana Cost: " + str(int(mana_cost)))
	if cast_time > 0.0:
		lines.append("Cast Time: " + str(snapped(cast_time, 0.1)) + " sec")
	else:
		lines.append("Cast Time: Instant")
	lines.append("Cooldown: " + str(snapped(cooldown_duration, 0.1)) + " sec")
	lines.append("")
	lines.append("Requires a selected party member.")
	return "\n".join(lines)
