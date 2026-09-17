extends RefCounted

# Read-only presentation of acquired evidence; no journal UI state enters saves.
const TITLES := {
	"wm_notes": "顾先生的用镜短记", "wm_ticket": "旧当存根",
	"wm_life": "柳巷街坊的证词", "wm_identity": "货郎的身份",
	"wm_concealed": "两册记录的出入", "wm_motive": "顾先生的夹页旁记",
	"wm_choice": "收起旧档时的打算"
}
const ANSWER_TITLES := ["离家时的生意与钱财", "恢复营生的日子", "为何没有联系妻儿"]

static func build(day: DayController, catalog: ContentCatalog) -> Array:
	var clues: Array = []
	var memories: Array = []
	var investigation: Array = []
	for row in day.state.event_history:
		if not TITLES.has(row.event_id): continue
		var event := catalog.get_definition("events", row.event_id) as EventDefinition
		if event == null or not event.presentation.get("manual", false): continue
		clues.append(entry(row.event_id, TITLES.get(row.event_id, event.title), "第%d夜 · 旧档与走访" % row.night, event.find_choice(row.choice_id).result))
	for index in day.state.mirror_history.size():
		var row: Dictionary = day.state.mirror_history[index]
		if row.action not in ["peek", "pursue"]: continue
		var encounter := MirrorEncounterService.find_definition(day.definition, row.encounter_id)
		memories.append(entry("mirror_%d" % index, "镜中片段" if row.action == "peek" else "追看留下的异象", "第%d夜 · 亲眼所见" % row.night, encounter.text("peek_text" if row.action == "peek" else "pursue_text")))
	var order := day.state.investigation
	if InvestigationService.enabled(day.definition) and not order.is_empty():
		var status := "查访已托付，约定第%d夜收到回报。" % order.report_night
		if order.delivered: status = "查访回报已送到，尚未拆阅。"
		if order.read:
			var report := InvestigationService.REPORT.split("\n\n")
			for index in 2:
				var part: String = report[index]
				investigation.append(entry("report_%d" % index, part.get_slice("\n", 0), "查访回报 · 抄件" if index == 0 else "查访回报 · 证词", part.substr(part.find("\n") + 1)))
			for answer in order.answers:
				var index := InvestigationService.QUESTIONS.find(answer.id)
				if index < 0: continue
				investigation.append(entry("answer_" + answer.id, ANSWER_TITLES[index], "第%d夜 · 当面问答" % answer.night, InvestigationService.answer(day.state, index)))
			status = report[2]
			var appointment := InvestigationService.appointment(day.state)
			if appointment.get("status", "") == "booked": status = "已约第%d夜20:00来铺，等到21:30。" % appointment.night
			elif appointment.get("status", "") in ["partial", "missed"]: status = "这次会面未谈完，可另托口信再约。"
			if order.answers.size() == 3: status = "离家后的营生与回避已经问清。镜中的等待尚未了结。"
			if order.attitude == "prepare_mirror": status += "\n你记下：准备将这些事实带到镜前。"
			elif order.attitude == "put_away": status += "\n材料暂时收在抽屉里。"
		if MirrorEndingService.finished(day.state): status = MirrorEndingService.note(day.state)
		investigation.append(entry("commission_status", "查访进展", "第%d夜托付" % order.accepted_night, status))
	for row in day.state.mirror_resolution.get("history", []):
		if day.state.mirror_reunion_enabled:
			var title: String = MirrorReunionService.ENDINGS.get(row.action, {"reveal": "夫妻重逢", "press": "当面追问", "mediate": "从中劝说"}.get(row.action, "镜前旧事"))
			investigation.append(entry("resolution_" + row.action, title, "第%d夜 · 镜前旧事" % row.night, MirrorReunionService.transcript(row.action, day.state)))
			continue
		var title: String = MirrorEndingService.ENDINGS.get(row.action, {"gentle": "他愿意面对", "force": "他拒绝面对", "evidence": "她听见了当年的事实"}.get(row.action, "镜前旧事"))
		investigation.append(entry("resolution_" + row.action, title, "第%d夜 · 镜前旧事" % row.night, MirrorEndingService.TEXTS[row.action]))
	var sections: Array = []
	for group in [["clues", "旧当线索", clues], ["memories", "镜中旧事", memories], ["investigation", "查访会面", investigation]]:
		if not group[2].is_empty(): sections.append({"id": group[0], "title": group[1], "entries": group[2]})
	return sections

static func entry(id: String, title: String, source: String, body: String) -> Dictionary:
	return {"id": id, "title": title, "source": source, "body": body}
