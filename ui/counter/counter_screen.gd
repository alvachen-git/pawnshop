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
var _session: RunSession
var _room_phase := ""
var _room_pending := ""
var _receipt: TradeReceiptView
var _receipt_run := ""
var _receipt_id := ""
var _receipt_followup := ""
const PANEL_TITLES := {"day": "营业", "appraisal": "鉴定", "dialogue": "对话", "trade": "交易", "inventory": "库存", "ledger": "账本", "events": "铺中记事", "risk": "鬼货与绝当录", "night": "夜间结算"}


func _ready() -> void:
	theme = CounterTheme.build()
	_counter_view.shop_requested.connect(_route_from_counter.bind(&"day", &"shop"))
	_counter_view.customer_action_requested.connect(_route_from_customer)
	_counter_view.item_action_requested.connect(_route_from_item)
	_counter_view.inventory_requested.connect(_route_from_counter.bind(&"inventory", &"inventory"))
	_counter_view.ledger_requested.connect(_route_from_counter.bind(&"ledger", &"ledger"))
	_counter_view.background_requested.connect(_close_menu)
	_counter_view.context_opened.connect(_on_context_opened)
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
	_room = PrivateRoomView.new()
	_room.name = "PrivateRoom"
	add_child(_room)
	move_child(_room, _counter_view.get_index() + 1)
	_room.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_room.anchor_bottom = 0.90
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

func _show_receipt(receipt: Dictionary) -> void:
	_receipt_run = _session.read_state().run_token
	_receipt_id = receipt.id
	_receipt_followup = receipt.followup
	_close_menu()
	_counter_view.dismiss_contexts()
	%Drawer.hide()
	_receipt.present(receipt)

func _receipt_closed(destination: String) -> void:
	var state := _session.read_state()
	if not state.risk_pending.is_empty() or _session.mirror_pending(): _flow.show_panel(&"risk")
	elif not state.pending_event_id.is_empty(): _flow.show_panel(&"events")
	elif not destination.is_empty():
		_flow.show_panel(StringName(destination))
		if destination == "ledger": %LedgerPanel.select_page(2)
	elif not _receipt_followup.is_empty(): _flow.show_panel(StringName(_receipt_followup))
	elif state.phase != "open": _flow.show_panel(&"night")
	else: _close_drawer()

func _sync_room() -> void:
	var state := _session.read_state()
	if _receipt != null and _receipt.visible:
		var still_present := false
		for entry in state.ledger_entries:
			if entry.transaction_id == _receipt_id: still_present = true
		if state.run_token != _receipt_run or not still_present or state.phase != "open": _receipt.hide()
	_counter_view.visible = not _room.visible
	%PreviewSelector.visible = OS.is_debug_build() and not _room.visible
	if state.phase != _room_phase or state.risk_pending != _room_pending:
		_room_phase = state.phase
		_room_pending = state.risk_pending
		if _room.visible and state.risk_pending.is_empty() and state.phase != "dead":
			%Drawer.hide()
			_close_menu()
			_room.get_node("RoomBed").grab_focus()
		elif state.phase == "shop_resolution" and state.risk_pending.is_empty(): _flow.show_panel(&"night")
		elif state.phase == "sleep_resolution" and not state.risk_pending.is_empty(): _flow.show_panel(&"risk")


func _route_from_counter(panel_id: StringName, hotspot: StringName) -> void:
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
	_return_focus = %MenuButton
	_flow.show_panel(panel_id)


func _on_context_opened(kind: StringName) -> void:
	%Drawer.hide()
	_close_menu()
	_return_focus = _counter_view.get_hotspot(kind)


func _open_drawer(panel_id: StringName) -> void:
	_close_menu()
	_counter_view.dismiss_contexts()
	%Drawer.show()
	%DrawerTitle.text = "  " + PANEL_TITLES[String(panel_id)]
	%CloseDrawerButton.grab_focus()


func _close_drawer() -> void:
	%Drawer.hide()
	_close_menu()
	if _return_focus != null and _return_focus.is_visible_in_tree():
		_return_focus.grab_focus()
	else:
		if _room != null and _room.visible: _room.get_node("RoomBed").grab_focus()
		else: _counter_view.focus_hotspot(&"shop")


func _toggle_menu() -> void:
	_counter_view.dismiss_contexts()
	%Drawer.hide()
	if _session_menu.visible:
		_close_menu()
		%MenuButton.grab_focus()
	else:
		_return_focus = %MenuButton
		_session_menu.open_menu()


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
	if _receipt != null and _receipt.visible:
		_receipt.dismiss()
		get_viewport().set_input_as_handled()
		return
	if _counter_view.dismiss_contexts():
		get_viewport().set_input_as_handled()
		return
	if _session_menu.visible:
		_close_menu()
		%MenuButton.grab_focus()
		get_viewport().set_input_as_handled()
		return
	if %Drawer.visible:
		_close_drawer()
		get_viewport().set_input_as_handled()


func show_content_ready(catalog: ContentCatalog) -> void:
	_status_view.show_content_ready(catalog.get_count("items"), catalog.get_count("customers"))


func show_content_error(issues: Array) -> void:
	var summary := "未知错误"
	if not issues.is_empty():
		summary = issues[0].format_message()
	_status_view.show_content_error(summary)
