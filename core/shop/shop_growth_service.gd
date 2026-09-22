class_name ShopGrowthService
extends RefCounted

const VERSION := 25
const RUN := "shop_growth_ten"
const COSTS := {"bench": 40, "display": 60}
const NAMES := {"bench": "一级鉴物台", "display": "一级陈列柜", "bench_two": "二级专用鉴物台", "fan_tools": "扇画工具"}
const STEPS := ["整理旧账", "核对柜号", "检查夹板"]
const MINUTES := [15, 15, 20]
const MATERIALS := [
	"旧柜目录\n你掸去旧账封面的灰，按年月摊开。几笔货物去向旁，反复写着‘入十七柜’。目录到这里缺了一角，收货人的姓名辨不清。",
	"柜号核对记录\n沿墙逐柜核过，木牌从一排到十六。旧目录的尺寸却多出一格。第十六柜侧面的夹板，比别处厚了一指。",
	"封闭柜格观察\n夹板后露出一道窄缝，里面封着旧柜格。一张旧票只留下柜号与转入、转出的笔迹；票角压着顾敬堂的私印。你照原样抄下，把旧票留在原处。经手的是什么、为何封柜，眼下还没有凭据。"
]

static func enabled(run: RunDefinition) -> bool:
	return String(run.id) == RUN or run.variety.get("shop_growth_version", 0) == 1

static func initial() -> Dictionary:
	return {"bench": false, "display": false, "investments": [], "exploration": [], "display_id": "", "opportunities": []}

static func preparation_count(state: RunState) -> int:
	if not state.shop_growth_enabled: return 0
	return FanAppraisalService.preparation_count(state) + ShopKnowledgeService.preparation_count(state) + state.shop_growth.investments.filter(func(row: Dictionary) -> bool: return row.night == state.current_night_index).size()

static func appraisal_minutes(state: RunState, item: ItemDefinition, action_id: String) -> int:
	var action := item.find_action(action_id)
	if action == null: return 0
	if state.shop_growth_enabled and state.shop_growth.bench and item.item_type == "normal" and item.ghost_rule_id.is_empty() and action.minutes == 10 and action.required_tool in ["magnifier", "lamp", "magnet"]: return 5
	return action.minutes

static func item_reason(state: RunState, item: ItemInstance) -> String:
	if item == null or item.ownership_state != "owned": return "只能陈列铺中自有现货。"
	var definition := state.ghost_catalog.get_definition("items", item.definition_id) as ItemDefinition
	if definition.item_type != "normal" or not definition.ghost_rule_id.is_empty(): return "这件货须另行保管，不能放进陈列柜。"
	if NightMarketRisk.item_pending(state, item.source_visit_id) or state.risk_pending == item.instance_id: return "货上的异状尚未处理，暂不能陈列。"
	return ""

static func opportunity(state: RunState) -> Dictionary:
	if not state.shop_growth_enabled: return {}
	for row in state.shop_growth.opportunities:
		if row.night == state.current_night_index: return row
	return {}

static func blocked(day: DayController) -> bool:
	return not day.state.pending_event_id.is_empty() or not day.state.risk_pending.is_empty() or not PawnReturnService.current(day.state).is_empty() or MirrorEncounterService.new(day.state.ghost_catalog).pending(day)

static func reason(day: DayController, command: String, detail := "") -> String:
	if command == "learn_knowledge": return ShopKnowledgeService.reason(day, detail)
	if command in FanAppraisalService.FACILITY_COMMANDS: return FanAppraisalService.facility_reason(day, command, detail)
	var state := day.state
	if not state.shop_growth_enabled: return "这局尚未开办修缮与查铺。"
	if blocked(day): return "请先处理眼前的事情。"
	match command:
		"build":
			if not COSTS.has(detail): return "没有这项整修。"
			if state.current_night_index < 2: return "第二夜起可托人整修。"
			if state.phase != &"pre_open" or PreparationService.used(state, "finish", state.current_night_index): return "须在开铺前、准备结束前托付。"
			if state.shop_growth[detail]: return "已经整修妥当，不必再付钱。"
			if PreparationService.count(state) >= 2: return "今夜两次准备已经用完。"
			if state.cash < int(COSTS[detail]): return "现银不足，需要%d银元。" % COSTS[detail]
		"display":
			if not state.shop_growth.display: return "先整修一级陈列柜。"
			if state.phase != &"pre_open": return "换货须等下次开铺前；营业中可撤下。"
			if detail == state.shop_growth.display_id: return "这件货已经陈列。"
			return item_reason(state, InventoryManager.new().find(state, detail))
		"withdraw":
			if not detail.is_empty(): return "撤下按眼前的陈列货办理。"
			if state.phase not in [&"pre_open", &"open"]: return "开铺前或营业时可撤下陈列货。"
			if state.shop_growth.display_id.is_empty(): return "柜里还没有陈列货。"
		"explore":
			var stage: int = state.shop_growth.exploration.size()
			if stage >= STEPS.size(): return "这处柜格已经查过，记录可免费复看。"
			if detail != str(stage): return "先按手边的线索往下查。"
			if state.current_night_index < 2: return "先将头一夜的生意理顺。"
			if state.phase != &"closed_processing" or state.closed_at < 0 or state.closed_at >= day.definition.night_minutes: return "提前关门后，才有空沿柜细查。"
			if state.game_minutes + int(MINUTES[stage]) > day.definition.night_minutes: return "到03:00前来不及查完，留待明夜。"
		_: return "没有这项铺务。"
	return ""

static func perform(day: DayController, command: String, detail := "") -> ActionResult:
	if command == "learn_knowledge": return ShopKnowledgeService.learn(day, detail)
	if command in FanAppraisalService.FACILITY_COMMANDS: return FanAppraisalService.facility(day, command, detail)
	var error := reason(day, command, detail)
	if not error.is_empty(): return ActionResult.new(false, error)
	var state := day.state
	match command:
		"build":
			var cost: int = COSTS[detail]
			EconomyManager.new().commit(state, -cost, "", "facility/" + detail, "facility_investment")
			state.shop_growth[detail] = true
			state.shop_growth.investments.append({"facility": detail, "night": state.current_night_index, "amount": cost, "preparation": 1})
			return ActionResult.new(true, "%s已经整修妥当，今晚便可使用。付出%d银元，占用一次准备。" % [NAMES[detail], cost])
		"display":
			state.shop_growth.display_id = detail
			return ActionResult.new(true, "你将货物放进陈列位，等识货的人来问价。")
		"withdraw":
			state.shop_growth.display_id = ""
			sync(state)
			CustomerManager.new().update(state)
			return ActionResult.new(true, "货已撤回库存。今夜不再另换陈列目标。" if state.phase == &"open" else "货已撤回库存，可另选一件。")
		"explore":
			var stage: int = state.shop_growth.exploration.size()
			var start := state.game_minutes
			day.spend_action(MINUTES[stage])
			# Commit evidence before the session applies the 03:00 seal/risk flow.
			state.shop_growth.exploration.append({"step": stage, "night": state.current_night_index, "start": start, "minute": state.game_minutes})
			return ActionResult.new(true, MATERIALS[stage])
	return ActionResult.new(false, "铺务未办妥。")

static func lock_night(state: RunState) -> void:
	if not state.shop_growth_enabled or not opportunity(state).is_empty(): return
	var id: String = state.shop_growth.display_id
	var item := InventoryManager.new().find(state, id)
	var eligible: bool = state.shop_growth.display and item_reason(state, item).is_empty()
	var key := "growth/%d" % state.current_night_index
	var arrives: bool = eligible and VarietyService.rng(state.run_seed, key + "/chance").randi_range(0, 99) < 40
	var arrival: int = VarietyService.pick([60, 120, 180], state.run_seed, key + "/arrival")
	var row := {"night": state.current_night_index, "item_id": id if eligible else "", "visit_id": "%s/%d/display_buyer" % [RUN, state.current_night_index], "arrives": arrives, "arrival": arrival, "expires_at": arrival + 90, "status": "scheduled" if arrives else "no_buyer", "offer_factor": int(VarietyService.pick([90, 100, 110], state.run_seed, key + "/offer")), "cap_factor": int(VarietyService.pick([110, 120, 130], state.run_seed, key + "/cap"))}
	state.shop_growth.opportunities.append(row)
	if not eligible: state.shop_growth.display_id = ""
	if not arrives: return
	var visit := CustomerVisit.new()
	visit.visit_id = row.visit_id
	visit.customer_id = "customer_hawker"
	visit.purpose = "display_buyer"
	visit.item = item # Reference the owned item; never manufacture another copy.
	visit.person = {"id": "person/" + visit.visit_id, "name": "看中陈列货的客人", "portrait": "asset.customer_hawker"}
	visit.arrival = arrival
	visit.expires_at = arrival + 90
	visit.voice = {"timed_out": "他朝柜里又看了一眼：‘还有事，改日吧。’脚步声渐渐远了。"}
	state.visits.append(visit)
	# Existing visitors keep precedence when arrival times coincide.
	state.visits.sort_custom(func(a: CustomerVisit, b: CustomerVisit) -> bool: return a.arrival < b.arrival if a.arrival != b.arrival else a.purpose != "display_buyer" and b.purpose == "display_buyer")

static func sync(state: RunState) -> void:
	if not state.shop_growth_enabled: return
	var id: String = state.shop_growth.display_id
	if not id.is_empty() and not item_reason(state, InventoryManager.new().find(state, id)).is_empty(): state.shop_growth.display_id = ""
	var row := opportunity(state)
	if row.is_empty() or row.status not in ["scheduled", "waiting", "active"]: return
	if state.shop_growth.display_id == row.item_id: return
	for visit in state.visits:
		if visit.visit_id == row.visit_id: CustomerManager.new().finish(state, visit, "display_cancelled")

static func activate(state: RunState, visit: CustomerVisit) -> void:
	if visit.purpose != "display_buyer": return
	var row := opportunity(state)
	row.status = "active"
	if row.has("offer"): return
	var definition := state.ghost_catalog.get_definition("items", visit.item.definition_id) as ItemDefinition
	var value := GoodsExpertise.value(visit.item, definition)
	var base := maxi(1, roundi(value * int(row.offer_factor) / 100.0))
	var cap_base := maxi(1, roundi(value * int(row.cap_factor) / 100.0))
	row["source_premium"] = ProvenanceService.premium_at_rate(visit.item, base, 1500)
	row["offer"] = base + int(row.source_premium)
	row["cap"] = cap_base + ProvenanceService.premium_at_rate(visit.item, cap_base, 1500)
	row["received_minute"] = state.game_minutes

static func departed(state: RunState, visit: CustomerVisit, outcome: String) -> void:
	if not state.shop_growth_enabled or visit.purpose != "display_buyer": return
	var row := opportunity(state)
	row.status = outcome
	row["ended_minute"] = state.game_minutes

static func trade_reason(day: DayController, command: String, visit_id: String, detail := "", amount := 0) -> String:
	if not day.state.shop_growth_enabled or day.state.phase != &"open": return "眼下没有陈列买家可接待。"
	if blocked(day): return "请先处理眼前的事情。"
	var visit := CustomerManager.new().active(day.state)
	if visit == null or visit.purpose != "display_buyer" or visit.visit_id != visit_id or day.state.game_minutes >= visit.expires_at: return "问价的客人已经离开。"
	if not detail.is_empty(): return "请按眼前这件陈列货议价。"
	if command not in ["display_accept", "display_counter", "reject"]: return "客人是来买陈列货的。可接受、拒绝，或回价一次。"
	if not item_reason(day.state, visit.item).is_empty() or day.state.shop_growth.display_id != visit.item.instance_id: return "这件货已经不在陈列位上。"
	var row := opportunity(day.state)
	if not row.has("offer"): return "客人尚未开价。"
	if command == "display_counter":
		if amount <= int(row.offer) or amount > 1000000: return "回价须为高于开价的有效整数银元。"
	elif amount != 0: return "接受或拒绝按客人的原报价办理。"
	if command != "reject" and day.state.game_minutes + 5 >= day.definition.night_minutes: return "来不及在03:00前交清货款。"
	return ""

static func trade(day: DayController, command: String, visit_id: String, detail := "", amount := 0) -> ActionResult:
	var error := trade_reason(day, command, visit_id, detail, amount)
	if not error.is_empty(): return ActionResult.new(false, error)
	var state := day.state
	var visit := CustomerManager.new().active(state)
	var row := opportunity(state)
	if command == "reject":
		CustomerManager.new().finish(state, visit, "display_rejected")
		CustomerManager.new().update(state)
		return ActionResult.new(true, "你摇头谢过，客人告辞。货仍留在陈列位上。")
	var start := state.game_minutes
	day.spend_action(5)
	CustomerManager.new().update(state, visit_id)
	row["decision"] = command
	row["quote_start"] = start
	row["counter"] = amount if command == "display_counter" else 0
	if command == "display_counter" and amount > int(row.cap):
		CustomerManager.new().finish(state, visit, "display_failed")
		CustomerManager.new().update(state)
		return ActionResult.new(true, "他拢起袖子：‘这个价，我接不住。’这次没谈拢，货仍留在柜里。")
	var price: int = amount if command == "display_counter" else row.offer
	CommerceService.commit_sale(state, visit.item, "display_buyer", price)
	row["price"] = price
	CustomerManager.new().finish(state, visit, "display_sold")
	state.shop_growth.display_id = ""
	CustomerManager.new().update(state)
	return ActionResult.new(true, "客人当面点清%d银元，你将货交到他手里。成本%d，交易毛利%+d。" % [price, visit.item.acquisition_price, price - visit.item.acquisition_price])
