class_name CustomerDeparturePresenter
extends Node

signal departed(notice: Dictionary)
signal reset

const REASONS := {
	"patience_exhausted": "耐心耗尽，客人不愿再谈价。",
	"rounds_exhausted": "议价轮次已用尽，双方没有谈成。",
	"timed_out": "等候期限已到，客人不能再留。",
	"shop_closed": "铺门已关，本夜接待结束。",
}
var _session: RunSession
var _state_id := 0
var _cursor := 0
var _minute := 0
var _known: Dictionary = {}

func bind(session: RunSession) -> void:
	_session = session
	_capture()
	session.changed.connect(_refresh)

func _capture() -> void:
	var state := _session._day.state
	_state_id = state.get_instance_id()
	_cursor = state.visit_history.size()
	_minute = state.game_minutes
	_known.clear()
	for visit in state.visits:
		if visit.status in ["active", "waiting"]: _known[visit.visit_id] = {"visit": visit, "was_active": visit.status == "active"}

func _refresh() -> void:
	var state := _session._day.state
	# Loading, restarting and failed-checkpoint rollback replace the state object.
	# History restored from disk is not a new departure notification.
	if state.get_instance_id() != _state_id or state.visit_history.size() < _cursor:
		_capture()
		reset.emit()
		return
	var lines: PackedStringArray = []
	var subjects: PackedStringArray = []
	var ids: Array = []
	var active_departed := false
	for row in state.visit_history.slice(_cursor):
		if not REASONS.has(row.outcome) or not _known.has(row.visit_id): continue
		var visit: CustomerVisit = _known[row.visit_id].visit
		var was_active: bool = _known[row.visit_id].was_active
		active_departed = active_departed or was_active
		var customer := _session._counter.catalog.get_definition("customers", visit.customer_id) as CustomerDefinition
		var item := _session._counter.catalog.get_definition("items", visit.item.definition_id) as ItemDefinition
		var name := VarietyService.name_for(visit.person, customer)
		subjects.append(name + " · " + item.display_name)
		var speech: String = {"patience_exhausted": "他把东西收回怀里：“这买卖，不谈了。”", "rounds_exhausted": "他重新扎好包袱：“价钱合不到一处，就到这里吧。”", "timed_out": "他朝门外看了一眼，收好东西，匆匆离开。", "shop_closed": "门板落下前，客人带着旧物离开了。"}[row.outcome]
		if row.outcome == "timed_out" and visit.voice.has("timed_out"): speech = String(visit.voice.timed_out)
		var reason: String = REASONS[row.outcome]
		if not was_active:
			reason = "还没轮到柜台，等候期限已到，客人先走了。" if row.outcome == "timed_out" else "尚在排队，铺门已关，客人带着货物离开。"
		lines.append(reason + "\n" + speech)
		ids.append(row.visit_id)
	var elapsed := maxi(0, state.game_minutes - _minute)
	_capture()
	if lines.is_empty(): return
	var detail := "货物未收取，也未向这些客人付款。\n本次操作耗时%d分钟；查看这条消息不耗时。" % elapsed
	var current := _session._counter.customers.active(state)
	if not active_departed and current != null:
		var current_customer := _session._counter.catalog.get_definition("customers", current.customer_id) as CustomerDefinition
		detail = "柜台仍在接待：" + VarietyService.name_for(current.person, current_customer) + "。\n" + detail
	if ids.size() > 1:
		for index in ids.size(): detail += "\n\n" + subjects[index] + "\n" + lines[index]
	departed.emit({"id": "departure/" + "/".join(ids), "kind": "departure", "title": ("未能成交" if active_departed else "等候客人离场") if ids.size() == 1 else "来客离场", "item": subjects[0] if ids.size() == 1 else "%d位客人带着货物离开了" % ids.size(),
		"clock": "第%d夜 · %s" % [state.current_night_index, TimeController.clock_text(_session.definition.opening_minute, state.game_minutes)],
		"note": lines[0] if ids.size() == 1 else "离场缘由列在下方，可滚动查看。", "detail": detail,
		"continuing_visit_id": current.visit_id if current != null and not active_departed else "",
		"amount": 0, "before": state.cash, "after": state.cash, "item_asset": "", "images": [], "destination": "", "can_inspect": false,
		"primary_label": ("继续当前接待" if not active_departed and current != null else "继续接待") if state.phase == &"open" else "知道了"})
