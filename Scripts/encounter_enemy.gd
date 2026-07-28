extends Sprite2D
class_name EncounterEnemy

@export_group("Enemy Stats")
@export var max_health: float = 100.0
@export var attack_damage: float = 5.0
@export var attack_interval: float = 1.0

@onready var health_bar: ProgressBar = get_node_or_null("EnemyHealthBar")
@onready var attack_sound: AudioStreamPlayer = get_node_or_null("AttackSound")
@onready var attack_timer_bar: ProgressBar = get_node_or_null("AttackTimerBar")

var current_health: float
var start_position: Vector2

func _ready() -> void:
	current_health = max_health
	start_position = position
	_refresh_bars()

# Called by the encounter scene to set this enemy's stats and appearance
# based on whichever overworld monster was walked into, so the same
# encounter scene can be reused for many different enemy types.
func configure(new_max_health: float, new_attack_damage: float, new_attack_interval: float, new_texture: Texture2D = null) -> void:
	max_health = new_max_health
	attack_damage = new_attack_damage
	attack_interval = new_attack_interval
	if new_texture:
		texture = new_texture
	current_health = max_health
	_refresh_bars()

func _refresh_bars() -> void:
	if health_bar:
		health_bar.max_value = max_health
		health_bar.value = current_health
	if attack_timer_bar:
		attack_timer_bar.max_value = attack_interval
		attack_timer_bar.value = 0.0

func update_attack_timer(time_elapsed: float) -> void:
	if not attack_timer_bar:
		return
	attack_timer_bar.max_value = attack_interval
	attack_timer_bar.value = time_elapsed

func take_damage(damage: float) -> void:
	current_health -= damage
	if current_health < 0:
		current_health = 0
	if health_bar:
		health_bar.value = current_health

func perform_attack_animation() -> void:
	# Lunge forward then back, and play the attack sound
	var tween = create_tween()
	tween.tween_property(self, "position", start_position + Vector2(-50, 0), 0.15)
	tween.tween_property(self, "position", start_position, 0.15)
	play_attack_sound()

func play_attack_sound() -> void:
	if not attack_sound:
		return
	
	attack_sound.play()
	var playback: AudioStreamGeneratorPlayback = attack_sound.get_stream_playback()
	if not playback:
		return
	
	# Synthesize a short, low growling impact thud
	var sample_rate = 44100.0
	var duration = 0.18
	var frame_count = int(sample_rate * duration)
	
	for i in range(frame_count):
		var t = i / sample_rate
		var progress = t / duration
		var freq = lerp(160.0, 55.0, progress)
		var envelope = pow(1.0 - progress, 2.0)
		var noise = (randf() * 2.0 - 1.0) * 0.15 * envelope
		var sample = sin(t * freq * TAU) * 0.5 * envelope + noise
		playback.push_frame(Vector2(sample, sample))
