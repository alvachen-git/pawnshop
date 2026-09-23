class_name CounterScreen
extends Control

@onready var _flow: ScreenFlowCoordinator = %ScreenFlowCoordinator
@onready var _status_view: ShopStatusView = %ShopStatusView
@onready var _counter_view: CounterView = %CounterView
@onready var _session_menu: SessionMenuView = %SessionMenu
var atmosphere_presenter: CounterAtmospherePresenter
var _preview_index := 0
var _return_focus: Control
var _room: PrivateRoomView
var _social_panel: SocialPanel
var _military_reception_key := ""
var _military_was_active := false
var _session: RunSession
var facilities: FacilitiesNavigation
var _room_phase := ""
var _room_pending := ""
var _market_notice: Button
var _notice_stamp: Label
var _notice_key := ""
var _notice_read_key := ""
var _departure: TradeReceiptView
var _departure_queue: Array[Dictionary] = []
var _departure_return_panel: StringName = &""
var _departure_presenter: CustomerDeparturePresenter
var _receipt: TradeReceiptView
var _receipt_run := ""
var _receipt_id := ""
var _receipt_followup := ""
var _receipt_event := ""
var _receipt_night := 0
var _return_id := ""
var _counter_story_active := false
var _counter_story_signature := ""
var _narrative: NarrativeScene
var _feedback: TradeFeedbackView
var _recent_bar: HBoxContainer
var _recent_button: Button
var _recent: Dictionary = {}
var _recent_collapsed := false
var _operation: Dictionary = {}
var _feedback_state_id := 0
var _review_panel: StringName = &""
var _reviewing := false
var _seen_feedback: Dictionary = {}
const PANEL_TITLES := {"social": "往来簿", "growth": "修缮与查铺", "day": "营业", "appraisal": "鉴定", "dialogue": "对话", "trade": "交易", "inventory": "库存", "ledger": "账本", "events": "铺中记事", "risk": "物品记事", "night": "夜间结算"}


func _ready() -> void:
	theme = CounterTheme.build()
	CounterTheme.style_paper_button(%MenuButton)
	%MenuButton.icon = preload("res://assets/ui/icons/menu-2.svg")
	%MenuButton.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	%MenuButton.expand_icon = true
	%MenuButton.add_theme_constant_override("icon_max_width", 32)
	%MenuButton.add_theme_color_override("icon_normal_color", Color("302a24"))
	%MenuButton.add_theme_color_override("icon_hover_color", Color("302a24"))
	%MenuButton.add_theme_color_override("icon_pressed_color", Color("302a24"))
	%MenuButton.add_theme_color_override("icon_focus_color", Color("302a24"))
	%ShopStatusView.add_theme_stylebox_override("panel", CounterTheme.painted_paper())
	_counter_view.shop_requested.connect(_route_from_counter.bind(&"day", &"shop"))
	_counter_view.customer_action_requested.connect(_route_from_customer)
	_counter_view.item_action_requested.connect(_route_from_item)
	_counter_view.inventory_requested.connect(_route_from_counter.bind(&"inventory", &"inventory"))
	_counter_view.social_requested.connect(_route_from_counter.bind(&"social", &"social"))
	_counter_view.plaque_requested.connect(func() -> void:
		_route_from_counter(&"social", &"plaque")
		_social_panel.section = 1
		_social_panel.refresh()
	)
	_counter_view.ledger_requested.connect(_route_from_counter.bind(&"ledger", &"ledger"))
	_counter_view.background_requested.connect(_close_menu)
	_counter_view.context_opened.connect(_on_context_opened)
	%LedgerPanel.panel_requested.connect(_flow.show_panel)
	%InventoryPanel.panel_requested.connect(func(panel: StringName) -> void:
		_flow.show_panel(panel)
		if panel == &"ledger":
			%LedgerPanel.select_page(2)
	)
	_flow.active_panel_changed.connect(_open_drawer)
	%CloseDrawerButton.pressed.connect(_close_drawer)
	%MenuButton.pressed.connect(_toggle_menu)
	_session_menu.panel_requested.connect(_route_from_menu)
	%PreviewSelector.pressed.connect(func() -> void:
		_preview_index = (_preview_index + 1) % 4
		_preview_selected(_preview_index)
	)
	%PreviewSelector.visible = OS.is_debug_build()
	%DebugSectionSeparator.visible = OS.is_debug_build()
	var panels: Array[FeaturePanel] = [
		%DayFlowPanel,
		%EventPanel,
		%RiskPanel,
		%AppraisalPanel,
		%DialoguePanel,
		%TradePanel,
		%InventoryPanel,
		%LedgerPanel,
		%NightResolutionView,
	]
	for panel in panels:
		_flow.register_panel(panel)
	_flow.show_panel(&"day")


func bind_session(session: RunSession) -> void:
	_session = session
	_social_panel = SocialPanel.new()
	_social_panel.panel_id = &"social"
	_social_panel.name = "SocialPanel"
	add_child(_social_panel)
	_social_panel.anchor_left = .215
	_social_panel.anchor_right = .985
	_social_panel.anchor_top = .065
	_social_panel.anchor_bottom = .875
	_social_panel.hide()
	_social_panel.close_requested.connect(_close_drawer)
	_flow.register_panel(_social_panel)
	_social_panel.bind(session)
	_social_panel.visibility_changed.connect(func() -> void:
		_counter_view.get_hotspot(&"social").visible = session._day.state.social_enabled and not _social_panel.visible and session._day.state.phase not in ["dead", "bankrupt"]
		if _market_notice != null: _refresh_notice_visibility()
		_refresh_recent_visibility()
	)
	var growth_panel := ShopGrowthPanel.new()
	growth_panel.panel_id = &"growth"
	growth_panel.name = "ShopGrowthPanel"
	%DayFlowPanel.get_parent().add_child(growth_panel)
	growth_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	growth_panel.hide()
	_flow.register_panel(growth_panel)
	growth_panel.bind(session)
	if InvestigationService.enabled(session.definition):
		var panel := InvestigationPanel.new()
		panel.panel_id = &"investigation"
		panel.name = "InvestigationPanel"
		%DayFlowPanel.get_parent().add_child(panel)
		panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		panel.hide()
		_flow.register_panel(panel)
		panel.bind(session)
	_counter_view.bell_requested.connect(session.bell_command)
	_counter_view.bell.blocked = _bell_blocked
	session.restored.connect(_reset_reception)
	_market_notice = Button.new()
	_market_notice.name = "MarketNotice"
	_market_notice.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	_market_notice.anchor_left = 1.0
	_market_notice.anchor_right = 1.0
	_market_notice.anchor_top = 0.904
	_market_notice.anchor_bottom = 0.904
	_market_notice.offset_left = -118
	_market_notice.offset_right = -12
	_market_notice.offset_top = -130
	_market_notice.offset_bottom = -12
	_market_notice.icon = preload("res://assets/ui/mail/envelope.png")
	_market_notice.expand_icon = true
	_market_notice.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_market_notice.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
	_market_notice.add_theme_constant_override("icon_max_width", 100)
	_market_notice.add_theme_font_override("font", CounterTheme.display_font())
	_market_notice.add_theme_font_size_override("font_size", 15)
	_market_notice.add_theme_color_override("font_color", Color("f0dfb6"))
	_market_notice.add_theme_color_override("font_hover_color", Color("fff3d5"))
	_market_notice.add_theme_color_override("font_focus_color", Color("fff3d5"))
	_market_notice.add_theme_color_override("font_pressed_color", Color("d5bd8b"))
	_market_notice.add_theme_color_override("font_outline_color", Color("211910"))
	_market_notice.add_theme_constant_override("outline_size", 3)
	for button_state in ["normal", "hover", "pressed", "disabled"]:
		_market_notice.add_theme_stylebox_override(button_state, StyleBoxEmpty.new())
	_market_notice.add_theme_color_override("icon_hover_color", Color("fff0cc"))
	_market_notice.add_theme_color_override("icon_pressed_color", Color("c8b38b"))
	_market_notice.accessibility_name = "陆掌眼来信"
	_market_notice.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_market_notice.pressed.connect(_open_market_notice)
	add_child(_market_notice)
	move_child(_market_notice, %Drawer.get_index())
	_notice_stamp = Label.new()
	_notice_stamp.text = "新"
	_notice_stamp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_notice_stamp.add_theme_color_override("font_color", Color("8d2a24"))
	_notice_stamp.add_theme_font_size_override("font_size", 14)
	_market_notice.add_child(_notice_stamp)
	_notice_stamp.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_notice_stamp.offset_left = -22
	_notice_stamp.offset_right = -8
	_notice_stamp.offset_top = 6
	_notice_stamp.offset_bottom = 24
	%Drawer.visibility_changed.connect(_refresh_notice_visibility)
	_session_menu.visibility_changed.connect(_refresh_notice_visibility)
	%InventoryPanel.batch_submitted.connect(session.sell_batch)
	_room = PrivateRoomView.new()
	_room.name = "PrivateRoom"
	add_child(_room)
	move_child(_room, _counter_view.get_index() + 1)
	_room.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_room.menu_requested.connect(_toggle_menu)
	_room.hide()
	var day_presenter := DayFlowPresenter.new()
	add_child(day_presenter)
	day_presenter.route_requested.connect(_flow.show_panel)
	day_presenter.bind(session, %DayFlowPanel, _session_menu)
	var night_presenter := NightResolutionPresenter.new()
	add_child(night_presenter)
	night_presenter.bind(session, %NightResolutionView)
	var counter_presenter := CounterPresenter.new()
	add_child(counter_presenter)
	counter_presenter.bind(session, _counter_view)
	var presenters: Array[CounterFeaturePresenter] = [AppraisalPresenter.new(), DialoguePresenter.new(), TradePresenter.new(), InventoryPresenter.new(), LedgerPresenter.new()]
	var views: Array[IntentPanel] = [%AppraisalPanel, %DialoguePanel, %TradePanel, %InventoryPanel, %LedgerPanel]
	for index in presenters.size():
		add_child(presenters[index])
		presenters[index].bind(session, views[index])

	var event_presenter := EventPresenter.new()
	add_child(event_presenter)
	event_presenter.route_requested.connect(_flow.show_panel)
	event_presenter.bind(session, %EventPanel)
	var risk_presenter := RiskPresenter.new()
	add_child(risk_presenter)
	risk_presenter.route_requested.connect(_flow.show_panel)
	risk_presenter.bind(session, %RiskPanel)
	atmosphere_presenter = CounterAtmospherePresenter.new()
	add_child(atmosphere_presenter)
	atmosphere_presenter.bind(session, _counter_view, _status_view)
	var room_presenter := PrivateRoomPresenter.new()
	add_child(room_presenter)
	room_presenter.bind(session, _room)
	session.changed.connect(_sync_room)
	_counter_view.get_node("Room").show_life_lamp = not session.definition.private_room
	_sync_room()
	_receipt = TradeReceiptView.new()
	_receipt.name = "TradeReceipt"
	add_child(_receipt)
	_receipt.dismissed.connect(_receipt_closed)
	session.transaction_completed.connect(_show_receipt)
	_feedback = TradeFeedbackView.new()
	_feedback.name = "TradeFeedback"
	add_child(_feedback)
	_feedback_state_id = session._day.state.get_instance_id()
	session.operation_completed.connect(_on_operation_feedback)
	%LedgerPanel.receipt_requested.connect(_review_receipt)
	_recent_bar = HBoxContainer.new()
	_recent_bar.name = "RecentTrade"
	_recent_bar.z_index = 12
	add_child(_recent_bar)
	_recent_bar.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	_recent_bar.anchor_left = 0.18
	_recent_bar.anchor_right = 0.78
	_recent_bar.anchor_top = 0.89
	_recent_bar.anchor_bottom = 0.89
	_recent_bar.offset_top = -64
	_recent_button = Button.new()
	_recent_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_recent_button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_recent_button.add_theme_font_size_override("font_size", 17)
	_recent_button.custom_minimum_size.y = 60
	_recent_button.pressed.connect(func() -> void:
		if _recent.get("kind", "") == "departure":
			_review_panel = _flow.get_active_panel_id() if %Drawer.visible else &""
			_reviewing = true
			_recent_bar.hide()
			_receipt.present(_recent)
		else: _review_receipt(_recent.get("id", ""))
	)
	_recent_bar.add_child(_recent_button)
	var dismiss_recent := Button.new()
	dismiss_recent.text = "收起"
	dismiss_recent.pressed.connect(func() -> void: _recent_collapsed = true; _recent_bar.hide())
	_recent_bar.add_child(dismiss_recent)
	_recent_bar.hide()
	_departure = TradeReceiptView.new()
	_departure.name = "CustomerDeparture"
	add_child(_departure)
	_departure.dismissed.connect(_departure_closed)
	_departure_presenter = CustomerDeparturePresenter.new()
	add_child(_departure_presenter)
	_departure_presenter.departed.connect(func(notice: Dictionary) -> void:
		_departure_queue.append(notice)
		_drain_departures.call_deferred()
	)
	_departure_presenter.reset.connect(func() -> void: _departure_queue.clear(); _departure.hide())
	_departure_presenter.bind(session)
	session.changed.connect(func() -> void: _drain_departures.call_deferred())
	_narrative = NarrativeScene.new()
	_narrative.name = "NarrativeScene"
	add_child(_narrative)
	move_child(_narrative, _receipt.get_index())
	# The existing menu must remain usable over an opening scene, below receipts.
	move_child(_session_menu, _receipt.get_index() - 1)
	_session_menu.z_index = 16
	_narrative.menu_requested.connect(_toggle_menu)
	_narrative.bind(session)
	_narrative.visibility_changed.connect(func() -> void:
		if not _narrative.visible and _session._day.state.phase == "open": _close_drawer()
		if not _narrative.visible and _session._day.state.phase == "shop_resolution" and _session._day.state.risk_pending.is_empty(): _flow.show_panel(&"night")
	)

	var inventory_event_notice := preload("res://ui/inventory/inventory_event_notice.gd").new()
	add_child(inventory_event_notice)
	inventory_event_notice.bind(session, self)
	if session._day.state.shop_growth_enabled:
		facilities = FacilitiesNavigation.new()
		facilities.name = "FacilitiesNavigation"
		add_child(facilities)
		facilities.bind(self, session)
	var dream := MirrorDreamView.new()
	add_child(dream)
	dream.bind(session, self)
	if MirrorReunionService.enabled(session.definition):
		var reunion := MirrorReunionView.new()
		add_child(reunion)
		reunion.bind(session, self)
	if MirrorEndingService.enabled(session.definition):
		var ending_effect := preload("res://ui/risk/mirror_ending_effect.gd").new()
		add_child(ending_effect)
		ending_effect.bind(session)

func focus_active_screen() -> void:
	if _counter_view.story_active:
		_counter_view.story.show_dialogue()
		return
	if _narrative != null and _narrative.visible and _narrative._choices.get_child_count() > 0:
		_narrative._choices.get_child(0).grab_focus()
	else: _active_menu_button().grab_focus()

func _drain_departures() -> void:
	if _departure == null: return
	if not is_visible_in_tree() or process_mode == Node.PROCESS_MODE_DISABLED: return
	var state := _session._day.state
	if state.phase in ["dead", "bankrupt"]:
		_departure_queue.clear()
		_departure.hide()
		return
	if _departure.visible or _receipt.visible or _feedback.visible: return
	_departure_queue.assign(_departure_queue.filter(func(notice: Dictionary) -> bool: return notice.get("night", state.current_night_index) == state.current_night_index))
	if _departure_queue.is_empty():
		_counter_view.release_feedback()
		return
	if not state.risk_pending.is_empty() or not state.pending_event_id.is_empty() or _session.mirror_pending(): return
	_departure_return_panel = _flow.get_active_panel_id() if %Drawer.visible else &""
	if _departure_return_panel in [&"trade", &"dialogue", &"appraisal"]:
		var continuing: String = _departure_queue[0].get("continuing_visit_id", "")
		if continuing.is_empty() or continuing != _session.counter_model().active_id: _departure_return_panel = &""
	var notice: Dictionary = _departure_queue.pop_front()
	if not notice.get("active_departed", true):
		# Waiting customers only leave a notification; the current reception stays.
		if _operation.get("paid", false) and _recent.get("kind", "") != "departure":
			_recent.note += "\n" + String(notice.note)
			_recent.detail += "\n\n" + String(notice.detail)
			_recent_button.tooltip_text = _recent.note
		else: _remember_feedback(notice)
		_counter_view.release_feedback()
		_drain_departures.call_deferred()
		return
	_start_feedback(notice)

func _departure_closed(_destination: String) -> void:
	if _session._day.state.phase != "open": _flow.show_panel(&"night")
	elif not _departure_return_panel.is_empty(): _flow.show_panel(_departure_return_panel)
	else:
		_close_drawer()
		var target := _counter_view.get_hotspot(&"customer")
		if not target.visible: target = _counter_view.get_hotspot(&"shop")
		target.grab_focus()
	_drain_departures.call_deferred()

func _show_receipt(receipt: Dictionary) -> void:
	if receipt.is_empty(): return
	var key := String(_session._day.state.run_token) + "/" + String(receipt.id)
	if _seen_feedback.has(key): return
	_seen_feedback[key] = true
	_reviewing = false
	_remember_feedback(receipt)
	_receipt_event = ""
	# Acknowledge the existing first-account event through its receipt, once.
	if receipt.kind == "acquisition" and _session._day.state.pending_event_id == "evt_intro_first_trade":
		_receipt_event = "evt_intro_first_trade"
		receipt = receipt.duplicate(true)
		receipt.detail = "你看着纸上的红印，想起顾叔按住你手的那一刻。\n" + tr("opening.first_trade.continue.result")
		receipt.can_inspect = _session._day.state.phase == "open" and _session._day.state.risk_pending.is_empty() and not _session.mirror_pending()
		_narrative.hide()
	_receipt_run = _session._day.state.run_token
	_receipt_night = _session._day.state.current_night_index
	_receipt_id = receipt.id
	_receipt_followup = receipt.followup
	_close_menu()
	_counter_view.dismiss_contexts()
	%Drawer.hide()
	_receipt.present(receipt)
	_refresh_recent_visibility()
	_status_view.release_cash()

func _receipt_closed(destination: String) -> void:
	_status_view.release_cash()
	if _reviewing:
		_reviewing = false
		if not destination.is_empty():
			_flow.show_panel(StringName(destination))
			if destination == "ledger": %LedgerPanel.select_page(2)
		elif not _review_panel.is_empty(): _flow.show_panel(_review_panel)
		else: _close_drawer()
		_refresh_recent_visibility()
		return
	var event := _receipt_event
	_receipt_event = ""
	if not event.is_empty() and _session._day.state.pending_event_id == event:
		_session.event_command(event, "continue")
	_counter_view.release_feedback()
	_drain_departures.call_deferred()
	var state := _session._day.state
	if not state.risk_pending.is_empty() or _session.mirror_pending(): _flow.show_panel(&"risk")
	elif not state.pending_event_id.is_empty():
		if _session.event_model().presentation.is_empty(): _flow.show_panel(&"events")
		else: _close_drawer()
	elif not destination.is_empty():
		_flow.show_panel(StringName(destination))
		if destination == "ledger": %LedgerPanel.select_page(2)
	elif not _receipt_followup.is_empty(): _flow.show_panel(StringName(_receipt_followup))
	elif state.phase != "open": _flow.show_panel(&"night")
	elif _session.counter_model().trade.get("pawn_return", false): _flow.show_panel(&"trade")
	else: _close_drawer()
	_refresh_recent_visibility()

func _sync_room() -> void:
	_sync_military_reception()
	_counter_view.get_hotspot(&"social").visible = _session._day.state.social_enabled and not _social_panel.visible and _session._day.state.phase not in ["dead", "bankrupt"]
	_counter_view.get_hotspot(&"plaque").visible = _session._day.state.social_enabled and _session._day.state.social.get("plaque_awarded", false) and _session._day.state.phase not in ["dead", "bankrupt"]
	if _social_panel != null and (_room.visible or _session._day.state.phase not in ["pre_open", "open", "closed_processing"] or not _session._day.state.pending_event_id.is_empty() or not _session._day.state.risk_pending.is_empty()): _social_panel.hide()
	var state := _session._day.state
	if _feedback != null and _feedback_state_id != _session._day.state.get_instance_id():
		_cancel_feedback(true)
		_feedback_state_id = _session._day.state.get_instance_id()
	_refresh_notice_visibility()
	_refresh_recent_visibility()
	if not _session.definition.market.is_empty():
		var current := MarketService.current(_session.definition, int(state.run_seed), int(state.current_night_index), int(state.game_minutes))
		var demand := MarketService.demand(_session.definition, current)
		_market_notice.text = "陆掌眼来信\n眼下收" + demand.name
		_market_notice.tooltip_text = demand.body + "\n查看口信不耗时；外出交货一趟20分钟。"
		_notice_key = state.run_token + "/" + current.id
		_notice_stamp.visible = _notice_key != _notice_read_key
	var returning := PawnReturnService.current(_session._day.state)
	var id: String = returning.get("id", "")
	if id.is_empty(): _return_id = ""
	elif id != _return_id and state.pending_event_id.is_empty() and state.risk_pending.is_empty() and not _session.mirror_pending():
		_return_id = id
		_flow.show_panel(&"trade")
	if _receipt != null and _receipt.visible:
		var still_present := false
		for entry in state.ledger_entries:
			if entry.transaction_id == _receipt_id: still_present = true
		# A completed redemption can land exactly at sealing time.
		if state.run_token != _receipt_run or not still_present or (not _reviewing and state.current_night_index != _receipt_night) or state.phase in ["dead", "bankrupt"]: _receipt.hide()
	_counter_view.visible = not _room.visible
	%MenuButton.visible = not _room.visible
	_status_view.visible = not _room.visible
	%PreviewSelector.visible = OS.is_debug_build() and not _room.visible
	if state.phase != _room_phase or state.risk_pending != _room_pending:
		_room_phase = state.phase
		_room_pending = state.risk_pending
		if _room.visible and state.risk_pending.is_empty() and state.phase != "dead":
			%Drawer.hide()
			_close_menu()
			_room.get_node("RoomBed").grab_focus()
		elif state.phase == "shop_resolution" and state.risk_pending.is_empty() and not _counter_view.story_active: _flow.show_panel(&"night")
		elif state.phase in ["shop_resolution", "sleep_resolution"] and not state.risk_pending.is_empty(): _flow.show_panel(&"risk")
	var previous_story := _counter_story_active
	_counter_story_active = _counter_view.story_active
	if _counter_story_active:
		if _counter_story_signature != _counter_view.story._signature:
			_counter_story_signature = _counter_view.story._signature
			_counter_view.story.show_dialogue()
	else:
		_counter_story_signature = ""
	if not _counter_story_active and previous_story and state.phase == "shop_resolution" and state.risk_pending.is_empty(): _flow.show_panel(&"night")


func _refresh_notice_visibility() -> void:
	var state := _session._day.state
	_market_notice.visible = not _session.definition.market.is_empty() and state.phase == "open" and state.pending_event_id.is_empty() and state.risk_pending.is_empty() and not _session.mirror_pending() and not %Drawer.visible and not _session_menu.visible and not (_social_panel != null and _social_panel.visible)


func _open_market_notice() -> void:
	_notice_read_key = _notice_key
	_notice_stamp.hide()
	_return_focus = _market_notice
	_flow.show_panel(&"inventory")
	%InventoryPanel.open_buyer(_session.definition.market.buyer_id)


func _route_from_counter(panel_id: StringName, hotspot: StringName) -> void:
	if _counter_view.story_active: _counter_view.story.hide()
	_return_focus = _counter_view.get_hotspot(hotspot)
	_flow.show_panel(panel_id)


func _route_from_customer(panel_id: StringName) -> void:
	_return_focus = _counter_view.get_hotspot(&"customer")
	_flow.show_panel(panel_id)


func _route_from_item(panel_id: StringName) -> void:
	_return_focus = _counter_view.get_hotspot(&"item")
	_flow.show_panel(panel_id)


func _route_from_menu(panel_id: StringName) -> void:
	if _room.visible and panel_id != &"risk": return
	_return_focus = _active_menu_button()
	_flow.show_panel(panel_id)


func _on_context_opened(kind: StringName) -> void:
	if _social_panel != null: _social_panel.hide()
	%Drawer.hide()
	_close_menu()
	_return_focus = _counter_view.get_hotspot(kind)


func _open_drawer(panel_id: StringName) -> void:
	if panel_id != &"social" and _social_panel != null: _social_panel.hide()
	if _counter_view.story_active: _counter_view.story.hide()
	if facilities != null:
		if panel_id == &"growth":
			_close_menu()
			%Drawer.hide()
			_counter_view.dismiss_contexts()
			facilities.enter()
			return
		elif facilities.in_room:
			facilities.leave(false)
	if _feedback != null and _feedback.visible: _cancel_feedback(false)
	_close_menu()
	_counter_view.dismiss_contexts()
	if panel_id == &"social":
		%Drawer.hide()
		_social_panel.clear_result()
		_social_panel.focus_close()
		_refresh_notice_visibility()
		return
	%Drawer.show()
	%DrawerTitle.text = "  " + ("托人查访" if panel_id == &"investigation" else PANEL_TITLES[String(panel_id)])
	%CloseDrawerButton.grab_focus()
	_refresh_recent_visibility()


func _close_drawer() -> void:
	if _social_panel != null: _social_panel.hide()
	%Drawer.hide()
	_close_menu()
	if _return_focus != null and _return_focus.is_visible_in_tree():
		_return_focus.grab_focus()
	else:
		if _room != null and _room.visible: _room.get_node("RoomBed").grab_focus()
		else: _counter_view.focus_hotspot(&"shop")


func _toggle_menu() -> void:
	if _counter_view.story_active: _counter_view.story.hide()
	if _social_panel != null: _social_panel.hide()
	_counter_view.dismiss_contexts()
	%Drawer.hide()
	if _session_menu.visible:
		_close_menu()
		_active_menu_button().grab_focus()
	else:
		_return_focus = _active_menu_button()
		_session_menu.open_menu()


func _active_menu_button() -> Button:
	if _narrative != null and _narrative.visible: return _narrative._menu_button
	return _room._menu if _room != null and _room.visible else %MenuButton


func _close_menu() -> void:
	_session_menu.close_menu()


func _preview_selected(index: int) -> void:
	if atmosphere_presenter != null:
		atmosphere_presenter.set_preview(index - 1)
	%PreviewSelector.text = ["美术预览：随游戏", "美术预览：正常营业", "美术预览：深夜异常", "美术预览：禁时鬼市"][index]
	_close_drawer()


func _unhandled_key_input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel"):
		return
	if _departure != null and _departure.visible:
		_departure.dismiss()
		get_viewport().set_input_as_handled()
		return
	if _receipt != null and _receipt.visible:
		_receipt.dismiss()
		get_viewport().set_input_as_handled()
		return
	if _counter_view.dismiss_contexts():
		get_viewport().set_input_as_handled()
		return
	if _session_menu.visible:
		_close_menu()
		_active_menu_button().grab_focus()
		get_viewport().set_input_as_handled()
		return
	if _counter_view.story_active and _counter_view.story.visible:
		_counter_view.story.hide()
		_counter_view.get_hotspot(&"customer" if _counter_view._story_actor else &"item").grab_focus()
		get_viewport().set_input_as_handled()
		return
	if _room != null and _room.visible and _room.dismiss_observation():
		get_viewport().set_input_as_handled()
		return
	if %Drawer.visible or (_social_panel != null and _social_panel.visible):
		_close_drawer()
		get_viewport().set_input_as_handled()
		return
	if facilities != null and facilities.cancel():
		get_viewport().set_input_as_handled()


func show_content_ready(catalog: ContentCatalog) -> void:
	_status_view.show_content_ready(catalog.get_count("items"), catalog.get_count("customers"))


func show_content_error(issues: Array) -> void:
	var summary := "未知错误"
	if not issues.is_empty():
		summary = issues[0].format_message()
	_status_view.show_content_error(summary)

func _reset_reception() -> void:
	_cancel_feedback(true)
	_room_phase = ""
	_room_pending = ""
	_departure_queue.clear()
	_receipt.hide()
	_departure.hide()
	_return_id = ""
	_receipt_id = ""
	_receipt_event = ""
	_close_menu()
	_close_drawer()
	_counter_view.dismiss_contexts()

func _bell_blocked() -> bool:
	if not is_visible_in_tree() or process_mode == Node.PROCESS_MODE_DISABLED: return true
	if %Drawer.visible or _session_menu.visible or (_social_panel != null and _social_panel.visible): return true
	if _counter_view.companion.dialogue.visible or _counter_view.story.visible: return true
	for overlay in [_receipt, _departure, _narrative, _feedback]:
		if overlay != null and overlay.visible: return true
	var main := get_parent()
	if "storage" in main and main.storage != null:
		var storage: SaveLibraryView = main.storage
		if storage.overlay.visible or storage.confirm.visible or storage.leave_dialog.visible: return true
	return false

func _on_operation_feedback(operation: Dictionary) -> void:
	if not operation.ok and operation.before.minute == operation.after.minute and operation.before.history_size == operation.after.history_size and not operation.paid: return
	if _feedback.visible: _cancel_feedback(false)
	_operation = operation
	var before: Dictionary = operation.before.counter
	var after: Dictionary = operation.after.counter
	var left: bool = not String(before.active_id).is_empty() and before.active_id != after.active_id
	if left and operation.command == "reject":
		var visual: Dictionary = before.get("visual", {})
		_start_feedback({"id": "reject/" + String(operation.before.run) + "/" + String(before.active_id),
			"reply_style": "rejected", "reply_name": String(visual.get("customer_name", "客人")),
			"kind": "departure", "title": "谢过，今夜不收", "item": String(visual.get("item_name", "旧物")),
			"note": "客人收好东西，离开柜台。", "detail": operation.message, "clock": "",
			"amount": 0, "before": operation.before.cash, "after": operation.after.cash,
			"item_asset": "", "images": [], "destination": "", "can_inspect": false})

func _start_feedback(receipt: Dictionary) -> void:
	var key := String(_session._day.state.run_token) + "/" + String(receipt.id)
	if _seen_feedback.has(key): return
	_seen_feedback[key] = true
	_reviewing = false
	_receipt_followup = receipt.get("followup", "")
	_remember_feedback(receipt)
	_close_menu()
	_counter_view.dismiss_contexts()
	%Drawer.hide()
	_feedback.record = receipt.duplicate(true)
	_status_view.release_cash()
	_feedback_finished()

func _remember_feedback(receipt: Dictionary) -> void:
	_recent = receipt.duplicate(true)
	_recent_collapsed = false
	_recent_button.text = "%s · %s · 查看详情" % [receipt.title, receipt.item]
	if receipt.get("due_night", 0) > 0:
		_recent_button.text = "留铺保管 · 第%d夜到期 · %s · 查看详情" % [receipt.due_night, receipt.item]
	var reply := CustomerReplyModel.build(receipt, _operation)
	if not reply.text.is_empty(): _recent_button.text = String(reply.text) + "\n" + _recent_button.text
	_recent_button.set_meta("reply_style", reply.style)
	_recent_button.tooltip_text = receipt.note
	_refresh_recent_visibility()

func _refresh_recent_visibility() -> void:
	if _recent_bar == null: return
	var state := _session._day.state
	_recent_bar.visible = not _recent.is_empty() and not _recent_collapsed and not _feedback.visible and not _receipt.visible and state.phase == "open" and state.pending_event_id.is_empty() and state.risk_pending.is_empty() and not _session.mirror_pending() and not (%Drawer.visible and _flow.get_active_panel_id() == &"risk") and not (_social_panel != null and _social_panel.visible)

func _feedback_finished() -> void:
	_counter_view.release_feedback()
	if _feedback.record.get("kind", "") == "departure": _departure_closed("")
	else: _receipt_closed("")
	_refresh_recent_visibility()

func _cancel_feedback(clear_recent: bool) -> void:
	if _feedback == null: return
	_feedback.cancel()
	_status_view.release_cash()
	_counter_view.release_feedback()
	_receipt_followup = ""
	_operation = {}
	if clear_recent:
		_departure_queue.clear()
		if _departure != null: _departure.hide()
		_recent.clear()
		_recent_bar.hide()
		_seen_feedback.clear()
		_reviewing = false
		_receipt.hide()
	else: _refresh_recent_visibility()

func _review_receipt(id: String) -> void:
	var state := _session._day.state
	if not state.pending_event_id.is_empty() or not state.risk_pending.is_empty() or _session.mirror_pending(): return
	var receipt := _session.receipt_for(id)
	if receipt.is_empty(): return
	_cancel_feedback(false)
	_review_panel = _flow.get_active_panel_id() if %Drawer.visible else &""
	_reviewing = true
	_receipt_run = state.run_token
	_receipt_id = receipt.id
	_close_menu()
	%Drawer.hide()
	_recent_bar.hide()
	_receipt.present(receipt)

func _sync_military_reception() -> void:
	var active := MilitaryIntroduction.active(_session._day.state)
	var key := _session._day.state.run_token + "/" + MilitaryIntroduction.id(_session._day.state)
	if active and (not _military_was_active or key != _military_reception_key):
		_military_reception_key = key
		# Show the arriving person on the counter; the player opens conversation.
		_close_drawer.call_deferred()
	elif not active and _military_was_active:
		_close_drawer.call_deferred()
	_military_was_active = active
