extends Node2D

## A simple interactable NPC that can be talked to in the overworld.
## Approach the NPC and press Space to open a dialogue window with two
## selectable options. Both options currently just close the conversation.

@export var npc_name: String = "Villager"
@export var interaction_prompt_text: String = "Press SPACE to talk"
@export_multiline var dialogue_text: String = "Hello there, traveler! Lovely weather we're having, isn't it?"
@export var option_1_text: String = "It sure is."
@export var option_2_text: String = "I don't have time to chat."
@export var portrait_texture: Texture2D

var player_in_range: bool = false
var player_reference: Node2D = null
var is_talking: bool = false

@onready var interaction_area: Area2D = $InteractionArea
@onready var prompt_label: Label = $PromptLabel
@onready var dialogue_layer: CanvasLayer = $DialogueLayer
@onready var name_label: Label = $DialogueLayer/DialoguePanel/NameLabel
@onready var dialogue_label: Label = $DialogueLayer/DialoguePanel/DialogueLabel
@onready var portrait_rect: TextureRect = $DialogueLayer/DialoguePanel/PortraitFrame/PortraitRect
@onready var option_1_button: Button = $DialogueLayer/DialoguePanel/Option1Button
@onready var option_2_button: Button = $DialogueLayer/DialoguePanel/Option2Button

func _ready() -> void:
	interaction_area.body_entered.connect(_on_body_entered)
	interaction_area.body_exited.connect(_on_body_exited)
	
	if option_1_button:
		option_1_button.pressed.connect(_on_option_pressed.bind(1))
	if option_2_button:
		option_2_button.pressed.connect(_on_option_pressed.bind(2))
	
	if portrait_rect and portrait_texture:
		portrait_rect.texture = portrait_texture
	if name_label:
		name_label.text = npc_name
	
	if prompt_label:
		prompt_label.text = interaction_prompt_text
		prompt_label.visible = false
	if dialogue_layer:
		dialogue_layer.visible = false

func _process(_delta: float) -> void:
	# Position the prompt below the player, same convention as the chest prompt
	if player_in_range and player_reference and prompt_label and prompt_label.visible:
		var player_pos = player_reference.global_position
		prompt_label.global_position = player_pos + Vector2(-60, -14)
	
	if player_in_range and not is_talking and Input.is_action_just_pressed("ui_accept"):
		open_dialogue()

func _on_body_entered(body: Node2D) -> void:
	if body.name == "Player":
		player_in_range = true
		player_reference = body
		if prompt_label and not is_talking:
			prompt_label.visible = true

func _on_body_exited(body: Node2D) -> void:
	if body.name == "Player":
		player_in_range = false
		player_reference = null
		if prompt_label:
			prompt_label.visible = false

func open_dialogue() -> void:
	is_talking = true
	GameState.dialogue_active = true
	
	if prompt_label:
		prompt_label.visible = false
	
	if dialogue_label:
		dialogue_label.text = dialogue_text
	if option_1_button:
		option_1_button.text = option_1_text
	if option_2_button:
		option_2_button.text = option_2_text
	
	if dialogue_layer:
		dialogue_layer.visible = true

func close_dialogue() -> void:
	is_talking = false
	GameState.dialogue_active = false
	
	if dialogue_layer:
		dialogue_layer.visible = false
	
	# Re-show the prompt if the player is still standing nearby
	if player_in_range and prompt_label:
		prompt_label.visible = true

func _on_option_pressed(_option_index: int) -> void:
	UISound.play_click()
	# Both options simply close the conversation for now.
	close_dialogue()
	if option_1_button:
		option_1_button.release_focus()
	if option_2_button:
		option_2_button.release_focus()
