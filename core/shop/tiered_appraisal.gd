class_name TieredAppraisal
extends RefCounted

const KITS := {
	"display":{"name":"展验工具","cost":30,"level":2},
	"metal":{"name":"金银衡验具","cost":40,"level":2},
	"clock":{"name":"钟表开验具","cost":50,"level":2},
	"jewel":{"name":"珠玉查验托具","cost":30,"level":2},
	"optics":{"name":"精细观察组件","cost":60,"level":3},
	"balance":{"name":"精密衡验组件","cost":60,"level":3},
	"clock_deep":{"name":"钟表深验组件","cost":80,"level":3},
}
const RETAIN := {"intact":100,"minor":80,"major":50}
const DAMAGE_NAMES := {"intact":"未见外伤","minor":"轻损","major":"重损"}
const NOTES := {"same":"相符","different":"存在差异","unsure":"暂难判断"}

static func enabled(run: RunDefinition) -> bool:
	return run.variety.get("tiered_appraisal_version",0) == 1

static func active(state: RunState) -> bool:
	return state.ghost_catalog != null and state.ghost_catalog.content_version >= 32 and state.ghost_catalog.get_definition("runs",state.run_definition_id) != null and enabled(state.ghost_catalog.get_definition("runs",state.run_definition_id))

static func config(state: RunState, item: ItemInstance) -> Dictionary:
	var run := state.ghost_catalog.get_definition("runs",state.run_definition_id) as RunDefinition
	return run.variety.tiered_appraisal[item.definition_id]

static func equipment(state: RunState) -> Dictionary:
	return state.shop_growth.get("precision",{})

static func owns(state: RunState, id: String) -> bool:
	return id.is_empty() or (id == "display" and FanAppraisalService.data(state).get("tools",false)) or equipment(state).get("kits",[]).has(id)

static func attach(state: RunState, item: ItemInstance, visit_id: String) -> void:
	if not active(state) or not WealthyCustomers.is_item(item.definition_id) or item.goods.has("precision"): return
	var damage := VarietyService.rng(state.run_seed,visit_id+"/precision/exterior").randi_range(0,99)
	var hidden := VarietyService.rng(state.run_seed,visit_id+"/precision/depth").randi_range(0,99) >= 70
	item.goods["precision"] = {"damage":"intact" if damage < 60 else "minor" if damage < 90 else "major","hidden":hidden}

static func adjusted(item: ItemInstance, value: int) -> int:
	if not item.goods.has("precision"): return value
	return maxi(1,roundi(value * int(RETAIN[item.goods.precision.damage]) / 100.0))

static func record(state: RunState, id: String) -> Dictionary:
	return WealthyCustomers.data(state).get("appraisals",{}).get(id,{})

static func stage(state: RunState, id: String, tier: int) -> Dictionary:
	return record(state,id).get("stages",{}).get(str(tier),{})

static func minutes(state: RunState, id: String, tier: int) -> int:
	if not stage(state,id,tier).is_empty(): return 0
	return 10 if tier == 2 or not stage(state,id,2).is_empty() else 20

static func access(day: DayController, id: String) -> String:
	if not enabled(day.definition): return "这局没有精鉴台。"
	if ShopGrowthService.blocked(day) or not PawnReturnService.current(day.state).is_empty(): return "先处理眼前的事情。"
	var item := LuxuryAppraisalService.target(day,id)
	if item == null or not WealthyCustomers.is_item(item.definition_id): return "这件货已不在眼前。"
	if day.state.phase not in [&"open",&"closed_processing"]: return "营业中或提前关门后才能查验。"
	return ""

static func missing(day: DayController, item: ItemInstance, tier: int) -> String:
	var needs: Array[String] = []
	if FanAppraisalService.bench_level(day.state) < tier: needs.append("二级鉴物台" if tier == 2 else "三级精鉴台")
	for tool in ["magnifier","lamp"]:
		if tool not in day.definition.tools: needs.append("放大镜" if tool == "magnifier" else "灯")
	var spec := config(day.state,item)
	for kit in [String(spec.kit),String(spec.deep_kit) if tier == 3 else ""]:
		if not owns(day.state,kit): needs.append(KITS[kit].name)
	var book := LuxuryAppraisalService.info(day.state,item)
	if not ShopKnowledgeService.mastered(day.state,book.topic): needs.append(ShopKnowledgeService.TOPICS[book.topic].name)
	return "缺：" + "、".join(needs) if not needs.is_empty() else ""

static func time_reason(day: DayController, item: ItemInstance, cost: int) -> String:
	if cost == 0: return ""
	var visit := CustomerManager.new().active(day.state)
	var limit := day.definition.night_minutes
	if visit != null and visit.item == item: limit = mini(limit,visit.expires_at)
	return "余下时辰不够，未开始查验。" if day.state.game_minutes + cost >= limit else ""

static func reason(day: DayController, command: String, id: String, detail := "") -> String:
	var error := access(day,id)
	if not error.is_empty(): return error
	var item := LuxuryAppraisalService.target(day,id)
	if command == "luxury_exterior":
		if not detail.is_empty(): return "外观检查无须另填内容。"
		return time_reason(day,item,0 if record(day.state,id).get("exterior",false) else 5)
	if WatchAppraisal.handles(day.state,item): return WatchAppraisal.reason(day,command,id,detail)
	if command == "luxury_begin":
		if detail not in ["2","3"]: return "请选择查验方式。"
		if not stage(day.state,id,int(detail)).is_empty(): return ""
		error = missing(day,item,int(detail))
		return error if not error.is_empty() else time_reason(day,item,minutes(day.state,id,int(detail)))
	var payload: Variant = {"tier":int(detail)}
	if command in ["luxury_pair","luxury_select","luxury_mark"]:
		var parser := JSON.new()
		if parser.parse(detail) != OK: return "查验记录格式有误。"
		payload = parser.data
	if not payload is Dictionary or not RunSchema.integer(payload.get("tier")) or int(payload.tier) not in [2,3]: return "请选择有效的查验记录。"
	var row := stage(day.state,id,int(payload.tier))
	if row.is_empty(): return "先使用器材查验。"
	if row.get("committed",false): return "这一份已落笔，可继续复看或作更深查验。"
	match command:
		"luxury_mark":
			if not RunSchema.integer(payload.get("index")) or int(payload.index) not in [0,1] or payload.get("side") not in ["object","reference"]: return "请选择图版中的细节。"
			if not valid_point(payload.get("point")): return "圈点不在图版内。"
		"luxury_pair":
			if not RunSchema.integer(payload.get("index")) or int(payload.index) not in [0,1] or not NOTES.has(payload.get("note","")): return "请圈选两边的细节并记下看法。"
			for side in ["object","reference"]:
				var point: Variant = payload.get(side)
				if not point is Array or point.size() != 2: return "请在实物和图录上各圈一处。"
				for number in point:
					if not (number is float or number is int) or not is_finite(float(number)) or number < 0 or number > 1: return "圈点不在图版内。"
		"luxury_select":
			if not identities(day.state,item).has(payload.get("identity","")) or not conditions().has(payload.get("condition","")): return "分别选择身份与修配判断。"
		"luxury_seal":
			if detail not in ["2","3"]: return "请选择有效的查验记录。"
			if row.pairs.size() != 2 or row.identity.is_empty() or row.condition.is_empty(): return "先圈好两处，记下比较，再选择身份与修配判断。"
		_: return "没有这项查验操作。"
	return ""

static func identities(state: RunState, item: ItemInstance) -> Dictionary:
	var result := LuxuryAppraisalService.identity_choices(state,item)
	result["unsure"] = "暂难定论"
	return result

static func conditions() -> Dictionary:
	return {"intact":"未见修配","altered":"有修补或替换","unsure":"暂难定论"}

static func valid_point(point: Variant) -> bool:
	if not point is Array or point.size() != 2: return false
	for number in point:
		if not (number is int or number is float) or not is_finite(float(number)) or number < 0 or number > 1: return false
	return true

static func blank_stage() -> Dictionary:
	return {"pairs":{},"marks":{},"identity":"","condition":"","committed":false}

static func perform(day: DayController, command: String, id: String, detail := "") -> ActionResult:
	if command != "luxury_exterior" and WatchAppraisal.handles(day.state,LuxuryAppraisalService.target(day,id)): return WatchAppraisal.perform(day,command,id,detail)
	var error := reason(day,command,id,detail)
	if not error.is_empty(): return ActionResult.new(false,error)
	var all: Dictionary = WealthyCustomers.data(day.state).appraisals
	if not all.has(id): all[id] = {"exterior":false,"stages":{}}
	var row: Dictionary = all[id]
	var item := LuxuryAppraisalService.target(day,id)
	match command:
		"luxury_exterior":
			if not row.exterior:
				var spent := day.spend_action(5)
				if not spent.ok: return spent
				row.exterior = true
				CustomerManager.new().update(day.state)
			return ActionResult.new(true,exterior_text(day.state,item))
		"luxury_begin":
			var cost := minutes(day.state,id,int(detail))
			if cost > 0:
				var spent := day.spend_action(cost)
				if not spent.ok: return spent
				if not row.stages.has("2"): row.stages["2"] = blank_stage()
				if detail == "3": row.stages["3"] = blank_stage()
				CustomerManager.new().update(day.state)
			return ActionResult.new(true,"查验所得已摊在案上，可圈选细节与图录对照。")
		"luxury_pair", "luxury_select", "luxury_mark":
			var payload: Dictionary = JSON.parse_string(detail)
			var entry: Dictionary = row.stages[str(int(payload.tier))]
			if command == "luxury_mark":
				var index := str(int(payload.index))
				if not entry.marks.has(index): entry.marks[index] = {}
				entry.marks[index][payload.side] = payload.point
				entry.pairs.erase(index)
			elif command == "luxury_pair": entry.pairs[str(int(payload.index))] = payload
			else:
				entry.identity = payload.identity; entry.condition = payload.condition
		"luxury_seal": row.stages[detail].committed = true
	return ActionResult.new(true,"鉴定记录已落笔。" if command == "luxury_seal" else "草稿已记下。")

static func exterior_text(state: RunState, item: ItemInstance) -> String:
	if not record(state,item.instance_id).get("exterior",false): return "外观尚未检查。"
	return String(config(state,item).damage[["intact","minor","major"].find(item.goods.precision.damage)])

static func observations(state: RunState, item: ItemInstance, tier: int) -> Array:
	if WatchAppraisal.handles(state,item): return WatchAppraisal.observations(state,item)
	if stage(state,item.instance_id,tier).is_empty(): return []
	var spec := config(state,item)
	if tier == 2 and item.goods.precision.hidden: return spec.ambiguous
	return spec.deep_observations[item.selected_variant_id] if tier == 3 else LuxuryAppraisalService.info(state,item).observations[item.selected_variant_id]

static func expected(item: ItemInstance, tier: int) -> Array:
	if tier == 2 and item.goods.precision.hidden: return ["unsure","unsure"]
	if tier == 3 and item.definition_id == "item_luxury_album" and item.selected_variant_id == "mended": return ["different","same"]
	if tier == 3: return ["same","same"] if item.selected_variant_id == "sound" else ["different","different"]
	return LuxuryAppraisalService.expected_matches(item).map(func(key: String) -> String: return "same" if key == "sound" else "different")

static func correct(state: RunState, item: ItemInstance, tier: int) -> bool:
	if WatchAppraisal.handles(state,item): return tier == 2 and WatchAppraisal.correct(state,item)
	var row := stage(state,item.instance_id,tier)
	if not row.get("committed",false) or (tier == 2 and item.goods.precision.hidden): return false
	var book := LuxuryAppraisalService.info(state,item)
	if row.identity != book.identity[item.selected_variant_id] or row.condition != book.condition[item.selected_variant_id]: return false
	for index in 2:
		var pair: Dictionary = row.pairs.get(str(index),{})
		if pair.get("note","") != expected(item,tier)[index]: return false
		for side in ["object","reference"]:
			var point: Array = pair.get(side,[])
			if point.size() != 2 or point[1] < 0.1 or point[1] > 0.9: return false
			if point[0] < (0.05 if index == 0 else 0.55) or point[0] > (0.45 if index == 0 else 0.95): return false
	return true

static func pending(state: RunState, visit: CustomerVisit) -> Array[String]:
	if WatchEconomy.handles(state,visit.item): return WatchEconomy.pending(state,visit)
	var trade := WealthyCustomers.trade(state,visit)
	var used: Array = trade.get("precision_used",[])
	var result: Array[String] = []
	if record(state,visit.item.instance_id).get("exterior",false) and visit.item.goods.precision.damage != "intact" and "exterior" not in used: result.append("exterior")
	for tier in [3,2]:
		var row := stage(state,visit.item.instance_id,tier)
		if row.get("committed",false):
			if str(tier) not in used and row.identity != "unsure" and row.condition != "unsure" and not trade.get("precision_identity",false): result.append(str(tier))
			break
	return result

static func pressure_reason(day: DayController, visit: CustomerVisit, detail: String, amount: int) -> String:
	if visit != null and WatchNegotiation.handles(day.state,visit.item): return "请在商量价钱中选择要谈的说法。"
	if visit == null or not WealthyCustomers.is_customer(visit.customer_id): return "眼前没有这笔生意。"
	if not detail.is_empty() or amount != 0: return "先拿证据谈价，再另行报价。"
	if pending(day.state,visit).is_empty(): return "尚无未谈过的新证据。"
	if visit.trade.rounds_left <= 0 or visit.trade.patience <= 0: return "客人已不肯再谈。"
	return time_reason(day,visit.item,5)

static func pressure(day: DayController, visit: CustomerVisit) -> String:
	if WatchEconomy.handles(day.state,visit.item): return WatchEconomy.pressure(day,visit)
	var row := WealthyCustomers.trade(day.state,visit)
	var new_evidence := pending(day.state,visit)
	if not row.has("precision_used"): row.precision_used = []
	visit.trade.rounds_left -= 1
	var failed := false
	for entry in new_evidence:
		row.precision_used.append(entry)
		if entry == "exterior": row["precision_damage"] = true
		elif correct(day.state,visit.item,int(entry)): row["precision_identity"] = true
		else: failed = true
	if failed:
		var customer := day.state.ghost_catalog.get_definition("customers",visit.customer_id) as CustomerDefinition
		visit.trade.patience -= customer.terms.false_pressure_cost
	var definition := day.state.ghost_catalog.get_definition("items",visit.item.definition_id) as ItemDefinition
	var value: int = definition.find_variant(visit.item.selected_variant_id).true_value if row.get("precision_identity",false) else definition.base_value
	if row.get("precision_damage",false): value = adjusted(visit.item,value)
	row.value = value; row.reference = WealthyCustomers.reference_price(value,visit.transaction_modes[0])
	var profile: Dictionary = WealthyCustomers.config(day.state).profiles[visit.customer_id]
	visit.trade.reserve_price = maxi(int(row.funding),roundi(row.reference * float(profile.reserve_percent)/100.0 * float(row.intimidation)))
	visit.trade.asking_price = maxi(visit.trade.reserve_price,mini(visit.trade.asking_price,roundi(row.reference * float(profile.asking_percent)/100.0 * float(row.intimidation))))
	return (("客人认下外伤，却把鉴定退了回来：‘其余还不足为凭。’" if "exterior" in new_evidence else "客人摇头退回鉴定：‘这还不足为凭。’") if failed else "客人核过你指出的地方：‘既然凭据说清了，就照这个再谈。’") + "\n要价%d银元。" % visit.trade.asking_price

static func facility_reason(day: DayController, command: String, detail: String) -> String:
	if not enabled(day.definition): return "这局没有精鉴器材。"
	if ShopGrowthService.blocked(day): return "请先处理眼前的事情。"
	if day.state.current_night_index < 2 or day.state.phase != &"pre_open" or PreparationService.used(day.state,"finish",day.state.current_night_index): return "第二夜起，开铺前可办理。"
	var cost := 160
	if command == "bench_three":
		if not detail.is_empty(): return "无须另填内容。"
		if FanAppraisalService.bench_level(day.state) < 2: return "须等二级鉴物台完工。"
		if equipment(day.state).get("due",0) > 0: return "三级精鉴台已委托，不必重复付款。"
	elif command == "precision_kit":
		if not KITS.has(detail): return "没有这套器材。"
		if owns(day.state,detail): return "这套器材已经配齐。"
		if FanAppraisalService.bench_level(day.state) < KITS[detail].level: return "须先建成%d级鉴物台。" % KITS[detail].level
		cost = KITS[detail].cost
	else: return "没有这项铺务。"
	if PreparationService.count(day.state) >= 2: return "今夜两次准备已经用完。"
	return "现银不足，需要%d银元。" % cost if day.state.cash < cost else ""

static func facility(day: DayController, command: String, detail: String) -> ActionResult:
	var error := facility_reason(day,command,detail)
	if not error.is_empty(): return ActionResult.new(false,error)
	var state := day.state
	if not state.shop_growth.has("precision"): state.shop_growth["precision"] = {"due":0,"kits":[]}
	var cost: int = 160 if command == "bench_three" else KITS[detail].cost
	EconomyManager.new().commit(state,-cost,"","facility/"+command+"/"+detail,"facility_investment")
	state.shop_growth.investments.append({"facility":command,"detail":detail,"night":state.current_night_index,"amount":cost,"preparation":1})
	if command == "bench_three":
		state.shop_growth.precision.due = state.current_night_index+2
		return ActionResult.new(true,"木匠已收款，三级精鉴台第%d夜开铺前完工。原台照常可用。" % state.shop_growth.precision.due)
	state.shop_growth.precision.kits.append(detail)
	if detail == "display": state.shop_growth.appraisal.tools = true
	return ActionResult.new(true,KITS[detail].name+"已配齐，占用1次准备。")

static func facility_model(day: DayController, model: Dictionary) -> void:
	if not enabled(day.definition): return
	var level := FanAppraisalService.bench_level(day.state)
	var due: int = equipment(day.state).get("due",0)
	model.body += "\n精鉴台：" + ("已完工" if level >= 3 else "第%d夜完工" % due if due > 0 else "尚未委托")
	if due == 0:
		var why := facility_reason(day,"bench_three","")
		model.buttons.append({"command":"bench_three","detail":"","label":"建三级精鉴台 · 160银元 / 准备1次 / 两夜工期","enabled":why.is_empty(),"reason":why})
	var owned: Array[String] = []
	for id in KITS:
		if owns(day.state,id): owned.append(KITS[id].name); continue
		var why := facility_reason(day,"precision_kit",id)
		model.buttons.append({"command":"precision_kit","detail":id,"label":"添置%s · %d银元 / 准备1次" % [KITS[id].name,KITS[id].cost],"enabled":why.is_empty(),"reason":why})
	model.body += "\n已配器材："+("、".join(owned) if not owned.is_empty() else "暂无专用套件")
	model.body += "\n放大镜与灯沿用柜台工具。知识在旧账柜学习。"
