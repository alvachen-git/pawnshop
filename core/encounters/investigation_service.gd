class_name InvestigationService
extends RefCounted

const PERSON := "mirror/husband"
const QUESTIONS := ["business", "settlement", "contact"]
const PROMPTS := ["问他离家时的生意与钱财", "出示码头结算抄件，核实恢复营生的日子", "拿出联络证词，追问为何不联系妻儿"]
const ANSWERS := [
	"他搓着指节：‘那趟货赔了，欠账追着人走。余下的现钱是我带走的，想着在外头翻本。我只想着先找口饭吃，空手回去，怎么见她？’",
	"他看了两遍抄件，手停在结算日期上：‘这笔是我的。后来在码头替人理货，每月有钱拿。’你将母子死讯的日期放在旁边。他低下头：‘是，在那之前。那时已经不是没饭吃了。’",
	"‘那人确实找得到我，也有人往家乡走。’他没有再推开证词。‘我有法子捎信。我怕她问钱去了哪里，怕回去还得认那些错，就一日拖一日。没有谁扣着我，是我自己躲着。’"
]
const REPORT := "码头往来结算抄件\n抄件列着他生意折本后替货栈理货的月结，连续数月领取工钱。首笔固定结算早于街坊所述母子去世的日子，账上姓名、旧住处与当票身份相合。它能说明恢复营生的时间，不能说明每笔钱去了哪里。\n\n旧联络人的证词\n那人曾替码头与家乡的商户带信，知道他的落脚处，也见过他领取工钱。‘那阵子路是通的，他要托我，我能捎到。我没替他送过家信。至于他有没有托旁人，我不能作保。’\n\n两份材料各有来处。为何没有回去、是否另托人联系，还须当面问他。"

static func enabled(run: RunDefinition) -> bool:
	return run.variety.get("investigation_version", 0) == 1

static func ready(state: RunState) -> bool:
	return ["wm_identity", "wm_concealed", "wm_motive"].all(func(id: String) -> bool: return id in state.narrative_flags)

static func appointment(state: RunState) -> Dictionary:
	var rows: Array = state.investigation.get("appointments", [])
	return rows.back() if not rows.is_empty() else {}

static func reason(day: DayController, catalog: ContentCatalog, command: String, detail := "") -> String:
	var state := day.state
	if not enabled(day.definition): return "这份查访尚未开办。"
	if command not in ["meeting_question", "meeting_end"] and not detail.is_empty(): return "委托按单上的约定办理。"
	if command == "read_report":
		return "回报尚未送到。" if not state.investigation.get("delivered", false) else ""
	if state.phase != &"open": return "开铺后才能托人办事。"
	if not state.pending_event_id.is_empty() or not state.risk_pending.is_empty() or MirrorEncounterService.new(catalog).pending(day) or not PawnReturnService.current(state).is_empty(): return "请先处理眼前的事情。"
	var cost := 5
	match command:
		"commission":
			if not ready(state): return "须先核清当票身份、两册出入与顾先生的旁记。"
			if not state.investigation.is_empty(): return "这份查访已经托付，不必再付钱。"
			if state.cash < 30: return "查访需30银元，现银不足。"
			cost = 10
		"book":
			if not state.investigation.get("read", false): return "先拆阅查访回报，再托人约他。"
			if appointment(state).get("status", "") == "booked": return "已有约定，等他依约来铺。"
			if state.investigation.get("answers", []).size() == 3: return "该问的话已经核清。"
		"meeting_question", "meeting_end":
			var visit := CustomerManager.new().active(state)
			if visit == null or visit.purpose != "husband_meeting" or visit.visit_id != detail.get_slice("|", 0): return "赴约的人眼下不在柜前。"
			if command == "meeting_question" and (not state.investigation.get("read", false) or state.investigation.get("answers", []).size() >= 3): return "眼下没有新的材料可问。"
			if command == "meeting_question" and detail.get_slice("|", 1) != QUESTIONS[state.investigation.answers.size()]: return "这句话已经问过，或前头的事情还未问清。"
			if command == "meeting_end": cost = 0
		"prepare_mirror", "put_away":
			if state.investigation.get("answers", []).size() != 3: return "离家后的事情还没有问清。"
			if command == "prepare_mirror" and LivingMirror.held(state) == null: return "铜镜已不在铺里，先把材料收好。"
			cost = 0
		_: return "没有这项查访事务。"
	if state.game_minutes + cost >= day.definition.night_minutes: return "余下时辰不够办妥，明夜再托人。"
	return ""

static func perform(day: DayController, catalog: ContentCatalog, command: String, detail := "") -> ActionResult:
	var error := reason(day, catalog, command, detail)
	if not error.is_empty(): return ActionResult.new(false, error)
	var state := day.state
	if command == "read_report":
		state.investigation["read"] = true
		return ActionResult.new(true, REPORT)
	if command in ["prepare_mirror", "put_away"]:
		state.investigation["attitude"] = command
		return ActionResult.new(true, "你将两份材料与问答放在一起，准备带到镜前。" if command == "prepare_mirror" else "你将材料折好，暂时收进抽屉。")
	var start := state.game_minutes
	if command == "meeting_end":
		CustomerManager.new().finish(state, CustomerManager.new().active(state), "meeting_ended")
		CustomerManager.new().update(state)
		return ActionResult.new(true, "你送他出门。未问完的话，留待另约。")
	day.spend_action(10 if command == "commission" else 5)
	CustomerManager.new().update(state)
	match command:
		"commission":
			var payment := "investigation/husband"
			EconomyManager.new().commit(state, -30, "", payment, "investigation")
			state.investigation = {"accepted_night": state.current_night_index, "accepted_minute": state.game_minutes, "payment_id": payment, "report_night": state.current_night_index + 1, "delivered": false, "read": false, "appointments": [], "answers": [], "attitude": ""}
			return ActionResult.new(true, "你付了30银元，将姓名、旧址与疑点交给跑腿的人。约好下一日把查访回报送来。")
		"book":
			var rows: Array = state.investigation.appointments
			rows.append({"visit_id": "%s/%d/husband_appointment_%d" % [day.definition.id, state.current_night_index + 1, rows.size() + 1], "person_id": PERSON, "booked_night": state.current_night_index, "booked_minute": state.game_minutes, "night": state.current_night_index + 1, "arrival": 120, "expires_at": 210, "status": "booked"})
			return ActionResult.new(true, "口信已托出，约他第%d夜20:00来铺，等到21:30。" % (state.current_night_index + 1))
		"meeting_question":
			var visit := CustomerManager.new().active(state)
			if visit == null or visit.visit_id != detail.get_slice("|", 0): return ActionResult.new(false, "他看了看时辰，起身告辞。这句话还没问清。")
			var answers: Array = state.investigation.answers
			var index := answers.size()
			answers.append({"id": QUESTIONS[index], "visit_id": visit.visit_id, "night": state.current_night_index, "start": start, "minute": state.game_minutes})
			return ActionResult.new(true, ANSWERS[index])
	return ActionResult.new(false, "事务未办妥。")

static func dawn(state: RunState) -> void:
	if not state.investigation_enabled or state.phase != &"pre_open": return
	var order := state.investigation
	if not order.is_empty() and not order.delivered and state.current_night_index >= int(order.report_night):
		order.delivered = true
		order["delivered_night"] = state.current_night_index

static func prepare(state: RunState, run: RunDefinition) -> void:
	if not enabled(run): return
	for visit in state.visits:
		if visit.customer_id == "mirror_husband": visit.person["id"] = PERSON
	var row := appointment(state)
	if row.get("status", "") != "booked" or row.night != state.current_night_index: return
	var visit := CustomerVisit.new()
	visit.visit_id = row.visit_id
	visit.customer_id = "mirror_husband"
	visit.purpose = "husband_meeting"
	visit.person = {"id": PERSON, "name": "赴约的丈夫", "portrait": "asset.customer_hawker"}
	visit.arrival = row.arrival
	visit.expires_at = row.expires_at
	visit.voice = {"timed_out": "他在门边停了一下：‘我得走了。还有话，另捎个信吧。’"}
	state.visits.append(visit)
	state.visits.sort_custom(func(a: CustomerVisit, b: CustomerVisit) -> bool: return a.arrival < b.arrival)

static func departed(state: RunState, visit: CustomerVisit, outcome: String) -> void:
	if visit.purpose != "husband_meeting": return
	var row := appointment(state)
	if row.get("visit_id", "") != visit.visit_id: return
	row.status = "complete" if state.investigation.get("answers", []).size() == 3 else "missed" if outcome in ["timed_out", "shop_closed"] else "partial"
	row["ended_minute"] = state.game_minutes

static func notes(state: RunState) -> String:
	var order := state.investigation
	if order.is_empty(): return ""
	var lines := "\n\n丈夫查访\n"
	if not order.delivered: return lines + "查访已托付，约定第%d夜收到回报。" % order.report_night
	if not order.read: return lines + "查访回报已送到，尚未拆阅。"
	lines += REPORT
	for answer in order.answers:
		var i := QUESTIONS.find(answer.id)
		lines += "\n\n" + PROMPTS[i] + "\n" + ANSWERS[i]
	var row := appointment(state)
	if row.get("status", "") == "booked": lines += "\n\n已约第%d夜20:00来铺，等到21:30。" % row.night
	elif row.get("status", "") in ["partial", "missed"]: lines += "\n\n这次会面未谈完，可另托口信再约。"
	if order.answers.size() == 3: lines += "\n\n离家后的营生与回避已经问清。镜中的等待尚未了结。"
	if order.attitude == "prepare_mirror": lines += "\n你记下：准备将这些事实带到镜前。"
	elif order.attitude == "put_away": lines += "\n材料暂时收在抽屉里。"
	return lines

static func model(day: DayController, catalog: ContentCatalog) -> Dictionary:
	if "wm_identity" not in day.state.narrative_flags:
		return {"body": "托人查访\n先把有来处的姓名、旧址和疑点记清，再托人查证。眼下还没有可托付的旧事。", "buttons": []}
	var model := {"body": "托人查访\n将已有姓名、旧址与疑点写在纸上，托人循着实处问。\n\n核查丈夫离家后的经历：30银元、10分钟，下一日送回报。\n约见：5分钟，约下一夜20:00来铺。" + notes(day.state), "buttons": []}
	var order := day.state.investigation
	if not order.is_empty(): model.body = "委托单 · 丈夫离家后的经历\n第%d夜受理 · 已付30银元\n" % order.accepted_night + notes(day.state)
	var actions := [["commission", "托人核查 · 30银元 · 10分钟"]] if order.is_empty() else ([["read_report", "拆阅查访回报"]] if order.delivered else [])
	if order.get("read", false): actions.append(["book", "重新约见 · 5分钟" if not appointment(day.state).is_empty() else "约丈夫来铺 · 5分钟"])
	if order.get("answers", []).size() == 3: actions.append_array([["prepare_mirror", "记下：准备把事实带到镜前"], ["put_away", "暂时收起材料"]])
	for action in actions:
		var error := reason(day, catalog, action[0])
		model.buttons.append({"command": action[0], "detail": "", "label": action[1], "enabled": error.is_empty(), "reason": error})
	return model
