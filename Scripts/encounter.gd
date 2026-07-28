extends Node2D

@onready var health_bar = $PartyFrames/Portrait/HealthBar
@onready var mana_bar = $PartyFrames/Portrait/ManaBar
@onready var enemy: EncounterEnemy = $Enemy
@onready var player = $Player
@onready var heal_ability: HealAbility = $PartyFrames/SoothingHeal
@onready var portrait = $PartyFrames/Portrait
@onready var portrait_area = $PartyFrames/Portrait/PortraitArea
@onready var member: PartyMember = $PartyFrames/MemberPortrait
@onready var deselect_area = $PartyFrames/DeselectArea
@onready var victory_layer: CanvasLayer = $VictoryLayer
@onready var victory_popup: Panel = $VictoryLayer/VictoryPopup
@onready var victory_label: Label = $VictoryLayer/VictoryPopup/VictoryLabel
@onready var exp_label: Label = $VictoryLayer/VictoryPopup/ExpLabel
@onready var level_label: Label = $VictoryLayer/VictoryPopup/LevelLabel
@onready var level_up_label: Label = $VictoryLayer/VictoryPopup/LevelUpLabel
@onready var victory_exp_bar: ProgressBar = $VictoryLayer/VictoryPopup/ExpBar
@onready var exp_min_label: Label = $VictoryLayer/VictoryPopup/ExpMinLabel
@onready var exp_max_label: Label = $VictoryLayer/VictoryPopup/ExpMaxLabel
@onready var continue_button: Button = $VictoryLayer/VictoryPopup/ContinueButton
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

func _ready() -> void:
	# Make sure the battle track loops even if the import setting hasn't refreshed
	if battle_music and battle_music.stream:
		battle_music.stream.loop = true
	if battle_music and not battle_music.playing:
		battle_music.play()
	
	# Configure this encounter's enemy using the stats/appearance of whichever
	# overworld monster was walked into, so this scene isn't locked to one enemy type
	enemy.configure(GameState.encounter_enemy_max_health, GameState.encounter_enemy_attack_damage, GameState.encounter_enemy_attack_interval, GameState.encounter_enemy_texture)
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
	
	# Setup heal ability
	heal_ability.setup(self, portrait, health_bar, member)
	
	# Connect portrait clicks
	portrait_area.input_event.connect(_on_portrait_clicked)
	member.member_area.input_event.connect(_on_member_clicked)
	deselect_area.input_event.connect(_on_deselect_clicked)
	
	# Set initial portrait to unselected
	portrait.texture = portrait_unselected_texture
	
	# Connect victory popup continue button
	continue_button.pressed.connect(_on_continue_pressed)

func _process(delta: float) -> void:
	# Stop all combat when battle is over
	if is_battle_over:
		return
	
	# Regenerate mana based on the player's spirit stat
	if current_mana < max_mana:
		current_mana = min(current_mana + mana_regen_rate * delta, max_mana)
		mana_bar.value = current_mana
	
	time_since_attack += delta
	
	if time_since_attack >= enemy.attack_interval:
		enemy_attack()
		time_since_attack = 0.0
	
	enemy.update_attack_timer(time_since_attack)
	
	# Member attack
	if member.can_attack(delta):
		member_attack()

func _on_heal_clicked(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if heal_ability.can_use():
			heal_ability.use_ability()
		# Consume the event to prevent propagation
		_viewport.set_input_as_handled()

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
	# Animate the enemy's lunge and play its attack sound
	enemy.perform_attack_animation()
	
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
			print("Player defeated!")
	else:
		# Attack member
		member.take_damage(enemy.attack_damage)
		show_damage_number(enemy.attack_damage, member.global_position)

func member_attack() -> void:
	# Perform attack animation
	member.perform_attack_animation()
	
	# Deal damage to enemy
	enemy.take_damage(member.attack_damage)
	show_damage_number(member.attack_damage, enemy.position)
	
	if enemy.current_health <= 0:
		on_enemy_defeated()

func on_enemy_defeated() -> void:
	print("Enemy defeated!")
	is_battle_over = true
	
	# Hide the enemy
	enemy.visible = false
	
	# Grant experience (this may trigger one or more level ups)
	levels_gained_this_battle = GameState.add_experience(exp_reward)
	
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
	
	# Show victory popup
	show_victory_popup()

func show_damage_number(damage: float, target_position: Vector2) -> void:
	var damage_label = Label.new()
	damage_label.text = str(int(damage))
	damage_label.position = target_position + Vector2(-10, -80)
	
	# Style the label
	damage_label.add_theme_font_size_override("font_size", 32)
	damage_label.add_theme_color_override("font_color", Color(1, 0, 0, 1))
	
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

func show_victory_popup() -> void:
	# Update exp label with actual reward
	exp_label.text = "+" + str(int(exp_reward)) + " EXP"
	
	# Update level and exp progress bar with real player data
	level_label.text = "LV " + str(GameState.player_level)
	victory_exp_bar.max_value = GameState.player_exp_to_next_level
	victory_exp_bar.value = min(GameState.player_current_exp, GameState.player_exp_to_next_level)
	exp_min_label.text = "0"
	exp_max_label.text = str(int(GameState.player_exp_to_next_level))
	
	# Show a level up callout if the exp reward pushed the player up a level
	if levels_gained_this_battle > 0:
		level_up_label.visible = true
		if levels_gained_this_battle > 1:
			level_up_label.text = "LEVEL UP! (x" + str(levels_gained_this_battle) + ")"
		else:
			level_up_label.text = "LEVEL UP!"
	else:
		level_up_label.visible = false
	
	# Make sure both the layer and the panel are visible, regardless of
	# which one was toggled off while editing the scene
	victory_layer.visible = true
	victory_popup.visible = true

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
