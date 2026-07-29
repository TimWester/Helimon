extends Ability
class_name AOEHealAbility

## A heal that hits the player and every party member at once, regardless of
## how many members are currently in the encounter, and without requiring a
## selected target.
@export var heal_amount: float = 15.0

var player_portrait: Sprite2D
var player_health_bar: ProgressBar

func setup(encounter: Node2D, portrait: Sprite2D, health_bar: ProgressBar, _party_member: PartyMember = null) -> void:
	encounter_scene = encounter
	player_portrait = portrait
	player_health_bar = health_bar

func has_valid_target() -> bool:
	# AOE heals always have a valid target — no selection needed
	return true

func perform_effect() -> void:
	if not encounter_scene:
		return
	
	# Heal the player
	encounter_scene.current_health += heal_amount
	if encounter_scene.current_health > encounter_scene.max_health:
		encounter_scene.current_health = encounter_scene.max_health
	if player_health_bar:
		player_health_bar.value = encounter_scene.current_health
	if player_portrait:
		encounter_scene.show_heal_number(heal_amount, player_portrait.global_position)
	
	# Heal every party member currently present, however many there are
	if encounter_scene.has_method("get_all_party_members"):
		for party_member in encounter_scene.get_all_party_members():
			if party_member.is_alive():
				party_member.heal(heal_amount)
				encounter_scene.show_heal_number(heal_amount, party_member.global_position)
	
	encounter_scene.play_heal_sound()

func get_tooltip_text() -> String:
	var lines: PackedStringArray = []
	lines.append("[color=#FFD700]%s[/color]" % ability_name)  # Gold name
	lines.append("")
	if description.strip_edges() != "":
		lines.append(description.strip_edges())
		lines.append("")
	lines.append("[color=#32CD32]Healing: %d[/color] [color=#FFFFFF](all party members)[/color]" % int(heal_amount))  # Green heal, white note
	lines.append("[color=#4DA6FF]Mana Cost: %d[/color]" % int(mana_cost))  # Blue
	
	var modified_cast_time = get_modified_cast_time()
	if cast_time > 0.0:
		if modified_cast_time > 0.0:
			lines.append("[color=#b0b7d2]Cast Time: %.2f sec[/color]" % modified_cast_time)
		else:
			lines.append("[color=#b0b7d2]Cast Time: Instant[/color]")
	else:
		lines.append("[color=#b0b7d2]Cast Time: Instant[/color]")
	
	var modified_cooldown = get_modified_cooldown()
	lines.append("[color=#e0e0e0]Cooldown: %.2f sec[/color]" % modified_cooldown)  # Orange
	
	lines.append("")
	#lines.append("[color=#AAAAAA]Heals the player and every party member. No target selection needed.[/color]")  # Gray note
	return "\n".join(lines)
