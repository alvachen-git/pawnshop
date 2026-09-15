extends Button

var _session: RunSession
var _screen: CounterScreen
var _target: StringName = &""

func bind(session: RunSession, screen: CounterScreen) -> void:
	_session = session
	_screen = screen
	name = "InventoryEventNotice"
	z_index = 12
	set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	anchor_left = 0.135
	anchor_right = 0.135
	anchor_top = 0.31
	anchor_bottom = 0.31
	offset_left = -26
	offset_right = 26
	offset_top = -26
	offset_bottom = 26
	var image := Image.new()
	image.load_svg_from_string(FileAccess.get_file_as_string("res://assets/ui/icons/alert-circle.svg"), 2.0)
	icon = ImageTexture.create_from_image(image)
	expand_icon = true
	icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_theme_constant_override("icon_max_width", 36)
	for state_name in ["normal", "hover", "pressed", "focus"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color("3b2418") if state_name == "normal" else Color("614127")
		style.border_color = Color("ffd77b")
		style.set_border_width_all(2)
		style.set_corner_radius_all(26)
		style.content_margin_left = 7
		style.content_margin_right = 7
		style.shadow_color = Color(1.0, 0.66, 0.2, 0.42)
		style.shadow_size = 8 if state_name == "normal" else 12
		add_theme_stylebox_override(state_name, style)
		add_theme_color_override("icon_" + state_name + "_color", Color("ffe5a0"))
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	tooltip_text = "物品有待处理的事 · 点击查看"
	accessibility_name = "库存物品事件，点击处理"
	pressed.connect(_open_pending)
	session.changed.connect(refresh)
	session.restored.connect(refresh)
	refresh()

func pending_panel() -> StringName:
	var state := _session._day.state
	if state.phase in [&"dead", &"bankrupt", &"run_ended", &"private_room", &"sleep_resolution"]: return &""
	# Only an event already triggered by an item can light the cabinet.
	# Available investigations and historical records are not pending events.
	if not state.pending_event_id.is_empty():
		var event := _session._counter.catalog.get_definition("events", state.pending_event_id) as EventDefinition
		if event != null and not event.required_items.is_empty(): return &"events"
	if not state.risk_pending.is_empty() or _session.mirror_pending(): return &"risk"
	return &""

func refresh() -> void:
	_target = pending_panel()
	visible = not _target.is_empty()

func _open_pending() -> void:
	refresh()
	if _target.is_empty(): return
	_screen._return_focus = self
	if _target == &"risk":
		var panel := _screen.get_node("%RiskPanel") as RiskPanel
		panel.record_selected.emit("")
		panel.show_notes(false)
		panel.reset_reading_position()
	_screen.get_node("%ScreenFlowCoordinator").show_panel(_target)
