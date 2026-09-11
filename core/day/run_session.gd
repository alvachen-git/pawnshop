class_name RunSession
extends RefCounted

signal restored
signal storage_requested(mode: String)
signal leave_requested(destination: String)
signal changed
signal transaction_completed(receipt: Dictionary)

var definition: RunDefinition
var content_version: int
# Transient feedback ownership; never serialized into the player's save.
var _message_visit_id := ""
var message := "开铺前准备。查看面板不耗时；开铺后可接待顾客。":
	set(value):
		message = value
		_message_visit_id = ""
var _day: DayController
var _save: SaveManager
var _counter: CounterService
var _events: EventDirector
var _commerce: CommerceService
var _risk: RiskManager
var _mirror: MirrorEncounterService
var _risk_error := ""
var _pawn_choices: Dictionary = {}
var _new_catalog: ContentCatalog
var _new_definition: RunDefinition
var _new_version: int

func _init(run_definition: RunDefinition, version: int, save_manager: SaveManager, catalog: ContentCatalog = null) -> void:
	_new_catalog = catalog
	_new_definition = run_definition
	_new_version = version
	definition = run_definition
	content_version = version
	_save = save_manager
	_day = DayController.new(definition, RunState.create(definition))
	_day.state.death_archive = _save.read_archive()
	_day.state.bankruptcy_archive = _save.read_bankruptcy_archive()
	if catalog != null:
		_counter = CounterService.new(catalog)
		_commerce = CommerceService.new(catalog)
		_events = EventDirector.new(catalog)
		if definition.private_room or not definition.ghost_rule_ids.is_empty(): _risk = RiskManager.new(catalog)
		_mirror = MirrorEncounterService.new(catalog)
		_save.catalog = catalog
		_counter.customers.prepare_night(_day.state, definition, catalog)
		MarketService.sync(_day.state, definition)
		_events.poll(_day.state, definition)

func read_state() -> Dictionary:
	return _day.state.to_read_model()

func seven_notice() -> String:
	if not SevenNightPlan.enabled(definition): return ""
	var introductions := {1: "借据压在柜上：本金500银元，日息按剩余本金1%向上取整，另付铺费5银元。第21夜首期200银元可整笔延期；已付首期则第49夜还余款300，延期则届时还本金500及延期费100。日常短款只宽限至次夜夜末。\n旧掌柜留话：先看货，再听人说；现银交出去，便压在货里了。", 2: "杂货商常收旧物，瓷器收藏客19:00–22:00来收。出门交货往返20分钟，店里的客人可不会替你停住钟。", 3: "今夜起可办活当：期限3夜，赎金为本金加10%固定息费，息费向上取整。在当旧物须替原主保管。", 7: "七夜的账即将合拢。未卖的货、未到期的票与借据都照实留着，本金今夜不催收。"}
	return String(introductions.get(_day.state.current_night_index, "")) + PreparationService.notice(_day.state, _counter.catalog) + MirrorChapterService.summary(_day.state, definition) + FamiliarStories.note(_day.state) + ("\n" + NightMarketRisk.note(_day.state) if NightMarketPlan.enabled(definition) else "")

func has_save() -> bool:
	return _save.exists()

func can_execute(command: String) -> bool:
	if command.begins_with("seal_cloth/"): return not mirror_pending() and NightMarketRisk.treatment_reason(_day, command.trim_prefix("seal_cloth/")).is_empty()
	if command.begins_with("prep_"): return PreparationService.reason(_day.state, definition, command.trim_prefix("prep_")).is_empty()
	if command == "open_shop" and SevenNightPlan.enabled(definition) and not OpeningPreparation.enabled(definition) and _day.state.current_night_index >= 4 and not PreparationService.used(_day.state, "finish", _day.state.current_night_index): return false
	if not PawnReturnService.current(_day.state).is_empty(): return false
	if command == "resolve_night" and _commerce != null and not _commerce.pawns.disposal_reason(_day.state, _commerce.catalog, _pawn_choices).is_empty(): return false
	return _day.state.risk_pending.is_empty() and _day.state.phase not in [&"dead", &"bankrupt"] and _day.state.pending_event_id.is_empty() and not mirror_pending() and (_day.can_execute(command) or RoomFlow.can_execute(_day.state, command))

func execute(command: String, detail := "") -> ActionResult:
	if command.begins_with("prep_"):
		var previous := _copy_state(_day.state)
		var prepared := OpeningPreparation.perform(_day.state, definition, _counter.catalog, command.trim_prefix("prep_"), detail) if OpeningPreparation.enabled(definition) else PreparationService.perform(_day.state, definition, command.trim_prefix("prep_"))
		if prepared.ok and OpeningPreparation.enabled(definition): OpeningPreparation.refresh_visits(_day.state, definition, _counter.catalog)
		if prepared.ok and not _save.save_state(_day.state, definition, content_version):
			_day.state = previous
			prepared = ActionResult.new(false, "准备未记下，请重试。" + _save.error_message)
		message = prepared.message
		changed.emit()
		return prepared
	if command == "open_shop" and not can_execute(command): return ActionResult.new(false, "请先结束准备并处理眼前的事情。")
	if command == "open_shop" and OpeningPreparation.enabled(definition) and _day.state.current_night_index >= 2 and not PreparationService.used(_day.state, "finish", _day.state.current_night_index):
		# Commit the pre-open checkpoint before advancing to the unsaveable trading phase.
		var finished := execute("prep_finish")
		if not finished.ok: return finished
	if not _day.state.risk_pending.is_empty() or _day.state.phase in [&"dead", &"bankrupt"]: return _risk_blocked()
	if not _day.state.pending_event_id.is_empty(): return _event_blocked()
	if mirror_pending(): return _mirror_blocked()
	if not PawnReturnService.current(_day.state).is_empty(): return _return_blocked()
	if command == "resolve_night" and _commerce != null:
		var error := _commerce.pawns.disposal_reason(_day.state, _commerce.catalog, _pawn_choices)
		if not error.is_empty():
			message = error
			MarketService.sync(_day.state, definition)
			changed.emit()
			return ActionResult.new(false, error)
	if command.begins_with("seal_cloth/"):
		var treated := NightMarketRisk.treat(_day, command.trim_prefix("seal_cloth/"))
		if _risk != null: _risk.capture_close(_day.state)
		if _events != null: _events.poll(_day.state, definition)
		MarketService.sync(_day.state, definition)
		message = treated.message
		changed.emit()
		return treated
	# Only these commands create checkpoints. Snapshot before mutation for rollback.
	var checkpoint := command in ["resolve_night", "continue_run", "enter_room", "sleep", "finish_sleep"]
	var previous: RunState
	if checkpoint:
		previous = _copy_state(_day.state)
	if command == "resolve_night" and not mirror_pending() and _day.can_execute(command) and _commerce != null:
		_commerce.pawns.resolve_maturities(_day.state, definition.night_minutes, _commerce.catalog, _pawn_choices)
	if command == "resolve_night" and _day.can_execute(command):
		NightMarketRisk.settle(_day.state)
		FeeService.settle(_day.state, definition)
	var prior_visitor: CustomerVisit = _counter.customers.active(_day.state) if _counter != null else null
	var result := RoomFlow.execute(_day.state, _risk, command) if command in ["enter_room", "sleep", "finish_sleep"] else _day.execute(command)
	if result.ok and _risk != null:
		_risk.capture_close(_day.state)
		if command == "resolve_night":
			if definition.private_room: RoomFlow.seal(_day.state, _risk)
			else: _risk.settle(_day.state)
	if result.ok and (command == "finish_sleep" or (command == "resolve_night" and not definition.private_room)): FeeService.finish(_day.state, definition)
	if result.ok and _counter != null:
		if command == "continue_run" and _day.state.phase == &"pre_open":
			_counter.customers.prepare_night(_day.state, definition, _counter.catalog)
		_counter.customers.update(_day.state)
	if result.ok and prior_visitor != null and prior_visitor.status == "timed_out" and prior_visitor.voice.has("timed_out"): result.message += "\n" + String(prior_visitor.voice.timed_out)
	if result.ok and _events != null: _events.poll(_day.state, definition)
	MarketService.sync(_day.state, definition)
	if result.ok and checkpoint:
		if not _save.save_state(_day.state, definition, content_version):
			_day.state = previous
			result = ActionResult.new(false, "未推进；请重试。" + _save.error_message)
		else:
			result.message = "这一夜的账，记下了。"
	if result.ok and command == "resolve_night": _pawn_choices.clear()
	message = result.message
	if prior_visitor != null and prior_visitor.status == "timed_out": _message_visit_id = prior_visitor.visit_id
	MarketService.sync(_day.state, definition)
	changed.emit()
	return result

func load_checkpoint() -> ActionResult:
	if _save.library != null:
		var state := _save.load_state(definition, content_version)
		if state == null: return ActionResult.new(false, _save.error_message)
		var ok := _save.library.adopt({"state": state, "run": _save.loaded_definition, "catalog": _save.loaded_catalog}, self)
		return ActionResult.new(ok, message if ok else _save.library.error_message)
	_risk_error = ""
	var restored := _save.load_state(definition, content_version)
	var result := ActionResult.new(restored != null, "账册翻回了上次合拢的那一页。" if restored != null else _save.error_message)
	if restored != null:
		if _save.loaded_catalog != null and _save.loaded_definition != null:
			_switch_content(_save.loaded_definition, _save.loaded_catalog.content_version, _save.loaded_catalog)
		_day.state = restored
		_pawn_choices.clear()
		if _counter != null and restored.phase == &"pre_open":
			_counter.customers.prepare_night(restored, definition, _counter.catalog)
	message = result.message
	MarketService.sync(_day.state, definition)
	changed.emit()
	return result

func _switch_content(run: RunDefinition, version: int, catalog: ContentCatalog) -> void:
	definition = run
	content_version = version
	_day = DayController.new(run, _day.state)
	_counter = CounterService.new(catalog)
	_commerce = CommerceService.new(catalog)
	_events = EventDirector.new(catalog)
	_risk = RiskManager.new(catalog) if run.private_room or not run.ghost_rule_ids.is_empty() else null
	_mirror = MirrorEncounterService.new(catalog)
	_save.catalog = catalog

func new_run() -> void:
	if _new_catalog != null: _switch_content(_new_definition, _new_version, _new_catalog)
	_pawn_choices.clear()
	_risk_error = ""
	var archive := _day.state.death_archive.duplicate(true)
	var bankruptcies := _day.state.bankruptcy_archive.duplicate(true)
	_day.state = RunState.create(definition)
	if _save.library != null:
		archive = _save.library.archive("death_archive", String(definition.id))
		bankruptcies = _save.library.archive("bankruptcy_archive", String(definition.id))
	_day.state.death_archive.assign(archive)
	_day.state.bankruptcy_archive.assign(bankruptcies)
	if _counter != null:
		_counter.customers.prepare_night(_day.state, definition, _counter.catalog)
	if _events != null: _events.poll(_day.state, definition)
	message = "暮色又落到了铺门前。柜上的账册，翻开了第一页。"
	MarketService.sync(_day.state, definition)
	changed.emit()

func _copy_state(source: RunState) -> RunState:
	var copy := RunState.new()
	copy.goods_version = source.goods_version
	copy.expertise_history = source.expertise_history.duplicate(true)
	copy.preparation_version = source.preparation_version
	for key in source.to_read_model():
		if key in ["inventory_instances", "pawn_tickets"]: continue
		copy.set(key, source.get(key).duplicate(true) if source.get(key) is Array or source.get(key) is Dictionary else source.get(key))
	for item in source.inventory_instances:
		var clone := ItemInstance.new()
		for key in item.to_data(): clone.set(key, item.to_data()[key])
		copy.inventory_instances.append(clone)
	for ticket in source.pawn_tickets:
		var clone := PawnTicket.new()
		for key in ticket.to_data(): clone.set(key, ticket.to_data()[key])
		copy.pawn_tickets.append(clone)
	copy.visits = source.visits.duplicate()
	return copy

func counter_command(command: String, visit_id: String, detail := "", amount := 0) -> ActionResult:
	if command in ["redeem", "extend"]:
		var visit := PawnReturnService.current(_day.state)
		if visit.is_empty() or visit.id != visit_id: return _return_blocked()
		return commerce_command(command, visit.ticket_id)
	if not PawnReturnService.current(_day.state).is_empty(): return _return_blocked()
	if not _day.state.risk_pending.is_empty() or _day.state.phase in [&"dead", &"bankrupt"]: return _risk_blocked()
	if not _day.state.pending_event_id.is_empty(): return _event_blocked()
	if mirror_pending(): return _mirror_blocked()
	var result := ActionResult.new(false, "当前运行未接入柜台内容。")
	var ledger_size := _day.state.ledger_entries.size()
	if _counter != null:
		result = _counter.execute(_day, command, visit_id, detail, amount)
	if _risk != null: _risk.capture_close(_day.state)
	if _events != null: _events.poll(_day.state, definition)
	message = result.message
	_message_visit_id = visit_id
	MarketService.sync(_day.state, definition)
	changed.emit()
	_emit_receipt(ledger_size)
	return result

func counter_model() -> Dictionary:
	var model := CounterReadModels.build(_day, _counter, message, _message_visit_id)
	PawnReturnReadModels.enrich(model, _day, _commerce)
	if _commerce != null: model.merge(CommerceReadModels.build(_day, _commerce, message), true)
	if not _day.state.pending_event_id.is_empty() or mirror_pending() or _day.state.phase in [&"dead", &"bankrupt"]:
		model.trade.can_offer = false
		model.trade.can_pawn = false
		for key in ["appraisal", "dialogue", "trade", "inventory", "ledger"]:
			for button in model[key].get("buttons", []):
				button.enabled = false
				button.reason = "请先处理眼前的事情。"
	return model

func commerce_command(command: String, target: String, detail := "") -> ActionResult:
	if command not in ["redeem", "extend"] and not PawnReturnService.current(_day.state).is_empty(): return _return_blocked()
	if not _day.state.risk_pending.is_empty() or _day.state.phase in [&"dead", &"bankrupt"]: return _risk_blocked()
	if not _day.state.pending_event_id.is_empty(): return _event_blocked()
	if mirror_pending(): return _mirror_blocked()
	var result := ActionResult.new(false, "当前运行没有交易内容。")
	var ledger_size := _day.state.ledger_entries.size()
	if _commerce != null:
		result = _commerce.execute(_day, command, target, detail)
		_counter.customers.update(_day.state)
	if _risk != null: _risk.capture_close(_day.state)
	if _events != null: _events.poll(_day.state, definition)
	message = result.message
	MarketService.sync(_day.state, definition)
	changed.emit()
	_emit_receipt(ledger_size)
	return result

func _emit_receipt(previous_size: int) -> void:
	if definition.batch_selling and _day.state.ledger_entries.size() > previous_size and _day.state.ledger_entries[previous_size].kind == "sale":
		transaction_completed.emit(TradeReceiptModel.batch(_day, _counter.catalog, previous_size))
		return
	# A rejected quote can return ok=true. A new ledger posting, rather than
	# ActionResult.ok or localized message matching, proves money changed hands.
	if _counter == null or _day.state.ledger_entries.size() != previous_size + 1: return
	var receipt := TradeReceiptModel.build(_day, _counter.catalog, _day.state.ledger_entries.back())
	if not receipt.is_empty(): transaction_completed.emit(receipt)

func sell_batch(buyer_id: String, item_ids: Array, pairs: Array = []) -> ActionResult:
	var previous := _day.state.ledger_entries.size()
	var result := _commerce.sell_batch(_day, buyer_id, item_ids, pairs)
	if result.ok:
		_counter.customers.update(_day.state)
		if _risk != null: _risk.capture_close(_day.state)
		if _events != null: _events.poll(_day.state, definition)
		MarketService.sync(_day.state, definition)
	message = result.message
	changed.emit()
	_emit_receipt(previous)
	return result

func event_model() -> Dictionary:
	var model: Dictionary = _events.model(_day, message) if _events != null else {"body": "暂无记事。", "buttons": [], "pending_id": ""}
	if SevenNightPlan.enabled(definition): model.body += "\n\n" + seven_notice()
	return model

func event_command(event_id: String, choice_id: String) -> ActionResult:
	if mirror_pending(): return _mirror_blocked()
	if not _day.state.risk_pending.is_empty() or _day.state.phase in [&"dead", &"bankrupt"]: return _risk_blocked()
	var result := ActionResult.new(false, "没有事件内容。")
	var previous := _copy_state(_day.state)
	var checkpoint := false
	if _events != null:
		var event := _events.catalog.get_definition("events", event_id) as EventDefinition
		checkpoint = event != null and event.presentation.get("checkpoint", false) and String(_day.state.phase) in SaveCodec.CHECKPOINTS
		result = _events.choose(_day, event_id, choice_id)
		if result.ok and _counter != null: _counter.customers.update(_day.state)
	if _risk != null: _risk.capture_close(_day.state)
	if result.ok and checkpoint and not _save.save_state(_day.state, definition, content_version):
		_day.state = previous
		result = ActionResult.new(false, "未推进；请重试。" + _save.error_message)
	message = result.message
	MarketService.sync(_day.state, definition)
	changed.emit()
	return result

func _event_blocked() -> ActionResult:
	message = "请先到「铺中记事」处理眼前的事情。"
	MarketService.sync(_day.state, definition)
	changed.emit()
	return ActionResult.new(false, message)

func risk_model() -> Dictionary:
	var model := RiskReadModels.build(_day, _risk, _risk_error) if _risk != null else {"body": "柜里暂无异物。", "buttons": [], "history": "", "pending_id": "", "held_ids": [], "intrusion": false}
	model.attention_id = ""
	if _mirror != null:
		var encounter := _mirror.model(_day)
		model.attention_id = encounter.attention_id
		if not encounter.body.is_empty():
			model.body = encounter.body
			if not mirror_pending(): model.body += "\n\n关门前，请将红布覆回镜面。"
			if mirror_pending(): model.buttons = []
			model.buttons = encounter.buttons + model.buttons
		if not _day.state.mirror_history.is_empty():
			var latest: Dictionary = _day.state.mirror_history.back()
			if latest.action == "pursue" and latest.night == _day.state.current_night_index and latest.minute == _day.state.game_minutes and _day.state.phase == &"open":
				model.body = MirrorEncounterService.find_definition(definition, latest.encounter_id).text("pursue_text") + "\n\n镜面还在眼前，关门前请覆好红布。"
		for row in _day.state.mirror_history:
			if row.action == "pursue":
				var encounter_def := MirrorEncounterService.find_definition(definition, row.encounter_id)
				model.history = "铺中旧事\n" + encounter_def.text("pursue_text") + "\n\n" + model.history
	MirrorChapterService.decorate(model, _day, _events)
	return model

func risk_command(command: String, id: String, detail := "") -> ActionResult:
	if command == "study": return study_command(id, detail)
	if command in ["cover", "uncover"] and not PawnReturnService.current(_day.state).is_empty(): return _return_blocked()
	if command.begins_with("mirror_"): return mirror_command(id, command.trim_prefix("mirror_"))
	if _day.state.phase in [&"dead", &"bankrupt"]: return _risk_blocked()
	if _risk == null: return ActionResult.new(false, "本运行未启用鬼货。")
	if not _day.state.pending_event_id.is_empty(): return _event_blocked()
	if mirror_pending(): return _mirror_blocked()
	var result: ActionResult
	if command in ["retreat", "defy"]:
		var previous := _copy_state(_day.state)
		result = RoomFlow.respond(_day.state, _risk, id, command) if definition.private_room else _risk.respond(_day.state, id, command)
		if result.ok and not definition.private_room: FeeService.finish(_day.state, definition)
		if result.ok and not _save.save_state(_day.state, definition, content_version):
			_day.state = previous
			result = ActionResult.new(false, "应对未提交，请重试。" + _save.error_message)
	else:
		result = _risk.handle(_day, id, command)
		if result.ok:
			_counter.customers.update(_day.state)
			_events.poll(_day.state, definition)
	_risk_error = "" if result.ok else result.message
	message = result.message
	MarketService.sync(_day.state, definition)
	changed.emit()
	return result

func _risk_blocked() -> ActionResult:
	message = "铺门上了封条，柜前再无人等候。" if _day.state.phase == &"bankrupt" else ("灯已冷了，铺中再没有人应声。" if _day.state.phase == &"dead" else "请先在「鬼货与绝当录」应对镜中来客。")
	MarketService.sync(_day.state, definition)
	changed.emit()
	return ActionResult.new(false, message)

func mirror_pending() -> bool:
	return _mirror != null and _mirror.pending(_day)

func mirror_command(id: String, command: String) -> ActionResult:
	if _mirror == null or not _day.state.risk_pending.is_empty() or _day.state.phase in [&"dead", &"bankrupt"]: return _risk_blocked()
	var result := _mirror.choose(_day, id, command)
	_risk_error = "" if result.ok else result.message
	if _events != null and not mirror_pending(): _events.poll(_day.state, definition)
	message = result.message
	MarketService.sync(_day.state, definition)
	changed.emit()
	return result

func _mirror_blocked() -> ActionResult:
	message = "镜里的旧当票还在眼前。请先收回视线，或再看一眼。"
	MarketService.sync(_day.state, definition)
	changed.emit()
	return ActionResult.new(false, message)

func economy_model() -> Dictionary:
	return {"description": FeeService.describe(_day.state, definition), "archive": FeeService.archive_text(_day.state), "outstanding": FeeService.outstanding(_day.state)}

func _return_blocked() -> ActionResult:
	message = "持票的老客正在柜前等候，请先验票办理。"
	MarketService.sync(_day.state, definition)
	changed.emit()
	return ActionResult.new(false, message)

func pawn_disposal_model() -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	if _commerce == null or _day.state.phase != &"night_resolution": return rows
	for ticket in _commerce.pawns.maturities(_day.state):
		var item := InventoryManager.new().find(_day.state, ticket.item_instance_id)
		var terms := _commerce.catalog.get_definition("pawn_terms", ticket.terms_id) as PawnTermsDefinition
		rows.append({"id": ticket.ticket_id, "number": "%03d" % (_day.state.pawn_tickets.find(ticket) + 1), "item": (_commerce.catalog.get_definition("items", item.definition_id) as ItemDefinition).display_name,
			"customer": VarietyService.name_for(ticket.person, _commerce.catalog.get_definition("customers", ticket.customer_id)),
			"principal": ticket.principal, "quote": _commerce.pawns.transfer_quote(ticket, terms), "choice": _pawn_choices.get(ticket.ticket_id, "")})
	return rows

func choose_pawn_disposal(id: String, choice: String) -> ActionResult:
	if _commerce == null or _day.state.phase != &"night_resolution" or choice not in ["keep", "transfer"]: return ActionResult.new(false, "眼下不能处置当票。")
	var ticket := _commerce.pawns.find(_day.state, id)
	if ticket == null or ticket not in _commerce.pawns.maturities(_day.state): return ActionResult.new(false, "当票尚未到期或已经结清。")
	_pawn_choices[id] = choice
	message = "选好后可改动；逐张核妥，再一并合账。"
	MarketService.sync(_day.state, definition)
	changed.emit()
	return ActionResult.new(true, message)

# Bell exposes only the action available at the counter, never the future visitor's identity.
func bell_model() -> Dictionary:
	var model := {"mode": "", "target_id": "", "enabled": false, "hint": "开铺后才能招呼客人。"}
	if _counter == null or _day.state.phase != &"open": return model
	if not _day.state.pending_event_id.is_empty() or not _day.state.risk_pending.is_empty() or mirror_pending():
		model.hint = "请先处理眼前的事情。"
		return model
	if not PawnReturnService.current(_day.state).is_empty():
		model.hint = "原当户带票来赎，请先办妥当票。"
		return model
	var visit := _counter.customers.active(_day.state)
	if visit != null:
		var reason := _counter.reason(_day, "reject", visit.visit_id)
		var customer := _counter.catalog.get_definition("customers", visit.customer_id) as CustomerDefinition
		model.merge({"mode": "dismiss", "target_id": visit.visit_id, "enabled": reason.is_empty(),
			"hint": "长按1秒送客 · 耗时%d分钟；松开取消。" % customer.terms.reject_minutes if reason.is_empty() else reason}, true)
		return model
	model.mode = "wait"
	model.enabled = _day.state.visits.any(func(v: CustomerVisit) -> bool: return v.status in ["scheduled", "waiting"] and v.arrival < definition.night_minutes and v.expires_at > _day.state.game_minutes)
	model.hint = "轻按铃铛，等下一位客人来；时辰会向前走。" if model.enabled else "今夜已无来客，可以收铺了。"
	return model

func bell_command(mode: String, target_id := "") -> ActionResult:
	var model := bell_model()
	if not model.enabled or model.mode != mode or model.target_id != target_id:
		return ActionResult.new(false, "柜前的情形已经变了。" if model.enabled else model.hint)
	if mode == "dismiss": return counter_command("reject", target_id)
	# Advance through normal time boundaries so events and arrivals are never skipped.
	var start := _day.state.game_minutes
	while _day.state.phase == &"open" and _counter.customers.active(_day.state) == null:
		_counter.customers.update(_day.state)
		if _counter.customers.active(_day.state) != null or not PawnReturnService.current(_day.state).is_empty(): break
		var spent := _day.spend_action(definition.time_step)
		if not spent.ok: return spent
		_counter.customers.update(_day.state)
		if _risk != null: _risk.capture_close(_day.state)
		if _events != null: _events.poll(_day.state, definition)
		if not _day.state.pending_event_id.is_empty() or not _day.state.risk_pending.is_empty() or mirror_pending(): break
	MarketService.sync(_day.state, definition)
	message = "铃声落下，门外终于响起脚步。" if _counter.customers.active(_day.state) != null else "你在柜后等着，铺里有了动静。"
	changed.emit()
	return ActionResult.new(true, message + "等候%d分钟。" % (_day.state.game_minutes - start))

func study_command(id: String, choice: String) -> ActionResult:
	if not MirrorChapterService.enabled(definition) or _day.state.phase != &"open" or not _day.state.risk_pending.is_empty(): return _risk_blocked()
	if not _day.state.pending_event_id.is_empty(): return _event_blocked()
	if mirror_pending(): return _mirror_blocked()
	if not PawnReturnService.current(_day.state).is_empty(): return _return_blocked()
	var result := _events.investigate(_day, id, choice)
	_counter.customers.update(_day.state)
	_risk.capture_close(_day.state)
	message = result.message
	MarketService.sync(_day.state, definition)
	changed.emit()
	return result
