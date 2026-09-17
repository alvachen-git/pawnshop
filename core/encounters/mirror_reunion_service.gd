class_name MirrorReunionService
extends RefCounted

const ENDINGS := {"acknowledged": "迟来的道歉", "released": "放下旧怨", "resentment": "以怨相留", "disappointed": "失望离去"}
const CONTACT := "‘我有办法捎信回去。可后来，我在外面又成了家，就不想回去了。’\n\n‘那时候她和孩子都还活着。我知道他们在等我，可我一直没捎信。’"
# Speaker/text pages are presentation data. Advancing a page never grants facts.
const PAGES := {
	"reveal": [["", "你揭开红布，将铜镜转向丈夫。女子的身影慢慢出现在镜中。"], ["丈夫", "你……你怎么会在这里？"], ["女子", "我一直在等你。你为什么不回家？"], ["丈夫", "我不知道你会在这面镜子里……"], ["女子", "我问的是，你为什么不回家？"], ["女子", "孩子每天都问，爹什么时候回来。后来他病了，还让我留着门，说你回来就能进屋。"], ["女子", "我替人洗衣服、缝衣服，挣一点钱就去买药。我盼你回来帮帮我们，哪怕捎封信也好。"], ["女子", "可你在外面又成了家，就不管我们了？"], ["丈夫", "那几年我也不好过，总得先顾着眼前的日子……"]],
	"press": [["掌柜", "你已经有工钱，也能捎信。她问你为什么不回家，你直接回答她。"]],
	"mediate": [["掌柜", "先别急。既然见面了，就把话说清楚。你听完她的话，再慢慢说。"]],
	"apology": [["丈夫", "是我对不起你们。"], ["丈夫", "我有了新的家，就不想再管从前的事了。不是回不去，是我不愿意回去。"], ["丈夫", "我把你和孩子丢下了，是我的错。对不起。"]],
	"angry": [["丈夫", "是，我没回去！我都认了，还要我怎么样？"], ["丈夫", "我现在也有一家人要养，难道非要我跪下来，你们才肯放过我？"], ["女子", "我们等了你那么久，你到现在还嫌我们烦？"], ["", "女子的手穿过镜面，抓住丈夫的影子。他后退却挣不开。"], ["女子", "你不肯回来，那就跟我走！"]],
	"evasive": [["丈夫", "事情都过去这么久了，一时也说不清。"], ["丈夫", "后来听说你们没了，我也很难受。你就别再问这些了。"], ["", "女子看着他。他转开脸，没有继续回答。"]],
	"acknowledged": [["女子", "这句道歉，我等了太久。好，我原谅你。可孩子已经不在了，我们也回不到从前了。"], ["女子", "我不再等你了。"], ["", "她最后看了丈夫一眼，身影慢慢消失。丈夫站在柜前，没有再说话。"]],
	"released": [["掌柜", "放下这份心结吧。这种人，不值得你再留恋。让他留在人间受苦，总好过你继续为他困在这里。"], ["女子", "我已经为他苦了这么多年……不能再把自己留在这里了。"], ["", "她慢慢松开手。"], ["女子", "我原谅你了。往后你过得怎样，都与我无关。我不会再等你了。"], ["", "女子转身离去。丈夫跌坐在柜边。"]],
	"resentment": [["掌柜", "欠债还债，天经地义。他欠你和孩子的，就让他自己来还。"], ["女子", "我们母子等了你这么多年。今天，你别想再走了。"], ["", "红影缠住丈夫，将他拖入镜中。他抓向柜沿，只来得及喊出半声。"], ["", "柜前空了下来。他已经死了。女子仍留在镜中。"]],
	"disappointed": [["女子", "你还是不肯好好回答我。"], ["女子", "算了。我以为见到你，就能问个明白。现在看来，再问也没用了。"], ["", "女子的身影慢慢消失。丈夫松开抓着柜沿的手，没有再开口。"]]
}

static func enabled(run: RunDefinition) -> bool:
	return run.variety.get("mirror_reunion_version", 0) == 1

static func roll(seed_value: int) -> int:
	# A separate stream, independent of visit order, panels and repeated attempts.
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value ^ 0x4d495252
	return rng.randi_range(0, 99)

static func reaction(choice: String, value: int) -> String:
	if choice == "press": return "apology" if value < 60 else "angry"
	return "apology" if value < 40 else "evasive"

static func actions(state: RunState) -> Array:
	match int(state.mirror_resolution.get("step", 0)):
		0: return [["reveal", "请镜中女子现身"]]
		1: return [["press", "逼问他为何不回家"], ["mediate", "帮两人打圆场"]]
		2:
			match str(state.mirror_resolution.husband):
				"apology": return [["acknowledged", "听她把话说完"]]
				"angry": return [["released", "劝她放下心结"], ["resentment", "让她向丈夫讨还这笔债"]]
				"evasive": return [["disappointed", "听她把话说完"]]
	return []

static func pages(action: String, state: RunState) -> Array:
	var result: Array = PAGES.get(action, []).duplicate(true)
	if action in ["press", "mediate"]: result.append_array(PAGES[state.mirror_resolution.husband])
	return result

static func transcript(action: String, state: RunState) -> String:
	var lines := PackedStringArray()
	for page in pages(action, state): lines.append((page[0] + "：" if not page[0].is_empty() else "") + page[1])
	return "\n\n".join(lines)

static func reason(day: DayController, catalog: ContentCatalog, command: String, visit_id: String) -> String:
	# Shared physical/evidence/time checks remain identical to v25.
	var base := MirrorEndingService.common_reason(day, catalog, "start" if command == "begin" else command, visit_id)
	if not base.is_empty(): return base
	if command == "begin": return "" if day.state.mirror_resolution.get("step", 0) == 0 else "两人已经见过面，继续前面的话即可。"
	if command in ["start", "pause"]: return ""
	if not actions(day.state).any(func(a: Array) -> bool: return a[0] == command): return "这句话已说过，或前面的话还没说完。"
	return ""

static func perform(day: DayController, catalog: ContentCatalog, command: String, visit_id: String) -> ActionResult:
	var error := reason(day, catalog, command, visit_id)
	if not error.is_empty(): return ActionResult.new(false, error)
	var state := day.state
	if command in ["start", "begin"]:
		if state.mirror_resolution.is_empty():
			state.mirror_resolution = {"active": false, "step": 0, "husband": "", "ending": "", "ability": "active", "mirror_id": LivingMirror.held(state).instance_id, "visit_id": visit_id, "history": [], "roll": roll(state.run_seed), "approach": ""}
		state.mirror_resolution.active = true
		state.mirror_resolution.visit_id = visit_id
		if state.mirror_resolution.step > 0:
			var risk := RiskManager.new(catalog)
			if risk.covered(state, state.mirror_resolution.mirror_id): risk.handle(day, state.mirror_resolution.mirror_id, "uncover")
		# Keep the old free start command replayable. New entry buttons atomically
		# open the conversation and perform its first paid stage in one command.
		if command == "start": return ActionResult.new(true, "他站在柜前，等你开口。")
		command = "reveal"
	var row := state.mirror_resolution
	if command == "pause":
		row.active = false
		return ActionResult.new(true, "你示意两人先停下来，这些话以后再说。")
	var start := state.game_minutes
	day.spend_action(5)
	CustomerManager.new().update(state)
	row.history.append({"action": command, "night": state.current_night_index, "start": start, "minute": state.game_minutes, "visit_id": visit_id})
	row.step += 1
	if command == "reveal":
		var risk := RiskManager.new(catalog)
		if risk.covered(state, row.mirror_id): risk.handle(day, row.mirror_id, "uncover")
	if command in ["press", "mediate"]:
		row.approach = command
		row.husband = reaction(command, row.roll)
	if command in ENDINGS:
		row.active = false
		row.ending = command
		row.ability = "resentful" if command == "resentment" else "ordinary"
		row["night"] = state.current_night_index
		row["minute"] = state.game_minutes
		row["notification_delivered"] = true
		if command == "resentment":
			state.person_deaths.append({"source": "mirror_revenge", "person_id": InvestigationService.PERSON, "name": "女主人的丈夫", "night": state.current_night_index, "minute": state.game_minutes, "visit_id": visit_id, "mirror_id": row.mirror_id})
			state.special_resources.append({"id": "mirror_resentment", "name": "铜镜怨气", "amount": 1, "source": "mirror_ending/resentment", "night": state.current_night_index, "mirror_id": row.mirror_id})
			CustomerManager.new().finish(state, CustomerManager.new().active(state), "mirror_revenge")
			CustomerManager.new().update(state)
	return ActionResult.new(true, transcript(command, state))

static func note(state: RunState) -> String:
	if not MirrorEndingService.finished(state): return ""
	var result := "女子仍留在镜中，铜镜的能力保留，关铺前仍须覆红布。\n获得：铜镜怨气 ×1。" if state.mirror_resolution.ending == "resentment" else "女子已经离去，铜镜恢复普通。\n无法再用它辨别生死或观看旧事，关铺前也不必再覆红布。"
	return "铜镜旧事 · " + ENDINGS[state.mirror_resolution.ending] + "\n\n" + result

static func decorate(model: Dictionary, day: DayController, catalog: ContentCatalog) -> void:
	var state := day.state
	if MirrorEndingService.finished(state):
		if model.requires_response: return
		model.body = transcript(state.mirror_resolution.ending, state) + "\n\n" + note(state)
		if MirrorEndingService.released(state): model.buttons = []; model.intrusion = false
	elif MirrorEndingService.active(state):
		model.requires_response = true
		model.attention_id = "reunion/" + state.mirror_resolution.visit_id + "/" + str(state.mirror_resolution.step)
		model.body = "夫妻两人正在镜前说话。"
		model.buttons = []
	elif MirrorEndingService.ready(state):
		var visit := CustomerManager.new().active(state)
		model.buttons.append(entry_button(day, catalog, visit.visit_id if visit != null else ""))

static func entry_button(day: DayController, catalog: ContentCatalog, visit_id: String) -> Dictionary:
	var first: bool = day.state.mirror_resolution.get("step", 0) == 0
	return MirrorEndingService.button(day, catalog, "begin" if first else "start", visit_id, "请镜中女子现身 · 5分钟" if first else "继续镜前的话")
