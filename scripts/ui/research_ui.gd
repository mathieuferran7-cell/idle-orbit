extends Control

# ── Layout ───────────────────────────────────────────────────────────────────
const COL_CENTERS := [170.0, 540.0, 910.0]
const ROW_START_Y := 30.0
const ROW_HEIGHT := 220.0
const CARD_W := 280.0
const CARD_H := 130.0

# ── Colors — 3 states only ───────────────────────────────────────────────────
const CARD_BUYABLE := Color.WHITE
const CARD_LOCKED := Color(0.35, 0.35, 0.45)
const CARD_MAXED := Color(1.0, 0.85, 0.2)
const LINE_ON := Color(0.3, 0.9, 0.5, 0.55)
const LINE_OFF := Color(0.3, 0.3, 0.4, 0.35)

var _cards: Dictionary = {}
var _popup: Control = null
var _active_id: String = ""

# ── Signals ──────────────────────────────────────────────────────────────────

func _ready() -> void:
	EventBus.game_ready.connect(_on_game_ready)
	EventBus.research_node_unlocked.connect(_on_research_changed)
	EventBus.resource_changed.connect(_on_resource_changed)

func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and visible:
		queue_redraw()

func _on_game_ready() -> void:
	_build_constellation()

func _on_research_changed(_node_id: String) -> void:
	_refresh_all()
	if _popup and _popup.visible:
		_refresh_popup()

func _on_resource_changed(type: String, _amount: float, _total: float) -> void:
	if type == "tech":
		_refresh_all()
		if _popup and _popup.visible:
			_refresh_popup()

# ── Constellation ────────────────────────────────────────────────────────────

func _build_constellation() -> void:
	for child in get_children():
		child.queue_free()
	_cards.clear()
	_popup = null

	for node_id in GameManager.research.data:
		var node_data: Dictionary = GameManager.research.data[node_id]
		var pos: Array = node_data.get("position", [0, 0])
		var card := _make_card(node_id, node_data)
		add_child(card)
		card.position = Vector2(
			COL_CENTERS[int(pos[0])] - CARD_W / 2.0,
			ROW_START_Y + int(pos[1]) * ROW_HEIGHT
		)
		card.size = Vector2(CARD_W, CARD_H)
		_cards[node_id] = card

	_build_popup()
	_refresh_all()
	queue_redraw()

func _make_card(node_id: String, node_data: Dictionary) -> Button:
	var btn := Button.new()
	btn.name = node_id
	btn.clip_contents = true

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("margin_left", 12)
	vbox.add_theme_constant_override("margin_right", 12)
	btn.add_child(vbox)

	# Row 1: name + level
	var row := HBoxContainer.new()
	vbox.add_child(row)

	var name_lbl := Label.new()
	name_lbl.name = "NameLbl"
	name_lbl.text = node_data.get("name", node_id)
	name_lbl.add_theme_font_size_override("font_size", 28)
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_lbl)

	var level_lbl := Label.new()
	level_lbl.name = "LevelLbl"
	level_lbl.add_theme_font_size_override("font_size", 22)
	row.add_child(level_lbl)

	# Row 2: effect
	var effect_lbl := Label.new()
	effect_lbl.name = "EffectLbl"
	effect_lbl.add_theme_font_size_override("font_size", 24)
	vbox.add_child(effect_lbl)

	# Cost: absolute position, bottom-right of the button
	var cost_lbl := Label.new()
	cost_lbl.name = "CostLbl"
	cost_lbl.add_theme_font_size_override("font_size", 20)
	cost_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	cost_lbl.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	cost_lbl.set_offset(SIDE_LEFT, -140)
	cost_lbl.set_offset(SIDE_TOP, -28)
	cost_lbl.set_offset(SIDE_RIGHT, -8)
	cost_lbl.set_offset(SIDE_BOTTOM, -4)
	btn.add_child(cost_lbl)

	btn.pressed.connect(_on_card_pressed.bind(node_id))
	return btn

# ── Refresh ──────────────────────────────────────────────────────────────────

func _refresh_all() -> void:
	for node_id in _cards:
		_refresh_card(node_id)
	queue_redraw()

func _refresh_card(node_id: String) -> void:
	var card: Button = _cards.get(node_id)
	if not card:
		return
	var r := GameManager.research
	var level := r.get_level(node_id)
	var max_level := r.get_max_level(node_id)

	# Resolve labels
	var vbox: VBoxContainer = card.get_child(0)
	var row: HBoxContainer = vbox.get_child(0)
	var name_lbl: Label = row.get_node("NameLbl")
	var level_lbl: Label = row.get_node("LevelLbl")
	var effect_lbl: Label = vbox.get_node("EffectLbl")
	var cost_lbl: Label = card.get_node("CostLbl")

	# Text
	level_lbl.text = "%d/%d" % [level, max_level]
	effect_lbl.text = r.get_effect_label(node_id)
	if r.is_maxed(node_id):
		cost_lbl.text = ""
	else:
		cost_lbl.text = "🔧 %s" % NumberFormatter.format(r.get_effective_cost(node_id))

	# ONE color for the entire card via modulate
	if r.is_maxed(node_id):
		card.modulate = CARD_MAXED
	elif r.can_upgrade(node_id):
		card.modulate = CARD_BUYABLE
	else:
		card.modulate = CARD_LOCKED

# ── Lines ────────────────────────────────────────────────────────────────────

func _draw() -> void:
	if _cards.is_empty():
		return
	for node_id in GameManager.research.data:
		var requires: Array = GameManager.research.data[node_id].get("requires", [])
		for req_id in requires:
			var from_card: Button = _cards.get(req_id)
			var to_card: Button = _cards.get(node_id)
			if not from_card or not to_card:
				continue
			var from := from_card.position + from_card.size / 2.0
			var to := to_card.position + to_card.size / 2.0
			var color := LINE_ON if GameManager.research.is_unlocked(req_id) else LINE_OFF
			draw_line(from, to, color, 3.0)

# ── Popup ────────────────────────────────────────────────────────────────────

func _build_popup() -> void:
	_popup = Control.new()
	_popup.name = "Popup"
	_popup.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_popup.mouse_filter = Control.MOUSE_FILTER_STOP
	_popup.visible = false
	add_child(_popup)

	# Dim background
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.72)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	bg.gui_input.connect(_on_bg_input)
	_popup.add_child(bg)

	# Card
	var card := PanelContainer.new()
	card.name = "Card"
	card.custom_minimum_size = Vector2(940, 0)
	card.set_anchor(SIDE_LEFT, 0.5)
	card.set_anchor(SIDE_RIGHT, 0.5)
	card.set_anchor(SIDE_TOP, 0.5)
	card.set_anchor(SIDE_BOTTOM, 0.5)
	card.set_offset(SIDE_LEFT, -470)
	card.set_offset(SIDE_RIGHT, 470)
	card.set_offset(SIDE_TOP, -380)
	card.set_offset(SIDE_BOTTOM, 380)
	_popup.add_child(card)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 40)
	margin.add_theme_constant_override("margin_right", 40)
	margin.add_theme_constant_override("margin_top", 32)
	margin.add_theme_constant_override("margin_bottom", 32)
	card.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 20)
	margin.add_child(vbox)

	# Header
	var header := HBoxContainer.new()
	vbox.add_child(header)

	var title := Label.new()
	title.name = "Title"
	title.add_theme_font_size_override("font_size", 48)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)

	var close_btn := Button.new()
	close_btn.text = "✕"
	close_btn.add_theme_font_size_override("font_size", 40)
	close_btn.custom_minimum_size = Vector2(80, 80)
	close_btn.pressed.connect(_close_popup)
	header.add_child(close_btn)

	vbox.add_child(HSeparator.new())

	var level_lbl := Label.new()
	level_lbl.name = "Level"
	level_lbl.add_theme_font_size_override("font_size", 34)
	level_lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	vbox.add_child(level_lbl)

	var desc_lbl := Label.new()
	desc_lbl.name = "Desc"
	desc_lbl.add_theme_font_size_override("font_size", 30)
	desc_lbl.add_theme_color_override("font_color", Color(0.75, 0.75, 0.75))
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(desc_lbl)

	vbox.add_child(HSeparator.new())

	var current_lbl := Label.new()
	current_lbl.name = "Current"
	current_lbl.add_theme_font_size_override("font_size", 36)
	current_lbl.add_theme_color_override("font_color", Color(0.4, 1.0, 0.55))
	vbox.add_child(current_lbl)

	var next_lbl := Label.new()
	next_lbl.name = "Next"
	next_lbl.add_theme_font_size_override("font_size", 32)
	next_lbl.add_theme_color_override("font_color", Color(0.9, 0.9, 0.4))
	vbox.add_child(next_lbl)

	var upgrade_btn := Button.new()
	upgrade_btn.name = "UpgradeBtn"
	upgrade_btn.custom_minimum_size = Vector2(0, 100)
	upgrade_btn.add_theme_font_size_override("font_size", 36)
	upgrade_btn.pressed.connect(_on_upgrade_pressed)
	vbox.add_child(upgrade_btn)

func _on_card_pressed(node_id: String) -> void:
	_active_id = node_id
	_refresh_popup()
	_popup.visible = true

func _on_bg_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		_close_popup()

func _close_popup() -> void:
	_popup.visible = false
	_active_id = ""

func _on_upgrade_pressed() -> void:
	if GameManager.upgrade_research(_active_id):
		AudioManager.play_sfx("upgrade")

func _refresh_popup() -> void:
	if _active_id.is_empty() or not _popup:
		return
	var r := GameManager.research
	var data: Dictionary = r.data.get(_active_id, {})
	var level := r.get_level(_active_id)
	var max_level := r.get_max_level(_active_id)
	var maxed := r.is_maxed(_active_id)

	var card: PanelContainer = _popup.get_node("Card")
	var vbox: VBoxContainer = card.get_child(0).get_child(0)

	vbox.get_child(0).get_node("Title").text = data.get("name", _active_id)
	vbox.get_node("Level").text = "Niveau  %d / %d" % [level, max_level]
	vbox.get_node("Desc").text = data.get("description", "")
	vbox.get_node("Current").text = "Actuel : %s" % r.get_effect_label(_active_id)

	var next_lbl: Label = vbox.get_node("Next")
	var upgrade_btn: Button = vbox.get_node("UpgradeBtn")

	if maxed:
		next_lbl.text = ""
		upgrade_btn.text = "NIVEAU MAX"
		upgrade_btn.disabled = true
	else:
		next_lbl.text = "Niveau %d : %s" % [level + 1, r.get_next_effect_label(_active_id)]
		upgrade_btn.text = "🔧 %s" % NumberFormatter.format(r.get_effective_cost(_active_id))
		upgrade_btn.disabled = not r.can_upgrade(_active_id)
