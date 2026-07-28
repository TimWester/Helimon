extends Node2D

# Inventory UI
@onready var bag_button: Button = $GameUI/BagButton
@onready var inventory_panel: Panel = $GameUI/InventoryPanel
var is_inventory_open = false

# Equipment UI
@onready var equipment_button: Button = $GameUI/GearButton
@onready var equipment_panel: Panel = $GameUI/EquipmentPanel
var is_equipment_open = false

# Stats UI
@onready var stats_button: Button = $GameUI/StatsButton
@onready var stats_panel: Panel = $GameUI/StatsPanel
@onready var health_value_label: Label = $GameUI/StatsPanel/HealthValueLabel
@onready var mana_value_label: Label = $GameUI/StatsPanel/ManaValueLabel
@onready var damage_value_label: Label = $GameUI/StatsPanel/DamageValueLabel
@onready var spirit_value_label: Label = $GameUI/StatsPanel/SpiritValueLabel
var is_stats_open = false

# Player HUD
@onready var hud_portrait: Sprite2D = $PlayerHUD/Portrait
@onready var hud_level_label: Label = $PlayerHUD/LevelLabel
@onready var hud_exp_bar: ProgressBar = $PlayerHUD/ExpBar
@onready var hud_exp_label: Label = $PlayerHUD/ExpLabel

# Background music
@onready var background_music: AudioStreamPlayer = $BackgroundMusic

func _ready() -> void:
	# Make sure the ambient track loops even if the import setting hasn't refreshed
	if background_music and background_music.stream:
		background_music.stream.loop = true
	if background_music and not background_music.playing:
		background_music.play()
	
	# Restore player position if returning from encounter
	var player_position = GameState.get_player_position()
	if player_position != Vector2.ZERO:
		var player = get_node_or_null("Player")
		if player:
			player.global_position = player_position
	
	# Check if an enemy was defeated and should be removed
	if GameState.should_remove_enemy():
		var enemy_path = GameState.get_enemy_path()
		if has_node(enemy_path):
			var enemy_node = get_node(enemy_path)
			enemy_node.queue_free()
		GameState.clear()
	
	# Connect UI buttons
	bag_button.pressed.connect(_on_bag_button_pressed)
	inventory_panel.get_node("CloseButton").pressed.connect(_on_close_inventory_pressed)
	
	equipment_button.pressed.connect(_on_equipment_button_pressed)
	equipment_panel.get_node("CloseButton").pressed.connect(_on_close_equipment_pressed)
	
	stats_button.pressed.connect(_on_stats_button_pressed)
	stats_panel.get_node("CloseButton").pressed.connect(_on_close_stats_pressed)
	
	update_player_hud()

func _on_bag_button_pressed() -> void:
	UISound.play_click()
	is_inventory_open = !is_inventory_open
	inventory_panel.visible = is_inventory_open

func _on_close_inventory_pressed() -> void:
	UISound.play_click()
	is_inventory_open = false
	inventory_panel.visible = false

func _on_equipment_button_pressed() -> void:
	UISound.play_click()
	is_equipment_open = !is_equipment_open
	equipment_panel.visible = is_equipment_open

func _on_close_equipment_pressed() -> void:
	UISound.play_click()
	is_equipment_open = false
	equipment_panel.visible = false

func _on_stats_button_pressed() -> void:
	UISound.play_click()
	is_stats_open = !is_stats_open
	stats_panel.visible = is_stats_open
	if is_stats_open:
		refresh_stats_display()

func _on_close_stats_pressed() -> void:
	UISound.play_click()
	is_stats_open = false
	stats_panel.visible = false

func refresh_stats_display() -> void:
	health_value_label.text = str(int(GameState.player_current_health)) + " / " + str(int(GameState.player_max_health))
	mana_value_label.text = str(int(GameState.player_current_mana)) + " / " + str(int(GameState.player_max_mana))
	damage_value_label.text = str(int(GameState.player_base_damage))
	spirit_value_label.text = str(int(GameState.player_spirit))

func update_player_hud() -> void:
	# Update HUD elements with current GameState values
	hud_level_label.text = "Level " + str(GameState.player_level)
	hud_exp_bar.max_value = GameState.player_exp_to_next_level
	hud_exp_bar.value = GameState.player_current_exp
	hud_exp_label.text = str(int(GameState.player_current_exp)) + " / " + str(int(GameState.player_exp_to_next_level))
