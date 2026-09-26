class_name MirrorChapterService
extends RefCounted

static func enabled(run: RunDefinition) -> bool:
	return run.variety.get("mirror_chapter", 0) == 1

static func summary(state: RunState, run: RunDefinition) -> String:
	if MirrorEndingService.finished(state): return "\n" + MirrorEndingService.note(state)
	if not enabled(run): return ""
	if state.investigation_enabled and state.investigation.get("answers", []).size() == 3:
		return "\n镜中旧事：丈夫承认早已恢复营生，也有办法联络妻儿，却一直回避。事实已经问清，镜中的等待尚未了结。" + ("\n你准备把事实带到镜前。" if state.investigation.attitude == "prepare_mirror" else "\n材料暂时收起。" if state.investigation.attitude == "put_away" else "")
	var flags := state.narrative_flags
	if "wm_motive" in flags:
		var ending := "西平码头的地址已记下，离家经过还须继续核实。"
		if "wm_use" in flags: ending = "你留下用镜短记，暂时压下了地址。镜中的等待仍在。"
		elif "wm_seal" in flags: ending = "你记下暂不借镜。这份旧事尚未办结。"
		return "\n镜中旧事：货郎就是她等的丈夫。顾先生为保住镜子的用处，藏起了能找到人的线索。\n" + ending
	if "wm_identity" in flags: return "\n镜中旧事：货郎身份已经核实，顾先生的记录还须对照。"
	if "wm_life" in flags: return "\n镜中旧事：典镜筹药费的母子都已不在人世，丈夫的去向尚未核实。"
	if "wm_notes" in flags: return "\n镜中旧事：用镜短记与典物号已记下，旧事尚待查访。"
	return ""

static func decorate(model: Dictionary, day: DayController, director: EventDirector) -> void:
	if not enabled(day.definition): return
	var notes := ""
	for row in day.state.event_history:
		if row.event_id == HiddenMerit.ECHO: continue
		var event := director.catalog.get_definition("events", row.event_id) as EventDefinition
		if not event.presentation.get("manual", false) or event.phase != "open": continue
		var result := event.find_choice(row.choice_id).result
		notes += "\n\n" + event.title + "\n" + result
	for row in day.state.mirror_history:
		if row.action != "peek": continue
		var encounter := MirrorEncounterService.find_definition(day.definition, row.encounter_id)
		notes += "\n\n第%d夜 · 镜中片段\n%s" % [row.night, encounter.text("peek_text")]
	model.history = ("已取得的旧事与片段" + notes + "\n\n" if not notes.is_empty() else "") + model.get("history", "")
	var blocked := not day.state.pending_event_id.is_empty() or not day.state.risk_pending.is_empty() or MirrorEncounterService.new(director.catalog).pending(day) or not PawnReturnService.current(day.state).is_empty()
	if day.state.phase == &"open":
		model.body += ("\n\n照客每次5分钟，不限次数。" if LivingMirror.enabled(day.definition) else "\n\n借镜每夜一回 · 5分钟。照见的缘由须再问清；品相仍须掌眼。") if "wm_notes" in day.state.narrative_flags else ""
		for id in day.definition.event_ids:
			var event := director.catalog.get_definition("events", id) as EventDefinition
			if not event.presentation.get("manual", false) or not director.eligible(day.state, event): continue
			for choice in event.choices:
				if not choice.available(day.state.narrative_flags, day.state.inventory_instances): continue
				var reason := "请先处理眼前的事情。" if blocked else ""
				if day.state.game_minutes + choice.minutes >= event.window_end: reason = "余下时辰不足，旧档可稍后再查。"
				model.buttons.append({"command": "study", "target_id": id, "detail": choice.id, "label": choice.label + (" · %d分钟" % choice.minutes if choice.minutes > 0 else ""), "enabled": reason.is_empty(), "reason": reason})
	else: model.body += summary(day.state, day.definition)
