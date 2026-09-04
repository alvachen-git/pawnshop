class_name CounterScreen
extends Control

@onready var _flow: ScreenFlowCoordinator = %ScreenFlowCoordinator
@onready var _status_view: ShopStatusView = %ShopStatusView
var atmosphere_presenter: CounterAtmospherePresenter
var _preview_index := 0
const PANEL_TITLES := {"day": "营业", "appraisal": "鉴定", "dialogue": "对话", "trade": "交易", "inventory": "库存", "ledger": "账本", "events": "铺中记事", "risk": "鬼货与绝当录", "night": "夜间结算"}


func _ready() -> void:
	theme = CounterTheme.build()
	%CounterView.inspect_requested.connect(_flow.show_panel.bind(&"appraisal"))
	%InventoryPanel.panel_requested.connect(func(panel: StringName) -> void:
		_flow.show_panel(panel)
		if panel == &"ledger": %LedgerPanel.select_page(2)
	)
	_flow.active_panel_changed.connect(_open_drawer)
	%CloseDrawerButton.pressed.connect(_close_drawer)
	%MoreButton.pressed.connect(func() -> void: %MoreMenu.visible = not %MoreMenu.visible)
	%PreviewSelector.pressed.connect(func() -> void:
		_preview_index = (_preview_index + 1) % 4
		_preview_selected(_preview_index)
	)
	%PreviewSelector.visible = OS.is_debug_build()
	for button in %DayButton.get_parent().get_children():
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
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

	%AppraisalButton.pressed.connect(_flow.show_panel.bind(&"appraisal"))
	%DialogueButton.pressed.connect(_flow.show_panel.bind(&"dialogue"))
	%TradeButton.pressed.connect(_flow.show_panel.bind(&"trade"))
	%InventoryButton.pressed.connect(_flow.show_panel.bind(&"inventory"))
	%LedgerButton.pressed.connect(_flow.show_panel.bind(&"ledger"))
	%NightButton.pressed.connect(_flow.show_panel.bind(&"night"))
	%EventButton.pressed.connect(_flow.show_panel.bind(&"events"))
	%RiskButton.pressed.connect(_flow.show_panel.bind(&"risk"))
	%DayButton.pressed.connect(_flow.show_panel.bind(&"day"))
	_flow.show_panel(&"day")


func bind_session(session: RunSession) -> void:
	var day_presenter := DayFlowPresenter.new()
	add_child(day_presenter)
	day_presenter.route_requested.connect(_flow.show_panel)
	day_presenter.bind(session, %DayFlowPanel)
	var night_presenter := NightResolutionPresenter.new()
	add_child(night_presenter)
	night_presenter.bind(session, %NightResolutionView)
	var counter_presenter := CounterPresenter.new()
	add_child(counter_presenter)
	counter_presenter.bind(session, %CounterView)
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
	atmosphere_presenter.bind(session, %CounterView, _status_view)

func _open_drawer(panel_id: StringName) -> void:
	%MoreMenu.hide()
	%Drawer.show()
	%DrawerTitle.text = "  " + PANEL_TITLES[String(panel_id)]
	%CloseDrawerButton.grab_focus()

func _close_drawer() -> void:
	%Drawer.hide()
	%MoreMenu.hide()
	%DayButton.grab_focus()

func _preview_selected(index: int) -> void:
	if atmosphere_presenter != null: atmosphere_presenter.set_preview(index - 1)
	%PreviewSelector.text = ["美术预览：随游戏", "美术预览：正常营业", "美术预览：深夜异常", "美术预览：禁时鬼市"][index]
	_close_drawer()

func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_close_drawer()
		get_viewport().set_input_as_handled()


func show_content_ready(catalog: ContentCatalog) -> void:
	_status_view.show_content_ready(catalog.get_count("items"), catalog.get_count("customers"))


func show_content_error(issues: Array) -> void:
	var summary := "未知错误"
	if not issues.is_empty():
		summary = issues[0].format_message()
	_status_view.show_content_error(summary)
