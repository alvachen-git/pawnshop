class_name CounterScreen
extends Control

@onready var _flow: ScreenFlowCoordinator = %ScreenFlowCoordinator
@onready var _status_view: ShopStatusView = %ShopStatusView


func _ready() -> void:
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
	day_presenter.status_updated.connect(_status_view.render_status)
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


func show_content_ready(catalog: ContentCatalog) -> void:
	_status_view.show_content_ready(catalog.get_count("items"), catalog.get_count("customers"))


func show_content_error(issues: Array) -> void:
	var summary := "未知错误"
	if not issues.is_empty():
		summary = issues[0].format_message()
	_status_view.show_content_error(summary)
