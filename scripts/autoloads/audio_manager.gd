extends Node

const MIX_RATE := 22050.0
const BUFFER_LENGTH := 0.1

func play_sfx(id: String) -> void:
	var player := AudioStreamPlayer.new()
	var stream := AudioStreamGenerator.new()
	stream.mix_rate = MIX_RATE
	stream.buffer_length = BUFFER_LENGTH
	player.stream = stream
	add_child(player)
	player.play()
	var playback: AudioStreamGeneratorPlayback = player.get_stream_playback()
	_fill_buffer(playback, id)
	await player.finished
	player.queue_free()

func _fill_buffer(playback: AudioStreamGeneratorPlayback, id: String) -> void:
	match id:
		"buy":
			_sfx_buy(playback)
		"tick":
			_sfx_tick(playback)
		_:
			_sfx_default(playback)

func _sfx_buy(playback: AudioStreamGeneratorPlayback) -> void:
	var frames := int(MIX_RATE * 0.08)
	for i in frames:
		var t := float(i) / MIX_RATE
		var freq := 440.0 + 200.0 * t
		var vol := 1.0 - (float(i) / frames)
		var sample := sin(TAU * freq * t) * vol * 0.3
		playback.push_frame(Vector2(sample, sample))

func _sfx_tick(playback: AudioStreamGeneratorPlayback) -> void:
	var frames := int(MIX_RATE * 0.03)
	for i in frames:
		var t := float(i) / MIX_RATE
		var vol := 1.0 - (float(i) / frames)
		var sample := sin(TAU * 880.0 * t) * vol * 0.15
		playback.push_frame(Vector2(sample, sample))

func _sfx_default(playback: AudioStreamGeneratorPlayback) -> void:
	var frames := int(MIX_RATE * 0.05)
	for i in frames:
		var t := float(i) / MIX_RATE
		var vol := 1.0 - (float(i) / frames)
		var sample := sin(TAU * 660.0 * t) * vol * 0.2
		playback.push_frame(Vector2(sample, sample))
