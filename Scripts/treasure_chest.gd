extends Node2D

## Interactive treasure chest that gives item rewards when opened

@export var item_rewards: Array[Item] = []
@export var interaction_prompt_text: String = "Press SPACE to open"

var is_opened: bool = false
var player_in_range: bool = false
var player_reference: Node2D = null

@onready var sprite: Sprite2D = $Sprite2D
@onready var interaction_area: Area2D = $InteractionArea
@onready var prompt_label: Label = $PromptLabel
@onready var reward_layer: CanvasLayer = $RewardLayer
@onready var reward_popup: Panel = $RewardLayer/RewardPopup
@onready var items_label: Label = $RewardLayer/RewardPopup/ItemsLabel
@onready var continue_button: Button = $RewardLayer/RewardPopup/ContinueButton
@onready var open_sound_player: AudioStreamPlayer = $OpenSoundPlayer

var closed_texture = preload("res://Sprites/WorldObject/Interactables/TreasureChest.png")
var open_texture = preload("res://Sprites/WorldObject/Interactables/TreasureChest_open.png")

func _ready() -> void:
	# Connect the area signals to detect when player enters/exits range
	interaction_area.body_entered.connect(_on_body_entered)
	interaction_area.body_exited.connect(_on_body_exited)
	
	# Connect continue button
	if continue_button:
		continue_button.pressed.connect(_on_continue_pressed)
	
	# Start with closed sprite
	sprite.texture = closed_texture
	
	# Hide prompt and reward popup initially
	if prompt_label:
		prompt_label.visible = false
	if reward_layer:
		reward_layer.visible = false

func _process(_delta: float) -> void:
	# Position the prompt below the player when visible
	if player_in_range and player_reference and prompt_label and prompt_label.visible:
		# Position the label south (below) the player. The player's origin is
		# now at their feet (see main_scene.tscn Y-sort fix), so this offset
		# is smaller than before to land in the same visual spot.
		var player_pos = player_reference.global_position
		prompt_label.global_position = player_pos + Vector2(-60, -14)
	
	# Check for space key press when player is in range and chest isn't opened
	if player_in_range and not is_opened and Input.is_action_just_pressed("ui_accept"):
		open_chest()
		return  # Exit early so we don't check for continue button in same frame
	
	# Allow Space key to press Continue button when reward popup is visible (only if chest is already opened)
	if is_opened and reward_layer and reward_layer.visible and Input.is_action_just_pressed("ui_accept"):
		_on_continue_pressed()

func _on_body_entered(body: Node2D) -> void:
	# Check if the player entered the interaction area
	if body.name == "Player" and not is_opened:
		player_in_range = true
		player_reference = body
		if prompt_label:
			prompt_label.visible = true

func _on_body_exited(body: Node2D) -> void:
	# Check if the player left the interaction area
	if body.name == "Player":
		player_in_range = false
		player_reference = null
		if prompt_label:
			prompt_label.visible = false

func open_chest() -> void:
	if is_opened:
		return
	
	is_opened = true
	
	# Change sprite to open chest
	sprite.texture = open_texture
	
	# Hide the prompt
	if prompt_label:
		prompt_label.visible = false
	
	# Play chest opening sound
	_play_chest_open_sound()
	
	# Give rewards to player
	for item in item_rewards:
		if item:
			GameState.add_item_to_inventory(item)
			print("Received from chest: ", item.item_name)
	
	# Refresh the inventory display if it's currently open
	_refresh_main_scene_inventory()
	
	# Show reward popup
	show_reward_popup()
	
	# Remember that this chest was opened so it stays open (and doesn't
	# re-grant rewards) if the overworld scene reloads later.
	GameState.mark_chest_opened(get_path())

## Restores this chest to its already-opened visual state without granting
## rewards again or showing the reward popup. Called on scene load for
## chests that were opened earlier in this play session.
func restore_opened_state() -> void:
	is_opened = true
	sprite.texture = open_texture
	if prompt_label:
		prompt_label.visible = false

func _refresh_main_scene_inventory() -> void:
	# Find the main scene and refresh its inventory display if open
	var main_scene = get_tree().current_scene
	if main_scene and main_scene.has_method("_refresh_inventory_display"):
		if main_scene.get("is_inventory_open"):
			main_scene._refresh_inventory_display()

func show_reward_popup() -> void:
	if not reward_layer or not items_label:
		return
	
	# Build the items text
	var item_names: PackedStringArray = []
	for item in item_rewards:
		if item:
			item_names.append(item.item_name)
	
	if item_names.size() > 0:
		items_label.text = "\n".join(item_names)
	else:
		items_label.text = "Empty chest"
	
	# Show the popup
	reward_layer.visible = true

func _on_continue_pressed() -> void:
	UISound.play_click()
	# Hide the reward popup
	if reward_layer:
		reward_layer.visible = false

func _play_chest_open_sound() -> void:
	## Generates and plays a chest opening sound (wooden creak and thunk)
	if not open_sound_player:
		return
	
	var stream_generator = AudioStreamGenerator.new()
	stream_generator.mix_rate = 22050.0
	stream_generator.buffer_length = 0.5
	
	open_sound_player.stream = stream_generator
	open_sound_player.play()
	
	var playback: AudioStreamGeneratorPlayback = open_sound_player.get_stream_playback()
	if not playback:
		return
	
	var sample_rate = stream_generator.mix_rate
	var duration = 0.35  # Shorter duration for chest sound
	var total_frames = int(duration * sample_rate)
	
	# Generate chest opening sound - combination of wooden creak and thump
	for i in range(total_frames):
		var t = float(i) / sample_rate
		var envelope = exp(-t * 8.0)  # Quick decay
		
		# Low frequency "thunk" (around 80-120 Hz)
		var thunk_freq = 100.0 + sin(t * 30.0) * 20.0
		var thunk = sin(t * thunk_freq * TAU) * 0.4
		
		# Mid frequency "creak" (around 300-600 Hz with vibrato)
		var creak_freq = 450.0 + sin(t * 12.0) * 150.0
		var creak = sin(t * creak_freq * TAU) * 0.25
		
		# High frequency "wood texture" noise
		var noise = (randf() * 2.0 - 1.0) * 0.1
		
		# Combine all components with envelope
		var sample = (thunk + creak + noise) * envelope * 0.5
		
		# Stereo output
		playback.push_frame(Vector2(sample, sample))
