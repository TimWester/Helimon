extends Node

# Global autoload for simple UI feedback sounds, callable from any scene
# as UISound.play_click()

var click_player: AudioStreamPlayer

func _ready() -> void:
	click_player = AudioStreamPlayer.new()
	var generator = AudioStreamGenerator.new()
	generator.mix_rate = 44100.0
	generator.buffer_length = 0.5
	click_player.stream = generator
	add_child(click_player)

func play_click() -> void:
	if not click_player:
		return
	
	click_player.play()
	var playback: AudioStreamGeneratorPlayback = click_player.get_stream_playback()
	if not playback:
		return
	
	# Synthesize a short, crisp click: a quick descending tone with a snappy decay
	var sample_rate = 44100.0
	var duration = 0.06
	var frame_count = int(sample_rate * duration)
	
	for i in range(frame_count):
		var t = i / sample_rate
		var progress = t / duration
		var freq = lerp(1200.0, 700.0, progress)
		var envelope = pow(1.0 - progress, 3.0)
		var sample = sin(t * freq * TAU) * 0.25 * envelope
		playback.push_frame(Vector2(sample, sample))
