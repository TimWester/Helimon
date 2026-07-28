extends Area2D
class_name Ability

@export_group("Ability Settings")
@export var ability_name: String = "Ability"
@export var cooldown_duration: float = 5.0
@export var keybinding: Key = KEY_1
@export var mana_cost: float = 10.0
@export var disabled_texture: Texture2D

@onready var sprite: Sprite2D
@onready var cooldown_bar: ProgressBar
@onready var key_label: Label

var cooldown_remaining: float = 0.0
var is_on_cooldown: bool = false
var key_was_pressed: bool = false
var encounter_scene: Node2D  # Reference to encounter scene for mana checks
var enabled_texture: Texture2D
var is_showing_disabled: bool = false
var enabled_sprite_scale: Vector2 = Vector2.ONE
var disabled_sprite_scale: Vector2 = Vector2.ONE

func _ready() -> void:
	# Find child nodes
	sprite = get_node_or_null("Sprite2D")
	cooldown_bar = get_node_or_null("CooldownBar")
	key_label = get_node_or_null("KeyLabel")
	
	if sprite:
		enabled_texture = sprite.texture
		enabled_sprite_scale = sprite.scale
		disabled_sprite_scale = enabled_sprite_scale
		
		# Compensate for the disabled texture possibly having different pixel
		# dimensions than the enabled one, so the on-screen size stays the same
		if disabled_texture and enabled_texture and disabled_texture.get_width() > 0 and disabled_texture.get_height() > 0:
			var size_ratio = Vector2(
				float(enabled_texture.get_width()) / float(disabled_texture.get_width()),
				float(enabled_texture.get_height()) / float(disabled_texture.get_height())
			)
			disabled_sprite_scale = enabled_sprite_scale * size_ratio
	
	if cooldown_bar:
		cooldown_bar.max_value = cooldown_duration
		cooldown_bar.value = 0.0
	
	if key_label:
		update_key_label()
	
	# Connect input event
	input_event.connect(_on_input_event)

func _process(delta: float) -> void:
	# Update cooldown
	if is_on_cooldown:
		cooldown_remaining -= delta
		if cooldown_bar:
			cooldown_bar.value = cooldown_remaining
		
		if cooldown_remaining <= 0:
			is_on_cooldown = false
			cooldown_remaining = 0.0
			if cooldown_bar:
				cooldown_bar.value = 0.0
	
	update_sprite_state()
	
	# Check for keybinding
	if Input.is_key_pressed(keybinding):
		if not key_was_pressed:
			try_use()
		key_was_pressed = true
	else:
		key_was_pressed = false

func update_sprite_state() -> void:
	# Swap to the disabled sprite while on cooldown or lacking enough mana
	if not sprite or not disabled_texture:
		return
	
	var out_of_mana = encounter_scene and not encounter_scene.has_mana(mana_cost)
	var should_show_disabled = is_on_cooldown or out_of_mana
	
	if should_show_disabled != is_showing_disabled:
		is_showing_disabled = should_show_disabled
		sprite.texture = disabled_texture if should_show_disabled else enabled_texture
		sprite.scale = disabled_sprite_scale if should_show_disabled else enabled_sprite_scale

func _on_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		try_use()
		# Consume the event
		_viewport.set_input_as_handled()

func try_use() -> void:
	# Attempt to use the ability, giving feedback when blocked by insufficient mana
	if is_on_cooldown:
		return
	if encounter_scene and not encounter_scene.has_mana(mana_cost):
		if encounter_scene.has_method("show_out_of_mana_message"):
			encounter_scene.show_out_of_mana_message()
		return
	if not has_valid_target():
		return
	use_ability()

func can_use() -> bool:
	# Check cooldown, valid target, and mana
	if is_on_cooldown:
		return false
	if not has_valid_target():
		return false
	if encounter_scene and not encounter_scene.has_mana(mana_cost):
		return false
	return true

func has_valid_target() -> bool:
	# Override in child classes
	return true

func use_ability() -> void:
	if not can_use():
		return
	
	# Consume mana
	if encounter_scene:
		if not encounter_scene.use_mana(mana_cost):
			return  # Not enough mana
	
	# Perform the ability effect (override in child classes)
	perform_effect()
	
	# Start cooldown
	is_on_cooldown = true
	cooldown_remaining = cooldown_duration
	if cooldown_bar:
		cooldown_bar.value = cooldown_duration

func perform_effect() -> void:
	# Override this in child classes to implement specific ability effects
	print(ability_name + " used!")

func update_key_label() -> void:
	if not key_label:
		return
	
	# Convert key enum to display text
	var key_text = ""
	match keybinding:
		KEY_1: key_text = "1"
		KEY_2: key_text = "2"
		KEY_3: key_text = "3"
		KEY_4: key_text = "4"
		KEY_Q: key_text = "Q"
		KEY_E: key_text = "E"
		KEY_R: key_text = "R"
		KEY_F: key_text = "F"
		_: key_text = str(keybinding)
	
	key_label.text = key_text
