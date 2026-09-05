class_name RiskReadModels
extends RefCounted

static func build(day: DayController, manager: RiskManager, error_message: String) -> Dictionary:
	var state := day.state
	var body := "鬼货存放\n柜里静得很，偶尔有木头受潮的轻响。\n"
	var buttons: Array = []
	var held: Array = []
	var intrusion := false
	var haunting := not MirrorEncounterService.pursuit(state, state.current_night_index).is_empty()
	for summary in state.summaries:
		if summary.outcome in ["mirror_scar", "mirror_survived", "mirror_death"]: haunting = true
	var closed: Array = []
	for row in state.risk_history:
		var key := "%d/%s" % [row.night, row.item_id]
		if row.action == "close": closed.append(key)
		if (row.action == "close" and not row.covered) or (row.action == "uncover" and key in closed): intrusion = true
	for item in manager.ghosts(state):
		if item.ownership_state not in ["owned", "pledged"]: continue
		held.append(item.instance_id)
		var definition := manager.catalog.get_definition("items", item.definition_id) as ItemDefinition
		var rule := manager.rule_for(item)
		body += "\n%s · %s\n%s\n" % [definition.display_name, "红布已盖" if manager.covered(state, item.instance_id) else "镜面外露", rule.warning]
		for command in ["cover", "uncover"]:
			var reason := manager.reason(day, item.instance_id, command)
			if not state.pending_event_id.is_empty(): reason = "请先处理铺中记事。"
			if state.phase not in [&"open", &"closed_processing"]: continue
			var cost := rule.cover_minutes if command == "cover" else rule.uncover_minutes
			var label := ("盖好红布" if command == "cover" else "揭开红布") + " · %d分钟" % cost
			buttons.append({"command": command, "target_id": item.instance_id, "detail": "", "label": label, "enabled": reason.is_empty(), "reason": reason})
	if held.is_empty(): body += "\n柜门掩着，暂时没有什么动静。\n"
	body += "\n财神香：%s\n命灯：%s\n" % ["香灰向镜面倒伏，窗缝里却没有风。" if intrusion else "香烟直上。", "已经熄灭。" if state.phase == &"dead" else ("向镜面倾斜，火苗贴着镜面发颤。" if not state.risk_pending.is_empty() else ("灯芯偏斜，你挪到哪边，它便跟到哪边。" if haunting else "火苗安稳。"))]
	if state.phase == &"dead":
		body = "灯芯烧尽了\n\n柜上的账册无风翻开，停在一张空白页上。\n\n门闩还落着。镜面里，映出一间空铺。"
		if not MirrorEncounterService.pursuit(state, state.current_night_index).is_empty(): body = "灯芯烧尽了\n\n那双脚的影子终于与你重合。命灯冷了，旧当票落在柜上，再没有人伸手去接。"
	elif not state.summaries.is_empty() and state.summaries.back().outcome == "mirror_survived":
		body += "\n红布下再无声息，地上的影子却迟迟没有归位。\n"
	if not state.risk_pending.is_empty():
		var rule := manager.rule_for(InventoryManager.new().find(state, state.risk_pending))
		body = "镜中来客\n\n" + rule.crisis + "\n\n财神香：香灰倒伏。命灯：火苗贴着镜面发颤。"
		var pursuit := MirrorEncounterService.pursuit(state, state.current_night_index)
		if state.room_enabled and state.phase == &"shop_resolution": pursuit = {}
		if not pursuit.is_empty():
			var encounter := MirrorEncounterService.find_definition(day.definition, pursuit.encounter_id)
			body = "身后的来客\n\n" + encounter.text("crisis")
		buttons = []
		for command in ["retreat", "defy"]:
			buttons.append({"command": command, "target_id": state.risk_pending, "detail": "", "label": (("垂下眼，护住命灯" if command == "retreat" else "回头看向身后的人") if not pursuit.is_empty() else ("低头退开，将红布覆上" if command == "retreat" else "抬眼看向镜中人")), "enabled": true, "reason": ""})
	if state.room_enabled:
		if state.phase == &"shop_resolution" and not state.risk_pending.is_empty():
			body = "镜中来客\n\n镜面里的柜台比屋里暗了一层。香灰伏向铜镜，身后有人轻声道：\n\n「别应声，也别看它的眼睛。」\n\n红布就在手边。"
		elif state.phase == &"sleep_resolution" and not state.risk_pending.is_empty():
			body = "床边的影子\n\n你刚躺下，床边便响起第二个人的呼吸。先前镜里那张旧当票，正贴着门缝往里滑。命灯的火苗低了下去。\n\n「别应声，也别看它的眼睛。」那句话忽然又在耳边响起。"
		elif state.phase == &"dead" and not state.room_history.is_empty() and state.room_history.back().action == "personal_defy":
			body = "灯芯烧尽了\n\n门缝下的当票不再动了。床边那道影子终于与你重合，屋里只剩下一盏冷灯。"
		elif state.phase == &"dead":
			body = "柜前再无人声\n\n镜面里映出一间空铺。楼上的命灯冷了，床铺还原样放着。"
		elif state.phase in [&"private_room", &"sleep_resolution"]:
			body = "寝屋无声\n\n" + ("床边的影子没有归位。命灯的火苗慢慢直起，你没有再看门缝。" if RoomFlow.response(state, state.current_night_index, "personal") == "retreat" else ("灯芯偏斜，你挪到哪边，它便跟到哪边。" if haunting else "楼下已经落闩，命灯的火苗安稳。"))
		elif state.phase != &"dead":
			var lamp_start := body.find("\n命灯：")
			if lamp_start >= 0:
				var lamp_end := body.find("\n", lamp_start + 1)
				body = body.left(lamp_start) + (body.substr(lamp_end) if lamp_end >= 0 else "")
	var archive := "《绝当录》\n"
	if state.death_archive.is_empty(): archive += "纸页尚空。"
	for record in state.death_archive:
		# IDs identify the recorded consequence; prose can be revised without rewriting history.
		var record_rule := manager.catalog.get_definition("ghost_rules", record.rule_id) as GhostRuleDefinition
		var cause: String = record_rule.death_cause if record_rule != null else record.cause
		if record.has("encounter_id"):
			var run := manager.catalog.get_definition("runs", record.run_id) as RunDefinition
			var encounter := MirrorEncounterService.find_definition(run, record.encounter_id) if run != null else null
			cause = encounter.text("death_cause") if encounter != null else record.cause
		archive += "第%d夜 · %s\n%s\n遗银%d · 现货成本%d · 在当本金%d\n\n" % [record.night, record.item_name, cause, record.cash, record.inventory_cost, record.pawn_principal]
	return {"body": body + ("\n\n" + error_message if not error_message.is_empty() else ""), "buttons": buttons, "history": archive, "pending_id": state.risk_pending, "held_ids": held, "intrusion": intrusion}
