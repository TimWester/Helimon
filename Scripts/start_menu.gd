extends Node2D

@onready var new_game_button: Button = $UI/NewGameButton
@onready var options_button: Button = $UI/OptionsButton
@onready var quit_button: Button = $UI/QuitButton
@onready var options_panel: Panel = $UI/OptionsPanel
@onready var back_button: Button = $UI/OptionsPanel/BackButton
@onready var volume_slider: HSlider = $UI/OptionsPanel/VolumeSlider

var master_bus_index: int

func _ready() -> void:
	master_bus_index = AudioServer.get_bus_index("Master")
	
	# Initialize the slider to reflect the current master volume
	if not AudioServer.is_bus_mute(master_bus_index):
		volume_slider.value = db_to_linear(AudioServer.get_bus_volume_db(master_bus_index))
	else:
		volume_slider.value = 0.0
	
	new_game_button.pressed.connect(_on_new_game_pressed)
	options_button.pressed.connect(_on_options_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	back_button.pressed.connect(_on_back_pressed)
	volume_slider.value_changed.connect(_on_volume_changed)

func _on_new_game_pressed() -> void:
	UISound.play_click()
	get_tree().change_scene_to_file("res://Scenes/main_scene.tscn")

func _on_options_pressed() -> void:
	UISound.play_click()
	options_panel.visible = true

func _on_back_pressed() -> void:
	UISound.play_click()
	options_panel.visible = false

func _on_quit_pressed() -> void:
	UISound.play_click()
	get_tree().quit()

func _on_volume_changed(value: float) -> void:
	if value <= 0.001:
		AudioServer.set_bus_mute(master_bus_index, true)
	else:
		AudioServer.set_bus_mute(master_bus_index, false)
		AudioServer.set_bus_volume_db(master_bus_index, linear_to_db(value))
