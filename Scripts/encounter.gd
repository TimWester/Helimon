extends Node2D

@onready var health_bar = $PartyFrames/Portrait/HealthBar
@onready var mana_bar = $PartyFrames/Portrait/ManaBar
@onready var enemy: EncounterEnemy = $Enemy
@onready var player = $Player
@onready var heal_ability: HealAbility = $PartyFrames/SpellSlots/SoothingHeal
@onready var greater_heal_ability: HealAbility = $PartyFrames/SpellSlots/GreaterHeal
@onready var spell_slots: SpellBar = $PartyFrames/SpellSlots
@onready var portrait = $PartyFrames/Portrait
@onready var portrait_area = $PartyFrames/Portrait/PortraitArea
@onready var member: PartyMember = $PartyFrames/MemberPortrait
@onready var deselect_area = $PartyFrames/DeselectArea
@onready var casting_ui: Control = $PartyFrames/CastingUI
@onready var cast_bar: ProgressBar = $PartyFrames/CastingUI/CastBar
@onready var cast_label: Label = $PartyFrames/CastingUI/CastLabel
@onready var cast_sound: AudioStreamPlayer = $CastSound
@onready var ability_tooltip: PanelContainer = $AbilityTooltipLayer/AbilityTooltip
@onready var ability_tooltip_label: Label = $AbilityTooltipLayer/AbilityTooltip/TooltipLabel
@onready var victory_layer: CanvasLayer = $VictoryLayer
@onready var victory_popup: Panel = $VictoryLayer/VictoryPopup
@onready var victory_label: Label = $VictoryLayer/VictoryPopup/VictoryLabel
@onready var exp_label: Label = $VictoryLayer/VictoryPopup/ExpLabel
@onready var item_label: Label = $VictoryLayer/VictoryPopup/ItemLabel
@onready var level_label: Label = $VictoryLayer/VictoryPopup/LevelLabel
@onready var level_up_label: Label = $VictoryLayer/VictoryPopup/LevelUpLabel
@onready var victory_exp_bar: ProgressBar = $VictoryLayer/VictoryPopup/LevelLabel/ExpBar
@onready var exp_min_label: Label = $VictoryLayer/VictoryPopup/LevelLabel/ExpMinLabel
@onready var exp_max_label: Label = $VictoryLayer/VictoryPopup/LevelLabel/ExpMaxLabel
@onready var continue_button: Button = $VictoryLayer/VictoryPopup/ContinueButton
@onready var defeat_layer: CanvasLayer = $DefeatLayer
@onready var defeat_popup: Panel = $DefeatLayer/DefeatPopup
@onready var defeat_label: Label = $DefeatLayer/DefeatPopup/DefeatLabel
@onready var defeat_continue_button: Button = $DefeatLayer/DefeatPopup/ContinueButton
@onready var out_of_mana_sound: AudioStreamPlayer = $OutOfManaSound
@onready var heal_sound: AudioStreamPlayer = $HealSound
@onready var battle_music: AudioStreamPlayer = $BattleMusic
var current_health = 100.0
var max_health = 100.0
var current_mana = 50.0
var max_mana = 50.0
var is_portrait_selected = false
var time_since_attack = 0.0
var portrait_selected_texture = preload("res://Sprites/UI/Portrait.png")
var portrait_unselected_texture = preload("res://Sprites/UI/PortraitUnselected.png")
var is_battle_over = false
var exp_reward = 30.0
var mana_regen_rate = 5.0
var levels_gained_this_battle = 0
var is_casting_spell = false
var cast_sound_phase = 0.0
var ability_tooltip_visible = false

func _ready() -> void:
	# Make sure the battle track loops even if the import setting hasn't refreshed
	if battle_music and battle_music.stream:
		battle_music.stream.loop = true
	if battle_music and not battle_music.playing:
		battle_music.play()
	
	# Configure this encounter's enemy using the stats/appearance of whichever
	# overworld monster was walked into, so this scene isn't locked to one enemy type
	enemy.configure(
		GameState.encounter_enemy_max_health,
		GameState.encounter_enemy_attack_damage,
		GameState.encounter_enemy_attack_interval,
		GameState.encounter_enemy_texture,
		GameState.encounter_enemy_attack_sheet,
		GameState.encounter_enemy_attack_frame_count,
		GameState.encounter_enemy_projectile_sheet,
		GameState.encounter_enemy_projectile_frame_count
	)
	exp_reward = GameState.encounter_enemy_exp_reward
	
	# Load stats from GameState
	current_health = GameState.player_current_health
	max_health = GameState.player_max_health
	current_mana = GameState.player_current_mana
	max_mana = GameState.player_max_mana
	mana_regen_rate = GameState.player_spirit
	
	health_bar.max_value = max_health
	health_bar.value = current_health
	
	# Setup mana bar
	mana_bar.max_value = max_mana
	mana_bar.value = current_mana
	
	# Setup member
	member.health_bar = member.get_node("MemberHealthBar")
	member.attack_sprite = member.get_node("MemberAttackSprite")
	member.member_area = member.get_node("MemberArea")
	member.selected_texture = preload("res://Sprites/UI/Member1Selected.png")
	member.unselected_texture = preload("res://Sprites/UI/Member1Unselected.png")
	member.deselect()
	
	# Setup every spell currently on the spell bar (works for future spells too)
	for ability in spell_slots.get_abilities():
		if ability is HealAbility:
			ability.setup(self, portrait, health_bar, member)
	
	if casting_ui:
		casting_ui.visible = false
	if cast_bar:
		cast_bar.value = 0.0
	
	# Connect portrait clicks
	portrait_area.input_event.connect(_on_portrait_clicked)
	member.member_area.input_event.connect(_on_member_clicked)
	deselect_area.input_event.connect(_on_deselect_clicked)
	
	# Set initial portrait to unselected
	portrait.texture = portrait_unselected_texture
	
	# Connect victory popup continue button
	continue_button.pressed.connect(_on_continue_pressed)
	
	# Damage is applied when the enemy signals its attack has landed
	# (after Ghast + projectile animations for sheet enemies)
	enemy.attack_hit.connect(_on_enemy_attack_hit)
	
	# Connect defeat popup continue button
	defeat_continue_button.pressed.connect(_on_defeat_continue_pressed)

func _process(delta: float) -> void:
	# Stop all combat when battle is over
	if is_battle_over:
		return
	
	# Keep ability tooltips near the cursor while shown
	if ability_tooltip_visible:
		_position_ability_tooltip()
	
	# Regenerate mana based on the player's spirit stat
	if current_mana < max_mana:
		current_mana = min(current_mana + mana_regen_rate * delta, max_mana)
		mana_bar.value = current_mana
	
	time_since_attack += delta
	
	if time_since_attack >= enemy.attack_interval and not enemy.is_playing_attack:
		enemy_attack()
		time_since_attack = 0.0
	
	enemy.update_attack_timer(time_since_attack)
	
	# Member attack
	if member.can_attack(delta):
		member_attack()

func _on_portrait_clicked(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		is_portrait_selected = true
		member.deselect()
		portrait.texture = portrait_selected_texture
		# Consume the event so deselect area doesn't get it
		_viewport.set_input_as_handled()

func _on_member_clicked(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		member.select()
		is_portrait_selected = false
		portrait.texture = portrait_unselected_texture
		# Consume the event
		_viewport.set_input_as_handled()

func _on_deselect_clicked(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if is_portrait_selected or member.is_selected:
			is_portrait_selected = false
			member.deselect()
			portrait.texture = portrait_unselected_texture

func enemy_attack() -> void:
	# Start the attack visuals; damage is applied later via attack_hit
	# so sheet enemies land damage only after: Ghast anim -> projectile anim
	enemy.perform_attack_animation()

func _on_enemy_attack_hit() -> void:
	if is_battle_over:
		return
	
	# Randomly choose target: 0 = player, 1 = member
	var target = randi() % 2
	
	if target == 0:
		# Attack player
		current_health -= enemy.attack_damage
		if current_health < 0:
			current_health = 0
		health_bar.value = current_health
		show_damage_number(enemy.attack_damage, portrait.global_position)
		
		if current_health <= 0:
			on_player_defeated()
	else:
		# Attack member
		member.take_damage(enemy.attack_damage)
		show_damage_number(enemy.attack_damage, member.global_position)
		
		if not member.is_alive():
			on_party_member_defeated()

func on_player_defeated() -> void:
	is_battle_over = true
	show_defeat_popup("YOU ARE DEAD")

func on_party_member_defeated() -> void:
	is_battle_over = true
	show_defeat_popup("YOUR PARTY MEMBER DIED")

func show_defeat_popup(message: String) -> void:
	defeat_label.text = message
	defeat_layer.visible = true
	defeat_popup.visible = true
	if battle_music and battle_music.playing:
		battle_music.stop()

func _on_defeat_continue_pressed() -> void:
	UISound.play_click()
	GameState.reset_run()
	if not ResourceLoader.exists("res://Scenes/start_menu.tscn"):
		push_error("start_menu.tscn not found at res://Scenes/start_menu.tscn")
		return
	get_tree().call_deferred("change_scene_to_file", "res://Scenes/start_menu.tscn")

func member_attack() -> void:
	# Perform attack animation
	member.perform_attack_animation()
	
	# Deal damage to enemy
	enemy.take_damage(member.attack_damage)
	show_damage_number(member.attack_damage, enemy.position, Color(1.0, 0.95, 0.55, 1))
	
	if enemy.current_health <= 0:
		on_enemy_defeated()

func on_enemy_defeated() -> void:
	print("Enemy defeated!")
	is_battle_over = true
	
	# Hide the enemy
	enemy.visible = false
	
	# Snapshot exp/level before granting the reward so the victory bar
	# can animate from the old value up to the new one
	var exp_before = GameState.player_current_exp
	var level_before = GameState.player_level
	var exp_to_next_before = GameState.player_exp_to_next_level
	
	# Grant experience (this may trigger one or more level ups)
	levels_gained_this_battle = GameState.add_experience(exp_reward)
	
	# Add all item rewards to inventory and equip them automatically
	for item in GameState.encounter_item_rewards:
		if item:
			GameState.add_item_to_inventory(item)
			print("Item added to inventory: ", item.item_name)
	
	# Reflect any stat/health/mana changes from leveling up immediately
	if levels_gained_this_battle > 0:
		max_health = GameState.player_max_health
		current_health = GameState.player_current_health
		max_mana = GameState.player_max_mana
		current_mana = GameState.player_current_mana
		health_bar.max_value = max_health
		health_bar.value = current_health
		mana_bar.max_value = max_mana
		mana_bar.value = current_mana
	
	# Mark enemy as defeated
	GameState.mark_enemy_defeated()
	
	# Show victory popup and animate the exp bar
	show_victory_popup(exp_before, level_before, exp_to_next_before)

func show_victory_popup(exp_before: float, level_before: int, exp_to_next_before: float) -> void:
	# Update exp label with actual reward
	exp_label.text = "+" + str(int(exp_reward)) + " EXP"
	
	# Show item rewards if there are any
	if GameState.encounter_item_rewards.size() > 0:
		var item_names: PackedStringArray = []
		for item in GameState.encounter_item_rewards:
			if item:
				item_names.append(item.item_name)
		
		if item_names.size() == 1:
			item_label.text = item_names[0]
		elif item_names.size() > 1:
			item_label.text =  ", ".join(item_names)
		item_label.visible = true
	else:
		item_label.visible = false
	
	# Start the bar at the pre-reward state
	level_label.text = "LV " + str(level_before)
	victory_exp_bar.max_value = exp_to_next_before
	victory_exp_bar.value = exp_before
	exp_min_label.text = "0"
	exp_max_label.text = str(int(exp_to_next_before))
	
	# Level-up callout appears only after the bar animation reaches a level up
	level_up_label.visible = false
	
	# Hide continue until the exp bar finishes filling
	continue_button.visible = false
	
	# Make sure both the layer and the panel are visible, regardless of
	# which one was toggled off while editing the scene
	victory_layer.visible = true
	victory_popup.visible = true
	
	_animate_exp_gain(exp_before, level_before, exp_to_next_before)

func _animate_exp_gain(exp_before: float, level_before: int, exp_to_next_before: float) -> void:
	var fill_speed = 60.0  # exp points per second
	var remaining_reward = exp_reward
	var current_exp = exp_before
	var current_level = level_before
	var current_to_next = max(exp_to_next_before, 1.0)
	
	# Build animation steps from the pre-reward state through any level-ups
	var steps: Array[Dictionary] = []
	var safety = 0
	while remaining_reward > 0.001 and current_level < GameState.player_max_level and safety < 20:
		safety += 1
		var room_in_bar = max(current_to_next - current_exp, 0.0)
		if room_in_bar <= 0.001:
			# Already full — advance a level if we still have reward left
			current_level += 1
			current_exp = 0.0
			var req_index = current_level - 1
			if req_index >= 0 and req_index < GameState.level_exp_requirements.size():
				current_to_next = max(GameState.level_exp_requirements[req_index], 1.0)
			else:
				current_to_next = max(GameState.player_exp_to_next_level, 1.0)
			continue
		
		var amount_this_segment = min(remaining_reward, room_in_bar)
		var target_value = current_exp + amount_this_segment
		var duration = clampf(amount_this_segment / fill_speed, 0.4, 2.0)
		# Level up if this segment fills the bar (exact fill or overflow)
		var fills_bar = target_value >= current_to_next - 0.001
		var will_level_up = fills_bar and current_level < GameState.player_max_level and (
			remaining_reward > amount_this_segment + 0.001 or current_level < GameState.player_level
		)
		
		var next_level = current_level + 1 if will_level_up else current_level
		var next_to_next = current_to_next
		if will_level_up:
			var req_index = next_level - 1
			if req_index >= 0 and req_index < GameState.level_exp_requirements.size():
				next_to_next = max(GameState.level_exp_requirements[req_index], 1.0)
			else:
				next_to_next = max(GameState.player_exp_to_next_level, 1.0)
		
		steps.append({
			"start": current_exp,
			"end": target_value,
			"duration": duration,
			"level": current_level,
			"to_next": current_to_next,
			"will_level_up": will_level_up,
			"next_level": next_level,
			"next_to_next": next_to_next,
		})
		
		remaining_reward -= amount_this_segment
		if will_level_up:
			current_level = next_level
			current_exp = 0.0
			current_to_next = next_to_next
		else:
			current_exp = target_value
			break
	
	var tween = create_tween()
	tween.set_parallel(false)
	
	if steps.is_empty():
		tween.tween_callback(_on_victory_exp_animation_finished)
		return
	
	for step in steps:
		var start_v: float = float(step["start"])
		var end_v: float = float(step["end"])
		var dur: float = float(step["duration"])
		var lvl: int = int(step["level"])
		var to_next: float = float(step["to_next"])
		
		# Set bar/level for this segment, then animate value directly on the ProgressBar
		tween.tween_callback(_setup_victory_exp_segment.bind(lvl, to_next, start_v))
		tween.tween_property(victory_exp_bar, "value", end_v, dur).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		
		if step["will_level_up"]:
			tween.tween_callback(_on_victory_level_up_step.bind(int(step["next_level"]), float(step["next_to_next"])))
			tween.tween_interval(0.3)
	
	tween.tween_callback(_on_victory_exp_animation_finished)

func _setup_victory_exp_segment(level: int, to_next: float, start_value: float) -> void:
	level_label.text = "LV " + str(level)
	victory_exp_bar.max_value = to_next
	victory_exp_bar.value = start_value
	exp_max_label.text = str(int(to_next))

func _on_victory_level_up_step(level: int, next_bar_max: float) -> void:
	level_label.text = "LV " + str(level)
	level_up_label.visible = true
	if levels_gained_this_battle > 1:
		level_up_label.text = "LEVEL UP! (x" + str(levels_gained_this_battle) + ")"
	else:
		level_up_label.text = "LEVEL UP!"
	victory_exp_bar.max_value = next_bar_max
	victory_exp_bar.value = 0.0
	exp_max_label.text = str(int(next_bar_max))

func _on_victory_exp_animation_finished() -> void:
	level_label.text = "LV " + str(GameState.player_level)
	victory_exp_bar.max_value = max(GameState.player_exp_to_next_level, 1.0)
	victory_exp_bar.value = min(GameState.player_current_exp, victory_exp_bar.max_value)
	exp_max_label.text = str(int(GameState.player_exp_to_next_level))
	if levels_gained_this_battle > 0:
		level_up_label.visible = true
		if levels_gained_this_battle > 1:
			level_up_label.text = "LEVEL UP! (x" + str(levels_gained_this_battle) + ")"
		else:
			level_up_label.text = "LEVEL UP!"
	continue_button.visible = true

func show_damage_number(damage: float, target_position: Vector2, color: Color = Color(1, 0, 0, 1)) -> void:
	var damage_label = Label.new()
	damage_label.text = str(int(damage))
	damage_label.position = target_position + Vector2(-10, -80)
	
	# Style the label
	damage_label.add_theme_font_size_override("font_size", 32)
	damage_label.add_theme_color_override("font_color", color)
	
	add_child(damage_label)
	
	# Animate the damage number
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(damage_label, "position", damage_label.position + Vector2(0, -50), 1.0)
	tween.tween_property(damage_label, "modulate:a", 0.0, 1.0)
	tween.chain().tween_callback(damage_label.queue_free)

func show_heal_number(heal: float, target_position: Vector2) -> void:
	var heal_label = Label.new()
	heal_label.text = "+" + str(int(heal))
	heal_label.position = target_position + Vector2(-10, -80)
	
	# Style the label
	heal_label.add_theme_font_size_override("font_size", 32)
	heal_label.add_theme_color_override("font_color", Color(0, 1, 0, 1))
	
	add_child(heal_label)
	
	# Animate the heal number
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(heal_label, "position", heal_label.position + Vector2(0, -50), 1.0)
	tween.tween_property(heal_label, "modulate:a", 0.0, 1.0)
	tween.chain().tween_callback(heal_label.queue_free)

func show_out_of_mana_message() -> void:
	var mana_msg = Label.new()
	mana_msg.text = "Out of Mana!"
	mana_msg.position = Vector2(-110, -60)
	
	# Style the label
	mana_msg.add_theme_font_size_override("font_size", 36)
	mana_msg.add_theme_color_override("font_color", Color(0.3, 0.6, 1, 1))
	mana_msg.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	mana_msg.add_theme_constant_override("outline_size", 4)
	
	add_child(mana_msg)
	
	# Animate the message: float up and fade out
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(mana_msg, "position", mana_msg.position + Vector2(0, -30), 1.0)
	tween.tween_property(mana_msg, "modulate:a", 0.0, 1.0)
	tween.chain().tween_callback(mana_msg.queue_free)
	
	play_out_of_mana_sound()

func play_out_of_mana_sound() -> void:
	if not out_of_mana_sound:
		return
	
	out_of_mana_sound.play()
	var playback: AudioStreamGeneratorPlayback = out_of_mana_sound.get_stream_playback()
	if not playback:
		return
	
	# Synthesize a short descending "denied" blip
	var sample_rate = 44100.0
	var duration = 0.22
	var frame_count = int(sample_rate * duration)
	
	for i in range(frame_count):
		var t = i / sample_rate
		var progress = t / duration
		var freq = lerp(480.0, 260.0, progress)
		var envelope = 1.0 - progress
		var sample = sin(t * freq * TAU) * 0.35 * envelope
		playback.push_frame(Vector2(sample, sample))

func play_heal_sound() -> void:
	if not heal_sound:
		return
	
	heal_sound.play()
	var playback: AudioStreamGeneratorPlayback = heal_sound.get_stream_playback()
	if not playback:
		return
	
	# Synthesize a warm, holy-sounding swell: a major chord with soft bell-like
	# overtones, gentle vibrato, and a slow attack/release like a choir or organ
	var sample_rate = 44100.0
	var duration = 1.4
	var frame_count = int(sample_rate * duration)
	# Root chord (C5 major) plus an octave-up shimmer overtone
	var frequencies = [523.25, 659.25, 783.99, 1046.5]
	var amplitudes = [0.22, 0.18, 0.16, 0.09]
	var attack_time = 0.2
	var release_time = 0.7
	
	for i in range(frame_count):
		var t = i / sample_rate
		
		var attack = clamp(t / attack_time, 0.0, 1.0)
		var release = clamp((duration - t) / release_time, 0.0, 1.0)
		var envelope = attack * release
		
		var sample = 0.0
		for f in range(frequencies.size()):
			var freq = frequencies[f]
			# Slow vibrato gives it a warm, choir-like shimmer
			var vibrato = sin(t * 4.5 * TAU) * 2.5
			sample += sin(t * (freq + vibrato) * TAU) * amplitudes[f]
		
		playback.push_frame(Vector2(sample, sample) * envelope)

func _on_continue_pressed() -> void:
	UISound.play_click()
	print("Continue pressed - returning to overworld")
	# Save current health and mana back to GameState
	GameState.player_current_health = current_health
	GameState.player_current_mana = current_mana
	# Return to overworld (deferred so it's safe no matter what triggered the click)
	if not ResourceLoader.exists("res://Scenes/main_scene.tscn"):
		push_error("main_scene.tscn not found at res://Scenes/main_scene.tscn")
		return
	get_tree().call_deferred("change_scene_to_file", "res://Scenes/main_scene.tscn")

func use_mana(amount: float) -> bool:
	if current_mana >= amount:
		current_mana -= amount
		if current_mana < 0:
			current_mana = 0
		if mana_bar:
			mana_bar.value = current_mana
		return true
	return false

func has_mana(amount: float) -> bool:
	return current_mana >= amount

func is_any_ability_casting() -> bool:
	return is_casting_spell

func show_ability_tooltip(text: String) -> void:
	if not ability_tooltip or not ability_tooltip_label:
		return
	ability_tooltip_label.text = text
	ability_tooltip.visible = true
	ability_tooltip_visible = true
	# Let the label size the panel, then place it near the cursor
	ability_tooltip.reset_size()
	_position_ability_tooltip()

func hide_ability_tooltip() -> void:
	ability_tooltip_visible = false
	if ability_tooltip:
		ability_tooltip.visible = false

func _position_ability_tooltip() -> void:
	if not ability_tooltip:
		return
	var mouse_pos = get_viewport().get_mouse_position()
	var offset = Vector2(18, 18)
	var tooltip_size = ability_tooltip.get_combined_minimum_size()
	if ability_tooltip.size.x > 1.0:
		tooltip_size = ability_tooltip.size
	
	var viewport_size = get_viewport().get_visible_rect().size
	var pos = mouse_pos + offset
	
	# Keep the tooltip on screen
	if pos.x + tooltip_size.x > viewport_size.x:
		pos.x = mouse_pos.x - tooltip_size.x - 12
	if pos.y + tooltip_size.y > viewport_size.y:
		pos.y = mouse_pos.y - tooltip_size.y - 12
	pos.x = max(pos.x, 4)
	pos.y = max(pos.y, 4)
	
	ability_tooltip.position = pos

func start_casting(spell_name: String, duration: float) -> void:
	is_casting_spell = true
	if cast_label:
		cast_label.text = spell_name
	if cast_bar:
		cast_bar.max_value = 1.0
		cast_bar.value = 0.0
	if casting_ui:
		casting_ui.visible = true
	_start_cast_sound()

func update_casting(progress: float) -> void:
	if cast_bar:
		cast_bar.value = clampf(progress, 0.0, 1.0)
	_fill_cast_sound_buffer()

func stop_casting() -> void:
	is_casting_spell = false
	if casting_ui:
		casting_ui.visible = false
	if cast_bar:
		cast_bar.value = 0.0
	_stop_cast_sound()

func _start_cast_sound() -> void:
	if not cast_sound:
		return
	cast_sound_phase = 0.0
	cast_sound.play()
	_fill_cast_sound_buffer()

func _stop_cast_sound() -> void:
	if cast_sound and cast_sound.playing:
		cast_sound.stop()

func _fill_cast_sound_buffer() -> void:
	# Keep a soft holy hum playing for as long as the cast continues
	if not cast_sound or not cast_sound.playing:
		return
	var playback: AudioStreamGeneratorPlayback = cast_sound.get_stream_playback()
	if not playback:
		return
	
	var sample_rate = 44100.0
	var frames_available = playback.get_frames_available()
	# Keep roughly 0.2s buffered ahead
	var target_frames = int(sample_rate * 0.2)
	var frames_to_push = mini(frames_available, target_frames)
	
	for i in range(frames_to_push):
		cast_sound_phase += 1.0 / sample_rate
		var t = cast_sound_phase
		# Soft sustained chord with slow vibrato — casting chant feel
		var sample = 0.0
		sample += sin(t * 392.0 * TAU) * 0.08
		sample += sin(t * 493.88 * TAU) * 0.07
		sample += sin(t * 587.33 * TAU) * 0.06
		var vibrato = 1.0 + sin(t * 3.0 * TAU) * 0.02
		sample *= vibrato
		playback.push_frame(Vector2(sample, sample))
