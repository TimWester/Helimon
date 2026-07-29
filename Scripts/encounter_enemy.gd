extends Sprite2D
class_name EncounterEnemy

signal attack_hit

@export_group("Enemy Stats")
@export var max_health: float = 100.0
@export var attack_damage: float = 5.0
@export var attack_interval: float = 1.0

@onready var health_bar: ProgressBar = get_node_or_null("EnemyHealthBar")
@onready var attack_sound: AudioStreamPlayer = get_node_or_null("AttackSound")
@onready var attack_timer_bar: ProgressBar = get_node_or_null("AttackTimerBar")
@onready var attack_anim: AnimatedSprite2D = get_node_or_null("AttackAnim")
@onready var projectile_anim: AnimatedSprite2D = get_node_or_null("ProjectileAnim")

var current_health: float
var start_position: Vector2
var idle_texture: Texture2D
var has_attack_animation: bool = false
var is_playing_attack: bool = false

const BLACK_TO_ALPHA_SHADER := preload("res://Shaders/black_to_alpha.gdshader")

func _ready() -> void:
	current_health = max_health
	start_position = position
	idle_texture = texture
	_refresh_bars()
	_ensure_anim_nodes()
	_hide_attack_visuals()

# Called by the encounter scene to set this enemy's stats and appearance
# based on whichever overworld monster was walked into, so the same
# encounter scene can be reused for many different enemy types.
func configure(
	new_max_health: float,
	new_attack_damage: float,
	new_attack_interval: float,
	new_texture: Texture2D = null,
	attack_sheet: Texture2D = null,
	attack_frame_count: int = 5,
	projectile_sheet: Texture2D = null,
	projectile_frame_count: int = 3
) -> void:
	max_health = new_max_health
	attack_damage = new_attack_damage
	attack_interval = new_attack_interval
	if new_texture:
		texture = new_texture
		idle_texture = new_texture
	current_health = max_health
	_refresh_bars()
	_ensure_anim_nodes()
	
	has_attack_animation = attack_sheet != null
	if attack_sheet:
		_apply_black_to_alpha(self)
		_apply_black_to_alpha(attack_anim)
		attack_anim.sprite_frames = _build_frames(attack_sheet, attack_frame_count, "attack", false, 8.0)
		attack_anim.animation = &"attack"
	
	if projectile_sheet:
		_apply_black_to_alpha(projectile_anim)
		projectile_anim.sprite_frames = _build_frames(projectile_sheet, projectile_frame_count, "projectile", false, 10.0)
		projectile_anim.animation = &"projectile"
		# Sit just to the left of the enemy so the slash reads as a projectile
		projectile_anim.position = Vector2(-90, 0)
	
	_hide_attack_visuals()

func _ensure_anim_nodes() -> void:
	if not attack_anim:
		attack_anim = AnimatedSprite2D.new()
		attack_anim.name = "AttackAnim"
		add_child(attack_anim)
	if not projectile_anim:
		projectile_anim = AnimatedSprite2D.new()
		projectile_anim.name = "ProjectileAnim"
		add_child(projectile_anim)
	
	if not attack_anim.animation_finished.is_connected(_on_attack_anim_finished):
		attack_anim.animation_finished.connect(_on_attack_anim_finished)
	if not projectile_anim.animation_finished.is_connected(_on_projectile_anim_finished):
		projectile_anim.animation_finished.connect(_on_projectile_anim_finished)

func _apply_black_to_alpha(node: CanvasItem) -> void:
	if not node:
		return
	var mat := ShaderMaterial.new()
	mat.shader = BLACK_TO_ALPHA_SHADER
	node.material = mat

func _build_frames(sheet: Texture2D, frame_count: int, anim_name: String, loop: bool, speed: float) -> SpriteFrames:
	var frames := SpriteFrames.new()
	frames.add_animation(anim_name)
	frames.set_animation_loop(anim_name, loop)
	frames.set_animation_speed(anim_name, speed)
	
	var safe_count = max(frame_count, 1)
	var frame_w = int(sheet.get_width() / float(safe_count))
	var frame_h = sheet.get_height()
	
	for i in range(safe_count):
		var atlas := AtlasTexture.new()
		atlas.atlas = sheet
		atlas.region = Rect2(i * frame_w, 0, frame_w, frame_h)
		frames.add_frame(anim_name, atlas)
	
	return frames

func _hide_attack_visuals() -> void:
	if attack_anim:
		attack_anim.visible = false
		attack_anim.stop()
	if projectile_anim:
		projectile_anim.visible = false
		projectile_anim.stop()
	if idle_texture:
		texture = idle_texture
	self_modulate.a = 1.0

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
	if has_attack_animation and attack_anim and attack_anim.sprite_frames:
		_play_sheet_attack()
	else:
		# Default lunge for enemies without a dedicated attack sheet.
		# Damage (and the hit sound) land when the enemy reaches the forward strike pose.
		is_playing_attack = true
		var tween = create_tween()
		tween.tween_property(self, "position", start_position + Vector2(-50, 0), 0.15)
		tween.tween_callback(_emit_attack_hit)
		tween.tween_property(self, "position", start_position, 0.15)
		tween.tween_callback(func(): is_playing_attack = false)

func _play_sheet_attack() -> void:
	is_playing_attack = true
	# Hide the idle texture while the attack sheet plays over the same spot
	self_modulate.a = 0.0
	if projectile_anim:
		projectile_anim.visible = false
		projectile_anim.stop()
	attack_anim.visible = true
	attack_anim.play(&"attack")

func _on_attack_anim_finished() -> void:
	if not is_playing_attack:
		return
	
	# Ghast attack finished — restore idle look, then fire the projectile
	if attack_anim:
		attack_anim.visible = false
		attack_anim.stop()
	if idle_texture:
		texture = idle_texture
	self_modulate.a = 1.0
	
	if projectile_anim and projectile_anim.sprite_frames:
		projectile_anim.visible = true
		projectile_anim.play(&"projectile")
	else:
		# No projectile sheet — land the hit as soon as the attack anim ends
		_emit_attack_hit()
		is_playing_attack = false

func _on_projectile_anim_finished() -> void:
	if projectile_anim:
		projectile_anim.visible = false
		projectile_anim.stop()
	# Projectile finished — this is the moment the attack lands
	_emit_attack_hit()
	is_playing_attack = false

func _emit_attack_hit() -> void:
	play_attack_sound()
	attack_hit.emit()

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
