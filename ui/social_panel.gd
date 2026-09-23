class_name SocialPanel
extends FeaturePanel

signal close_requested
var session: RunSession
var section := 0
var selected_faction := "military"
var _page_key := ""
var _pending_key := ""
var _title: Label
var _facts: GridContainer
var _letter: VBoxContainer
var _roster: VBoxContainer
var _right: VBoxContainer
var _name: Label
var _role: Label
var _attitude: Label
var _balance: Label
var _portrait: TextureRect
var _body: Label
var _scroll: ScrollContainer
var _actions: VBoxContainer
var _result: Label
var _close: Button
var _tabs: Array[Button] = []
var _empty: Label
var _selected_coats: Array[String] = []
var _selected_order := -1

func _ready() -> void:
	z_index = 14
	add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	var surface := Control.new()
	add_child(surface)
	var background := TextureRect.new()
	background.texture = preload("res://assets/social_book/open_book.png")
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_SCALE
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	surface.add_child(background)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 18)
	surface.add_child(left)
	_bounds(left, .057, .078, .412, .9)
	left.add_child(_label("名帖索引册", 36, true))
	left.add_child(_label("往 来 簿", 14))
	left.add_child(HSeparator.new())
	var index_scroll := ScrollContainer.new()
	index_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	index_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	left.add_child(index_scroll)
	_roster = VBoxContainer.new()
	_roster.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_roster.add_theme_constant_override("separation", 12)
	index_scroll.add_child(_roster)
	var note := _label("新结识的人，会在这里留下一页。", 16)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	left.add_child(note)
	_close = Button.new()
	_close.name = "CloseBookButton"
	_close.text = "合上 · Esc"
	_close.custom_minimum_size = Vector2(112, 30)
	_compact_button(_close)
	_close.pressed.connect(close_requested.emit)
	surface.add_child(_close)
	_bounds(_close, .802, .875, .946, .933)
	_right = VBoxContainer.new()
	_right.add_theme_constant_override("separation", 8)
	surface.add_child(_right)
	_bounds(_right, .476, .078, .946, .855)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	_right.add_child(header)
	var profile := VBoxContainer.new()
	profile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	profile.add_theme_constant_override("separation", 7)
	header.add_child(profile)
	_name = _label("", 36, true)
	_role = _label("", 16)
	_attitude = _label("", 17)
	_attitude.add_theme_color_override("font_color", Color("8d2a24"))
	for label in [_name, _role, _attitude]:
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		profile.add_child(label)
	_portrait = TextureRect.new()
	_portrait.custom_minimum_size = Vector2(96, 122)
	_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	header.add_child(_portrait)
	var tabs := HBoxContainer.new()
	_right.add_child(tabs)
	for title in ["采购", "打点", "旧事"]:
		var index := tabs.get_child_count()
		var tab := Button.new()
		tab.text = title
		tab.toggle_mode = true
		tab.custom_minimum_size = Vector2(80, 32)
		_compact_button(tab)
		tab.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		tab.pressed.connect(func() -> void: section = index; clear_result(); refresh())
		var active := CounterTheme.box("d8c7a233", "8d2a24", 12, 4)
		active.set_border_width_all(0)
		active.border_width_bottom = 2
		tab.add_theme_stylebox_override("pressed", active)
		tab.add_theme_color_override("font_pressed_color", Color("8d2a24"))
		tab.add_theme_color_override("font_hover_pressed_color", Color("8d2a24"))
		tabs.add_child(tab)
		_tabs.append(tab)
	_balance = _label("", 15)
	_right.add_child(_balance)
	_scroll = ScrollContainer.new()
	_scroll.name = "BookLetterScroll"
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_right.add_child(_scroll)
	_letter = VBoxContainer.new()
	_letter.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_letter.add_theme_constant_override("separation", 10)
	_scroll.add_child(_letter)
	_title = _label("", 22, true)
	_title.add_theme_color_override("font_color", Color("8d2a24"))
	_letter.add_child(_title)
	_body = _label("", 17)
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.add_theme_constant_override("line_spacing", 2)
	_letter.add_child(_body)
	_facts = GridContainer.new()
	_facts.columns = 2
	_facts.add_theme_constant_override("h_separation", 20)
	_facts.add_theme_constant_override("v_separation", 6)
	_letter.add_child(_facts)
	_result = _label("", 15)
	_result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_result.hide()
	_letter.add_child(_result)
	_actions = VBoxContainer.new()
	_actions.add_theme_constant_override("separation", 4)
	_letter.add_child(_actions)
	_empty = _label("尚无往来记录。", 20, true)
	_empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	surface.add_child(_empty)
	_bounds(_empty, .5, .3, .91, .65)
	visibility_changed.connect(refresh)
	resized.connect(_scale_type)

func _label(words: String, font_size: int, display := false) -> Label:
	var label := Label.new()
	label.text = words
	label.add_theme_font_size_override("font_size", font_size)
	if display:
		var face := FontVariation.new()
		face.base_font = CounterTheme.display_font()
		face.variation_embolden = .5
		label.add_theme_font_override("font", face)
	return label

func _bounds(control: Control, left: float, top: float, right: float, bottom: float) -> void:
	control.anchor_left = left
	control.anchor_top = top
	control.anchor_right = right
	control.anchor_bottom = bottom

func focus_close() -> void:
	_close.grab_focus()

func bind(value: RunSession) -> void:
	session = value
	session.changed.connect(refresh)
	session.restored.connect(func() -> void: section = 0; _pending_key = ""; _page_key = ""; clear_result(); refresh())
	refresh()

func refresh() -> void:
	if session == null or not is_visible_in_tree(): return
	var state := session._day.state
	var pending_key := state.run_token + "/" + str(state.current_night_index) + "/" + JSON.stringify(state.social.pending)
	if pending_key != _pending_key:
		_pending_key = pending_key
		if not state.social.pending.is_empty(): section = FactionBookModels.pending_section(state)
	var entries := FactionBookModels.roster(state)
	_right.visible = not entries.is_empty()
	_empty.visible = entries.is_empty()
	for child in _roster.get_children():
		_roster.remove_child(child)
		child.queue_free()
	if entries.is_empty(): return
	if not entries.any(func(entry: Dictionary) -> bool: return entry.id == selected_faction): selected_faction = entries[0].id
	var selected: Dictionary = {}
	for entry in entries:
		var button := Button.new()
		button.text = "%s\n%s · %s" % [entry.name, entry.representative, FactionBookModels.attitude(state, entry.id)]
		button.add_theme_font_size_override("font_size", 17)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.custom_minimum_size.y = 84
		if entry.has("emblem"):
			button.icon = load(entry.emblem)
			button.expand_icon = true
			button.add_theme_constant_override("icon_max_width", 64)
			button.add_theme_constant_override("h_separation", 12)
		button.toggle_mode = true
		button.button_pressed = entry.id == selected_faction
		var selected_style := CounterTheme.box("8d2a2424", "8d2a24", 14, 12)
		selected_style.border_width_left = 5
		button.add_theme_stylebox_override("pressed", selected_style)
		button.pressed.connect(func() -> void: selected_faction = entry.id; section = 0; clear_result(); refresh())
		_roster.add_child(button)
		if entry.id == selected_faction: selected = entry
	_name.text = selected.representative
	_role.text = selected.role + " · " + selected.scope
	_attitude.text = FactionBookModels.attitude(state, selected_faction)
	_portrait.texture = load(selected.portrait)
	_balance.text = "现银 %d 银元　·　今夜准备 %d / 2 次" % [state.cash, PreparationService.count(state)]
	for index in _tabs.size():
		_tabs[index].set_pressed_no_signal(section == index)
		_tabs[index].tooltip_text = "有来信待办" if not state.social.pending.is_empty() and index == FactionBookModels.pending_section(state) else ""

	var model := FactionBookModels.page(session._day, selected_faction, section)
	_letter.add_theme_constant_override("separation", 6 if model.has("stock") else 10)
	_actions.add_theme_constant_override("separation", 2 if model.has("stock") else 4)
	var order_number := int(state.social.contract.get("number", -1))
	if _selected_order != order_number:
		_selected_order = order_number
		_selected_coats.clear()
	var key := "%s/%d/%d/%s" % [selected_faction, state.current_night_index, section, JSON.stringify(state.social.pending)]
	if key != _page_key:
		_page_key = key
		_scroll.set_deferred("scroll_vertical", 0)
	_title.text = model.title
	_body.text = model.body
	_body.visible = not String(model.body).is_empty()
	for child in _facts.get_children():
		_facts.remove_child(child)
		child.queue_free()
	_facts.visible = not model.fields.is_empty()
	for pair in model.fields:
		_facts.add_child(_label(pair[0], 17))
		var value := _label(pair[1], 17)
		value.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_facts.add_child(value)
	for child in _actions.get_children():
		_actions.remove_child(child)
		child.queue_free()
	_actions.visible = not model.buttons.is_empty()
	if model.has("stock"):
		var stock_ids: Array = model.stock.map(func(row: Dictionary) -> String: return row.id)
		_selected_coats = _selected_coats.filter(func(id: String) -> bool: return id in stock_ids)
		for row in model.stock:
			var pick := CheckBox.new()
			pick.text = row.label
			pick.set_meta("coat_id", row.id)
			pick.add_theme_font_size_override("font_size", 15)
			for kind in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
				var style := CounterTheme.box("8d2a2410" if kind in ["hover", "hover_pressed"] else "00000000", "00000000", 4, 0)
				style.set_border_width_all(0)
				pick.add_theme_stylebox_override(kind, style)
			pick.set_pressed_no_signal(row.id in _selected_coats)
			pick.disabled = _selected_coats.size() >= 3 and row.id not in _selected_coats
			pick.toggled.connect(func(checked: bool) -> void:
				if checked and row.id not in _selected_coats: _selected_coats.append(row.id)
				elif not checked: _selected_coats.erase(row.id)
				clear_result()
				refresh()
			)
			_actions.add_child(pick)
	for entry in model.buttons:
		if entry.command == "deliver":
			entry.detail = JSON.stringify({"order":order_number, "ids":_selected_coats})
			entry.reason = MilitaryService.reason(session._day, "deliver", entry.detail)
			entry.enabled = entry.reason.is_empty()
			entry.label = "交付所选三件 · 已选%d／3" % _selected_coats.size()
		var action := Button.new()
		action.text = entry.label
		action.add_theme_font_size_override("font_size", 16)
		action.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		action.custom_minimum_size = Vector2(144, 32)
		var primary: bool = entry.command in ["accept_contract", "gift", "pay", "deliver", "select_supply", "book_section", "check_supply"]
		action.set_meta("primary", primary)
		for kind in ["normal", "hover", "pressed", "disabled"]:
			var style := CounterTheme.box("00000000" if kind in ["normal", "disabled"] else "8d2a2418", "8d2a24" if kind != "disabled" else "897557", 14, 3)
			style.set_border_width_all(1 if primary else 0)
			action.add_theme_stylebox_override(kind, style)
		if primary:
			action.add_theme_color_override("font_color", Color("8d2a24"))
			action.add_theme_color_override("font_focus_color", Color("8d2a24"))
		action.disabled = not entry.enabled
		action.tooltip_text = entry.reason
		action.pressed.connect(func() -> void:
			if entry.command == "book_section":
				section = int(entry.detail)
				clear_result()
				refresh()
				return
			FactionBookModels.perform(session, selected_faction, entry.command, entry.detail)
			_result.text = session.message
			_result.tooltip_text = session.message
			_result.visible = not session.message.is_empty()
			refresh()
		)
		_actions.add_child(action)
	_scale_type()

func clear_result() -> void:
	_result.text = ""
	_result.hide()

func _compact_button(button: Button) -> void:
	if not button.has_theme_font_size_override("font_size"): button.add_theme_font_size_override("font_size", 17)
	button.add_theme_color_override("font_hover_pressed_color", Color("302a24"))
	for state in ["normal", "hover", "pressed", "disabled"]:
		var style := CounterTheme.paper_button_style(state)
		style.set_content_margin(SIDE_TOP, 4)
		style.set_content_margin(SIDE_BOTTOM, 4)
		button.add_theme_stylebox_override(state, style)

func _scale_type() -> void:
	if _portrait == null: return
	var ratio := clampf(size.x / 985.6, 1.0, 1.6)
	_scale_node(self, ratio)
	_portrait.custom_minimum_size = Vector2(96, 122) * ratio
	for tab in _tabs: tab.custom_minimum_size = Vector2(80, 32) * ratio
	for action in _actions.get_children():
		action.custom_minimum_size = Vector2(0, 22) * ratio if action is CheckBox else Vector2(144, 32 if action.get_meta("primary", false) else 26) * ratio

func _scale_node(node: Node, ratio: float) -> void:
	if node is Control and node.has_theme_font_size_override("font_size"):
		if not node.has_meta("book_font_size"): node.set_meta("book_font_size", node.get_theme_font_size("font_size"))
		node.add_theme_font_size_override("font_size", roundi(float(node.get_meta("book_font_size")) * ratio))
	for child in node.get_children(): _scale_node(child, ratio)
