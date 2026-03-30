extends Control

const TIER_NAMES := ["", "Tier 1", "Tier 2", "Tier 3", "Tier 4"]

var _talent_buttons: Dictionary = {}
var _orbits_label: Label = null
var _progress_label: Label = null
var _prestige_btn: Button = null

func _ready() -> void:
	EventBus.game_ready.connect(_on_game_ready)
	EventBus.resource_changed.connect(_on_resource_changed)
	EventBus.prestige_completed.connect(_on_prestige_completed)

func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and visible:
		_refresh_all()

func _on_game_ready() -> void:
	_build_ui()

func _on_resource_changed(type: String, _amount: float, _total: float) -> void:
	if type == "energy" or type == "orbits":
		if visible:
			_refresh_all()

func _on_prestige_completed(_orbits: int) -> void:
	_refresh_all()

# ── Build UI ─────────────────────────────────────────────────────────────────

func _build_ui() -> void:
	for child in get_children():
		child.queue_free()
	_talent_buttons.clear()

	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(scroll)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 16)
	vbox.mouse_filter = Control.MOUSE_FILTER_PASS
	scroll.add_child(vbox)

	# Margin
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	margin.mouse_filter = Control.MOUSE_FILTER_PASS
	vbox.add_child(margin)

	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 16)
	inner.mouse_filter = Control.MOUSE_FILTER_PASS
	margin.add_child(inner)

	# Header
	_orbits_label = Label.new()
	_orbits_label.add_theme_font_size_override("font_size", 40)
	_orbits_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	inner.add_child(_orbits_label)

	inner.add_child(HSeparator.new())

	# Talents by tier
	var p := GameManager.prestige
	var tiers: Dictionary = {}
	for tid in p.data:
		var tier: int = int(p.data[tid].get("tier", 1))
		if tier not in tiers:
			tiers[tier] = []
		tiers[tier].append(tid)

	for tier_num in range(1, 5):
		if tier_num not in tiers:
			continue
		var tier_label := Label.new()
		tier_label.text = TIER_NAMES[tier_num]
		tier_label.add_theme_font_size_override("font_size", 28)
		tier_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		inner.add_child(tier_label)

		for tid in tiers[tier_num]:
			var row := _create_talent_row(tid)
			inner.add_child(row)
			_talent_buttons[tid] = row

	inner.add_child(HSeparator.new())

	# Progress + prestige button
	_progress_label = Label.new()
	_progress_label.add_theme_font_size_override("font_size", 30)
	_progress_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	inner.add_child(_progress_label)

	_prestige_btn = Button.new()
	_prestige_btn.custom_minimum_size = Vector2(0, 110)
	_prestige_btn.add_theme_font_size_override("font_size", 36)
	_prestige_btn.pressed.connect(_on_prestige_pressed)
	inner.add_child(_prestige_btn)

	# ── DEV MENU ─────────────────────────────────────────────────────────
	inner.add_child(HSeparator.new())
	var dev_title := Label.new()
	dev_title.text = "[DEV]"
	dev_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dev_title.add_theme_font_size_override("font_size", 24)
	dev_title.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4))
	inner.add_child(dev_title)

	var dev_minigame := Button.new()
	dev_minigame.text = "Lancer Last Stand"
	dev_minigame.custom_minimum_size = Vector2(0, 70)
	dev_minigame.add_theme_font_size_override("font_size", 24)
	dev_minigame.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4))
	dev_minigame.pressed.connect(_on_dev_minigame)
	inner.add_child(dev_minigame)

	for eid in GameManager.events.data:
		var evt: Dictionary = GameManager.events.data[eid]
		var btn := Button.new()
		btn.text = "%s %s" % [evt.get("icon", ""), evt.get("title", eid)]
		btn.custom_minimum_size = Vector2(0, 60)
		btn.add_theme_font_size_override("font_size", 22)
		btn.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4))
		btn.pressed.connect(_on_dev_event.bind(eid))
		inner.add_child(btn)

	_refresh_all()

func _create_talent_row(tid: String) -> PanelContainer:
	var talent: Dictionary = GameManager.prestige.data[tid]

	var panel := PanelContainer.new()
	panel.name = tid
	panel.mouse_filter = Control.MOUSE_FILTER_PASS

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	margin.mouse_filter = Control.MOUSE_FILTER_PASS
	panel.add_child(margin)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)
	hbox.mouse_filter = Control.MOUSE_FILTER_PASS
	margin.add_child(hbox)

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.mouse_filter = Control.MOUSE_FILTER_PASS

	var name_lbl := Label.new()
	name_lbl.name = "NameLbl"
	name_lbl.text = talent.get("name", tid)
	name_lbl.add_theme_font_size_override("font_size", 32)
	info.add_child(name_lbl)

	var desc_lbl := Label.new()
	desc_lbl.name = "DescLbl"
	desc_lbl.text = talent.get("desc", "")
	desc_lbl.add_theme_font_size_override("font_size", 22)
	desc_lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	info.add_child(desc_lbl)

	var level_lbl := Label.new()
	level_lbl.name = "LevelLbl"
	level_lbl.add_theme_font_size_override("font_size", 26)
	info.add_child(level_lbl)

	hbox.add_child(info)

	var buy_btn := Button.new()
	buy_btn.name = "BuyBtn"
	buy_btn.custom_minimum_size = Vector2(160, 80)
	buy_btn.add_theme_font_size_override("font_size", 26)
	buy_btn.pressed.connect(_on_talent_buy.bind(tid))
	hbox.add_child(buy_btn)

	return panel

# ── Refresh ──────────────────────────────────────────────────────────────────

func _refresh_all() -> void:
	var p := GameManager.prestige
	if _orbits_label:
		_orbits_label.text = "⭐ %d Orbits (%d dispo)" % [p.orbits, p.get_available_orbits()]

	for tid in _talent_buttons:
		_refresh_talent_row(tid)

	if _progress_label:
		var produced := p.total_energy_produced
		var threshold := p.get_threshold()
		var pct := minf(produced / threshold, 1.0) * 100.0
		_progress_label.text = "⚡ %s / %s (%.0f%%)" % [
			NumberFormatter.format(produced),
			NumberFormatter.format(threshold),
			pct
		]

	if _prestige_btn:
		var pending := p.get_pending_orbits()
		if p.can_prestige():
			_prestige_btn.text = "PRESTIGE (+%d ⭐)" % pending
			_prestige_btn.disabled = false
		else:
			_prestige_btn.text = "PRESTIGE (+%d ⭐)" % pending
			_prestige_btn.disabled = true

func _refresh_talent_row(tid: String) -> void:
	var row: PanelContainer = _talent_buttons.get(tid)
	if not row:
		return
	var p := GameManager.prestige
	var level := p.get_talent_level(tid)
	var max_level := p.get_talent_max(tid)
	var cost := p.get_talent_cost(tid)

	var hbox: HBoxContainer = row.get_child(0).get_child(0)
	var info: VBoxContainer = hbox.get_child(0)
	var level_lbl: Label = info.get_node("LevelLbl")
	var buy_btn: Button = hbox.get_node("BuyBtn")

	level_lbl.text = "Niv %d/%d" % [level, max_level]

	if level >= max_level:
		buy_btn.text = "MAX"
		buy_btn.disabled = true
		level_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	else:
		buy_btn.text = "⭐ %d" % cost
		buy_btn.disabled = not p.can_buy_talent(tid)
		level_lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))

# ── Actions ──────────────────────────────────────────────────────────────────

func _on_talent_buy(tid: String) -> void:
	if GameManager.prestige.buy_talent(tid):
		AudioManager.play_sfx("upgrade")
		_refresh_all()

func _on_prestige_pressed() -> void:
	if GameManager.prestige.can_prestige():
		GameManager.start_prestige_minigame()

func _on_dev_minigame() -> void:
	GameManager.start_prestige_minigame()

func _on_dev_event(eid: String) -> void:
	var evt: Dictionary = GameManager.events.data[eid].duplicate(true)
	evt["id"] = eid
	EventBus.event_triggered.emit(evt)
