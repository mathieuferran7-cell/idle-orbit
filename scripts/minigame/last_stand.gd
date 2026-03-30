extends Node2D

enum State { COUNTDOWN, WAVE_ACTIVE, WAVE_PAUSE, GAME_OVER }

const CENTER := Vector2(540, 960)

var _data: Dictionary = {}
var _params: Dictionary = {}
var _state: int = State.COUNTDOWN
var _timer: float = 3.0
var _station_hp: int = 10
var _station_max_hp: int = 10
var _wave_index: int = 0
var _waves_survived: int = 0
var _enemies_spawned: int = 0
var _enemies_total: int = 0
var _spawn_timer: float = 0.0
var _current_wave: Dictionary = {}
var _swipe_cooldown: float = 0.0
var _swipe_start_pos: Vector2 = Vector2.ZERO
var _swipe_active: bool = false

var _enemies_node: Node2D
var _turrets_node: Node2D
var _projectiles_node: Node2D
var _shockwaves_node: Node2D
var _hud: CanvasLayer
var _hp_label: Label
var _wave_label: Label
var _center_label: Label
var _cooldown_label: Label
var _game_over_panel: Control

func _ready() -> void:
	_params = GameManager.get_minigame_params()
	_data = _params.get("data", {})

	var station_data: Dictionary = _data.get("station", {})
	var base_hp: int = int(station_data.get("base_hp", 10))
	var hp_per: int = int(station_data.get("hp_per_energy_module", 2))
	_station_max_hp = base_hp + _params.get("total_energy_modules", 0) * hp_per
	_station_hp = _station_max_hp

	# Containers
	_enemies_node = Node2D.new()
	_enemies_node.name = "Enemies"
	add_child(_enemies_node)

	_turrets_node = Node2D.new()
	_turrets_node.name = "Turrets"
	add_child(_turrets_node)

	_projectiles_node = Node2D.new()
	_projectiles_node.name = "Projectiles"
	add_child(_projectiles_node)

	_shockwaves_node = Node2D.new()
	_shockwaves_node.name = "Shockwaves"
	add_child(_shockwaves_node)

	_create_turrets()
	_build_hud()
	_state = State.COUNTDOWN
	_timer = 3.0
	_update_center_label("PREPAREZ-VOUS")

func _create_turrets() -> void:
	var turret_count := maxi(1, _params.get("total_tech_modules", 0))
	var turret_data: Dictionary = _data.get("turret", {})
	var orbit_radius: float = float(turret_data.get("orbit_radius", 80))
	for i in turret_count:
		var angle := (TAU / turret_count) * i
		var turret := MinigameTurret.new()
		turret.position = CENTER + Vector2.from_angle(angle) * orbit_radius
		turret.setup(turret_data, _enemies_node, _projectiles_node)
		_turrets_node.add_child(turret)

func _process(delta: float) -> void:
	_swipe_cooldown = maxf(0.0, _swipe_cooldown - delta)
	match _state:
		State.COUNTDOWN:
			_timer -= delta
			if _timer <= 0.0:
				_start_wave()
		State.WAVE_ACTIVE:
			_process_wave(delta)
		State.WAVE_PAUSE:
			_timer -= delta
			if _timer <= 0.0:
				_start_wave()
		State.GAME_OVER:
			pass
	_update_hud()
	queue_redraw()

func _process_wave(delta: float) -> void:
	# Spawn enemies
	if _enemies_spawned < _enemies_total:
		_spawn_timer -= delta
		if _spawn_timer <= 0.0:
			_spawn_enemy()
			_spawn_timer = float(_current_wave.get("spawn_interval", 1.0))

	# Wave complete: all spawned and all dead
	if _enemies_spawned >= _enemies_total and _enemies_node.get_child_count() == 0:
		_waves_survived = _wave_index + 1
		_wave_index += 1
		_state = State.WAVE_PAUSE
		_timer = float(_data.get("wave_pause_seconds", 3.0))
		_update_center_label("VAGUE %d TERMINEE" % _waves_survived)

func _start_wave() -> void:
	_current_wave = _get_wave_def(_wave_index)
	_enemies_spawned = 0
	_enemies_total = int(_current_wave.get("count", 4))
	_spawn_timer = 0.5
	_state = State.WAVE_ACTIVE
	_update_center_label("VAGUE %d" % (_wave_index + 1))
	AudioManager.play_sfx("wave_start")

func _get_wave_def(index: int) -> Dictionary:
	var waves: Array = _data.get("waves", [])
	if index < waves.size():
		return waves[index]
	# Overflow
	var base: Dictionary = waves[waves.size() - 1]
	var overflow: int = index - waves.size() + 1
	var growth: int = int(_data.get("overflow_wave_count_growth", 3))
	var decay: float = float(_data.get("overflow_wave_interval_decay", 0.05))
	var min_interval: float = float(_data.get("overflow_wave_min_interval", 0.25))
	return {
		"count": int(base.get("count", 18)) + overflow * growth,
		"types": base.get("types", ["small_asteroid"]),
		"spawn_interval": maxf(float(base.get("spawn_interval", 0.4)) - overflow * decay, min_interval),
	}

func _spawn_enemy() -> void:
	var types: Array = _current_wave.get("types", ["small_asteroid"])
	var type_id: String = types[randi() % types.size()]
	var enemies_data: Dictionary = _data.get("enemies", {})
	var type_data: Dictionary = enemies_data.get(type_id, {})

	var angle := randf() * TAU
	var spawn_pos := _get_edge_spawn(angle)

	var enemy := MinigameEnemy.new()
	enemy.setup(type_data, spawn_pos, CENTER)
	enemy.reached_station.connect(_on_station_hit)
	enemy.died.connect(_on_enemy_died)
	_enemies_node.add_child(enemy)
	_enemies_spawned += 1

func _get_edge_spawn(angle: float) -> Vector2:
	var margin: float = float(_data.get("spawn_margin", 50))
	var dir := Vector2.from_angle(angle)
	var t_values: Array[float] = []
	if dir.x > 0.001:
		t_values.append((1080.0 + margin - CENTER.x) / dir.x)
	elif dir.x < -0.001:
		t_values.append((-margin - CENTER.x) / dir.x)
	if dir.y > 0.001:
		t_values.append((1920.0 + margin - CENTER.y) / dir.y)
	elif dir.y < -0.001:
		t_values.append((-margin - CENTER.y) / dir.y)
	if t_values.is_empty():
		return CENTER + dir * 1000
	var t: float = t_values.min()
	return CENTER + dir * t

func _on_station_hit(damage: int) -> void:
	_station_hp -= damage
	AudioManager.play_sfx("station_hit")
	if _station_hp <= 0:
		_station_hp = 0
		_game_over()

func _on_enemy_died() -> void:
	pass

func _game_over() -> void:
	_state = State.GAME_OVER
	AudioManager.play_sfx("game_over")
	for enemy in _enemies_node.get_children():
		enemy.queue_free()
	for proj in _projectiles_node.get_children():
		proj.queue_free()
	for shock in _shockwaves_node.get_children():
		shock.queue_free()
	_show_results_panel()

# ── Input (swipe) ────────────────────────────────────────────────────────────

func _unhandled_input(event: InputEvent) -> void:
	if _state == State.GAME_OVER:
		return

	# Touch
	if event is InputEventScreenTouch:
		if event.pressed:
			_swipe_start_pos = event.position
			_swipe_active = true
		elif _swipe_active:
			_swipe_active = false
			_try_swipe(event.position)

	# Mouse (desktop testing)
	if event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_swipe_start_pos = event.position
			_swipe_active = true
		elif not event.pressed and event.button_index == MOUSE_BUTTON_LEFT and _swipe_active:
			_swipe_active = false
			_try_swipe(event.position)

func _try_swipe(end_pos: Vector2) -> void:
	var swipe_vec := end_pos - _swipe_start_pos
	var min_dist: float = float(_data.get("min_swipe_distance", 80))
	if swipe_vec.length() < min_dist:
		return
	if _swipe_cooldown > 0.0:
		return

	var swipe_data: Dictionary = _data.get("shockwave", {})
	_swipe_cooldown = float(swipe_data.get("cooldown", 1.5))

	var shock := MinigameShockwave.new()
	shock.position = CENTER
	shock.setup(swipe_data, swipe_vec.angle(), _enemies_node)
	_shockwaves_node.add_child(shock)
	AudioManager.play_sfx("shockwave")

# ── Drawing ──────────────────────────────────────────────────────────────────

func _draw() -> void:
	# Background
	draw_rect(Rect2(0, 0, 1080, 1920), Color(0.04, 0.04, 0.1))

	# Station
	var station_radius: float = float(_data.get("station", {}).get("radius", 60))
	draw_circle(CENTER, station_radius, Color(0.3, 0.35, 0.5))
	draw_arc(CENTER, station_radius, 0, TAU, 32, Color(0.4, 0.5, 0.7), 3.0)
	draw_arc(CENTER, station_radius * 0.7, 0, TAU, 24, Color(0.5, 0.7, 1.0), 2.0)

	# HP flash when damaged
	if _station_hp < _station_max_hp:
		var hp_ratio := float(_station_hp) / float(_station_max_hp)
		if hp_ratio < 0.3:
			draw_circle(CENTER, station_radius + 5, Color(1.0, 0.2, 0.1, 0.15))

# ── HUD ──────────────────────────────────────────────────────────────────────

func _build_hud() -> void:
	_hud = CanvasLayer.new()
	_hud.layer = 10
	add_child(_hud)

	# HP bar background
	var hp_bg := ColorRect.new()
	hp_bg.name = "HPBg"
	hp_bg.position = Vector2(40, 40)
	hp_bg.size = Vector2(1000, 40)
	hp_bg.color = Color(0.2, 0.2, 0.2)
	_hud.add_child(hp_bg)

	var hp_fill := ColorRect.new()
	hp_fill.name = "HPFill"
	hp_fill.position = Vector2(40, 40)
	hp_fill.size = Vector2(1000, 40)
	hp_fill.color = Color(0.3, 0.9, 0.4)
	_hud.add_child(hp_fill)

	_hp_label = Label.new()
	_hp_label.position = Vector2(40, 42)
	_hp_label.size = Vector2(1000, 40)
	_hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hp_label.add_theme_font_size_override("font_size", 28)
	_hud.add_child(_hp_label)

	_wave_label = Label.new()
	_wave_label.position = Vector2(0, 90)
	_wave_label.size = Vector2(1080, 50)
	_wave_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_wave_label.add_theme_font_size_override("font_size", 34)
	_hud.add_child(_wave_label)

	_center_label = Label.new()
	_center_label.position = Vector2(0, 800)
	_center_label.size = Vector2(1080, 100)
	_center_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_center_label.add_theme_font_size_override("font_size", 52)
	_center_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.3))
	_hud.add_child(_center_label)

	_cooldown_label = Label.new()
	_cooldown_label.position = Vector2(0, 1780)
	_cooldown_label.size = Vector2(1080, 60)
	_cooldown_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_cooldown_label.add_theme_font_size_override("font_size", 30)
	_hud.add_child(_cooldown_label)

func _update_center_label(text: String) -> void:
	if _center_label:
		_center_label.text = text
		# Auto-clear after 2 seconds
		var tw := create_tween()
		tw.tween_interval(2.0)
		tw.tween_callback(func(): _center_label.text = "")

func _update_hud() -> void:
	if not _hp_label:
		return

	# HP bar
	var hp_ratio := float(_station_hp) / float(_station_max_hp)
	var hp_fill: ColorRect = _hud.get_node("HPFill")
	hp_fill.size.x = 1000.0 * hp_ratio
	hp_fill.color = Color.GREEN.lerp(Color.RED, 1.0 - hp_ratio)
	_hp_label.text = "HP: %d / %d" % [_station_hp, _station_max_hp]

	# Wave
	_wave_label.text = "Vague %d" % (_wave_index + 1)

	# Cooldown
	var swipe_data: Dictionary = _data.get("shockwave", {})
	var max_cd: float = float(swipe_data.get("cooldown", 1.5))
	if _swipe_cooldown > 0.0:
		_cooldown_label.text = "Swipe: %.1fs" % _swipe_cooldown
		_cooldown_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	else:
		_cooldown_label.text = "SWIPE PRET"
		_cooldown_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.5))

# ── Game Over Panel ──────────────────────────────────────────────────────────

func _show_results_panel() -> void:
	if _game_over_panel:
		_game_over_panel.queue_free()

	_game_over_panel = Control.new()
	_game_over_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_game_over_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_hud.add_child(_game_over_panel)

	var bg := ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0, 0, 0, 0.8)
	_game_over_panel.add_child(bg)

	var card := PanelContainer.new()
	card.set_anchor(SIDE_LEFT, 0.5)
	card.set_anchor(SIDE_RIGHT, 0.5)
	card.set_anchor(SIDE_TOP, 0.5)
	card.set_anchor(SIDE_BOTTOM, 0.5)
	card.set_offset(SIDE_LEFT, -440)
	card.set_offset(SIDE_RIGHT, 440)
	card.set_offset(SIDE_TOP, -420)
	card.set_offset(SIDE_BOTTOM, 420)
	_game_over_panel.add_child(card)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 40)
	margin.add_theme_constant_override("margin_right", 40)
	margin.add_theme_constant_override("margin_top", 36)
	margin.add_theme_constant_override("margin_bottom", 36)
	card.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 18)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	margin.add_child(vbox)

	# Title
	var title := Label.new()
	title.text = "LAST STAND"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 48)
	vbox.add_child(title)

	var wave_lbl := Label.new()
	wave_lbl.text = "Vague %d" % (_waves_survived)
	wave_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	wave_lbl.add_theme_font_size_override("font_size", 30)
	wave_lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	vbox.add_child(wave_lbl)

	vbox.add_child(HSeparator.new())

	# Score breakdown
	var pending: int = _params.get("pending_orbits", 0)
	var bonus_mult: float = 1.0 + _waves_survived * float(_data.get("orbit_bonus_per_wave", 0.1))
	var final_orbits: int = int(pending * bonus_mult)

	var base_lbl := Label.new()
	base_lbl.text = "Orbits de base : %d ⭐" % pending
	base_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	base_lbl.add_theme_font_size_override("font_size", 32)
	base_lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	vbox.add_child(base_lbl)

	var mult_lbl := Label.new()
	mult_lbl.text = "Bonus Last Stand : x%.1f" % bonus_mult
	mult_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mult_lbl.add_theme_font_size_override("font_size", 32)
	mult_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	vbox.add_child(mult_lbl)

	var total_lbl := Label.new()
	total_lbl.text = "Total : %d ⭐" % final_orbits
	total_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	total_lbl.add_theme_font_size_override("font_size", 44)
	total_lbl.add_theme_color_override("font_color", Color(1.0, 0.9, 0.3))
	vbox.add_child(total_lbl)

	vbox.add_child(HSeparator.new())

	# Continue via ad (restart from current wave)
	var ad_btn := Button.new()
	ad_btn.text = "CONTINUER  📺"
	ad_btn.custom_minimum_size = Vector2(0, 100)
	ad_btn.add_theme_font_size_override("font_size", 34)
	ad_btn.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	ad_btn.pressed.connect(_on_ad_continue)
	vbox.add_child(ad_btn)

	# Prestige (finalize)
	var prestige_btn := Button.new()
	prestige_btn.text = "PRESTIGE (+%d ⭐)" % final_orbits
	prestige_btn.custom_minimum_size = Vector2(0, 100)
	prestige_btn.add_theme_font_size_override("font_size", 34)
	prestige_btn.pressed.connect(_on_prestige_confirm)
	vbox.add_child(prestige_btn)

func _on_ad_continue() -> void:
	AdManager.show_rewarded(func():
		if _game_over_panel:
			_game_over_panel.queue_free()
			_game_over_panel = null
		_station_hp = _station_max_hp
		_state = State.WAVE_PAUSE
		_timer = 1.0
		_update_center_label("ROUND %d" % (_wave_index + 1))
	)

func _on_prestige_confirm() -> void:
	GameManager.complete_prestige_with_bonus(_waves_survived)
