extends Node2D

# Inventory UI
@onready var bag_button: Button = $GameUI/BagButton
@onready var inventory_panel: Panel = $GameUI/InventoryPanel
@onready var inventory_tooltip: PanelContainer = $GameUI/InventoryTooltip
@onready var inventory_tooltip_label: Label = $GameUI/InventoryTooltip/TooltipLabel
var is_inventory_open = false
var inventory_slots: Array[Panel] = []
var inventory_tooltip_visible = false

# Equipment UI
@onready var equipment_button: Button = $GameUI/GearButton
@onready var equipment_panel: Panel = $GameUI/EquipmentPanel
var is_equipment_open = false
# Gear slot node names in the EquipmentPanel, matching Item.EquipSlot types
const GEAR_SLOT_NAMES: Array[String] = [
	"NecklaceSlot", "HelmSlot", "HandSlot", "ShoulderSlot",
	"Ring1Slot", "Ring2Slot", "Ring3Slot", "Ring4Slot",
	"TorsoSlot", "LegsSlot", "BootsSlot"
]

# Stats UI
@onready var stats_button: Button = $GameUI/StatsButton
@onready var stats_panel: Panel = $GameUI/StatsPanel
@onready var health_value_label: Label = $GameUI/StatsPanel/HealthValueLabel
@onready var mana_value_label: Label = $GameUI/StatsPanel/ManaValueLabel
@onready var damage_value_label: Label = $GameUI/StatsPanel/DamageValueLabel
@onready var spirit_value_label: Label = $GameUI/StatsPanel/SpiritValueLabel
@onready var haste_value_label: Label = $GameUI/StatsPanel/HasteValueLabel
var is_stats_open = false

# Player HUD
@onready var hud_portrait: TextureRect = $PlayerHUD/FrameBackground/Portrait
@onready var hud_name_label: Label = $PlayerHUD/FrameBackground/NameLabel
@onready var hud_level_label: Label = $PlayerHUD/FrameBackground/LevelLabel
@onready var hud_health_bar: ProgressBar = $PlayerHUD/FrameBackground/HealthBar
@onready var hud_health_label: Label = $PlayerHUD/FrameBackground/HealthBar/HealthLabel
@onready var hud_mana_bar: ProgressBar = $PlayerHUD/FrameBackground/ManaBar
@onready var hud_mana_label: Label = $PlayerHUD/FrameBackground/ManaBar/ManaLabel
@onready var hud_exp_bar: ProgressBar = $PlayerHUD/FrameBackground/ExpBar

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
		var player = get_node_or_null("WorldYSort/Player")
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
	
	# Setup inventory slots
	_setup_inventory_slots()
	_setup_equipment_slots()
	
	update_player_hud()

func _on_close_inventory_pressed() -> void:
	UISound.play_click()
	is_inventory_open = false
	inventory_panel.visible = false

func _on_equipment_button_pressed() -> void:
	UISound.play_click()
	equipment_button.release_focus()  # Prevent space from toggling the button
	is_equipment_open = !is_equipment_open
	equipment_panel.visible = is_equipment_open
	if is_equipment_open:
		_refresh_equipment_display()

func _on_close_equipment_pressed() -> void:
	UISound.play_click()
	is_equipment_open = false
	equipment_panel.visible = false

func _on_stats_button_pressed() -> void:
	UISound.play_click()
	stats_button.release_focus()  # Prevent space from toggling the button
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
	haste_value_label.text = str(int(GameState.player_haste))

func _setup_inventory_slots() -> void:
	# Collect all inventory slot panels
	for i in range(20):
		var slot = inventory_panel.get_node_or_null("Slot" + str(i))
		if slot:
			inventory_slots.append(slot)
			
			# Add an icon texture to each slot
			var icon_rect = TextureRect.new()
			icon_rect.name = "ItemIcon"
			icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			icon_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
			icon_rect.offset_top = 4
			icon_rect.offset_bottom = -18
			icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
			slot.add_child(icon_rect)
			
			# Add a label to each slot for item name (shown below the icon)
			var label = Label.new()
			label.name = "ItemLabel"
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			label.custom_minimum_size = Vector2(60, 16)
			label.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
			label.offset_top = -18
			label.add_theme_font_size_override("font_size", 9)
			label.mouse_filter = Control.MOUSE_FILTER_IGNORE
			slot.add_child(label)
			
			# Use the Panel's own mouse signals (Control-native) for hover/click
			# detection instead of Area2D, which doesn't reliably pick up mouse
			# events when nested inside a CanvasLayer/Control UI hierarchy.
			slot.mouse_filter = Control.MOUSE_FILTER_STOP
			slot.mouse_entered.connect(_on_item_slot_mouse_entered.bind(i))
			slot.mouse_exited.connect(_on_item_slot_mouse_exited)
			slot.gui_input.connect(_on_item_slot_gui_input.bind(i))

func _setup_equipment_slots() -> void:
	for slot_name in GEAR_SLOT_NAMES:
		var slot: Panel = equipment_panel.get_node_or_null(slot_name)
		if not slot:
			continue
		
		# Add an icon texture on top of the slot (drawn above the slot label)
		var icon_rect = TextureRect.new()
		icon_rect.name = "ItemIcon"
		icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
		icon_rect.offset_left = 4
		icon_rect.offset_top = 4
		icon_rect.offset_right = -4
		icon_rect.offset_bottom = -4
		icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(icon_rect)
		
		slot.mouse_filter = Control.MOUSE_FILTER_STOP
		slot.mouse_entered.connect(_on_gear_slot_mouse_entered.bind(slot_name))
		slot.mouse_exited.connect(_on_item_slot_mouse_exited)
		slot.gui_input.connect(_on_gear_slot_gui_input.bind(slot_name))

func _refresh_equipment_display() -> void:
	for slot_name in GEAR_SLOT_NAMES:
		var slot: Panel = equipment_panel.get_node_or_null(slot_name)
		if not slot:
			continue
		var icon_rect = slot.get_node_or_null("ItemIcon")
		if not icon_rect:
			continue
		
		var equipped_item = GameState.get_equipped_item(slot_name)
		icon_rect.texture = equipped_item.icon if equipped_item else null
		
		# Hide/show the label based on whether an item is equipped
		var label_name = slot_name.replace("Slot", "Label")
		var label = equipment_panel.get_node_or_null(label_name)
		if label:
			label.visible = (equipped_item == null)  # Show label only when slot is empty

func _on_gear_slot_gui_input(event: InputEvent, slot_name: String) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		GameState.unequip_slot(slot_name)
		_refresh_equipment_display()
		_refresh_inventory_display()
		refresh_stats_display()
		_hide_item_tooltip()

func _on_gear_slot_mouse_entered(slot_name: String) -> void:
	var item = GameState.get_equipped_item(slot_name)
	if item:
		_show_item_tooltip(item)

func _on_bag_button_pressed() -> void:
	UISound.play_click()
	bag_button.release_focus()  # Prevent space from toggling the button
	is_inventory_open = !is_inventory_open
	inventory_panel.visible = is_inventory_open
	if is_inventory_open:
		_refresh_inventory_display()

func _refresh_inventory_display() -> void:
	# Clear all slots first
	for slot in inventory_slots:
		var label = slot.get_node_or_null("ItemLabel")
		var icon_rect = slot.get_node_or_null("ItemIcon")
		if label:
			label.text = ""
		if icon_rect:
			icon_rect.texture = null
	
	# Fill slots with items from inventory (equipped items are moved out of
	# the inventory array, so everything shown here is always unequipped).
	# player_inventory is a fixed-size array with null for empty slots, so
	# each item's index always matches its visual slot position.
	for i in range(min(GameState.player_inventory.size(), inventory_slots.size())):
		var item = GameState.player_inventory[i]
		if item:
			var label = inventory_slots[i].get_node_or_null("ItemLabel")
			var icon_rect = inventory_slots[i].get_node_or_null("ItemIcon")
			if label:
				label.visible = false  # Hide item names in inventory, show only icons
			if icon_rect:
				icon_rect.texture = item.icon

func _on_item_slot_gui_input(event: InputEvent, slot_index: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		if slot_index < GameState.player_inventory.size():
			var item = GameState.player_inventory[slot_index]
			if item and item.equip_slot != Item.EquipSlot.NONE and not GameState.is_item_equipped(item):
				GameState.equip_item(item, slot_index)  # Pass the specific slot index
				_refresh_inventory_display()
				_refresh_equipment_display()
				refresh_stats_display()
				_hide_item_tooltip()

func _on_item_slot_mouse_entered(slot_index: int) -> void:
	if slot_index < GameState.player_inventory.size():
		var item = GameState.player_inventory[slot_index]
		if item:
			_show_item_tooltip(item)

func _on_item_slot_mouse_exited() -> void:
	_hide_item_tooltip()

func _show_item_tooltip(item: Item) -> void:
	if not item:
		return
	
	var lines: PackedStringArray = []
	lines.append(item.item_name)
	lines.append("")
	if item.description and item.description.strip_edges() != "":
		lines.append(item.description.strip_edges())
		lines.append("")
	
	var stats_text = item.get_stats_text()
	lines.append(stats_text)
	
	if item.equip_slot != Item.EquipSlot.NONE:
		lines.append("")
		if GameState.is_item_equipped(item):
			lines.append("Right-click to unequip")
		else:
			lines.append("Right-click to equip")
	
	inventory_tooltip_label.text = "\n".join(lines)
	inventory_tooltip.visible = true
	inventory_tooltip_visible = true
	_position_inventory_tooltip()

func _hide_item_tooltip() -> void:
	inventory_tooltip.visible = false
	inventory_tooltip_visible = false

func _position_inventory_tooltip() -> void:
	if not inventory_tooltip_visible:
		return
	
	var mouse_pos = get_viewport().get_mouse_position()
	var tooltip_size = inventory_tooltip.size
	var viewport_size = get_viewport_rect().size
	
	# Position tooltip to the right of cursor, but keep it on screen
	var x = mouse_pos.x + 20
	var y = mouse_pos.y - tooltip_size.y / 2
	
	# Keep within screen bounds
	if x + tooltip_size.x > viewport_size.x:
		x = mouse_pos.x - tooltip_size.x - 20
	if y < 0:
		y = 0
	if y + tooltip_size.y > viewport_size.y:
		y = viewport_size.y - tooltip_size.y
	
	inventory_tooltip.position = Vector2(x, y)

func _process(delta: float) -> void:
	if inventory_tooltip_visible:
		_position_inventory_tooltip()
	
	# Regenerate mana in the overworld based on spirit stat
	if GameState.player_current_mana < GameState.player_max_mana:
		var mana_per_second = GameState.player_spirit * GameState.spirit_to_mana_multiplier
		GameState.player_current_mana = min(
			GameState.player_current_mana + mana_per_second * delta,
			GameState.player_max_mana
		)
		# Update the mana bar display
		hud_mana_bar.value = GameState.player_current_mana
		hud_mana_label.text = str(int(GameState.player_current_mana)) + " / " + str(int(GameState.player_max_mana))

func update_player_hud() -> void:
	# Update HUD elements with current GameState values
	hud_level_label.text = "Lv. " + str(GameState.player_level)
	hud_exp_bar.max_value = GameState.player_exp_to_next_level
	hud_exp_bar.value = GameState.player_current_exp
	
	hud_health_bar.max_value = GameState.player_max_health
	hud_health_bar.value = GameState.player_current_health
	hud_health_label.text = str(int(GameState.player_current_health)) + " / " + str(int(GameState.player_max_health))
	
	hud_mana_bar.max_value = GameState.player_max_mana
	hud_mana_bar.value = GameState.player_current_mana
	hud_mana_label.text = str(int(GameState.player_current_mana)) + " / " + str(int(GameState.player_max_mana))
