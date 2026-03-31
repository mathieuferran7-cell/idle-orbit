extends Control

@onready var energy_label: Label = %EnergyLabel
@onready var energy_rate_label: Label = %EnergyRateLabel
@onready var tech_label: Label = %TechLabel
@onready var tech_rate_label: Label = %TechRateLabel
@onready var asteroid_btn: Button = %AsteroidZone
@onready var modules_panel: MarginContainer = %ModulesPanel
@onready var modules_container: VBoxContainer = %ModulesContainer
@onready var research_panel: Control = %ResearchPanel
@onready var tab_modules_btn: Button = %TabModulesBtn
@onready var tab_research_btn: Button = %TabResearchBtn
@onready var tab_prestige_btn: Button = %TabPrestigeBtn
@onready var tab_quests_btn: Button = %TabQuestsBtn
@onready var prestige_panel: Control = %PrestigePanel
@onready var quests_panel: Control = %QuestsPanel
@onready var mining_manager: MiningManager = $MiningManager

var _module_buttons: Dictionary = {}
var _asteroid_tween: Tween
var _offline_popup: Control = null
var _event_popup: Control = null
var _buff_label: Label = null
var _buy_mode_btn: Button = null
var _tap_particles: CPUParticles2D = null
var _quests_container: VBoxContainer = null
var _quest_badge: Label = null
const BUY_MODES := [1, 10, 25, 0]
var _buy_mode_index: int = 0

func _ready() -> void:
	EventBus.game_ready.connect(_on_game_ready)
	EventBus.resource_changed.connect(_on_resource_changed)
	EventBus.module_purchased.connect(_on_module_purchased)
	EventBus.mining_tapped.connect(_on_mining_tapped)
	EventBus.offline_gains_ready.connect(_on_offline_gains_ready)
	EventBus.module_unlocked.connect(_on_module_unlocked)
	EventBus.event_triggered.connect(_on_event_triggered)
	EventBus.buff_started.connect(_on_buff_changed)
	EventBus.buff_ended.connect(_on_buff_ended)
	EventBus.achievement_unlocked.connect(_on_achievement_unlocked)
	EventBus.quest_completed.connect(_on_quest_completed)
	EventBus.quest_progress.connect(_on_quest_progress)
	asteroid_btn.pressed.connect(_on_asteroid_tapped)
	tab_modules_btn.pressed.connect(_show_modules_tab)
	tab_research_btn.pressed.connect(_show_research_tab)
	tab_prestige_btn.pressed.connect(_show_prestige_tab)
	tab_quests_btn.pressed.connect(_show_quests_tab)
	# If returning from minigame, emit game_ready ourselves (autoload _post_init won't re-fire)
	if GameManager._post_prestige_pending >= 0:
		var orbits := GameManager._post_prestige_pending
		GameManager._post_prestige_pending = -1
		call_deferred("_emit_post_prestige", orbits)

func _emit_post_prestige(orbits: int) -> void:
	EventBus.game_ready.emit()
	EventBus.prestige_completed.emit(orbits)

func _on_game_ready() -> void:
	mining_manager.setup(GameManager.balance)
	_build_buy_mode_toggle()
	_build_buff_label()
	_build_module_list()
	_build_quest_badge()
	_refresh_all()
	_update_quest_badge()
	AdManager.show_banner()
	# Retroactive check: mark already-met achievements without granting rewards
	GameManager.achievements._suppress_rewards = true
	GameManager.achievements.check_all()
	GameManager.achievements._suppress_rewards = false
	if GameManager._return_to_prestige_tab:
		GameManager._return_to_prestige_tab = false
		_show_prestige_tab()
	else:
		_show_modules_tab()

func _show_modules_tab() -> void:
	_set_tab(modules_panel)

func _show_research_tab() -> void:
	_set_tab(research_panel)

func _show_prestige_tab() -> void:
	_set_tab(prestige_panel)

func _show_quests_tab() -> void:
	_set_tab(quests_panel)
	_build_quests_list()

func _set_tab(active: Control) -> void:
	var panels := [modules_panel, research_panel, prestige_panel, quests_panel]
	var buttons := [tab_modules_btn, tab_research_btn, tab_prestige_btn, tab_quests_btn]
	for i in panels.size():
		panels[i].visible = (panels[i] == active)
		buttons[i].disabled = (panels[i] == active)
	_fade_in_panel(active)

func _fade_in_panel(panel: Control) -> void:
	panel.modulate = Color(1, 1, 1, 0)
	var tw := create_tween()
	tw.tween_property(panel, "modulate", Color(1, 1, 1, 1), 0.15)

func _on_asteroid_tapped() -> void:
	mining_manager.tap()

func _on_mining_tapped(_tech_gained: float) -> void:
	if _asteroid_tween:
		_asteroid_tween.kill()
	asteroid_btn.pivot_offset = asteroid_btn.size / 2.0
	_asteroid_tween = create_tween()
	_asteroid_tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_asteroid_tween.tween_property(asteroid_btn, "scale", Vector2(1.06, 1.06), 0.06)
	_asteroid_tween.tween_property(asteroid_btn, "scale", Vector2(1.0, 1.0), 0.12)
	_asteroid_tween.parallel().tween_property(
		asteroid_btn, "modulate", Color(1.4, 1.2, 0.6), 0.06
	)
	_asteroid_tween.tween_property(asteroid_btn, "modulate", Color(1.0, 1.0, 1.0), 0.15)
	# Tap particles burst
	_emit_tap_particles()
	# Floating "+N 🔧" at tap point
	_show_floating_text(_tech_gained)

func _show_floating_text(amount: float) -> void:
	var lbl := Label.new()
	lbl.text = "+" + NumberFormatter.format(amount) + " 🔧"
	var buffs: Dictionary = GameManager.events.get_active_buffs()
	if buffs.has("tap_x3"):
		lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	else:
		lbl.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
	lbl.add_theme_font_size_override("font_size", 32)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.position = asteroid_btn.global_position + asteroid_btn.size / 2.0 - Vector2(60, 20)
	add_child(lbl)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(lbl, "position:y", lbl.position.y - 60.0, 0.7).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tw.tween_property(lbl, "modulate:a", 0.0, 0.3).set_delay(0.4)
	tw.chain().tween_callback(lbl.queue_free)

func _emit_tap_particles() -> void:
	if not _tap_particles:
		_tap_particles = CPUParticles2D.new()
		_tap_particles.name = "TapParticles"
		_tap_particles.emitting = false
		_tap_particles.one_shot = true
		_tap_particles.amount = 12
		_tap_particles.lifetime = 0.5
		_tap_particles.explosiveness = 1.0
		_tap_particles.direction = Vector2(0, -1)
		_tap_particles.spread = 60.0
		_tap_particles.initial_velocity_min = 80.0
		_tap_particles.initial_velocity_max = 200.0
		_tap_particles.gravity = Vector2(0, 120)
		_tap_particles.scale_amount_min = 2.0
		_tap_particles.scale_amount_max = 4.0
		_tap_particles.color = Color(1.0, 0.85, 0.3, 0.9)
		asteroid_btn.add_child(_tap_particles)
	_tap_particles.position = asteroid_btn.size / 2.0
	_tap_particles.restart()

func _build_buff_label() -> void:
	if _buff_label and is_instance_valid(_buff_label):
		return
	# Insert below AsteroidZone in the header VBox
	var header_vbox: VBoxContainer = asteroid_btn.get_parent()
	_buff_label = Label.new()
	_buff_label.name = "BuffLabel"
	_buff_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_buff_label.add_theme_font_size_override("font_size", 24)
	_buff_label.add_theme_color_override("font_color", Color(0.9, 0.8, 0.3))
	header_vbox.add_child(_buff_label)

func _build_quest_badge() -> void:
	if _quest_badge and is_instance_valid(_quest_badge):
		return
	_quest_badge = Label.new()
	_quest_badge.name = "QuestBadge"
	_quest_badge.add_theme_font_size_override("font_size", 22)
	_quest_badge.add_theme_color_override("font_color", Color(1.0, 0.65, 0.0))
	_quest_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_quest_badge.visible = false
	tab_quests_btn.add_child(_quest_badge)
	_quest_badge.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_quest_badge.set_offset(SIDE_RIGHT, -8)
	_quest_badge.set_offset(SIDE_TOP, 4)

func _build_buy_mode_toggle() -> void:
	if _buy_mode_btn and is_instance_valid(_buy_mode_btn):
		return
	_buy_mode_btn = Button.new()
	_buy_mode_btn.name = "BuyModeBtn"
	_buy_mode_btn.custom_minimum_size = Vector2(0, 70)
	_buy_mode_btn.add_theme_font_size_override("font_size", 30)
	_buy_mode_btn.text = "x1"
	_buy_mode_btn.pressed.connect(_on_buy_mode_toggle)
	# Add to ModulesVBox wrapper (sticky, above ScrollContainer)
	var modules_vbox: VBoxContainer = modules_container.get_parent().get_parent()
	modules_vbox.add_child(_buy_mode_btn)
	modules_vbox.move_child(_buy_mode_btn, 0)

func _on_buy_mode_toggle() -> void:
	_buy_mode_index = (_buy_mode_index + 1) % BUY_MODES.size()
	var mode: int = BUY_MODES[_buy_mode_index]
	_buy_mode_btn.text = "MAX" if mode == 0 else "x%d" % mode
	_refresh_all()

func _get_buy_amount() -> int:
	return BUY_MODES[_buy_mode_index]

func _build_module_list() -> void:
	for child in modules_container.get_children():
		child.queue_free()
	_module_buttons.clear()

	for module_id in GameManager.modules_data:
		var row := _create_module_row(module_id)
		modules_container.add_child(row)
		_module_buttons[module_id] = row

func _create_module_row(module_id: String) -> PanelContainer:
	var mod: Dictionary = GameManager.modules_data[module_id]

	var panel := PanelContainer.new()
	panel.name = module_id
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

	var info_vbox := VBoxContainer.new()
	info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_vbox.mouse_filter = Control.MOUSE_FILTER_PASS

	var name_label := Label.new()
	name_label.name = "NameLabel"
	name_label.text = mod.get("name", module_id)
	name_label.add_theme_font_size_override("font_size", 38)
	info_vbox.add_child(name_label)

	var desc_label := Label.new()
	desc_label.name = "DescLabel"
	desc_label.text = mod.get("description", "")
	desc_label.add_theme_font_size_override("font_size", 24)
	desc_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	info_vbox.add_child(desc_label)

	var stats_label := Label.new()
	stats_label.name = "StatsLabel"
	stats_label.add_theme_font_size_override("font_size", 28)
	info_vbox.add_child(stats_label)

	hbox.add_child(info_vbox)

	var buy_btn := Button.new()
	buy_btn.name = "BuyButton"
	buy_btn.custom_minimum_size = Vector2(200, 90)
	buy_btn.add_theme_font_size_override("font_size", 28)
	buy_btn.pressed.connect(_on_buy_pressed.bind(module_id))
	hbox.add_child(buy_btn)

	return panel

func _on_buy_pressed(module_id: String) -> void:
	var amount := _get_buy_amount()
	if amount == 1:
		if GameManager.buy_module(module_id):
			AudioManager.play_sfx("buy")
	else:
		if GameManager.buy_module_bulk(module_id, amount):
			AudioManager.play_sfx("buy")

func _on_resource_changed(_type: String, _amount: float, _total: float) -> void:
	_refresh_all()

func _on_module_purchased(_module_id: String, _count: int) -> void:
	_refresh_all()
	# Flash the purchased module row
	var row: PanelContainer = _module_buttons.get(_module_id)
	if row:
		var tw := create_tween()
		tw.tween_property(row, "modulate", Color(0.5, 1.0, 0.5), 0.08)
		tw.tween_property(row, "modulate", Color(1, 1, 1), 0.2)

func _on_module_unlocked(_module_id: String) -> void:
	_build_module_list()
	_refresh_all()

func _refresh_all() -> void:
	energy_label.text = "⚡ " + NumberFormatter.format(GameManager.energy)
	var energy_rate := GameManager.get_total_production("energy")
	energy_rate_label.text = NumberFormatter.format(energy_rate) + "/s"

	tech_label.text = "🔧 " + NumberFormatter.format(GameManager.tech)
	var tech_rate := GameManager.get_total_production("tech")
	if tech_rate > 0.0:
		tech_rate_label.text = NumberFormatter.format(tech_rate) + "/s"
	else:
		tech_rate_label.text = "tap!"

	asteroid_btn.disabled = not mining_manager.can_tap()
	_refresh_buffs()

	for module_id in _module_buttons:
		_refresh_module_row(module_id)

func _refresh_module_row(module_id: String) -> void:
	var row: PanelContainer = _module_buttons.get(module_id)
	if not row:
		return

	var unlocked := GameManager.is_module_unlocked(module_id)
	row.visible = unlocked

	if not unlocked:
		return

	var count: int = GameManager.module_counts.get(module_id, 0)
	var cost := GameManager.get_module_cost(module_id)
	var mod: Dictionary = GameManager.modules_data[module_id]
	var prod: float = mod.get("base_production", 0.0)
	var res_icon := "⚡" if mod.get("resource", "energy") == "energy" else "🔧"

	var hbox: HBoxContainer = row.get_child(0).get_child(0)
	var info_vbox: VBoxContainer = hbox.get_child(0)
	var stats_label: Label = info_vbox.get_node("StatsLabel")
	stats_label.text = "x%d  |  +%s%s/s" % [count, res_icon, NumberFormatter.format(prod * count)]

	var buy_btn: Button = hbox.get_node("BuyButton")
	var amount := _get_buy_amount()
	if amount == 0:
		var max_n := GameManager.get_max_affordable(module_id)
		if max_n > 0:
			var bulk_cost := GameManager.get_bulk_cost(module_id, max_n)
			buy_btn.text = "MAX(%d) ⚡%s" % [max_n, NumberFormatter.format(bulk_cost)]
			buy_btn.disabled = false
		else:
			buy_btn.text = "MAX ⚡%s" % NumberFormatter.format(cost)
			buy_btn.disabled = true
	elif amount == 1:
		buy_btn.text = "⚡ %s" % NumberFormatter.format(cost)
		buy_btn.disabled = not GameManager.can_afford_module(module_id)
	else:
		var bulk_cost := GameManager.get_bulk_cost(module_id, amount)
		buy_btn.text = "x%d ⚡%s" % [amount, NumberFormatter.format(bulk_cost)]
		buy_btn.disabled = bulk_cost > GameManager.energy

# ── Offline Popup ────────────────────────────────────────────────────────────

func _on_offline_gains_ready(gains: Dictionary) -> void:
	_build_offline_popup(gains)

func _build_offline_popup(gains: Dictionary) -> void:
	if _offline_popup:
		_offline_popup.queue_free()

	var seconds: float = gains.get("seconds", 0.0)
	var energy_gained: float = gains.get("energy", 0.0)
	var tech_gained: float = gains.get("tech", 0.0)

	# Format duration
	var hours := int(seconds) / 3600
	var minutes := (int(seconds) % 3600) / 60
	var duration_text: String
	if hours > 0:
		duration_text = "%dh %02dmin" % [hours, minutes]
	else:
		duration_text = "%d min" % minutes

	# Overlay
	_offline_popup = Control.new()
	_offline_popup.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_offline_popup.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_offline_popup)

	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.8)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	_offline_popup.add_child(bg)

	# Card
	var card := PanelContainer.new()
	card.set_anchor(SIDE_LEFT, 0.5)
	card.set_anchor(SIDE_RIGHT, 0.5)
	card.set_anchor(SIDE_TOP, 0.5)
	card.set_anchor(SIDE_BOTTOM, 0.5)
	card.set_offset(SIDE_LEFT, -420)
	card.set_offset(SIDE_RIGHT, 420)
	card.set_offset(SIDE_TOP, -340)
	card.set_offset(SIDE_BOTTOM, 340)
	_offline_popup.add_child(card)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 48)
	margin.add_theme_constant_override("margin_right", 48)
	margin.add_theme_constant_override("margin_top", 40)
	margin.add_theme_constant_override("margin_bottom", 40)
	card.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 24)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	margin.add_child(vbox)

	# Title
	var title := Label.new()
	title.text = "BIENVENUE !"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 52)
	vbox.add_child(title)

	# Duration
	var dur_lbl := Label.new()
	dur_lbl.text = "Absent %s" % duration_text
	dur_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dur_lbl.add_theme_font_size_override("font_size", 32)
	dur_lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	vbox.add_child(dur_lbl)

	vbox.add_child(HSeparator.new())

	# Gains
	if energy_gained > 0.0:
		var e_lbl := Label.new()
		e_lbl.text = "⚡ +%s Énergie" % NumberFormatter.format(energy_gained)
		e_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		e_lbl.add_theme_font_size_override("font_size", 40)
		e_lbl.add_theme_color_override("font_color", Color(0.6, 0.85, 1.0))
		vbox.add_child(e_lbl)

	if tech_gained > 0.0:
		var t_lbl := Label.new()
		t_lbl.text = "🔧 +%s Tech" % NumberFormatter.format(tech_gained)
		t_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		t_lbl.add_theme_font_size_override("font_size", 40)
		t_lbl.add_theme_color_override("font_color", Color(0.6, 1.0, 0.7))
		vbox.add_child(t_lbl)

	if energy_gained <= 0.0 and tech_gained <= 0.0:
		var no_lbl := Label.new()
		no_lbl.text = "Aucune production active"
		no_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		no_lbl.add_theme_font_size_override("font_size", 30)
		no_lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		vbox.add_child(no_lbl)

	vbox.add_child(HSeparator.new())

	# Collect button
	var collect_btn := Button.new()
	collect_btn.text = "COLLECTER"
	collect_btn.custom_minimum_size = Vector2(0, 100)
	collect_btn.add_theme_font_size_override("font_size", 36)
	collect_btn.pressed.connect(_on_offline_collect.bind(1.0))
	vbox.add_child(collect_btn)

	# Ad x2 button
	var ad_btn := Button.new()
	ad_btn.text = "x2  📺"
	ad_btn.custom_minimum_size = Vector2(0, 100)
	ad_btn.add_theme_font_size_override("font_size", 36)
	ad_btn.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	ad_btn.pressed.connect(_on_offline_collect.bind(2.0))
	vbox.add_child(ad_btn)

func _on_offline_collect(multiplier: float) -> void:
	if multiplier == 2.0:
		AdManager.show_rewarded(func():
			GameManager.claim_offline_gains(2.0)
			if _offline_popup:
				_offline_popup.queue_free()
				_offline_popup = null
		)
	else:
		GameManager.claim_offline_gains(1.0)
		if _offline_popup:
			_offline_popup.queue_free()
			_offline_popup = null

# ── Event Popup (FTL style) ──────────────────────────────────────────────────

func _on_event_triggered(event_data: Dictionary) -> void:
	_build_event_popup(event_data)

func _on_buff_changed(_buff_id: String, _duration: float = 0.0) -> void:
	_refresh_buffs()

func _on_buff_ended(_buff_id: String) -> void:
	_refresh_buffs()

func _refresh_buffs() -> void:
	if not _buff_label or not is_instance_valid(_buff_label):
		return
	var buffs := GameManager.events.get_active_buffs()
	if buffs.is_empty():
		_buff_label.text = ""
		return
	var parts: Array[String] = []
	for buff in buffs:
		var icon := _buff_icon(buff.id)
		parts.append("%s %ds" % [icon, int(buff.remaining)])
	_buff_label.text = "  ".join(parts)

func _buff_icon(buff_id: String) -> String:
	match buff_id:
		"energy_x2": return "⚡x2"
		"tech_x2": return "🔧x2"
		"speed_x2": return "⏩x2"
		"tap_x3": return "👆x3"
		"research_discount": return "🔬-50%"
		_: return buff_id

func _build_event_popup(event_data: Dictionary) -> void:
	if _event_popup:
		_event_popup.queue_free()

	_event_popup = Control.new()
	_event_popup.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_event_popup.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_event_popup)

	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.8)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	_event_popup.add_child(bg)

	var card := PanelContainer.new()
	card.set_anchor(SIDE_LEFT, 0.5)
	card.set_anchor(SIDE_RIGHT, 0.5)
	card.set_anchor(SIDE_TOP, 0.5)
	card.set_anchor(SIDE_BOTTOM, 0.5)
	card.set_offset(SIDE_LEFT, -460)
	card.set_offset(SIDE_RIGHT, 460)
	card.set_offset(SIDE_TOP, -440)
	card.set_offset(SIDE_BOTTOM, 440)
	_event_popup.add_child(card)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 40)
	margin.add_theme_constant_override("margin_right", 40)
	margin.add_theme_constant_override("margin_top", 36)
	margin.add_theme_constant_override("margin_bottom", 36)
	card.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	margin.add_child(vbox)

	# Title with icon
	var icon: String = event_data.get("icon", "")
	var title_text: String = event_data.get("title", "Événement")
	var title := Label.new()
	title.text = "%s  %s" % [icon, title_text]
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 42)
	vbox.add_child(title)

	vbox.add_child(HSeparator.new())

	# Body text
	var body := Label.new()
	body.text = event_data.get("text", "")
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_theme_font_size_override("font_size", 28)
	body.add_theme_color_override("font_color", Color(0.75, 0.75, 0.75))
	vbox.add_child(body)

	vbox.add_child(HSeparator.new())

	# Choices
	var choices: Array = event_data.get("choices", [])
	for i in choices.size():
		var choice: Dictionary = choices[i]
		var is_premium: bool = choice.get("premium", false)
		var btn := Button.new()
		var label_text: String = choice.get("label", "Choix")
		var desc_text: String = choice.get("desc", "")
		if is_premium:
			btn.text = "📺  %s\n%s" % [label_text, desc_text]
			btn.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
		else:
			btn.text = "%s\n%s" % [label_text, desc_text]
		btn.custom_minimum_size = Vector2(0, 90)
		btn.add_theme_font_size_override("font_size", 26)
		btn.pressed.connect(_on_event_choice.bind(choice.get("reward", {}), is_premium))
		vbox.add_child(btn)

func _on_event_choice(reward: Dictionary, is_premium: bool = false) -> void:
	if is_premium:
		AdManager.show_rewarded(func():
			_apply_event_reward(reward)
		)
	else:
		_apply_event_reward(reward)

func _apply_event_reward(reward: Dictionary) -> void:
	var result_text := GameManager.events.apply_reward(reward)
	GameManager.events.on_choice_made()
	if _event_popup:
		_event_popup.queue_free()
		_event_popup = null
	_show_reward_toast(result_text)

func _show_reward_toast(text: String) -> void:
	var toast := Label.new()
	toast.text = text
	toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	toast.set_offset(SIDE_TOP, 160)
	toast.set_offset(SIDE_LEFT, -400)
	toast.set_offset(SIDE_RIGHT, 400)
	toast.add_theme_font_size_override("font_size", 40)
	toast.add_theme_color_override("font_color", Color(1.0, 0.9, 0.3))
	toast.modulate.a = 1.0
	add_child(toast)
	var tw := create_tween()
	tw.tween_interval(1.5)
	tw.tween_property(toast, "modulate:a", 0.0, 0.5)
	tw.tween_callback(toast.queue_free)

# ── Achievement toast ────────────────────────────────────────────────────────

func _on_achievement_unlocked(_ach_id: String, ach_data: Dictionary) -> void:
	var icon: String = ach_data.get("icon", "🏆")
	var ach_name: String = ach_data.get("name", "")
	_show_reward_toast("%s %s" % [icon, ach_name])

# ── Quests UI ────────────────────────────────────────────────────────────────

func _on_quest_completed(_quest_id: String) -> void:
	_update_quest_badge()
	if quests_panel.visible:
		_build_quests_list()

func _on_quest_progress(_quest_id: String, _current: int, _target: int) -> void:
	if quests_panel.visible:
		_build_quests_list()

func _update_quest_badge() -> void:
	var count := GameManager.quests.get_claimable_count()
	if _quest_badge:
		_quest_badge.text = str(count) if count > 0 else ""
		_quest_badge.visible = count > 0

func _build_quests_list() -> void:
	if not _quests_container:
		# Create scroll + container inside quests_panel
		var scroll := ScrollContainer.new()
		scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		scroll.add_theme_constant_override("margin_left", 24)
		quests_panel.add_child(scroll)
		_quests_container = VBoxContainer.new()
		_quests_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_quests_container.add_theme_constant_override("separation", 12)
		scroll.add_child(_quests_container)
		# Ensure scroll works on mobile
		scroll.mouse_filter = Control.MOUSE_FILTER_PASS
		_quests_container.mouse_filter = Control.MOUSE_FILTER_PASS

	# Clear existing
	for child in _quests_container.get_children():
		child.queue_free()

	# Header: Daily
	var daily_header := Label.new()
	daily_header.text = "QUOTIDIENNES"
	daily_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	daily_header.add_theme_font_size_override("font_size", 34)
	daily_header.add_theme_color_override("font_color", Color(1.0, 0.9, 0.3))
	_quests_container.add_child(daily_header)

	for quest in GameManager.quests.get_active_daily():
		_quests_container.add_child(_create_quest_row(quest, "daily"))

	# Separator
	_quests_container.add_child(HSeparator.new())

	# Header: Weekly
	var weekly_header := Label.new()
	weekly_header.text = "HEBDOMADAIRES"
	weekly_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	weekly_header.add_theme_font_size_override("font_size", 34)
	weekly_header.add_theme_color_override("font_color", Color(0.6, 0.85, 1.0))
	_quests_container.add_child(weekly_header)

	for quest in GameManager.quests.get_weekly():
		_quests_container.add_child(_create_quest_row(quest, "weekly"))

	# Achievements summary
	_quests_container.add_child(HSeparator.new())
	var ach_header := Label.new()
	var unlocked := GameManager.achievements.get_unlocked_count()
	var total := GameManager.achievements.data.size()
	ach_header.text = "ACHIEVEMENTS : %d / %d" % [unlocked, total]
	ach_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ach_header.add_theme_font_size_override("font_size", 30)
	ach_header.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	_quests_container.add_child(ach_header)

func _create_quest_row(quest: Dictionary, _category: String) -> PanelContainer:
	var qid: String = quest.get("id", "")
	var target: int = GameManager.quests._get_scaled_target(quest)
	var progress: int = GameManager.quests.get_progress(qid)
	var claimed: bool = GameManager.quests.is_claimed(qid)
	var completable: bool = GameManager.quests.is_completable(qid)

	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_PASS

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	margin.mouse_filter = Control.MOUSE_FILTER_PASS
	panel.add_child(margin)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 16)
	hbox.mouse_filter = Control.MOUSE_FILTER_PASS
	margin.add_child(hbox)

	# Text column
	var text_vbox := VBoxContainer.new()
	text_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_vbox.mouse_filter = Control.MOUSE_FILTER_PASS
	hbox.add_child(text_vbox)

	var title_lbl := Label.new()
	title_lbl.text = quest.get("text", "")
	title_lbl.add_theme_font_size_override("font_size", 28)
	if claimed:
		title_lbl.add_theme_color_override("font_color", Color(0.4, 0.4, 0.4))
	text_vbox.add_child(title_lbl)

	var desc_lbl := Label.new()
	desc_lbl.text = quest.get("desc", "")
	desc_lbl.add_theme_font_size_override("font_size", 22)
	desc_lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	text_vbox.add_child(desc_lbl)

	# Progress
	var prog_lbl := Label.new()
	var display_progress := mini(progress, target)
	prog_lbl.text = "%d / %d" % [display_progress, target]
	prog_lbl.add_theme_font_size_override("font_size", 24)
	if claimed:
		prog_lbl.text = "OK"
		prog_lbl.add_theme_color_override("font_color", Color(0.4, 0.7, 0.4))
	elif completable:
		prog_lbl.add_theme_color_override("font_color", Color(0.3, 1.0, 0.5))
	else:
		prog_lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	text_vbox.add_child(prog_lbl)

	# Reward + Claim button
	var reward: Dictionary = quest.get("reward", {})
	var reward_type: String = reward.get("type", "")
	var reward_amount: int = GameManager.quests._get_scaled_reward_amount(quest)
	var reward_icon := "⚡" if reward_type == "energy" else ("🔧" if reward_type == "tech" else "⭐")

	if completable:
		var claim_btn := Button.new()
		claim_btn.text = "%s %d" % [reward_icon, reward_amount]
		claim_btn.custom_minimum_size = Vector2(160, 70)
		claim_btn.add_theme_font_size_override("font_size", 26)
		claim_btn.add_theme_color_override("font_color", Color(1.0, 0.9, 0.3))
		claim_btn.pressed.connect(_on_claim_quest.bind(qid))
		hbox.add_child(claim_btn)
	elif not claimed:
		var reward_lbl := Label.new()
		reward_lbl.text = "%s %d" % [reward_icon, reward_amount]
		reward_lbl.add_theme_font_size_override("font_size", 24)
		reward_lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		hbox.add_child(reward_lbl)

	if claimed:
		panel.modulate = Color(0.6, 0.6, 0.6)

	return panel

func _on_claim_quest(quest_id: String) -> void:
	if GameManager.claim_quest(quest_id):
		AudioManager.play_sfx("buy")
		_build_quests_list()
		_update_quest_badge()
