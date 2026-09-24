class_name CounterFeaturePresenter
extends Node

var _session: RunSession
var _view: IntentPanel

func feature_key() -> String:
	return ""

func bind(session: RunSession, view: IntentPanel) -> void:
	_session = session
	_view = view
	_view.intent.connect(_on_intent)
	_session.changed.connect(refresh)
	_view.visibility_changed.connect(refresh, CONNECT_DEFERRED)
	refresh()

func refresh() -> void:
	# Hidden drawers read current state when opened; no eager rebuild per action.
	if not _view.is_visible_in_tree(): return
	if MirrorReunionService.enabled(_session.definition) and MirrorEndingService.active(_session._day.state): return
	_view.render(_session.counter_model()[feature_key()])

func _on_intent(command: String, visit_id: String, detail: String, amount: int) -> void:
	if command == "luxury_begin" and TieredAppraisal.enabled(_session.definition):
		var visitor := CustomerManager.new().active(_session._day.state)
		if visitor == null: return
		var result := _session.fan_command(command,visitor.item.instance_id,detail)
		if result.ok:
			if PorcelainEconomy.handles(_session._day.state,visitor.item):
				PorcelainDeskView.open_porcelain(_view,_session,visitor.item.instance_id)
				return
			if BangleEconomy.handles(_session._day.state,visitor.item):
				BangleDeskView.open_bangle(_view,_session,visitor.item.instance_id)
				return
			if PearlEconomy.handles(_session._day.state,visitor.item):
				PearlDeskView.open_pearl(_view,_session,visitor.item.instance_id)
				return
			if WatchAppraisal.handles(_session._day.state,visitor.item):
				WatchDeskView.create(_view,_session,visitor.item.instance_id)
				return
			var desk := TieredAppraisalView.create(_view,_session,visitor.item.instance_id)
			desk.tier = int(detail); desk.refresh()
		return
	if command == "luxury_open":
		LuxuryAppraisalView.open(_view, _session, detail)
		return
	if command == "fan_open":
		FanAppraisalView.open(_view, _session, detail)
		return
	if command == "condition":
		_session.fan_command("condition", detail)
		return
	var result := _session.counter_command(command, visit_id, detail, amount)
	if command == "fd_event" and visit_id in FirstDebt.DOCUMENTS and FirstDebt.revised(_session._day.state):
		if result.ok: _view.document_requested.emit(visit_id)
		else: _view._body.text = result.message
