class_name MirrorEndingService
extends RefCounted

const ENDINGS := {"acknowledged": "当面认下", "released": "不再等他", "resentment": "以怨相留"}
const TEXTS := {
	"gentle": "你先把镜中人的来历说清，将旧当存根推到他手边，等他自己开口。\n\n他扶着柜沿站了许久，终于朝镜面低下头：‘是我的妻子，也是我的孩子。钱是我带走的，后来有了营生，是我不敢回去。’",
	"force": "红布一落，旧人的身影浮了起来。他猛地退开，攥紧柜沿：‘先前那些话我认。可你别逼我看她，我开不了这个口。’\n\n他还站在柜前，却把脸转向了门。他承认的事实没有改变，仍不肯面对她。",
	"evidence": "你把典物存根、街坊证词、码头结算与问答一一说给她听。她久久望着当票：‘孩子病着，我洗衣、缝补，挨家去问药钱。我以为再撑一日，总能等到一句消息。’\n\n镜里的手抚平了衣襟。‘原来路一直通着。’",
	"acknowledged": "他终于对着她，把带走钱财、恢复营生和不肯联系的事说完。她没有接他的道歉，只把那张旧票推回镜外。\n\n‘我听见了。可我不再替你等下去了。’\n\n她转身走向窗边。镜缘的红痕慢慢干了，铜胎里只剩铺中寻常的倒影。丈夫仍站着，这一声承认没有替他免去责任。",
	"released": "你告诉她：‘你替孩子撑过的那些日子，不由他认不认来定。他不肯开口，也不必再占着你往后的路。’\n\n她低头理好衣襟，抬眼时已不再看向柜前的人。‘那便不等了。’\n\n窗光从她身后散开。铜镜恢复寻常，丈夫还在柜边，始终没有抬起头。",
	"resentment": "你把他拒绝面对的话再次递向镜中：‘别再等他，把这些年受的苦还给他。’\n\n镜里的红影骤然越过柜沿。他的倒影先被拖入黑暗，柜前紧接着传来一声短促的惊叫。人影消失时，最后一口气也断了。\n\n她夺了他的命，却没有离去。镜缘凝下一缕冰冷的黑气，落在你收起的旧票上。她不再等他归来，留下的是怨恨。"
}

static func enabled(run: RunDefinition) -> bool:
	return run.variety.get("mirror_ending_version", 0) == 1

static func active(state: RunState) -> bool:
	return state.mirror_ending_enabled and state.mirror_resolution.get("active", false)

static func finished(state: RunState) -> bool:
	return state.mirror_ending_enabled and not state.mirror_resolution.get("ending", "").is_empty()

static func released(state: RunState, id := "") -> bool:
	return finished(state) and state.mirror_resolution.ending in ["acknowledged", "released", "disappointed"] and (id.is_empty() or id == state.mirror_resolution.mirror_id)

static func ready(state: RunState) -> bool:
	return state.mirror_ending_enabled and InvestigationService.ready(state) and state.investigation.get("read", false) and state.investigation.get("answers", []).size() == 3

static func reason(day: DayController, catalog: ContentCatalog, command: String, visit_id: String) -> String:
	if MirrorReunionService.enabled(day.definition): return MirrorReunionService.reason(day, catalog, command, visit_id)
	return common_reason(day, catalog, command, visit_id)

static func common_reason(day: DayController, catalog: ContentCatalog, command: String, visit_id: String) -> String:
	var state := day.state
	if not enabled(day.definition): return "这份旧事尚未到镜前。"
	if finished(state): return "这份旧事已经落定。"
	if command == "pause": return "" if active(state) and visit_id == state.mirror_resolution.visit_id else "眼下没有正在进行的对质。"
	if not ready(state): return "先把当年的事查实，再问清他离家后的经过。"
	if state.phase != &"open": return "开铺后再请他到镜前。"
	if not state.pending_event_id.is_empty() or not state.risk_pending.is_empty() or not PawnReturnService.current(state).is_empty() or MirrorEncounterService.new(catalog).pending(day): return "先处理眼前的事情。"
	if not MirrorEncounterService.pursuit(state, state.current_night_index).is_empty() and RoomFlow.response(state, state.current_night_index, "personal").is_empty(): return "身后的影子还没有退去，先应对这场纠缠，再谈镜中旧事。"
	var mirror := LivingMirror.held(state)
	if mirror == null or released(state, mirror.instance_id): return "有能力的铜镜须仍在铺里。"
	var visit := CustomerManager.new().active(state)
	if visit == null or visit.purpose != "husband_meeting" or visit.person.get("id", "") != InvestigationService.PERSON or visit.visit_id != visit_id: return "请先约他来铺，等他到了柜前再谈。"
	if not state.mirror_resolution.is_empty() and state.mirror_resolution.mirror_id != mirror.instance_id: return "须把原来那面铜镜请到柜前。"
	var step: int = state.mirror_resolution.get("step", 0)
	if command == "start":
		if active(state): return "话已说到镜前，先把眼下这一段谈完。"
	else:
		if not active(state) or state.mirror_resolution.visit_id != visit_id: return "先将旧事带到镜前。"
		var allowed: Array = ["gentle", "force"] if step == 0 else (["evidence"] if step == 1 else (["acknowledged"] if state.mirror_resolution.husband == "willing" else ["released", "resentment"]))
		if not MirrorReunionService.enabled(day.definition) and command not in allowed: return "这句话已说过，或前面的事还未说清。"
	var remaining := (3 - step) * 5
	if state.game_minutes + remaining >= day.definition.night_minutes or state.game_minutes + remaining >= visit.expires_at: return "余下时辰不够把这几句话说完，另约一个时候。"
	return ""

static func perform(day: DayController, catalog: ContentCatalog, command: String, visit_id: String) -> ActionResult:
	if MirrorReunionService.enabled(day.definition): return MirrorReunionService.perform(day, catalog, command, visit_id)
	var error := reason(day, catalog, command, visit_id)
	if not error.is_empty(): return ActionResult.new(false, error)
	var state := day.state
	if command == "start":
		if state.mirror_resolution.is_empty():
			state.mirror_resolution = {"active": false, "step": 0, "husband": "", "ending": "", "ability": "active", "mirror_id": LivingMirror.held(state).instance_id, "visit_id": visit_id, "history": []}
		state.mirror_resolution.active = true
		state.mirror_resolution.visit_id = visit_id
		if state.mirror_resolution.step > 0:
			var risk := RiskManager.new(catalog)
			if risk.covered(state, state.mirror_resolution.mirror_id): risk.handle(day, state.mirror_resolution.mirror_id, "uncover")
		return ActionResult.new(true, "你把旧当存根放到铜镜旁。他避开镜面，低声说：‘让我缓一缓。’")
	var resolution := state.mirror_resolution
	if command == "pause":
		resolution.active = false
		return ActionResult.new(true, "你将旧票收回，话先停在这里。")
	var start := state.game_minutes
	day.spend_action(5)
	CustomerManager.new().update(state)
	resolution.history.append({"action": command, "night": state.current_night_index, "start": start, "minute": state.game_minutes, "visit_id": visit_id})
	resolution.step += 1
	if command in ["gentle", "force"]:
		resolution.husband = "willing" if command == "gentle" else "refused"
		var risk := RiskManager.new(catalog)
		if risk.covered(state, resolution.mirror_id): risk.handle(day, resolution.mirror_id, "uncover")
	if command in ENDINGS:
		resolution.active = false
		resolution.ending = command
		resolution.ability = "resentful" if command == "resentment" else "ordinary"
		resolution["night"] = state.current_night_index
		resolution["minute"] = state.game_minutes
		if command == "resentment":
			state.person_deaths.append({"source": "mirror_revenge", "person_id": InvestigationService.PERSON, "name": "女主人的丈夫", "night": state.current_night_index, "minute": state.game_minutes, "visit_id": visit_id, "mirror_id": resolution.mirror_id})
			state.special_resources.append({"id": "mirror_resentment", "name": "铜镜怨气", "amount": 1, "source": "mirror_ending/resentment", "night": state.current_night_index, "mirror_id": resolution.mirror_id})
			CustomerManager.new().finish(state, CustomerManager.new().active(state), "mirror_revenge")
			CustomerManager.new().update(state)
	return ActionResult.new(true, TEXTS[command])

static func note(state: RunState) -> String:
	if state.mirror_reunion_enabled: return MirrorReunionService.note(state)
	if not finished(state): return ""
	return "铜镜旧事 · " + ENDINGS[state.mirror_resolution.ending] + ("\n女主人已经离去。铜镜只剩普通旧物的价值。" if released(state) else "\n她以怨相留，铜镜仍能辨人生死，关铺前仍须覆红。\n特殊资源：铜镜怨气 ×1。")

static func decorate(model: Dictionary, day: DayController, catalog: ContentCatalog) -> void:
	if MirrorReunionService.enabled(day.definition):
		MirrorReunionService.decorate(model, day, catalog)
		return
	if not enabled(day.definition): return
	var state := day.state
	if finished(state):
		if model.requires_response: return
		model.body = TEXTS[state.mirror_resolution.ending] + "\n\n" + note(state)
		if released(state):
			model.buttons = []
			model.intrusion = false
		return
	if active(state):
		var row := state.mirror_resolution
		model.requires_response = true
		model.attention_id = "resolution/" + row.visit_id + "/" + str(row.step)
		model.body = "镜前旧事\n\n"
		if row.step == 0: model.body += "你将旧当存根放到铜镜旁。他避开镜面，低声说：‘让我缓一缓。’"
		else: model.body += TEXTS[row.history.back().action]
		var actions: Array
		if row.step == 0: actions = [["gentle", "先说明镜中是谁，等他自己开口"], ["force", "揭开铜镜，请他立即面对旧人"]]
		elif row.step == 1: actions = [["evidence", "把当票、证词和问答说给她听"]]
		else:
			model.body = "她听完材料，低声说：‘我洗衣、缝补，挨家去问药钱，只想替孩子再撑一日。原来路一直通着。’\n\n‘我若不等了，这面镜也就只剩铜胎。你还肯替我把话说完么？’"
			if row.husband == "willing": actions = [["acknowledged", "请他亲口认下妻儿，让她自行离去"]]
			else:
				model.body += "\n\n丈夫仍背着脸。她盯住他的倒影，手指越过镜缘：‘他不肯看我，那便把他拉进来。’红影已挨到他的衣角。"
				actions = [["released", "劝她不必再等他的承认"], ["resentment", "让她把这些年的苦还给他"]]
		model.buttons = []
		for action in actions: model.buttons.append(button(day, catalog, action[0], row.visit_id, action[1] + " · 5分钟"))
		model.buttons.append(button(day, catalog, "pause", row.visit_id, "暂且收起"))
	elif ready(state):
		var visit := CustomerManager.new().active(state)
		var id := visit.visit_id if visit != null else ""
		model.buttons.append(button(day, catalog, "start", id, "把旧事带到镜前" if state.mirror_resolution.is_empty() else "继续镜前的话"))

static func button(day: DayController, catalog: ContentCatalog, command: String, id: String, label: String) -> Dictionary:
	var error := reason(day, catalog, command, id)
	return {"command": "ending_" + command, "target_id": id, "detail": "", "label": label, "enabled": error.is_empty(), "reason": error}
