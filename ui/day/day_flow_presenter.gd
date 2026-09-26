class_name DayFlowPresenter
extends Node

signal status_updated(text: String)
signal route_requested(panel_id: StringName)
signal sale_requested(buyer_id: String)

const PHASE_LABELS := {"pre_open": "开铺前", "open": "营业中", "closed_processing": "已关门 · 店内处理", "night_resolution": "封铺 · 夜间结算", "shop_resolution": "封铺 · 铺内收尾", "private_room": "回房", "sleep_resolution": "就寝", "day_summary": "日结", "run_ended": "经营告一段落", "dead": "命灯已灭", "bankrupt": "铺门已封"}
var _session: RunSession
var _view: DayFlowPanel
var _session_menu: SessionMenuView
var _last_phase := ""
var _category_picker := false
var _picker_night := 0
var _wait_picker := false

func bind(session: RunSession, view: DayFlowPanel, session_menu: SessionMenuView) -> void:
	_session = session
	_view = view
	_session_menu = session_menu
	_view.command_requested.connect(_on_command)
	_session_menu.new_requested.connect(_session.new_run)
	_session_menu.load_requested.connect(_on_load)
	_session_menu.save_requested.connect(func() -> void: _session.storage_requested.emit("save"))
	_session_menu.leave_requested.connect(func(destination: String) -> void: _session.leave_requested.emit(destination))
	_session.changed.connect(refresh)
	_view.visibility_changed.connect(refresh, CONNECT_DEFERRED)
	_session.restored.connect(func() -> void: _last_phase = ""; _wait_picker = false)
	refresh()

func refresh() -> void:
	var state := _session._day.state
	var definition := _session.definition
	if state.phase not in ["open", "closed_processing"]: _wait_picker = false
	if state.phase != "pre_open" or _picker_night != state.current_night_index: _category_picker = false
	if not _view.is_visible_in_tree():
		_refresh_chrome(state)
		return
	var commands: Array = []
	for entry in [{"id": "open_shop", "label": "开铺"}, {"id": "close_shop", "label": "关门（本夜不可重开）"}]:
		entry.enabled = _session.can_execute(entry.id)
		entry.visible = state.phase == "pre_open" if entry.id == "open_shop" else state.phase in ["open", "closed_processing"]
		commands.append(entry)
	var remaining := maxi(0, definition.night_minutes - int(state.game_minutes))
	commands.append({"id": "wait_until_seal", "label": "等到封铺 · %d分钟" % remaining, "enabled": _session.can_execute("wait_until_seal"), "visible": state.phase in ["open", "closed_processing"]})
	commands.append({"id": "choose_wait", "label": "等待", "enabled": _wait_commands().any(func(entry: Dictionary) -> bool: return entry.enabled), "visible": state.phase in ["open", "closed_processing"]})
	if NightMarketPlan.enabled(definition):
		for id in NightMarketRisk.unresolved(_session._day.state):
			var command := "seal_cloth/" + id
			var n := int(NightMarketRisk.selection(_session._day.state, id).get("night", 0))
			commands.append({"id": command, "label": "按旧规封存包布（第%d夜） · 20分钟" % n, "enabled": _session.can_execute(command), "reason": NightMarketRisk.treatment_reason(_session._day, id)})
	if SevenNightPlan.enabled(definition) and not OpeningPreparation.enabled(definition):
		for entry in commands:
			if state.phase == "pre_open" and entry.id != "open_shop": entry.visible = false
		for entry in [{"id": "prep_investigate", "label": "调查收货消息 · 1行动点"}, {"id": "prep_contact", "label": "联系收货人 · 1行动点"}, {"id": "prep_visitors", "label": "打听今晚来客 · 1行动点"}, {"id": "prep_finish", "label": "结束准备"}]:
			entry.enabled = _session.can_execute(entry.id)
			entry.visible = state.current_night_index >= 4 and state.phase == "pre_open"
			commands.append(entry)
	var appointment_hint := ""
	if not state.buyer_appointment.is_empty(): appointment_hint = "\n" + OrdinarySamplePlan.notice(_session._day.state)
	if SevenNightPlan.enabled(definition):
		appointment_hint += "\n" + _session.seven_notice()
		if state.current_night_index >= 4 and state.phase == "pre_open": appointment_hint = "\n收货传闻与来客口信记在铺中记事里。"
	var event_hint := "\n有待处理的铺中记事，请先查看。" if not state.pending_event_id.is_empty() else ""
	var description := String(PHASE_LABELS[state.phase]) + event_hint + appointment_hint
	if SevenNightPlan.enabled(definition) and state.phase == "pre_open" and state.current_night_index >= 4:
		description = "收货与来客消息可免费复看。"
	if OpeningPreparation.enabled(definition) and state.current_night_index >= 2:
		if state.phase == "pre_open":
			commands = _preparation_commands()
			description = ""
			if _category_picker: description += "\n选好收货类别才消耗行动点，返回不消耗。"
	if state.phase in ["night_resolution", "shop_resolution"]:
		description = "已封铺\n先核清今夜的当票与息费，再回房歇息。"
		commands = [{"id": "read_night", "label": "查看夜间结算", "enabled": true}]
		if state.phase == "shop_resolution":
			description = "铺内收尾\n门闩已经落好，可以回房歇息了。"
			commands = [{"id": "enter_room", "label": "回房", "enabled": _session.can_execute("enter_room"), "reason": "先处理眼前的事情，再回房。"}]
		if not state.risk_pending.is_empty():
			description = "已封铺\n铺里的异响还没停，先查看物品记事。"
			commands.push_front({"id": "read_risk", "label": "查看物品记事", "enabled": true})
		elif not state.pending_event_id.is_empty():
			description = "已封铺\n铺里还有未办完的事，先查看铺中记事。"
			commands.push_front({"id": "read_events", "label": "查看铺中记事", "enabled": true})
	if state.phase == "open": description = "停业守铺 · 只办旧票" if SocialRules.closed(_session._day.state) else "营业中"
	if SocialRules.enabled(definition):
		description += SocialReadModels.notice(_session._day.state)
	if state.phase in ["pre_open", "open", "closed_processing"] and definition.fee_policy.enabled:
		description += "\n" + FeeService.nightly_fee_notice(state, definition)
		var principal_notice := FeeService.principal_schedule_notice(state, definition)
		if not principal_notice.is_empty(): description += "\n" + principal_notice
	if RecyclerPolicy.enabled(definition) and state.current_night_index >= 2 and state.phase in [&"pre_open", &"open"] and not _category_picker:
		var reason := RecyclerPolicy.browse_reason(_session._day)
		var sale_commands: Array = []
		for buyer_id in definition.buyer_ids:
			if buyer_id == "buyer_lu" or not RecyclerPolicy.visible(_session._day, buyer_id): continue
			var buyer := _session._counter.catalog.get_definition("buyers", buyer_id) as BuyerDefinition
			var label := "卖货 · " + buyer.display_name
			if buyer_id == RecyclerPolicy.BUYER: label += " · 1行动点"
			sale_commands.append({"id": "sale/" + buyer_id, "label": label, "enabled": reason.is_empty(), "reason": reason})
		commands = commands.slice(0, 1) + sale_commands + commands.slice(1)
	if _wait_picker:
		description = "等待多久？"
		commands = _wait_commands()
		commands.append({"id": "cancel_wait", "label": "返回", "enabled": true})
	_view.render({"description": description, "message": _session.message, "commands": commands, "preparation": OpeningPreparation.enabled(definition) and state.current_night_index >= 2 and state.phase == "pre_open"})
	_refresh_chrome(state)

func _refresh_chrome(state: RunState) -> void:
	var definition := _session.definition
	_session_menu.render({"old_shop": FirstDebt.enabled(definition), "social": SocialRules.enabled(definition), "shop_growth": ShopGrowthService.enabled(definition), "investigation": InvestigationService.enabled(definition), "has_save": _session.has_save(), "manual_storage": _session._save.library != null, "save_reason": SaveLibrary.save_reason(_session._day.state), "room_flow": state.room_enabled, "in_room": state.room_enabled and state.phase in ["private_room", "sleep_resolution", "dead"]})
	status_updated.emit(("第 %d 夜" % state.current_night_index if FirstDebt.enabled(definition) else "第 %d / %d 夜" % [state.current_night_index, definition.total_nights]) + " · " + PHASE_LABELS[state.phase] + " · " + TimeController.clock_text(definition.opening_minute, state.game_minutes) + " · 现银 %d" % state.cash)
	if state.phase != _last_phase:
		_last_phase = state.phase
		if MilitaryIntroduction.active(_session._day.state) or LuIntroduction.active(_session._day.state): return
		route_requested.emit(&"night" if state.phase in ["night_resolution", "day_summary", "run_ended", "dead", "bankrupt"] else &"day")

func _on_command(command: String) -> void:
	if command.begins_with("sale/"):
		sale_requested.emit(command.trim_prefix("sale/"))
		return
	if command == "choose_wait":
		_wait_picker = true
		refresh()
		return
	if command == "cancel_wait":
		_wait_picker = false
		refresh()
		return
	if command.begins_with("wait_option/"):
		_wait_picker = false
		_session.execute(command.trim_prefix("wait_option/"))
		refresh()
		return
	var routes := {"read_social": &"social", "read_night": &"night", "read_risk": &"risk", "read_events": &"events"}
	if routes.has(command):
		route_requested.emit(routes[command])
		return
	if command.begins_with("prep_seek/"):
		var target := command.trim_prefix("prep_seek/")
		var state := _session._day.state
		var item := InventoryManager.new().find(state, target)
		if item == null: return
		var dialog := ConfirmationDialog.new()
		dialog.title = "寻配茶盏"
		dialog.dialog_text = "为货签%d茶盏寻配 · 3银元 / 1行动点\n约来同纹样、相对式样的候选，价钱另谈。\n是否原配还须验看，不保证成交。" % (state.inventory_instances.find(item) + 1)
		dialog.ok_button_text = "托人寻配"; dialog.cancel_button_text = "暂不寻配"
		_view.add_child(dialog)
		dialog.confirmed.connect(func() -> void: _session.execute("prep_seek", target); dialog.queue_free())
		dialog.canceled.connect(dialog.queue_free)
		dialog.popup_centered(Vector2i(450, 210))
		return
	if command == "prep_choose_category":
		_category_picker = true
		_picker_night = _session._day.state.current_night_index
		refresh()
		return
	if command == "prep_cancel_category":
		_category_picker = false
		refresh()
		return
	if command.begins_with("prep_category/"):
		_category_picker = false
		_session.execute("prep_target", command.trim_prefix("prep_category/"))
		return
	if command == "read_seven_notes":
		route_requested.emit(&"events")
		return
	_session.execute(command)

func _wait_commands() -> Array:
	var choices: Array = []
	for action in _session.definition.actions:
		choices.append({"id": "wait_option/" + action.id, "label": "%d分钟" % action.minutes, "enabled": _session.can_execute(action.id)})
	return choices

func _preparation_commands() -> Array:
	var commands: Array = []
	var state := _session._day.state
	if _category_picker:
		for category in OpeningPreparation.CATEGORIES:
			var error := OpeningPreparation.reason(state, "target", category)
			commands.append({"id": "prep_category/" + category, "label": "收" + OpeningPreparation.CATEGORIES[category] + " · 1行动点", "enabled": error.is_empty(), "reason": error})
		commands.append({"id": "prep_cancel_category", "label": "返回 · 不耗行动点", "enabled": true})
		return commands
	commands.append({"id": "open_shop", "label": "开铺营业", "enabled": _session.can_execute("open_shop")})
	var actions := [
		["attract", "招揽客人 · 3大洋 · 1行动点", "今晚增加1位普通潜在来客"],
		["target", "托人捎话收货 · 1行动点", "选择类别，另约1位普通来客带货"],
		["tea", "备茶候客 · 5大洋 · 1行动点", "今晚普通来客多等20分钟"],
		["visitors", "打听来客 · 1行动点", "获知2位来客的时段、货类与交易意向"]]
	if WealthyCustomers.active(state): actions.append(["advertise", "宣传铺子 · 30银元 · 1行动点", "每夜一次，关铺时听街面回音；可能传开好名声，也可能无人理会或传岔了话"] )
	if state.current_night_index in [4, 5, 6] and not PreparationService.used(state, "investigate"):
		actions.append(["investigate", "调查收货消息 · 1行动点", "提前打听第六夜的收货细目"])
	if PhoenixRecovery.available(state):
		actions.push_front(["phoenix_invite", "约卖镯人带凤镯来 · 1行动点", "不另收费，19:00起等空柜接待，货款另谈"])
	if DragonSearch.enabled(state):
		if not FirstDebt.last(state, "fd_search_motive").is_empty() and not FirstDebt.flag(state, "fd_followed"):
			actions.push_front(["chen_invite", "约陈小满来谈 · 1行动点", "不另收费，开铺后等空柜接待；谈完后告辞"])
		if FirstDebt.flag(state, "fd_search_promised") and DragonSearch.preparation(state, "dragon_search").is_empty() and not FirstDebt.settled(state):
			actions.push_front(["dragon_search", "托人寻找龙镯 · 1行动点", "不另收费，收铺后收口信"])
		if FirstDebt.flag(state, "fd_search_message") and not FirstDebt.item_exists(state, FirstDebt.DRAGON) and not FirstDebt.settled(state):
			actions.push_front(["dragon_invite", "约陆掌眼带龙镯来 · 1行动点", "19:00起等空柜接待，货款另谈"])
	for action in actions:
		var error := OpeningPreparation.reason(state, action[0])
		var tooltip: String = action[2] + "。"
		if not error.is_empty(): tooltip += "\n" + error
		commands.append({"id": "prep_choose_category" if action[0] == "target" else "prep_" + action[0], "label": action[1], "enabled": error.is_empty(), "reason": error, "tooltip": tooltip})
	if state.goods_version == 1:
		for item in state.inventory_instances:
			if item.definition_id != GoodsExpertise.CUP or item.ownership_state != "owned" or "form" not in item.revealed_clue_ids: continue
			var error := OpeningPreparation.reason(state, "seek", item.instance_id)
			commands.append({"id": "prep_seek/" + item.instance_id, "label": "寻配茶盏 · 货签%d · 3银元 / 1行动点" % (state.inventory_instances.find(item) + 1), "enabled": error.is_empty(), "reason": error, "tooltip": GoodsExpertise.description(item, _session._counter.catalog.get_definition("items", item.definition_id))})
	return commands

func _on_load() -> void:
	if _session._save.library != null:
		_session.storage_requested.emit("load")
		return
	var result := _session.load_checkpoint()
	if _session.definition.private_room and not result.ok: _session_menu.show_load_error(result.message)
