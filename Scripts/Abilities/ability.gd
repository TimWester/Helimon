extends Area2D
class_name Ability

@export_group("Ability Settings")
@export var ability_name: String = "Ability"
@export_multiline var description: String = ""
@export var cooldown_duration: float = 5.0
@export var cast_time: float = 0.0
@export var keybinding: Key = KEY_1
@export var mana_cost: float = 10.0
@export var disabled_texture: Texture2D

@onready var sprite: Sprite2D
@onready var cooldown_bar: ProgressBar
@onready var key_label: Label

var cooldown_remaining: float = 0.0
var is_on_cooldown: bool = false
var cast_remaining: float = 0.0
var is_casting: bool = false
var key_was_pressed: bool = false
var encounter_scene: Node2D  # Reference to encounter scene for mana checks
var enabled_texture: Texture2D
var is_showing_disabled: bool = false
var enabled_sprite_scale: Vector2 = Vector2.ONE
var disabled_sprite_scale: Vector2 = Vector2.ONE

func get_modified_cast_time() -> float:
	## Returns cast time reduced by haste percentage
	var haste_percent = GameState.player_haste * GameState.haste_cast_speed_per_point / 100.0
	var reduction = 1.0 - clamp(haste_percent, 0.0, 0.75)  # Cap at 75% reduction
	return cast_time * reduction

func get_modified_cooldown() -> float:
	## Returns cooldown reduced by haste percentage
	var haste_percent = GameState.player_haste * GameState.haste_cooldown_per_point / 100.0
	var reduction = 1.0 - clamp(haste_percent, 0.0, 0.75)  # Cap at 75% reduction
	return cooldown_duration * reduction

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
		cooldown_bar.max_value = get_modified_cooldown()
		cooldown_bar.value = 0.0
		cooldown_bar.visible = false
	
	if key_label:
		update_key_label()
	
	# Connect input event
	input_event.connect(_on_input_event)
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)

func _process(delta: float) -> void:
	# Update active cast
	if is_casting:
		if encounter_scene and encounter_scene.get("is_battle_over"):
			_cancel_cast()
		else:
			cast_remaining -= delta
			if encounter_scene and encounter_scene.has_method("update_casting"):
				var modified_cast_time = get_modified_cast_time()
				var progress = 1.0 - (cast_remaining / max(modified_cast_time, 0.001))
				encounter_scene.update_casting(progress)
			
			if cast_remaining <= 0.0:
				_finish_cast()
	
	# Update cooldown
	if is_on_cooldown:
		cooldown_remaining -= delta
		if cooldown_bar:
			cooldown_bar.visible = true
			cooldown_bar.value = cooldown_remaining
		
		if cooldown_remaining <= 0:
			is_on_cooldown = false
			cooldown_remaining = 0.0
			if cooldown_bar:
				cooldown_bar.value = 0.0
				cooldown_bar.visible = false
	
	update_sprite_state()
	
	# Check for keybinding
	if Input.is_key_pressed(keybinding):
		if not key_was_pressed:
			try_use()
		key_was_pressed = true
	else:
		key_was_pressed = false

func update_sprite_state() -> void:
	# Swap to the disabled sprite while on cooldown, casting, or lacking enough mana
	if not sprite or not disabled_texture:
		return
	
	var out_of_mana = encounter_scene and not encounter_scene.has_mana(mana_cost)
	var should_show_disabled = is_on_cooldown or is_casting or out_of_mana
	
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
	if is_on_cooldown or is_casting:
		return
	if encounter_scene and encounter_scene.has_method("is_any_ability_casting") and encounter_scene.is_any_ability_casting():
		return
	if encounter_scene and not encounter_scene.has_mana(mana_cost):
		if encounter_scene.has_method("show_out_of_mana_message"):
			encounter_scene.show_out_of_mana_message()
		return
	if not has_valid_target():
		return
	use_ability()

func can_use() -> bool:
	# Check cooldown, casting, valid target, and mana
	if is_on_cooldown or is_casting:
		return false
	if encounter_scene and encounter_scene.has_method("is_any_ability_casting") and encounter_scene.is_any_ability_casting():
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
	
	# Consume mana up front when the cast/use begins
	if encounter_scene:
		if not encounter_scene.use_mana(mana_cost):
			return  # Not enough mana
	
	var modified_cast_time = get_modified_cast_time()
	if modified_cast_time > 0.0:
		_begin_cast()
	else:
		perform_effect()
		_start_cooldown()

func _begin_cast() -> void:
	is_casting = true
	var modified_cast_time = get_modified_cast_time()
	cast_remaining = modified_cast_time
	if encounter_scene and encounter_scene.has_method("start_casting"):
		encounter_scene.start_casting(ability_name, modified_cast_time)

func _finish_cast() -> void:
	is_casting = false
	cast_remaining = 0.0
	if encounter_scene and encounter_scene.has_method("stop_casting"):
		encounter_scene.stop_casting()
	
	# Target may have been deselected during the cast — still finish if valid
	if has_valid_target():
		perform_effect()
	_start_cooldown()

func _cancel_cast() -> void:
	# Interrupted (e.g. battle ended) — no effect, no cooldown refund of mana
	is_casting = false
	cast_remaining = 0.0
	if encounter_scene and encounter_scene.has_method("stop_casting"):
		encounter_scene.stop_casting()

func _start_cooldown() -> void:
	is_on_cooldown = true
	var modified_cooldown = get_modified_cooldown()
	cooldown_remaining = modified_cooldown
	if cooldown_bar:
		cooldown_bar.max_value = modified_cooldown
		cooldown_bar.visible = true
		cooldown_bar.value = modified_cooldown

func perform_effect() -> void:
	# Override this in child classes to implement specific ability effects
	print(ability_name + " used!")

func get_tooltip_text() -> String:
	var lines: PackedStringArray = []
	lines.append("[color=#FFD700]%s[/color]" % ability_name)  # Gold name
	lines.append("")
	if description.strip_edges() != "":
		lines.append(description.strip_edges())
		lines.append("")
	
	lines.append("[color=#4DA6FF]Mana Cost: %d[/color]" % int(mana_cost))  # Blue
	
	var modified_cast_time = get_modified_cast_time()
	if cast_time > 0.0:
		if modified_cast_time > 0.0:
			lines.append("[color=#90EE90]Cast Time: %.2f sec[/color]" % modified_cast_time)  # Green
		else:
			lines.append("[color=#90EE90]Cast Time: Instant[/color]")
	else:
		lines.append("[color=#90EE90]Cast Time: Instant[/color]")
	
	var modified_cooldown = get_modified_cooldown()
	lines.append("[color=#FFA500]Cooldown: %.2f sec[/color]" % modified_cooldown)  # Orange
	
	return "\n".join(lines)

func _on_mouse_entered() -> void:
	if encounter_scene and encounter_scene.has_method("show_ability_tooltip"):
		# Use call_deferred to ensure this happens after other events settle
		encounter_scene.call_deferred("show_ability_tooltip", get_tooltip_text())

func _on_mouse_exited() -> void:
	if encounter_scene and encounter_scene.has_method("hide_ability_tooltip"):
		encounter_scene.call_deferred("hide_ability_tooltip")

func update_key_label() -> void:
	if not key_label:
		return
	key_label.text = _get_key_text()

func _get_key_text() -> String:
	match keybinding:
		KEY_1: return "1"
		KEY_2: return "2"
		KEY_3: return "3"
		KEY_4: return "4"
		KEY_Q: return "Q"
		KEY_E: return "E"
		KEY_R: return "R"
		KEY_F: return "F"
		_: return str(keybinding)
