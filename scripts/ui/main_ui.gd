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
@onready var mining_manager: MiningManager = $MiningManager

var _module_buttons: Dictionary = {}
var _asteroid_tween: Tween
var _offline_popup: Control = null
var _buy_mode_btn: Button = null
const BUY_MODES := [1, 10, 25, 0]
var _buy_mode_index: int = 0

func _ready() -> void:
	EventBus.game_ready.connect(_on_game_ready)
	EventBus.resource_changed.connect(_on_resource_changed)
	EventBus.module_purchased.connect(_on_module_purchased)
	EventBus.mining_tapped.connect(_on_mining_tapped)
	EventBus.offline_gains_ready.connect(_on_offline_gains_ready)
	asteroid_btn.pressed.connect(_on_asteroid_tapped)
	tab_modules_btn.pressed.connect(_show_modules_tab)
	tab_research_btn.pressed.connect(_show_research_tab)

func _on_game_ready() -> void:
	mining_manager.setup(GameManager.balance)
	_build_buy_mode_toggle()
	_build_module_list()
	_refresh_all()
	_show_modules_tab()

func _show_modules_tab() -> void:
	modules_panel.visible = true
	research_panel.visible = false
	tab_modules_btn.disabled = true
	tab_research_btn.disabled = false

func _show_research_tab() -> void:
	modules_panel.visible = false
	research_panel.visible = true
	tab_modules_btn.disabled = false
	tab_research_btn.disabled = true

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

func _build_buy_mode_toggle() -> void:
	if _buy_mode_btn and is_instance_valid(_buy_mode_btn):
		return
	_buy_mode_btn = Button.new()
	_buy_mode_btn.name = "BuyModeBtn"
	_buy_mode_btn.custom_minimum_size = Vector2(0, 70)
	_buy_mode_btn.add_theme_font_size_override("font_size", 30)
	_buy_mode_btn.text = "x1"
	_buy_mode_btn.pressed.connect(_on_buy_mode_toggle)

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

	# Toggle button as first child
	modules_container.add_child(_buy_mode_btn)

	for module_id in GameManager.modules_data:
		var row := _create_module_row(module_id)
		modules_container.add_child(row)
		_module_buttons[module_id] = row

func _create_module_row(module_id: String) -> PanelContainer:
	var mod: Dictionary = GameManager.modules_data[module_id]

	var panel := PanelContainer.new()
	panel.name = module_id

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	panel.add_child(margin)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)
	margin.add_child(hbox)

	var info_vbox := VBoxContainer.new()
	info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL

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
	stats_label.text = "x%d  |  +%s%s/s" % [count, res_icon, NumberFormatter.format(prod)]

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
	GameManager.claim_offline_gains(multiplier)
	if _offline_popup:
		_offline_popup.queue_free()
		_offline_popup = null
