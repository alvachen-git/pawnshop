class_name RunSession
extends RefCounted

signal restored
signal storage_requested(mode: String)
signal leave_requested(destination: String)
signal changed
signal transaction_completed(receipt: Dictionary)
signal operation_completed(feedback: Dictionary)

const NEW_RUN_MESSAGE := "暮色又落到了铺门前。柜上的账册，翻开了第一页。"

var _model_cache: Dictionary = {}
var _notifying := false

var _ghost_depth := 0
var definition: RunDefinition
var content_version: int
# Transient feedback ownership; never serialized into the player's save.
var _message_visit_id := ""
var _negotiation_reactions := NegotiationReactions.new()
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
	if _save.get_meta("legacy_social_intro", false): _day.state.social.erase("intro_step")
	_day.state.ghost_catalog = catalog
	if _save is GhostReplayStore:
		_day.state.run_seed = int(_save.origin.seed)
		_day.state.run_token = _save.origin.run_token
	_day.state.ghost_origin = {"seed": _day.state.run_seed, "run_token": _day.state.run_token}
	_day.state.death_archive.assign(_save.read_archive())
	_day.state.bankruptcy_archive.assign(_save.read_bankruptcy_archive())
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
	var key := "state"
	if _notifying and _model_cache.has(key): return _model_cache[key].duplicate(true)
	var model: Dictionary = _day.state.to_read_model()
	if _notifying: _model_cache[key] = model.duplicate(true)
	return model

func seven_notice() -> String:
	if not SevenNightPlan.enabled(definition): return ""
	var introductions := {1: "借据压在柜上。\n本金五百银元。\n第二十一夜还二百，第四十九夜还余款三百。", 2: "杂货商常收旧物，瓷器收藏客19:00–22:00来收。出门交货往返20分钟，店里的客人可不会替你停住钟。", 3: "今夜起可办活当：期限3夜，赎金为本金加10%固定息费，息费向上取整。在当旧物须替原主保管。", 7: "七夜的账即将合拢。未卖的货、未到期的票与借据都照实留着，本金今夜不催收。"}
	if InvestigationService.enabled(definition):
		introductions[7] = "七夜的账暂结一页。铺子照常开，未办完的旧事仍可接着查。"
		introductions[10] = "十夜的账将合拢。未到期的票、托出的口信与未回的委托，照实留在账上。"
	if FirstDebt.enabled(definition):
		introductions[1] = "借据本金500银元，日息5银元，另付铺费5银元。息费未付清便记短款，须在次夜夜末补齐。"
		introductions.erase(10)
	return String(introductions.get(_day.state.current_night_index, "")) + PreparationService.notice(_day.state, _counter.catalog) + MirrorChapterService.summary(_day.state, definition) + FamiliarStories.note(_day.state) + ("\n" + NightMarketRisk.note(_day.state) if NightMarketPlan.enabled(definition) else "") + GhostGuests.notice(_day.state, _counter.catalog) + ("\n查访回报已送到，可去「托人查访」拆阅。" if _day.state.investigation.get("delivered", false) and not _day.state.investigation.get("read", false) else "")

func has_save() -> bool:
	return _save.exists()

func can_execute(command: String) -> bool:
	if command == "finish_trial": return FirstDebt.enabled(definition) and _day.state.phase == &"day_summary" and _day.state.current_night_index >= 18
	if MirrorEndingService.active(_day.state): return false
	if MilitaryIntroduction.active(_day.state): return false
	if command == "open_shop" and SocialRules.blocked(_day.state): return false
	if command in RoomKeepsakes.COMMANDS: return not mirror_pending() and RoomKeepsakes.can_execute(_day.state, command)
	if command.begins_with("seal_cloth/"): return not mirror_pending() and NightMarketRisk.treatment_reason(_day, command.trim_prefix("seal_cloth/")).is_empty()
	if command.begins_with("prep_"): return PreparationService.reason(_day.state, definition, command.trim_prefix("prep_")).is_empty()
	if command == "open_shop" and SevenNightPlan.enabled(definition) and not OpeningPreparation.enabled(definition) and _day.state.current_night_index >= 4 and not PreparationService.used(_day.state, "finish", _day.state.current_night_index): return false
	if not PawnReturnService.current(_day.state).is_empty(): return false
	if command == "resolve_night" and _commerce != null and not _commerce.pawns.disposal_reason(_day.state, _commerce.catalog, _pawn_choices).is_empty(): return false
	return _day.state.risk_pending.is_empty() and _day.state.phase not in [&"dead", &"bankrupt"] and _day.state.pending_event_id.is_empty() and not mirror_pending() and (_day.can_execute(command) or RoomFlow.can_execute(_day.state, command))

func execute(command: String, detail := "") -> ActionResult:
	if LivingMirror.enabled(definition) and _ghost_depth == 0 and command == "open_shop" and can_execute(command) and _day.state.current_night_index >= 2 and not PreparationService.used(_day.state, "finish", _day.state.current_night_index):
		var prepared := execute("prep_finish")
		if not prepared.ok: return prepared
	# Invalid or repeated placement must not grow the transcript or write a save.
	if command in RoomKeepsakes.COMMANDS and (not detail.is_empty() or not can_execute(command)):
		return ActionResult.new(false, "现在不能挪动照片。")
	return _journal_call("execute", [command, detail])

func _impl_execute(command: String, detail := "") -> ActionResult:
	if MilitaryIntroduction.active(_day.state): return ActionResult.new(false, "孙大元还在柜前，请先把话说完。")
	if command == "finish_trial":
		if not can_execute(command): return ActionResult.new(false, "请先完成今夜结算。")
		_day.state.phase = &"run_ended"
		_persist()
		_emit_changed()
		return ActionResult.new(true, "本次试玩已结算。" + FirstDebt.outcome(_day.state))
	if command in RoomKeepsakes.COMMANDS:
		var placed := RoomKeepsakes.execute(_day.state, command)
		if placed.ok: _persist()
		message = placed.message
		_emit_changed()
		return placed
	if command.begins_with("prep_"):
		var previous := _copy_state(_day.state)
		var prepared := OpeningPreparation.perform(_day.state, definition, _counter.catalog, command.trim_prefix("prep_"), detail) if OpeningPreparation.enabled(definition) else PreparationService.perform(_day.state, definition, command.trim_prefix("prep_"))
		if prepared.ok and OpeningPreparation.enabled(definition): OpeningPreparation.refresh_visits(_day.state, definition, _counter.catalog)
		if prepared.ok and not _persist():
			_day.state = previous
			prepared = ActionResult.new(false, "准备未记下，请重试。" + _save.error_message)
		message = prepared.message
		_emit_changed()
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
			_emit_changed()
			return ActionResult.new(false, error)
	if command.begins_with("seal_cloth/"):
		var treatment_before := _feedback_snapshot()
		var treated := NightMarketRisk.treat(_day, command.trim_prefix("seal_cloth/"))
		if _risk != null: _risk.capture_close(_day.state)
		if _events != null: _events.poll(_day.state, definition)
		MarketService.sync(_day.state, definition)
		message = treated.message
		_publish_feedback(treatment_before, command, "", treated)
		_emit_changed()
		return treated
	# Lifecycle checkpoints plus v25 opening story checkpoints roll back atomically.
	var checkpoint := command in ["resolve_night", "continue_run", "enter_room", "sleep", "finish_sleep"] or (AqiCompanion.enabled(definition) and command == "open_shop")
	var previous: RunState
	if checkpoint:
		previous = _copy_state(_day.state)
	if command == "resolve_night" and not mirror_pending() and _day.can_execute(command) and _commerce != null:
		_commerce.pawns.resolve_maturities(_day.state, definition.night_minutes, _commerce.catalog, _pawn_choices)
	if command == "resolve_night" and _day.can_execute(command):
		ReputationGrowth.settle(_day.state)
		MilitaryService.settle(_day.state)
		NightMarketRisk.settle(_day.state)
		FeeService.settle(_day.state, definition)
	var prior_visitor: CustomerVisit = _counter.customers.active(_day.state) if _counter != null else null
	var feedback_before := _feedback_snapshot()
	var result := RoomFlow.execute(_day.state, _risk, command) if command in ["enter_room", "sleep", "finish_sleep"] else _day.execute(command)
	if result.ok and _risk != null:
		_risk.capture_close(_day.state)
		if command == "resolve_night":
			if definition.private_room: RoomFlow.seal(_day.state, _risk)
			else: _risk.settle(_day.state)
	if result.ok and (command == "finish_sleep" or (command == "resolve_night" and not definition.private_room)): FeeService.finish(_day.state, definition)
	if result.ok and command == "open_shop":
		MilitaryService.spawn_supply(_day.state)
		ShopGrowthService.lock_night(_day.state)
	if result.ok and _counter != null:
		if command == "continue_run" and _day.state.phase == &"pre_open":
			GhostGuests.dawn(_day.state)
			InvestigationService.dawn(_day.state)
			_counter.customers.prepare_night(_day.state, definition, _counter.catalog)
		_counter.customers.update(_day.state)
	if result.ok and command == "open_shop" and _day.state.shop_growth_enabled: _persist()
	if result.ok and prior_visitor != null and prior_visitor.status == "timed_out" and prior_visitor.voice.has("timed_out"): result.message += "\n" + String(prior_visitor.voice.timed_out)
	if result.ok and _events != null: _events.poll(_day.state, definition)
	MarketService.sync(_day.state, definition)
	if result.ok and checkpoint:
		if not _persist():
			_day.state = previous
			result = ActionResult.new(false, "未推进；请重试。" + _save.error_message)
		elif command != "open_shop":
			result.message = "这一夜的账，记下了。"
	if result.ok and command == "resolve_night":
		_pawn_choices.clear()
		_day.state.pending_pawn_choices.clear()
	message = result.message
	if prior_visitor != null and prior_visitor.status == "timed_out": _message_visit_id = prior_visitor.visit_id
	MarketService.sync(_day.state, definition)
	_publish_feedback(feedback_before, command, "", result)
	_emit_changed()
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
		if restored.personal_risk_enabled: emit_signal("restored")
		_pawn_choices = restored.pending_pawn_choices.duplicate(true)
		if _counter != null and restored.phase == &"pre_open":
			_counter.customers.prepare_night(restored, definition, _counter.catalog)
	message = result.message
	MarketService.sync(_day.state, definition)
	_emit_changed()
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
	_day.state.ghost_catalog = _counter.catalog if _counter != null else null
	_day.state.ghost_origin = {"seed": _day.state.run_seed, "run_token": _day.state.run_token}
	if _save.library != null:
		archive = _save.library.archive("death_archive", String(definition.id))
		bankruptcies = _save.library.archive("bankruptcy_archive", String(definition.id))
	_day.state.death_archive.assign(archive)
	_day.state.bankruptcy_archive.assign(bankruptcies)
	if _counter != null:
		_counter.customers.prepare_night(_day.state, definition, _counter.catalog)
	if _events != null: _events.poll(_day.state, definition)
	message = NEW_RUN_MESSAGE
	MarketService.sync(_day.state, definition)
	_emit_changed()

func _copy_state(source: RunState) -> RunState:
	if replaying: return source
	var started := Time.get_ticks_usec()
	var snapshot := RunSnapshot.copy(source)
	_profile("snapshots", started)
	return snapshot

func counter_command(command: String, visit_id: String, detail := "", amount := 0) -> ActionResult:
	if command == "fd_event":
		return observe_document(visit_id) if visit_id in FirstDebt.DOCUMENTS else event_command(visit_id, detail)
	if command.begins_with("ending_"): return mirror_resolution_command(command.trim_prefix("ending_"), visit_id)
	return _journal_call("counter_command", [command, visit_id, detail, amount])

func _impl_counter_command(command: String, visit_id: String, detail := "", amount := 0) -> ActionResult:
	if command == "pawn" and PawnInterestPolicy.enabled(definition):
		var pawn_error := _counter.reason(_day, command, visit_id, detail, amount)
		if not pawn_error.is_empty(): return ActionResult.new(false, pawn_error)
	# v41 porcelain preflights failed funding before polling unrelated events.
	var porcelain_visit := _counter.customers.active(_day.state) if _counter != null else null
	if command in ["offer","pawn"] and porcelain_visit != null and (PorcelainEconomy.handles(_day.state,porcelain_visit.item) or GramophoneEconomy.handles(_day.state,porcelain_visit.item) or CameraEconomy.handles(_day.state,porcelain_visit.item)):
		var why := _counter.reason(_day,command,visit_id,detail,amount)
		if not why.is_empty(): return ActionResult.new(false,why)
	# Rejected new pressure attempts must not poll events or synchronize markets.
	if command in [FanBargainingService.COMMAND, "condition_pressure", "watch_bluff", "watch_claim", "pearl_claim", "gramophone_claim", "camera_claim", "porcelain_claim", "bangle_claim"] or (FanConditionService.enabled(definition) and command in ["appraise", "judge"]):
		var error := _counter.reason(_day, command, visit_id, detail, amount)
		if not error.is_empty(): return ActionResult.new(false, error)
	if command == "military_intro":
		if visit_id != MilitaryIntroduction.id(_day.state) or amount != 0: return ActionResult.new(false, "请先听清柜前来客的话。")
		return social_command("intro_talk", detail)
	if command == "lu_intro":
		if not LuIntroduction.active(_day.state) or visit_id != _day.state.pending_event_id or amount != 0: return ActionResult.new(false, "请按陆掌眼眼前的话头作答。")
		return event_command(visit_id, detail)
	if (not replaying or DragonSearch.enabled(_day.state)) and FirstDebt.chen_recognition_due(_day.state):
		return ActionResult.new(false, "陈小满还在柜前，先听她把话说完。")
	if command == "soul_inspect": return inspect_customer(visit_id)
	var growth_visit := _counter.customers.active(_day.state)
	if growth_visit != null and growth_visit.purpose == "display_buyer":
		var ledger_start := _day.state.ledger_entries.size()
		var result := ShopGrowthService.trade(_day, command, visit_id, detail, amount)
		if result.ok:
			if _risk != null: _risk.capture_close(_day.state)
			_events.poll(_day.state, definition)
			MarketService.sync(_day.state, definition)
			_persist()
			_emit_receipt(ledger_start)
		message = result.message
		_message_visit_id = visit_id
		return result
	if command in ["meeting_question", "meeting_end"]:
		if amount != 0: return ActionResult.new(false, "这次只谈旧事。")
		return investigation_command(command, visit_id + ("|" + detail if command == "meeting_question" else ""))
	if command in ["swap_accept", "swap_reject"]:
		if not detail.is_empty() or amount != 0: return ActionResult.new(false, "这笔换物只按约定的八十银元办理。")
		var before := _day.state.ledger_entries.size()
		var swapped := GhostGuests.exchange(_day, _counter.catalog, visit_id, command == "swap_accept")
		if _risk != null: _risk.capture_close(_day.state)
		if _events != null: _events.poll(_day.state, definition)
		MarketService.sync(_day.state, definition)
		message = swapped.message
		_message_visit_id = visit_id
		_emit_changed()
		_emit_receipt(before)
		return swapped
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
	var feedback_before := _feedback_snapshot()
	if _counter != null:
		var negotiating_visit := _counter.customers.active(_day.state)
		var asking_before := (negotiating_visit.trade.asking_price if command == "pawn" else FanBargainingService.asking(_day.state, negotiating_visit)) if negotiating_visit != null else 0
		result = _counter.execute(_day, command, visit_id, detail, amount)
		_negotiation_reactions.record(_day, negotiating_visit, asking_before, command, detail, result)
		if result.ok and FanConditionService.enabled(definition) and command in ["condition_pressure", "offer", "pawn"]: _persist()
		if result.ok and PawnInterestPolicy.enabled(definition) and command in ["early_redeem", "defer_redeem"]: _persist()
		if result.ok and command == "question" and PawnInterestPolicy.timing_question(_day, negotiating_visit, detail): _persist()
		if result.ok and FirstDebt.enabled(definition) and negotiating_visit != null and negotiating_visit.customer_id in ["fd_seller", "fd_chen"]: _persist()
	if _risk != null: _risk.capture_close(_day.state)
	if _events != null: _events.poll(_day.state, definition)
	message = result.message
	_message_visit_id = visit_id
	MarketService.sync(_day.state, definition)
	_publish_feedback(feedback_before, command, visit_id, result)
	_emit_changed()
	_emit_receipt(ledger_size)
	if result.ok: _first_debt_trade_checkpoint(ledger_size)
	return result

func counter_model() -> Dictionary:
	var key := "counter"
	if _notifying and _model_cache.has(key): return _model_cache[key].duplicate(true)
	var model: Dictionary = _build_counter_model()
	if _notifying: _model_cache[key] = model.duplicate(true)
	return model

func _build_counter_model() -> Dictionary:
	var model := CounterReadModels.build(_day, _counter, message, _message_visit_id)
	if MilitaryIntroduction.active(_day.state) or LuIntroduction.active(_day.state): return model
	model.trade.reactions = _negotiation_reactions.for_visit(_day.state, model.active_id)
	var active_visit := _counter.customers.active(_day.state)
	if active_visit != null and GramophoneEconomy.handles(_day.state,active_visit.item):
		for reply in GramophoneNegotiation.history(_day.state,active_visit):
			if reply not in model.trade.reactions: model.trade.reactions.append(reply)
	if active_visit != null and CameraEconomy.handles(_day.state,active_visit.item):
		for reply in CameraNegotiation.history(_day.state,active_visit):
			if reply not in model.trade.reactions: model.trade.reactions.append(reply)
	if active_visit != null and WatchNegotiation.handles(_day.state,active_visit.item):
		# Restore previous customer replies after a cold load as well as live play.
		for reply in WatchNegotiation.history(_day.state,active_visit):
			if reply not in model.trade.reactions: model.trade.reactions.append(reply)
	if active_visit != null and PorcelainEconomy.handles(_day.state,active_visit.item):
		for reply in PorcelainNegotiation.history(_day.state,active_visit):
			if reply not in model.trade.reactions: model.trade.reactions.append(reply)
	if active_visit != null and BangleEconomy.handles(_day.state,active_visit.item):
		for reply in BangleNegotiation.history(_day.state,active_visit):
			if reply not in model.trade.reactions: model.trade.reactions.append(reply)
	if active_visit != null and PearlEconomy.handles(_day.state,active_visit.item):
		for reply in PearlNegotiation.history(_day.state,active_visit):
			if reply not in model.trade.reactions: model.trade.reactions.append(reply)
	PawnReturnReadModels.enrich(model, _day, _commerce)
	if _commerce != null: model.merge(CommerceReadModels.build(_day, _commerce, message), true)
	ShopGrowthReadModels.inventory(model, _day)
	FanAppraisalModels.enrich(model, _day)
	if not _day.state.pending_event_id.is_empty() or mirror_pending() or _day.state.phase in [&"dead", &"bankrupt"]:
		model.trade.can_offer = false
		model.trade.can_pawn = false
		for key in ["appraisal", "dialogue", "trade", "inventory", "ledger"]:
			for button in model[key].get("buttons", []):
				button.enabled = false
				button.reason = "请先处理眼前的事情。"
	GhostGuests.decorate(model, _day, _counter.catalog)
	if LivingMirror.enabled(definition):
		var mirror_view := {"buttons": [], "history": "", "body": ""}
		LivingMirror.decorate(mirror_view, _day, _counter.catalog)
		model.dialogue.buttons.append_array(mirror_view.buttons)
		model.dialogue.body += "\n\n" + mirror_view.history
		if model.dialogue.has("visual"):
			var target := LivingMirror.customer(_day, _counter.catalog)
			for row in _day.state.soul_history:
				if row.visit_id == target.get("id", "") and row.result != "expired": model.dialogue.visual["soul_note"] = LivingMirror.describe(row)
	if FirstDebt.enabled(definition): FirstDebt.decorate(model, _day, _events, _counter)
	return model

func commerce_command(command: String, target: String, detail := "") -> ActionResult:
	return _journal_call("commerce_command", [command, target, detail])

func _impl_commerce_command(command: String, target: String, detail := "") -> ActionResult:
	if command not in ["redeem", "extend"] and not PawnReturnService.current(_day.state).is_empty(): return _return_blocked()
	if not _day.state.risk_pending.is_empty() or _day.state.phase in [&"dead", &"bankrupt"]: return _risk_blocked()
	if not _day.state.pending_event_id.is_empty(): return _event_blocked()
	if mirror_pending(): return _mirror_blocked()
	var result := ActionResult.new(false, "当前运行没有交易内容。")
	var ledger_size := _day.state.ledger_entries.size()
	var feedback_before := _feedback_snapshot()
	if _commerce != null:
		result = _commerce.execute(_day, command, target, detail)
		_counter.customers.update(_day.state)
	if _risk != null: _risk.capture_close(_day.state)
	if _events != null: _events.poll(_day.state, definition)
	message = result.message
	MarketService.sync(_day.state, definition)
	_publish_feedback(feedback_before, command, target, result)
	_emit_changed()
	_emit_receipt(ledger_size)
	if result.ok: _first_debt_trade_checkpoint(ledger_size)
	return result

func _first_debt_trade_checkpoint(previous_size: int) -> void:
	if not FirstDebt.enabled(definition): return
	for entry in _day.state.ledger_entries.slice(previous_size):
		var item := InventoryManager.new().find(_day.state, entry.item_instance_id)
		if item != null and item.definition_id in [FirstDebt.PHOENIX, FirstDebt.DRAGON]:
			_persist()
			return

func _emit_receipt(previous_size: int) -> void:
	if definition.batch_selling and _day.state.ledger_entries.size() > previous_size and _day.state.ledger_entries[previous_size].kind == "sale":
		var batch := TradeReceiptModel.batch(_day, _counter.catalog, previous_size)
		if not batch.is_empty():
			_emit_transaction(batch)
			return
	# A rejected quote can return ok=true. A new ledger posting, rather than
	# ActionResult.ok or localized message matching, proves money changed hands.
	if _counter == null or _day.state.ledger_entries.size() != previous_size + 1: return
	var receipt := TradeReceiptModel.build(_day, _counter.catalog, _day.state.ledger_entries.back())
	if not receipt.is_empty(): _emit_transaction(receipt)

func sell_batch(buyer_id: String, item_ids: Array, pairs: Array = []) -> ActionResult:
	return _journal_call("sell_batch", [buyer_id, item_ids, pairs])

func _impl_sell_batch(buyer_id: String, item_ids: Array, pairs: Array = []) -> ActionResult:
	var previous := _day.state.ledger_entries.size()
	var feedback_before := _feedback_snapshot()
	var result := _commerce.sell_batch(_day, buyer_id, item_ids, pairs)
	if result.ok:
		_counter.customers.update(_day.state)
		if _risk != null: _risk.capture_close(_day.state)
		if _events != null: _events.poll(_day.state, definition)
		MarketService.sync(_day.state, definition)
	message = result.message
	_publish_feedback(feedback_before, "sell_batch", buyer_id, result)
	_emit_changed()
	_emit_receipt(previous)
	if result.ok: _first_debt_trade_checkpoint(previous)
	return result

# Public presentation snapshots only; neither hidden item variants nor reserves
# cross the UI boundary. No feedback state is serialized.
func _feedback_snapshot() -> Dictionary:
	if not operation_completed.has_connections(): return {}
	var model := counter_model()
	return {"run": _day.state.run_token, "state_id": _day.state.get_instance_id(),
		"counter": model, "cash": _day.state.cash, "minute": _day.state.game_minutes,
		"ledger_size": _day.state.ledger_entries.size(), "history_size": _day.state.visit_history.size()}

func _publish_feedback(before: Dictionary, command: String, target: String, result: ActionResult) -> void:
	if before.is_empty(): return
	if before.state_id != _day.state.get_instance_id(): return
	var departures: Array = []
	for row in _day.state.visit_history.slice(before.history_size):
		departures.append({"visit_id": row.visit_id, "outcome": row.outcome})
	_emit_operation({"command": command, "target": target, "ok": result.ok,
		"message": result.message, "before": before, "after": _feedback_snapshot(), "departures": departures,
		"paid": _day.state.ledger_entries.size() > before.ledger_size})

func receipt_for(transaction_id: String) -> Dictionary:
	for index in _day.state.ledger_entries.size():
		var entry: Dictionary = _day.state.ledger_entries[index]
		if entry.transaction_id != transaction_id: continue
		if definition.batch_selling and entry.kind == "sale":
			var batch := TradeReceiptModel.batch(_day, _counter.catalog, index)
			if not batch.is_empty(): return batch
		return TradeReceiptModel.build(_day, _counter.catalog, entry)
	return {}

func companion_model() -> Dictionary:
	var model := AqiCompanion.model(_day, _events, _counter, mirror_pending() or MirrorEndingService.active(_day.state))
	if model.get("available", false) and PhoenixRecovery.hint_due(_day.state):
		var event := _events.catalog.get_definition("events", PhoenixRecovery.HINT) as EventDefinition
		model["notification"] = {"id": event.id, "choice": "heard", "title": "柜边的阿七", "text": event.body}
	return model

func old_debt_model() -> Dictionary:
	return AqiCompanion.old_debt(_day, _events)

func event_model() -> Dictionary:
	var key := "event"
	if _notifying and _model_cache.has(key): return _model_cache[key].duplicate(true)
	var model: Dictionary = _build_event_model()
	if _notifying: _model_cache[key] = model.duplicate(true)
	return model

func _build_event_model() -> Dictionary:
	var model: Dictionary = _events.model(_day, message) if _events != null else {"body": "暂无记事。", "buttons": [], "pending_id": ""}
	if not _day.state.risk_pending.is_empty():
		model.presentation = {}
		model.body = "柜前的动静还没有停，先处理眼前的事情。"
		model.text = ""
		model.title = ""
		model.pending_id = ""
		model.buttons = []
	if SevenNightPlan.enabled(definition): model.body += "\n\n" + seven_notice()
	return model

func event_command(event_id: String, choice_id: String) -> ActionResult:
	return _journal_call("event_command", [event_id, choice_id])

func _impl_event_command(event_id: String, choice_id: String) -> ActionResult:
	if event_id in LuIntroduction.ALL_EVENTS and not LuIntroduction.active(_day.state): return ActionResult.new(false, "先把柜前来客的话说完。")
	if FirstDebt.enabled(definition) and event_id.begins_with("fd_"):
		var before_minute := _day.state.game_minutes
		var result := FirstDebt.choose(_day, _events, _counter, event_id, choice_id, replaying and not DragonSearch.enabled(_day.state))
		if result.ok:
			if _day.state.game_minutes != before_minute: _counter.customers.update(_day.state)
			_risk.capture_close(_day.state)
			_events.poll(_day.state, definition)
			MarketService.sync(_day.state, definition)
			_persist()
		message = result.message
		if FirstDebt.revised(_day.state): _message_visit_id = "first_debt/dialogue"
		_emit_changed()
		return result
	if mirror_pending(): return _mirror_blocked()
	if not _day.state.risk_pending.is_empty() or _day.state.phase in [&"dead", &"bankrupt"]: return _risk_blocked()
	var result := ActionResult.new(false, "没有事件内容。")
	var previous := _copy_state(_day.state)
	var checkpoint := false
	if _events != null:
		var event := _events.catalog.get_definition("events", event_id) as EventDefinition
		checkpoint = event != null and event.presentation.get("checkpoint", false) and (String(_day.state.phase) in SaveCodec.CHECKPOINTS or (AqiCompanion.enabled(definition) and _day.state.phase == &"open"))
		if event != null and event.presentation.get("scene", "") == "aqi_companion":
			if not companion_model().get("available", false): return ActionResult.new(false, "先招呼客人，等会儿再聊。")
			result = _events.investigate(_day, event_id, choice_id)
		else:
			result = _events.choose(_day, event_id, choice_id)
		if result.ok and event_id == MirrorDreamService.EVENT:
			# Event history and the existing sleep settlement share the outer journal commit.
			result = _impl_execute("finish_sleep")
		elif result.ok and event_id == MirrorDreamService.CALL and choice_id == "ignore":
			result = _impl_execute("finish_sleep")
			if result.ok and _day.state.phase == &"day_summary" and _day.state.pending_event_id.is_empty():
				result = _impl_execute("continue_run")
		elif result.ok and event_id == MirrorDreamService.MORNING:
			result = _impl_execute("continue_run")
		if result.ok and _counter != null: _counter.customers.update(_day.state)
	if _risk != null: _risk.capture_close(_day.state)
	if result.ok and checkpoint and not _persist():
		_day.state = previous
		result = ActionResult.new(false, "未推进；请重试。" + _save.error_message)
	message = result.message
	MarketService.sync(_day.state, definition)
	_emit_changed()
	return result

func _event_blocked() -> ActionResult:
	message = "请先到「铺中记事」处理眼前的事情。"
	MarketService.sync(_day.state, definition)
	_emit_changed()
	return ActionResult.new(false, message)

func risk_model(record_id := "") -> Dictionary:
	var key := "risk/" + record_id + ""
	if _notifying and _model_cache.has(key): return _model_cache[key].duplicate(true)
	var model: Dictionary = _build_risk_model(record_id)
	if _notifying: _model_cache[key] = model.duplicate(true)
	return model

func _build_risk_model(record_id := "") -> Dictionary:
	var records: Array = RiskReadModels.records(_day, _risk) if _risk != null else []
	if not _day.state.risk_pending.is_empty():
		record_id = InventoryManager.new().find(_day.state, _day.state.risk_pending).definition_id
	elif mirror_pending() or MirrorEndingService.active(_day.state): record_id = "item_weeping_mirror"
	elif _day.state.phase == &"dead": record_id = "death_archive"
	if not records.any(func(row: Dictionary) -> bool: return row.id == record_id):
		record_id = records[0].id if not records.is_empty() else ""
	var model := RiskReadModels.build(_day, _risk, _risk_error, record_id) if _risk != null else {"body": "尚无物品记事。", "buttons": [], "history": "", "pending_id": "", "held_ids": [], "intrusion": false}
	model.records = records
	model.record_id = record_id
	model.requires_response = not _day.state.risk_pending.is_empty() or mirror_pending()
	model.attention_id = ""
	if record_id == "death_archive":
		if _day.state.phase != &"dead": model.body = "旧页上的字迹仍在。"
		model.history = model.get("archive", "")
		model.buttons = []
		return model
	if record_id.is_empty():
		model.body = "尚无物品记事。经手物品后，相关见闻会记在各自名下。"
		return model
	if record_id != "item_weeping_mirror": return model
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
	LivingMirror.decorate(model, _day, _counter.catalog)
	if InvestigationService.enabled(definition):
		model.history += InvestigationService.notes(_day.state)
		model.buttons.append({"command": "open_investigation", "target_id": "", "detail": "", "label": "托人查访", "enabled": not model.requires_response, "reason": ""})
	MirrorEndingService.decorate(model, _day, _counter.catalog)
	var dream_hint := MirrorDreamService.guidance(_day.state)
	if not dream_hint.is_empty(): model.body += "\n\n" + dream_hint
	model.note_sections = preload("res://ui/risk/mirror_journal.gd").build(_day, _counter.catalog)
	return model

func mirror_resolution_command(command: String, visit_id: String) -> ActionResult:
	return _journal_call("mirror_resolution_command", [command, visit_id])

func _impl_mirror_resolution_command(command: String, visit_id: String) -> ActionResult:
	var result := MirrorEndingService.perform(_day, _counter.catalog, command, visit_id)
	if result.ok and (command in MirrorEndingService.ENDINGS or (MirrorReunionService.enabled(definition) and command in MirrorReunionService.ENDINGS)): _persist()
	if result.ok and not MirrorEndingService.active(_day.state):
		_risk.capture_close(_day.state)
		_events.poll(_day.state, definition)
		MarketService.sync(_day.state, definition)
	message = result.message
	_emit_changed()
	return result

func investigation_command(command: String, detail := "") -> ActionResult:
	return _journal_call("investigation_command", [command, detail])

func _impl_investigation_command(command: String, detail := "") -> ActionResult:
	var start := _day.state.game_minutes
	var result := InvestigationService.perform(_day, _counter.catalog, command, detail)
	if not result.ok and start == _day.state.game_minutes:
		message = result.message
		_emit_changed()
		return result
	if _risk != null: _risk.capture_close(_day.state)
	if _events != null: _events.poll(_day.state, definition)
	MarketService.sync(_day.state, definition)
	message = result.message
	_emit_changed()
	return result

func risk_command(command: String, id: String, detail := "") -> ActionResult:
	if command.begins_with("ending_"): return mirror_resolution_command(command.trim_prefix("ending_"), id)
	return _journal_call("risk_command", [command, id, detail])

func _impl_risk_command(command: String, id: String, detail := "") -> ActionResult:
	if command == "soul_inspect": return inspect_customer(id)
	if command == "study": return study_command(id, detail)
	if command in ["cover", "uncover"] and not LivingMirror.enabled(definition) and not PawnReturnService.current(_day.state).is_empty(): return _return_blocked()
	if command.begins_with("mirror_"): return mirror_command(id, command.trim_prefix("mirror_"))
	if _day.state.phase in [&"dead", &"bankrupt"]: return _risk_blocked()
	if _risk == null: return ActionResult.new(false, "暂无可查看的物品记录。")
	if not _day.state.pending_event_id.is_empty() and command not in ["retreat", "defy"]: return _event_blocked()
	if mirror_pending(): return _mirror_blocked()
	var result: ActionResult
	if command in ["retreat", "defy"]:
		var previous := _copy_state(_day.state)
		result = RoomFlow.respond(_day.state, _risk, id, command) if definition.private_room else _risk.respond(_day.state, id, command)
		if result.ok and not definition.private_room: FeeService.finish(_day.state, definition)
		if result.ok and _events != null: _events.poll(_day.state, definition)
		if result.ok and not _persist():
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
	_emit_changed()
	return result

func _risk_blocked() -> ActionResult:
	message = "铺门上了封条，柜前再无人等候。" if _day.state.phase == &"bankrupt" else ("灯已冷了，铺中再没有人应声。" if _day.state.phase == &"dead" else "请先在「物品记事」应对镜中来客。")
	MarketService.sync(_day.state, definition)
	_emit_changed()
	return ActionResult.new(false, message)

func mirror_pending() -> bool:
	return _mirror != null and _mirror.pending(_day)

func mirror_command(id: String, command: String) -> ActionResult:
	return _journal_call("mirror_command", [id, command])

func _impl_mirror_command(id: String, command: String) -> ActionResult:
	if _mirror == null or not _day.state.risk_pending.is_empty() or _day.state.phase in [&"dead", &"bankrupt"]: return _risk_blocked()
	var result := _mirror.choose(_day, id, command)
	_risk_error = "" if result.ok else result.message
	if _events != null and not mirror_pending(): _events.poll(_day.state, definition)
	message = result.message
	MarketService.sync(_day.state, definition)
	_emit_changed()
	return result

func _mirror_blocked() -> ActionResult:
	message = "镜里的旧当票还在眼前。请先收回视线，或再看一眼。"
	MarketService.sync(_day.state, definition)
	_emit_changed()
	return ActionResult.new(false, message)

func economy_model() -> Dictionary:
	return {"description": FeeService.describe(_day.state, definition), "archive": FeeService.archive_text(_day.state), "outstanding": FeeService.outstanding(_day.state)}

func _return_blocked() -> ActionResult:
	message = "持票的老客正在柜前等候，请先验票办理。"
	MarketService.sync(_day.state, definition)
	_emit_changed()
	return ActionResult.new(false, message)

func pawn_disposal_model() -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	if _commerce == null or _day.state.phase != &"night_resolution": return rows
	for ticket in _commerce.pawns.maturities(_day.state):
		var item := InventoryManager.new().find(_day.state, ticket.collateral_id())
		var terms := _commerce.catalog.get_definition("pawn_terms", ticket.terms_id) as PawnTermsDefinition
		rows.append({"id": ticket.ticket_id, "number": "%03d" % (_day.state.pawn_tickets.find(ticket) + 1), "item": (_commerce.catalog.get_definition("items", item.definition_id) as ItemDefinition).display_name,
			"customer": VarietyService.name_for(ticket.person, _commerce.catalog.get_definition("customers", ticket.customer_id)),
			"principal": ticket.principal, "quote": _commerce.pawns.transfer_quote(ticket, terms), "choice": _pawn_choices.get(ticket.ticket_id, "")})
	return rows

func choose_pawn_disposal(id: String, choice: String) -> ActionResult:
	return _journal_call("choose_pawn_disposal", [id, choice])

func _impl_choose_pawn_disposal(id: String, choice: String) -> ActionResult:
	if _commerce == null or _day.state.phase != &"night_resolution" or choice not in ["keep", "transfer"]: return ActionResult.new(false, "眼下不能处置当票。")
	var ticket := _commerce.pawns.find(_day.state, id)
	if ticket == null or ticket not in _commerce.pawns.maturities(_day.state): return ActionResult.new(false, "当票尚未到期或已经结清。")
	_pawn_choices[id] = choice
	if _day.state.personal_risk_enabled: _day.state.pending_pawn_choices[id] = choice
	message = "选好后可改动；逐张核妥，再一并合账。"
	MarketService.sync(_day.state, definition)
	_emit_changed()
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
	if DragonSearch.ready(_day, _counter):
		model.hint = "陆掌眼已应约带货来，先和他把话说完。"
		return model
	if (not replaying or DragonSearch.enabled(_day.state)) and FirstDebt.chen_recognition_due(_day.state):
		model.hint = "陈小满还在柜前，先听她把话说完。"
		return model
	var visit := _counter.customers.active(_day.state)
	if visit != null:
		var reason := _counter.reason(_day, "reject", visit.visit_id)
		var customer := _counter.catalog.get_definition("customers", visit.customer_id) as CustomerDefinition
		model.merge({"mode": "dismiss", "target_id": visit.visit_id, "enabled": reason.is_empty(),
			"hint": "长按1秒谢绝买家 · 不耗时；松开取消。" if visit.purpose == "display_buyer" else "长按1秒送客 · 耗时%d分钟；松开取消。" % customer.terms.reject_minutes if reason.is_empty() else reason}, true)
		return model
	model.mode = "wait"
	model.enabled = (DragonSearch.enabled(_day.state) and DragonSearch.appointment_night(_day.state) == _day.state.current_night_index and _day.state.game_minutes < 60) or _day.state.visits.any(func(v: CustomerVisit) -> bool: return v.status in ["scheduled", "waiting"] and v.arrival < definition.night_minutes and v.expires_at > _day.state.game_minutes)
	model.hint = "轻按铃铛，等下一位客人来；时辰会向前走。" if model.enabled else "今夜已无来客，可以收铺了。"
	return model

func bell_command(mode: String, target_id := "") -> ActionResult:
	return _journal_call("bell_command", [mode, target_id])

func _impl_bell_command(mode: String, target_id := "") -> ActionResult:
	var model := bell_model()
	if not model.enabled or model.mode != mode or model.target_id != target_id:
		return ActionResult.new(false, "柜前的情形已经变了。" if model.enabled else model.hint)
	if mode == "dismiss": return counter_command("reject", target_id)
	# Advance through normal time boundaries so events and arrivals are never skipped.
	var start := _day.state.game_minutes
	while _day.state.phase == &"open" and _counter.customers.active(_day.state) == null:
		_counter.customers.update(_day.state)
		if _counter.customers.active(_day.state) != null or not PawnReturnService.current(_day.state).is_empty() or DragonSearch.ready(_day, _counter): break
		var spent := _day.spend_action(definition.time_step)
		if not spent.ok: return spent
		_counter.customers.update(_day.state)
		if _risk != null: _risk.capture_close(_day.state)
		if _events != null: _events.poll(_day.state, definition)
		if not _day.state.pending_event_id.is_empty() or not _day.state.risk_pending.is_empty() or mirror_pending(): break
	MarketService.sync(_day.state, definition)
	message = "铃声落下，门外终于响起脚步。" if _counter.customers.active(_day.state) != null else "你在柜后等着，铺里有了动静。"
	_emit_changed()
	return ActionResult.new(true, message + "等候%d分钟。" % (_day.state.game_minutes - start))

func study_command(id: String, choice: String) -> ActionResult:
	return _journal_call("study_command", [id, choice])

func _impl_study_command(id: String, choice: String) -> ActionResult:
	if not MirrorChapterService.enabled(definition) or _day.state.phase != &"open" or not _day.state.risk_pending.is_empty(): return _risk_blocked()
	if not _day.state.pending_event_id.is_empty(): return _event_blocked()
	if mirror_pending(): return _mirror_blocked()
	if not PawnReturnService.current(_day.state).is_empty(): return _return_blocked()
	var result := _events.investigate(_day, id, choice)
	_counter.customers.update(_day.state)
	_risk.capture_close(_day.state)
	message = result.message
	MarketService.sync(_day.state, definition)
	_emit_changed()
	return result

# One outer command owns mutation, checkpoint publication and rollback. Nested
# commands (bell waits, automatic preparation, mirror routing) share its entry.
var replaying := false
var _journal_depth := 0
var _pending_checkpoint := false

func _persist() -> bool:
	if _day.state.personal_risk_enabled and _journal_depth > 0:
		_pending_checkpoint = true
		return true
	return _save.save_state(_day.state, definition, content_version)

func _journal_call(method: String, args: Array) -> ActionResult:
	if MirrorEndingService.active(_day.state) and method != "mirror_resolution_command":
		return ActionResult.new(false, "镜前的话还未说完，请从库存提醒回到镜前。" if MirrorReunionService.enabled(definition) else "镜前的话还未说完；若要先办别的事，请选择「暂且收起」。")
	if LivingMirror.enabled(definition) and not InvestigationService.enabled(definition): return _ghost_call(method, args)
	if not _day.state.personal_risk_enabled or _journal_depth > 0: return callv("_impl_" + method, args)
	if not FirstDebt.enabled(definition) and _day.state.action_journal.size() >= 4096: return ActionResult.new(false, "本局操作记录已满，请读取较早的存档。")
	var previous: RunState = _copy_state(_day.state) if not replaying else null
	var pawn_choices := _pawn_choices.duplicate(true)
	var before_damage := _day.state.personal_risk_history.size()
	var recovery_visit: CustomerVisit = _counter.customers.active(_day.state) if PhoenixRecovery.enabled(_day.state) and _counter != null else null
	var recovery_visit_id := recovery_visit.visit_id if recovery_visit != null else ""
	var recovery_history_start := _day.state.visit_history.size()
	var journal_row := {"method": method, "args": args.duplicate(true)}
	if DragonSearch.enabled(_day.state) and not _day.state.get_meta("legacy_chen_visits", false): journal_row["chen_visits"] = 1
	_day.state.action_journal.append(journal_row)
	_pending_checkpoint = false
	_pending_notifications.clear()
	_journal_depth += 1
	var domain_started := Time.get_ticks_usec()
	var result: ActionResult = callv("_impl_" + method, args)
	if PhoenixRecovery.enabled(_day.state) and PhoenixRecovery.capture(_day.state, recovery_visit_id, recovery_history_start, mirror_pending() or MilitaryIntroduction.active(_day.state)): _pending_checkpoint = true
	_profile("domain", domain_started)
	_journal_depth -= 1
	if _day.state.shop_growth_enabled:
		ShopGrowthService.sync(_day.state)
		if previous != null and previous.shop_growth != _day.state.shop_growth: _pending_checkpoint = true
	if _day.state.social_enabled and previous != null and previous.social != _day.state.social: _pending_checkpoint = true
	if not replaying and not result.ok:
		var before := previous.to_read_model()
		var after := _day.state.to_read_model()
		before.erase("action_journal"); after.erase("action_journal")
		if before == after: _day.state.action_journal.pop_back()
	if not replaying and (_pending_checkpoint or before_damage != _day.state.personal_risk_history.size()):
		var save_started := Time.get_ticks_usec()
		var saved := _save.save_state(_day.state, definition, content_version)
		_profile("save", save_started)
		if not saved:
			_day.state = previous
			_pawn_choices = pawn_choices
			result = ActionResult.new(false, "操作未保存，已恢复原状；请重试。" + _save.error_message)
			message = result.message
			_risk_error = result.message
			_pending_notifications.clear()
			MarketService.sync(_day.state, definition)
	if not replaying:
		if result.ok: _risk_error = ""
		var notifications := _pending_notifications.duplicate()
		_pending_notifications.clear()
		var notification_started := Time.get_ticks_usec()
		for notification in notifications: emit_signal(notification.signal_name, notification.payload)
		_profile("notices", notification_started)
		_notify_changed()
	return result

var _pending_notifications: Array[Dictionary] = []

func _emit_changed() -> void:
	if _journal_depth == 0 and not replaying: _notify_changed()

func _emit_transaction(payload: Dictionary) -> void:
	if replaying: return
	if _journal_depth > 0: _pending_notifications.append({"signal_name": "transaction_completed", "payload": payload})
	else: transaction_completed.emit(payload)

func _emit_operation(payload: Dictionary) -> void:
	if replaying: return
	if _journal_depth > 0: _pending_notifications.append({"signal_name": "operation_completed", "payload": payload})
	else: operation_completed.emit(payload)
func inspect_customer(visit_id: String) -> ActionResult:
	return _journal_call("inspect_customer", [visit_id]) if InvestigationService.enabled(definition) else _ghost_call("inspect_customer", [visit_id])

func _impl_inspect_customer(visit_id: String) -> ActionResult:
	var result := LivingMirror.inspect(_day, _counter.catalog, visit_id)
	if _risk != null: _risk.capture_close(_day.state)
	if _events != null: _events.poll(_day.state, definition)
	message = result.message
	_message_visit_id = visit_id
	_emit_changed()
	return result

func _ghost_call(method: String, args: Array) -> ActionResult:
	if not LivingMirror.enabled(definition) or _ghost_depth > 0: return callv("_impl_" + method, args)
	var before := read_state()
	before.erase("ghost_commands")
	var choices := _pawn_choices.duplicate(true)
	_day.state.ghost_commands.append({"method": method, "args": args.duplicate(true)})
	_ghost_depth += 1
	var result: ActionResult = callv("_impl_" + method, args)
	_ghost_depth -= 1
	var after := read_state()
	after.erase("ghost_commands")
	if GhostSaveCodec.same(before, after) and choices == _pawn_choices:
		_day.state.ghost_commands.pop_back()
	return result

# Room discoveries use the same event history as the chapter, never a UI-only unlock.
func room_observation_model(id: String) -> Dictionary:
	if id not in ["aq_coat", "aq_paper", "aq_floorplan"] or id not in definition.event_ids: return {}
	var event := _counter.catalog.get_definition("events", id) as EventDefinition
	var seen_flag: String = {"aq_coat": "aq_coat_seen", "aq_paper": "aq_paper_seen", "aq_floorplan": "aq_plan_seen"}[id]
	var known: bool = seen_flag in _day.state.narrative_flags
	var available: bool = _day.state.phase == &"private_room" and _day.state.risk_pending.is_empty() and _day.state.pending_event_id.is_empty() and (known or (event.presentation.get("manual", false) and _events.eligible(_day.state, event)))
	return {"available": available, "known": known, "title": event.title, "body": event.body, "art": event.presentation.get("art", "")}

func observe_room(id: String) -> ActionResult:
	return _journal_call("observe_room", [id])

func _impl_observe_room(id: String) -> ActionResult:
	var model := room_observation_model(id)
	if model.is_empty() or not model.available: return ActionResult.new(false, "眼下没有可看的东西。")
	if model.known: return ActionResult.new(true, model.body)
	var previous := _copy_state(_day.state)
	var result := _events.investigate(_day, id, "look")
	if result.ok and not _persist():
		_day.state = previous
		result = ActionResult.new(false, "未能记下，请重试。" + _save.error_message)
	message = result.message
	_emit_changed()
	return result

func social_command(command: String, detail := "") -> ActionResult:
	return _journal_call("social_command", [command, detail])

func _impl_social_command(command: String, detail := "") -> ActionResult:
	var result := MilitaryService.perform(_day, command, detail)
	if result.ok:
		ShopGrowthService.sync(_day.state)
		MarketService.sync(_day.state, definition)
		_persist()
	message = result.message
	_emit_changed()
	return result

func growth_command(command: String, detail := "") -> ActionResult:
	return _journal_call("growth_command", [command, detail])

func _impl_growth_command(command: String, detail := "") -> ActionResult:
	var result := ShopGrowthService.perform(_day, command, detail)
	if result.ok:
		if _risk != null: _risk.capture_close(_day.state)
		if _events != null: _events.poll(_day.state, definition)
		MarketService.sync(_day.state, definition)
		_persist()
	message = result.message
	return result


func fan_command(command: String, item_id: String, detail := "") -> ActionResult:
	return _journal_call("fan_command", [command, item_id, detail])

func _impl_fan_command(command: String, item_id: String, detail := "") -> ActionResult:
	var result := LuxuryAppraisalService.perform(_day, command, item_id, detail) if command.begins_with("luxury_") else FanAppraisalService.perform(_day, command, item_id, detail)
	if result.ok:
		if command not in ["draft", "clear_draft"]:
			if _risk != null: _risk.capture_close(_day.state)
			if _events != null: _events.poll(_day.state, definition)
			MarketService.sync(_day.state, definition)
		_persist()
	message = result.message
	var visit := _counter.customers.active(_day.state)
	_message_visit_id = visit.visit_id if visit != null and visit.item.instance_id == item_id else ""
	return result

# Models live only for one synchronous notification, never across actions or rollback.
func _notify_changed() -> void:
	_model_cache.clear()
	_notifying = true
	var started := Time.get_ticks_usec()
	changed.emit()
	_profile("refresh_dispatch", started)
	_notifying = false
	_model_cache.clear()

# Attention/atmosphere must remain live even when the journal drawer is closed.
# This projection deliberately does not build prose, investigation buttons or records.
func risk_signal_model() -> Dictionary:
	var state := _day.state
	var held: Array = []
	if _risk != null:
		for item in _risk.ghosts(state):
			if item.ownership_state in ["owned", "pledged"]: held.append(item.instance_id)
	var closed: Array = []
	var intrusion := false
	for row in state.risk_history:
		var key := "%d/%s" % [row.night, row.item_id]
		if row.action == "close": closed.append(key)
		if (row.action == "close" and not row.covered) or (row.action == "uncover" and key in closed): intrusion = true
	if MirrorEndingService.released(state): intrusion = false
	var attention: String = _mirror.model(_day).attention_id if _mirror != null else ""
	if MirrorEndingService.active(state): attention = "resolution/" + state.mirror_resolution.visit_id + "/" + str(state.mirror_resolution.step)
	return {"held_ids": held, "pending_id": state.risk_pending, "intrusion": intrusion, "attention_id": attention}

# Optional diagnostics; never serialized and never consulted by gameplay.
var profile_enabled := false
var profile_us: Dictionary = {}

func _profile(label: String, started: int) -> void:
	if profile_enabled: profile_us[label] = int(profile_us.get(label, 0)) + Time.get_ticks_usec() - started

func observe_document(id: String) -> ActionResult:
	return _journal_call("observe_document", [id])

func _impl_observe_document(id: String) -> ActionResult:
	if id not in FirstDebt.DOCUMENTS: return ActionResult.new(false, "没有这份资料。")
	return _impl_event_command(id, "read")

func first_debt_model() -> Dictionary:
	return FirstDebt.model(_day, _events, _counter)

func old_shop_model() -> Dictionary:
	return OldShopReadModel.build(_day, _events, _counter)
