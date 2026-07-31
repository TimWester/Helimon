extends Node2D

# Inventory UI
@onready var bag_button: Button = $GameUI/BagButton
@onready var inventory_panel: Panel = $GameUI/InventoryPanel
@onready var inventory_tooltip: PanelContainer = $GameUI/InventoryTooltip
@onready var inventory_tooltip_label: RichTextLabel = $GameUI/InventoryTooltip/TooltipLabel
var is_inventory_open = false
var inventory_slots: Array[Panel] = []
var inventory_tooltip_visible = false

# Item pick-up/drag-and-drop (works across both the inventory bag and the
# equipment panel). Slots are identified by a string key: "inv:<index>" for
# bag slots, or "equip:<slot_name>" for gear slots.
var dragged_from_key: String = ""  # "" = nothing held
var pending_click_key: String = ""  # Key where the mouse button is still physically held down
var held_item_icon: TextureRect  # Floating icon that follows the mouse while holding an item

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

# Party UI
@onready var party_button: Button = $GameUI/PartyButton
@onready var party_panel: Panel = $GameUI/PartyPanel
@onready var party_cards_container: HBoxContainer = $GameUI/PartyPanel/CardsContainer
var is_party_open = false
const PartyMemberCardScene: PackedScene = preload("res://Scenes/Party/party_member_card.tscn")
# Gear slot node names on each party_member_card.tscn instance, matching
# Item.EquipSlot types WEAPON/CAPE/TRINKET.
const PARTY_SLOT_NAMES: Array[String] = ["WeaponSlot", "CapeSlot", "Trinket1Slot", "Trinket2Slot"]

# Player HUD
@onready var hud_portrait: TextureRect = $PlayerHUD/FrameBackground/Portrait
@onready var hud_name_label: Label = $PlayerHUD/FrameBackground/NameLabel
@onready var hud_level_label: Label = $PlayerHUD/FrameBackground/LevelLabel
@onready var hud_health_bar: ProgressBar = $PlayerHUD/FrameBackground/HealthBar
@onready var hud_health_label: Label = $PlayerHUD/FrameBackground/HealthBar/HealthLabel
@onready var hud_mana_bar: ProgressBar = $PlayerHUD/FrameBackground/ManaBar
@onready var hud_mana_label: Label = $PlayerHUD/FrameBackground/ManaBar/ManaLabel
@onready var hud_exp_bar: ProgressBar = $PlayerHUD/FrameBackground/ExpBar
@onready var hud_exp_label: Label = $PlayerHUD/FrameBackground/ExpLabel

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
	
	# Remove every enemy defeated so far this play session (not just the one
	# just fought), so previously cleared enemies don't respawn whenever the
	# overworld scene reloads.
	for enemy_path in GameState.defeated_enemy_paths:
		if has_node(enemy_path):
			get_node(enemy_path).queue_free()
	
	# Likewise, restore every chest already opened this play session to its
	# opened state (no sprite/rewards re-trigger, just the visual).
	for chest_path in GameState.opened_chest_paths:
		if has_node(chest_path):
			var chest_node = get_node(chest_path)
			if chest_node.has_method("restore_opened_state"):
				chest_node.restore_opened_state()
	
	# Connect UI buttons
	bag_button.pressed.connect(_on_bag_button_pressed)
	inventory_panel.get_node("CloseButton").pressed.connect(_on_close_inventory_pressed)
	
	equipment_button.pressed.connect(_on_equipment_button_pressed)
	equipment_panel.get_node("CloseButton").pressed.connect(_on_close_equipment_pressed)
	
	stats_button.pressed.connect(_on_stats_button_pressed)
	stats_panel.get_node("CloseButton").pressed.connect(_on_close_stats_pressed)
	
	party_button.pressed.connect(_on_party_button_pressed)
	party_panel.get_node("CloseButton").pressed.connect(_on_close_party_pressed)
	
	# Setup inventory slots
	_setup_inventory_slots()
	_setup_equipment_slots()
	_setup_held_item_icon()
	
	update_player_hud()

func _setup_held_item_icon() -> void:
	## Floating icon shown at the mouse cursor while an inventory item is
	## picked up (either via click-to-pick-up or click-and-drag).
	held_item_icon = TextureRect.new()
	held_item_icon.name = "HeldItemIcon"
	held_item_icon.size = Vector2(56, 56)
	held_item_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	held_item_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	held_item_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	held_item_icon.modulate.a = 0.85
	held_item_icon.z_index = 100
	held_item_icon.visible = false
	$GameUI.add_child(held_item_icon)

func _on_close_inventory_pressed() -> void:
	UISound.play_click()
	is_inventory_open = false
	inventory_panel.visible = false
	if dragged_from_key != "":
		_end_holding_item("")

func _on_equipment_button_pressed() -> void:
	UISound.play_click()
	equipment_button.release_focus()  # Prevent space from toggling the button
	is_equipment_open = !is_equipment_open
	equipment_panel.visible = is_equipment_open
	if is_equipment_open:
		_refresh_equipment_display()
	elif dragged_from_key != "":
		_end_holding_item("")

func _on_close_equipment_pressed() -> void:
	UISound.play_click()
	is_equipment_open = false
	equipment_panel.visible = false
	if dragged_from_key != "":
		_end_holding_item("")

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

func _on_party_button_pressed() -> void:
	UISound.play_click()
	party_button.release_focus()  # Prevent space from toggling the button
	is_party_open = !is_party_open
	party_panel.visible = is_party_open
	if is_party_open:
		_refresh_party_display()
	elif dragged_from_key != "":
		_end_holding_item("")

func _on_close_party_pressed() -> void:
	UISound.play_click()
	is_party_open = false
	party_panel.visible = false
	if dragged_from_key != "":
		_end_holding_item("")

func _refresh_party_display() -> void:
	## Rebuilds one card per member currently in GameState.party_roster, so
	## the panel always reflects exactly who/how many party members the
	## player owns. Each card is an instance of the editable
	## party_member_card.tscn scene (see Scenes/Party/), so its layout can be
	## rearranged/restyled directly in the editor, just like PlayerHUD.
	for child in party_cards_container.get_children():
		party_cards_container.remove_child(child)
		child.queue_free()
	
	for i in range(GameState.party_roster.size()):
		var card = PartyMemberCardScene.instantiate()
		party_cards_container.add_child(card)
		card.setup(GameState.party_roster[i])
		_setup_party_card_slots(card, i)
	
	_refresh_party_equipment_display()
	_resize_party_panel(GameState.party_roster.size())

## Adds an item icon and wires up mouse/click handling for the Weapon/Cape/
## Trinket slots on one freshly-instanced party member card, so its gear
## slots support the exact same click-to-pick-up/drag-and-drop/right-click
## flow as the player's own Equipment panel.
func _setup_party_card_slots(card: Control, member_index: int) -> void:
	var equipment_row: Control = card.get_node_or_null("EquipmentRow")
	if not equipment_row:
		return
	for slot_name in PARTY_SLOT_NAMES:
		var slot: Panel = equipment_row.get_node_or_null(slot_name)
		if not slot:
			continue
		
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
		slot.mouse_entered.connect(_on_party_slot_mouse_entered.bind(member_index, slot_name))
		slot.mouse_exited.connect(_on_item_slot_mouse_exited)
		slot.gui_input.connect(_on_party_slot_gui_input.bind(member_index, slot_name))

## Updates every currently-shown party card's gear slot icons/labels to
## reflect GameState.party_equipped_slots, and re-runs setup() so the
## header's health bar/attack damage also pick up any equipment stat bonus
## change. Safe to call even if the Party panel has never been opened yet
## (no-ops with zero cards).
func _refresh_party_equipment_display() -> void:
	var cards = party_cards_container.get_children()
	for i in range(min(cards.size(), GameState.party_roster.size())):
		var member_data = GameState.party_roster[i]
		cards[i].setup(member_data)
		
		var equipment_row: Control = cards[i].get_node_or_null("EquipmentRow")
		if not equipment_row:
			continue
		for slot_name in PARTY_SLOT_NAMES:
			var slot: Panel = equipment_row.get_node_or_null(slot_name)
			if not slot:
				continue
			var icon_rect = slot.get_node_or_null("ItemIcon")
			var label = slot.get_node_or_null("Label")
			var equipped_item = GameState.get_party_equipped_item(member_data, slot_name)
			if icon_rect:
				icon_rect.modulate.a = 1.0  # Reset dimming left over from a pick-up gesture
				icon_rect.texture = equipped_item.icon if equipped_item else null
			if label:
				label.visible = (equipped_item == null)  # Show placeholder label only when slot is empty

func _resize_party_panel(card_count: int) -> void:
	## Shrinks/grows the Party window to fit exactly however many member
	## cards are currently shown, instead of always reserving room for a
	## full roster (which left a lot of empty space with only 1 member).
	## The panel is center-anchored in main_scene.tscn, so resizing it here
	## keeps it centered on screen no matter how big it gets.
	const CARD_WIDTH = 240.0
	const CARD_HEIGHT = 230.0
	const CARD_SPACING = 20.0
	const SIDE_PADDING = 20.0
	const TOP_AREA = 70.0
	const BOTTOM_PADDING = 20.0
	
	var count = max(card_count, 1)
	var content_width = SIDE_PADDING * 2 + CARD_WIDTH * count + CARD_SPACING * (count - 1)
	var content_height = TOP_AREA + CARD_HEIGHT + BOTTOM_PADDING
	
	party_panel.offset_left = -content_width / 2.0
	party_panel.offset_right = content_width / 2.0
	party_panel.offset_top = -content_height / 2.0
	party_panel.offset_bottom = content_height / 2.0
	
	var close_button = party_panel.get_node("CloseButton")
	close_button.offset_left = content_width - 43.0
	close_button.offset_right = content_width - 3.0
	
	party_cards_container.offset_right = party_cards_container.offset_left + CARD_WIDTH * count + CARD_SPACING * (count - 1)
	party_cards_container.offset_bottom = party_cards_container.offset_top + CARD_HEIGHT

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
		
		icon_rect.modulate.a = 1.0  # Reset dimming left over from a pick-up gesture
		var equipped_item = GameState.get_equipped_item(slot_name)
		icon_rect.texture = equipped_item.icon if equipped_item else null
		
		# Hide/show the label based on whether an item is equipped
		var label_name = slot_name.replace("Slot", "Label")
		var label = equipment_panel.get_node_or_null(label_name)
		if label:
			label.visible = (equipped_item == null)  # Show label only when slot is empty

func _on_gear_slot_gui_input(event: InputEvent, slot_name: String) -> void:
	var key = _equip_key(slot_name)
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_handle_slot_left_click(event, key)
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		if dragged_from_key != "":
			_end_holding_item("")  # Cancel any pick-up before unequipping
		GameState.unequip_slot(slot_name)
		_refresh_equipment_display()
		_refresh_inventory_display()
		refresh_stats_display()
		_hide_item_tooltip()

func _on_gear_slot_mouse_entered(slot_name: String) -> void:
	if dragged_from_key != "":
		return  # Don't show item tooltips while carrying a held item around
	var item = GameState.get_equipped_item(slot_name)
	if item:
		_show_item_tooltip(item)

func _on_party_slot_gui_input(event: InputEvent, member_index: int, slot_name: String) -> void:
	var key = _party_key(member_index, slot_name)
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_handle_slot_left_click(event, key)
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		if dragged_from_key != "":
			_end_holding_item("")  # Cancel any pick-up before unequipping
		if member_index >= 0 and member_index < GameState.party_roster.size():
			GameState.unequip_party_slot(GameState.party_roster[member_index], slot_name)
			_refresh_party_equipment_display()
			_refresh_inventory_display()
			_hide_item_tooltip()

func _on_party_slot_mouse_entered(member_index: int, slot_name: String) -> void:
	if dragged_from_key != "":
		return  # Don't show item tooltips while carrying a held item around
	if member_index >= 0 and member_index < GameState.party_roster.size():
		var item = GameState.get_party_equipped_item(GameState.party_roster[member_index], slot_name)
		if item:
			_show_item_tooltip(item)

func _on_bag_button_pressed() -> void:
	UISound.play_click()
	bag_button.release_focus()  # Prevent space from toggling the button
	is_inventory_open = !is_inventory_open
	inventory_panel.visible = is_inventory_open
	if is_inventory_open:
		_refresh_inventory_display()
	elif dragged_from_key != "":
		_end_holding_item("")

func _refresh_inventory_display() -> void:
	# Clear all slots first
	for slot in inventory_slots:
		var label = slot.get_node_or_null("ItemLabel")
		var icon_rect = slot.get_node_or_null("ItemIcon")
		if label:
			label.text = ""
		if icon_rect:
			icon_rect.texture = null
			icon_rect.modulate.a = 1.0  # Reset dimming left over from a pick-up gesture
	
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
	var key = _inv_key(slot_index)
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_handle_slot_left_click(event, key)
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		if dragged_from_key != "":
			_end_holding_item("")  # Cancel any pick-up before equipping
		if slot_index < GameState.player_inventory.size():
			var item = GameState.player_inventory[slot_index]
			if item and item.equip_slot != Item.EquipSlot.NONE:
				if item.item_type == Item.ItemType.PARTY_EQUIPMENT:
					# Ambiguous which member to equip onto via right-click, so
					# default to the first party member (drag-and-drop onto a
					# specific card is how you target a different member).
					if not GameState.is_party_item_equipped(item) and GameState.party_roster.size() > 0:
						GameState.equip_party_item(GameState.party_roster[0], item, slot_index)
						_refresh_inventory_display()
						_refresh_party_equipment_display()
						_hide_item_tooltip()
				elif not GameState.is_item_equipped(item):
					GameState.equip_item(item, slot_index)  # Pass the specific slot index
					_refresh_inventory_display()
					_refresh_equipment_display()
					refresh_stats_display()
					_hide_item_tooltip()

## Builds the string key used to identify an inventory bag slot.
func _inv_key(slot_index: int) -> String:
	return "inv:%d" % slot_index

## Builds the string key used to identify an equipment gear slot.
func _equip_key(slot_name: String) -> String:
	return "equip:%s" % slot_name

## Builds the string key used to identify a party member's gear slot.
func _party_key(member_index: int, slot_name: String) -> String:
	return "party:%d:%s" % [member_index, slot_name]

## Parses a "party:<member_index>:<slot_name>" key into its member resource,
## slot name, and index. Returns an empty "slot" if the key is malformed.
func _parse_party_key(key: String) -> Dictionary:
	var parts = key.substr(6).split(":", true, 1)
	if parts.size() < 2:
		return {"member": null, "slot": "", "index": -1}
	var member_index = int(parts[0])
	var member_data = null
	if member_index >= 0 and member_index < GameState.party_roster.size():
		member_data = GameState.party_roster[member_index]
	return {"member": member_data, "slot": parts[1], "index": member_index}

## Returns the item currently sitting in the slot identified by key, or null.
func _get_item_for_key(key: String) -> Item:
	if key.begins_with("inv:"):
		var idx = int(key.substr(4))
		if idx >= 0 and idx < GameState.player_inventory.size():
			return GameState.player_inventory[idx]
	elif key.begins_with("equip:"):
		return GameState.get_equipped_item(key.substr(6))
	elif key.begins_with("party:"):
		var info = _parse_party_key(key)
		if info.member:
			return GameState.get_party_equipped_item(info.member, info.slot)
	return null

## Finds the ItemIcon TextureRect for a given slot key, used to dim it while
## its item is being held/dragged.
func _get_icon_for_key(key: String) -> TextureRect:
	if key.begins_with("inv:"):
		var idx = int(key.substr(4))
		if idx >= 0 and idx < inventory_slots.size():
			return inventory_slots[idx].get_node_or_null("ItemIcon")
	elif key.begins_with("equip:"):
		var slot = equipment_panel.get_node_or_null(key.substr(6))
		if slot:
			return slot.get_node_or_null("ItemIcon")
	elif key.begins_with("party:"):
		var info = _parse_party_key(key)
		var cards = party_cards_container.get_children()
		if info.index >= 0 and info.index < cards.size():
			var equipment_row = cards[info.index].get_node_or_null("EquipmentRow")
			if equipment_row:
				var slot = equipment_row.get_node_or_null(info.slot)
				if slot:
					return slot.get_node_or_null("ItemIcon")
	return null

## Shared left-click handler for both inventory and equipment slots. Handles
## both "click to pick up, click again to drop" and "press, drag, release to
## drop" gestures.
func _handle_slot_left_click(event: InputEventMouseButton, key: String) -> void:
	if event.pressed:
		if dragged_from_key != "":
			# Already holding an item -> this click drops/swaps it into this slot
			_end_holding_item(key)
		else:
			_begin_holding_item(key)
	else:
		if dragged_from_key != "" and pending_click_key != "":
			if key == pending_click_key:
				# Press and release happened on the same slot without moving away
				# -> treat as a simple click, keep holding until the next click.
				pending_click_key = ""
			else:
				# Button was held down and released over a different slot -> drag & drop
				_end_holding_item(key)

func _begin_holding_item(key: String) -> void:
	## Picks up the item in the given slot so it can be moved to another slot,
	## either by clicking again later or by dragging with the button held down.
	var item = _get_item_for_key(key)
	if not item:
		return
	
	dragged_from_key = key
	pending_click_key = key
	held_item_icon.texture = item.icon
	held_item_icon.visible = true
	_update_held_item_position()
	
	# Dim the source slot's icon to show it has been picked up
	var icon_rect = _get_icon_for_key(key)
	if icon_rect:
		icon_rect.modulate.a = 0.3
	
	_hide_item_tooltip()

func _end_holding_item(target_key: String) -> void:
	## Resolves a pick-up/drag gesture: moves the held item to target_key if
	## that's a valid destination for it. Pass "" to cancel and leave the item
	## where it was.
	if dragged_from_key == "":
		return
	var source_key = dragged_from_key
	dragged_from_key = ""
	pending_click_key = ""
	held_item_icon.visible = false
	
	var source_icon = _get_icon_for_key(source_key)
	if source_icon:
		source_icon.modulate.a = 1.0
	
	if target_key != "" and target_key != source_key:
		_resolve_drop(source_key, target_key)
	
	_refresh_inventory_display()
	_refresh_equipment_display()
	_refresh_party_equipment_display()
	refresh_stats_display()
	_hide_item_tooltip()

## Returns "inv", "equip", or "party" depending on which kind of slot a key refers to.
func _key_kind(key: String) -> String:
	if key.begins_with("inv:"):
		return "inv"
	if key.begins_with("equip:"):
		return "equip"
	if key.begins_with("party:"):
		return "party"
	return ""

## Moves/swaps the item at source_key into target_key, respecting equipment
## slot type restrictions (e.g. a ring can only go into a ring slot, but may
## go into any of the 4; a party item can only go into a matching party gear
## slot). Invalid drops are silently rejected and change nothing. Player
## equipment (equip:) and party equipment (party:) never interact directly,
## since their EquipSlot types never overlap.
func _resolve_drop(source_key: String, target_key: String) -> void:
	var source_kind = _key_kind(source_key)
	var target_kind = _key_kind(target_key)
	
	if source_kind == "inv" and target_kind == "inv":
		var a = int(source_key.substr(4))
		var b = int(target_key.substr(4))
		if a < 0 or b < 0 or a >= GameState.player_inventory.size() or b >= GameState.player_inventory.size():
			return
		var temp = GameState.player_inventory[b]
		GameState.player_inventory[b] = GameState.player_inventory[a]
		GameState.player_inventory[a] = temp
	
	elif source_kind == "inv" and target_kind == "equip":
		var bag_index = int(source_key.substr(4))
		var slot_name = target_key.substr(6)
		if bag_index < 0 or bag_index >= GameState.player_inventory.size():
			return
		var item = GameState.player_inventory[bag_index]
		if not item or not GameState.is_valid_equip_slot(slot_name, item):
			return  # Wrong slot type for this item -> reject the drop
		GameState.equip_item_to_slot(item, slot_name, bag_index)
	
	elif source_kind == "equip" and target_kind == "inv":
		var slot_name = source_key.substr(6)
		var bag_index = int(target_key.substr(4))
		if bag_index < 0 or bag_index >= GameState.player_inventory.size():
			return
		var target_item = GameState.player_inventory[bag_index]
		if target_item:
			if not GameState.is_valid_equip_slot(slot_name, target_item):
				return  # Can't swap an incompatible item into this gear slot
			GameState.swap_equipment_with_bag_item(slot_name, bag_index)
		else:
			GameState.unequip_slot_to_bag_index(slot_name, bag_index)
	
	elif source_kind == "equip" and target_kind == "equip":
		var src_slot = source_key.substr(6)
		var tgt_slot = target_key.substr(6)
		var item = GameState.get_equipped_item(src_slot)
		if not item or not GameState.is_valid_equip_slot(tgt_slot, item):
			return  # e.g. can't move a ring into the Helm slot
		GameState.move_equipped_item(src_slot, tgt_slot)
	
	elif source_kind == "inv" and target_kind == "party":
		var bag_index = int(source_key.substr(4))
		var info = _parse_party_key(target_key)
		if not info.member or bag_index < 0 or bag_index >= GameState.player_inventory.size():
			return
		var item = GameState.player_inventory[bag_index]
		if not item or not GameState.is_valid_party_equip_slot(info.slot, item):
			return  # Wrong slot type for this item -> reject the drop
		GameState.equip_party_item_to_slot(info.member, item, info.slot, bag_index)
	
	elif source_kind == "party" and target_kind == "inv":
		var info = _parse_party_key(source_key)
		var bag_index = int(target_key.substr(4))
		if not info.member or bag_index < 0 or bag_index >= GameState.player_inventory.size():
			return
		var target_item = GameState.player_inventory[bag_index]
		if target_item:
			if not GameState.is_valid_party_equip_slot(info.slot, target_item):
				return  # Can't swap an incompatible item into this gear slot
			GameState.swap_party_equipment_with_bag_item(info.member, info.slot, bag_index)
		else:
			GameState.unequip_party_slot_to_bag_index(info.member, info.slot, bag_index)
	
	elif source_kind == "party" and target_kind == "party":
		var src_info = _parse_party_key(source_key)
		var tgt_info = _parse_party_key(target_key)
		if not src_info.member or not tgt_info.member:
			return
		var item = GameState.get_party_equipped_item(src_info.member, src_info.slot)
		if not item or not GameState.is_valid_party_equip_slot(tgt_info.slot, item):
			return  # e.g. can't move a weapon into a trinket slot
		GameState.move_party_equipped_item(src_info.member, src_info.slot, tgt_info.member, tgt_info.slot)
	
	# equip <-> party drops are intentionally left as no-ops: player gear and
	# party gear use entirely separate EquipSlot types, so such a drop would
	# never be valid anyway.

func _update_held_item_position() -> void:
	if not held_item_icon:
		return
	var mouse_pos = get_viewport().get_mouse_position()
	held_item_icon.position = mouse_pos - held_item_icon.size / 2.0

func _on_item_slot_mouse_entered(slot_index: int) -> void:
	if dragged_from_key != "":
		return  # Don't show item tooltips while carrying a held item around
	if slot_index < GameState.player_inventory.size():
		var item = GameState.player_inventory[slot_index]
		if item:
			_show_item_tooltip(item)

func _on_item_slot_mouse_exited() -> void:
	_hide_item_tooltip()

func _show_item_tooltip(item: Item) -> void:
	if not item:
		return
	
	inventory_tooltip_label.text = item.get_tooltip_text()
	inventory_tooltip.visible = true
	inventory_tooltip_visible = true
	# Let the label size the panel to fit the (possibly multi-line) BBCode text
	inventory_tooltip.reset_size()
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
	
	if dragged_from_key != "":
		_update_held_item_position()
		# If the mouse button was released somewhere outside any slot
		# (no gui_input fired to resolve the drag), cancel and snap back.
		if pending_click_key != "" and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			_end_holding_item("")
	
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
	hud_exp_label.text = str(int(GameState.player_current_exp)) + " / " + str(int(GameState.player_exp_to_next_level))
	
	hud_health_bar.max_value = GameState.player_max_health
	hud_health_bar.value = GameState.player_current_health
	hud_health_label.text = str(int(GameState.player_current_health)) + " / " + str(int(GameState.player_max_health))
	
	hud_mana_bar.max_value = GameState.player_max_mana
	hud_mana_bar.value = GameState.player_current_mana
	hud_mana_label.text = str(int(GameState.player_current_mana)) + " / " + str(int(GameState.player_max_mana))
