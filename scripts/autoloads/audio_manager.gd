extends Node

const MIX_RATE := 22050.0

func play_sfx(id: String) -> void:
	var duration := _get_duration(id)
	var player := AudioStreamPlayer.new()
	var stream := AudioStreamGenerator.new()
	stream.mix_rate = MIX_RATE
	stream.buffer_length = duration + 0.05
	player.stream = stream
	player.volume_db = -6.0
	add_child(player)
	player.play()
	var playback: AudioStreamGeneratorPlayback = player.get_stream_playback()
	_fill_buffer(playback, id)
	await player.finished
	player.queue_free()

func _get_duration(id: String) -> float:
	match id:
		"tick": return 0.025
		"buy": return 0.08
		"upgrade": return 0.12
		"prestige": return 0.4
		"wave_start": return 0.15
		"turret_fire": return 0.035
		"shockwave": return 0.12
		"enemy_hit": return 0.04
		"enemy_die": return 0.07
		"station_hit": return 0.1
		"game_over": return 0.35
		_: return 0.05

func _fill_buffer(playback: AudioStreamGeneratorPlayback, id: String) -> void:
	match id:
		"tick": _sfx_tick(playback)
		"buy": _sfx_buy(playback)
		"upgrade": _sfx_upgrade(playback)
		"prestige": _sfx_prestige(playback)
		"wave_start": _sfx_wave_start(playback)
		"turret_fire": _sfx_turret_fire(playback)
		"shockwave": _sfx_shockwave(playback)
		"enemy_hit": _sfx_enemy_hit(playback)
		"enemy_die": _sfx_enemy_die(playback)
		"station_hit": _sfx_station_hit(playback)
		"game_over": _sfx_game_over(playback)
		_: _sfx_default(playback)

# ── Idle SFX ─────────────────────────────────────────────────────────────────

func _sfx_tick(playback: AudioStreamGeneratorPlayback) -> void:
	# Tiny soft click — mining tap
	var frames := int(MIX_RATE * 0.025)
	for i in frames:
		var t := float(i) / MIX_RATE
		var env := 1.0 - (float(i) / frames)
		env *= env  # quadratic decay
		var sample := sin(TAU * 1200.0 * t) * env * 0.08
		playback.push_frame(Vector2(sample, sample))

func _sfx_buy(playback: AudioStreamGeneratorPlayback) -> void:
	# Quick ascending blip — module purchase
	var frames := int(MIX_RATE * 0.08)
	for i in frames:
		var t := float(i) / MIX_RATE
		var freq := 520.0 + 300.0 * t / 0.08
		var env := 1.0 - (float(i) / frames)
		var sample := sin(TAU * freq * t) * env * 0.15
		playback.push_frame(Vector2(sample, sample))

func _sfx_upgrade(playback: AudioStreamGeneratorPlayback) -> void:
	# Two-note ascending chime — research/talent upgrade
	var frames := int(MIX_RATE * 0.12)
	for i in frames:
		var t := float(i) / MIX_RATE
		var env := 1.0 - (float(i) / frames)
		var freq := 660.0 if t < 0.06 else 880.0
		var sample := sin(TAU * freq * t) * env * 0.15
		# Add soft harmonic
		sample += sin(TAU * freq * 2.0 * t) * env * 0.04
		playback.push_frame(Vector2(sample, sample))

func _sfx_prestige(playback: AudioStreamGeneratorPlayback) -> void:
	# Grand ascending sweep — prestige moment
	var frames := int(MIX_RATE * 0.4)
	for i in frames:
		var t := float(i) / MIX_RATE
		var progress := t / 0.4
		var env := sin(progress * PI) * 0.8  # bell curve
		var freq := 330.0 + 440.0 * progress
		var sample := sin(TAU * freq * t) * env * 0.12
		sample += sin(TAU * freq * 1.5 * t) * env * 0.05  # fifth harmonic
		sample += sin(TAU * freq * 2.0 * t) * env * 0.03  # octave
		playback.push_frame(Vector2(sample, sample))

# ── Minigame SFX ─────────────────────────────────────────────────────────────

func _sfx_wave_start(playback: AudioStreamGeneratorPlayback) -> void:
	# Alert tone — wave incoming
	var frames := int(MIX_RATE * 0.15)
	for i in frames:
		var t := float(i) / MIX_RATE
		var env := 1.0 - (float(i) / frames)
		var freq := 440.0 if t < 0.075 else 550.0
		var sample := sin(TAU * freq * t) * env * 0.12
		playback.push_frame(Vector2(sample, sample))

func _sfx_turret_fire(playback: AudioStreamGeneratorPlayback) -> void:
	# Short high ping — turret shot
	var frames := int(MIX_RATE * 0.035)
	for i in frames:
		var t := float(i) / MIX_RATE
		var env := 1.0 - (float(i) / frames)
		env *= env
		var sample := sin(TAU * 1800.0 * t) * env * 0.06
		playback.push_frame(Vector2(sample, sample))

func _sfx_shockwave(playback: AudioStreamGeneratorPlayback) -> void:
	# Low frequency sweep down — swipe shockwave
	var frames := int(MIX_RATE * 0.12)
	for i in frames:
		var t := float(i) / MIX_RATE
		var env := 1.0 - (float(i) / frames)
		var freq := 250.0 - 150.0 * (t / 0.12)
		var sample := sin(TAU * freq * t) * env * 0.18
		# Mix in noise for impact feel
		sample += (randf() * 2.0 - 1.0) * env * 0.06
		playback.push_frame(Vector2(sample, sample))

func _sfx_enemy_hit(playback: AudioStreamGeneratorPlayback) -> void:
	# Sharp click — bullet hits asteroid
	var frames := int(MIX_RATE * 0.04)
	for i in frames:
		var t := float(i) / MIX_RATE
		var env := 1.0 - (float(i) / frames)
		env = env * env * env  # steep decay
		var sample := sin(TAU * 900.0 * t) * env * 0.1
		sample += (randf() * 2.0 - 1.0) * env * 0.04
		playback.push_frame(Vector2(sample, sample))

func _sfx_enemy_die(playback: AudioStreamGeneratorPlayback) -> void:
	# Descending pop — asteroid destroyed
	var frames := int(MIX_RATE * 0.07)
	for i in frames:
		var t := float(i) / MIX_RATE
		var env := 1.0 - (float(i) / frames)
		var freq := 600.0 - 400.0 * (t / 0.07)
		var sample := sin(TAU * freq * t) * env * 0.14
		playback.push_frame(Vector2(sample, sample))

func _sfx_station_hit(playback: AudioStreamGeneratorPlayback) -> void:
	# Low rumble — station takes damage
	var frames := int(MIX_RATE * 0.1)
	for i in frames:
		var t := float(i) / MIX_RATE
		var env := 1.0 - (float(i) / frames)
		var sample := sin(TAU * 110.0 * t) * env * 0.2
		sample += (randf() * 2.0 - 1.0) * env * 0.08
		playback.push_frame(Vector2(sample, sample))

func _sfx_game_over(playback: AudioStreamGeneratorPlayback) -> void:
	# Descending three-note — game over
	var frames := int(MIX_RATE * 0.35)
	for i in frames:
		var t := float(i) / MIX_RATE
		var env := 1.0 - (float(i) / frames)
		var freq: float
		if t < 0.12:
			freq = 550.0
		elif t < 0.24:
			freq = 440.0
		else:
			freq = 330.0
		var sample := sin(TAU * freq * t) * env * 0.14
		sample += sin(TAU * freq * 0.5 * t) * env * 0.06  # sub octave
		playback.push_frame(Vector2(sample, sample))

func _sfx_default(playback: AudioStreamGeneratorPlayback) -> void:
	var frames := int(MIX_RATE * 0.05)
	for i in frames:
		var t := float(i) / MIX_RATE
		var env := 1.0 - (float(i) / frames)
		var sample := sin(TAU * 660.0 * t) * env * 0.1
		playback.push_frame(Vector2(sample, sample))
