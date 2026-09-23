class_name LuxuryAppraisalService
extends RefCounted

const IDENTITIES := {"original":"与声称相符","copy":"旧临本","lower_grade":"低成色旧款","imitation":"仿制或冒名"}
const CONDITIONS := {"intact":"未见修配","altered":"有修补或替换"}
const MATCHES := {"sound":"符合完整样例","mended":"对应修配或旧临样例","flawed":"对应仿制疑点"}

static func target(day: DayController, id: String) -> ItemInstance:
	var visit := CustomerManager.new().active(day.state)
	if visit != null and visit.purpose.is_empty() and visit.item.instance_id == id: return visit.item
	var item := InventoryManager.new().find(day.state,id)
	return item if item != null and item.ownership_state in ["owned","pledged"] else null

static func record(state: RunState, id: String) -> Dictionary:
	return WealthyCustomers.data(state).get("appraisals",{}).get(id,{})

static func info(state: RunState, item: ItemInstance) -> Dictionary:
	return WealthyCustomers.config(state).items[item.definition_id]

static func expected_matches(item: ItemInstance) -> Array:
	if item.selected_variant_id == "sound": return ["sound","sound"]
	if item.selected_variant_id == "flawed": return ["flawed","flawed"]
	if item.definition_id in ["item_luxury_embroidery","item_luxury_jade_pendant","item_luxury_porcelain_vase","item_luxury_repeater"]: return ["sound","mended"]
	if item.definition_id == "item_luxury_album": return ["mended","sound"]
	return ["mended","mended"]

static func reason(day: DayController, command: String, id: String, detail := "") -> String:
	if TieredAppraisal.enabled(day.definition): return TieredAppraisal.reason(day,command,id,detail)
	if not WealthyCustomers.active(day.state): return "这局没有高档货图录。"
	if not PawnReturnService.current(day.state).is_empty(): return "先接待持票取赎的原当户，再来细查。"
	var item := target(day,id)
	if item == null or not WealthyCustomers.is_item(item.definition_id): return "只能查看柜前待收或铺中持有的高档货。"
	if day.state.phase not in [&"open",&"closed_processing"] or ShopGrowthService.blocked(day): return "请先处理眼前的事情，再来鉴物台。"
	if FanAppraisalService.bench_level(day.state) < 2: return "须待二级鉴物台建成，才能细查这件货。"
	var row := record(day.state,id)
	if command == "luxury_check":
		if detail not in ["0","1"]: return "请选一处要查的细节。"
		if detail in row.get("checks",[]): return ""
		var visit := CustomerManager.new().active(day.state)
		var limit := mini(day.definition.night_minutes,visit.expires_at) if visit != null and visit.item.instance_id == id else day.definition.night_minutes
		if day.state.game_minutes + 10 >= limit: return "余下时辰不够细查，未开始检查。"
		return ""
	if not ShopKnowledgeService.mastered(day.state,info(day.state,item).topic): return "须先在旧账柜学习对应知识，才能对照图录落笔。"
	if row.get("committed",false): return "这份判断已经落笔，可免费复看。"
	match command:
		"luxury_match":
			var pair := detail.split("/")
			if pair.size() != 2 or pair[0] not in ["0","1"] or not MATCHES.has(pair[1]): return "请在实物细节旁选一项图录样例。"
			if pair[0] not in row.get("checks",[]): return "先检查这处实物，再和图录配对。"
		"luxury_identity":
			if not identity_choices(day.state,item).has(detail): return "请按这件货选择身份判断。"
		"luxury_condition":
			if not CONDITIONS.has(detail): return "请选择品相判断。"
		"luxury_commit":
			if not detail.is_empty(): return "落笔不需要另填内容。"
			if row.get("checks",[]).size() != 2 or row.get("matches",{}).size() != 2 or row.get("identity","").is_empty() or row.get("condition","").is_empty(): return "先查完两处、配对两项图录，并分别记下身份与品相。"
		_: return "没有这项鉴定操作。"
	return ""

static func identity_choices(state: RunState, item: ItemInstance) -> Dictionary:
	var choices := {"original":IDENTITIES.original,"imitation":IDENTITIES.imitation}
	if item.definition_id == "item_luxury_album": choices["copy"] = IDENTITIES.copy
	if item.definition_id == "item_luxury_gold_bangle": choices["lower_grade"] = IDENTITIES.lower_grade
	return choices

# A price guide lists every possible condition, never the unseen selected variant.
static func price_guide(item: ItemDefinition) -> String:
	var text := "估价旧簿（银元） · 货值 / 参考当金 / 参考收购价"
	var labels := {"sound":"完整货","mended":"修补或替换货","flawed":"仿制或冒名货"}
	if item.id == "item_luxury_album": labels.mended = "旧临本"
	if item.id == "item_luxury_gold_bangle": labels.mended = "低成色旧款"
	for variant in ["sound","mended","flawed"]:
		var value := item.find_variant(variant).true_value
		text += "\n%s：%d / %d / %d" % [labels[variant],value,WealthyCustomers.reference_price(value,"pawn"),WealthyCustomers.reference_price(value,"sell")]
	return text

static func perform(day: DayController, command: String, id: String, detail := "") -> ActionResult:
	if TieredAppraisal.enabled(day.definition): return TieredAppraisal.perform(day,command,id,detail)
	var error := reason(day,command,id,detail)
	if not error.is_empty(): return ActionResult.new(false,error)
	var item := target(day,id)
	var records: Dictionary = WealthyCustomers.data(day.state).appraisals
	if not records.has(id): records[id] = {"checks":[],"matches":{},"identity":"","condition":"","committed":false}
	var row: Dictionary = records[id]
	var message := "草稿已记下，可在落笔前修改。"
	match command:
		"luxury_check":
			if detail not in row.checks:
				day.spend_action(10)
				row.checks.append(detail)
				CustomerManager.new().update(day.state)
			message = info(day.state,item).observations[item.selected_variant_id][int(detail)]
		"luxury_match": row.matches[detail.get_slice("/",0)] = detail.get_slice("/",1)
		"luxury_identity": row.identity = detail
		"luxury_condition": row.condition = detail
		"luxury_commit":
			row.committed = true
			item.judgement = "fake" if row.identity == "imitation" else "damaged" if row.condition == "altered" or row.identity != "original" else "sound"
			message = "鉴定记录已落笔。"
	return ActionResult.new(true,message)

static func correct(state: RunState, item: ItemInstance) -> bool:
	var row := record(state,item.instance_id)
	if not row.get("committed",false): return false
	var definition := info(state,item)
	var expected := expected_matches(item)
	return row.identity == definition.identity[item.selected_variant_id] and row.condition == definition.condition[item.selected_variant_id] and row.matches.get("0","") == expected[0] and row.matches.get("1","") == expected[1]

static func pressure_reason(day: DayController, visit: CustomerVisit, detail: String, amount: int) -> String:
	if TieredAppraisal.enabled(day.definition): return TieredAppraisal.pressure_reason(day,visit,detail,amount)
	if not WealthyCustomers.active(day.state) or not WealthyCustomers.is_customer(visit.customer_id): return "眼前这笔生意不适用高档货举证。"
	if not detail.is_empty() or amount != 0: return "先拿鉴定记录谈，再另行报价。"
	if not record(day.state,visit.item.instance_id).get("committed",false): return "先查完两处并在鉴物台落笔。"
	if WealthyCustomers.trade(day.state,visit).evidence_used: return "这份鉴定记录已经谈过。"
	if visit.trade.rounds_left <= 0 or visit.trade.patience <= 0: return "客人已不肯再谈。"
	if day.state.game_minutes + 5 >= mini(day.definition.night_minutes,visit.expires_at): return "余下时辰不够谈完这一轮。"
	return ""

static func pressure(day: DayController, visit: CustomerVisit) -> String:
	if TieredAppraisal.enabled(day.definition): return TieredAppraisal.pressure(day,visit)
	var row := WealthyCustomers.trade(day.state,visit)
	var customer := day.state.ghost_catalog.get_definition("customers",visit.customer_id) as CustomerDefinition
	row.evidence_used = true
	visit.trade.rounds_left -= 1
	if not correct(day.state,visit.item):
		visit.trade.patience -= customer.terms.false_pressure_cost
		return "他将图录推回来：‘这两处还没说到一块儿，不能照这个改价。’"
	var item := day.state.ghost_catalog.get_definition("items",visit.item.definition_id) as ItemDefinition
	row.value = item.find_variant(visit.item.selected_variant_id).true_value
	row.reference = WealthyCustomers.reference_price(int(row.value),visit.transaction_modes[0])
	var profile: Dictionary = WealthyCustomers.config(day.state).profiles[visit.customer_id]
	var new_asking := roundi(int(row.reference)*float(profile.asking_percent)/100.0*float(row.intimidation))
	visit.trade.reserve_price = maxi(int(row.funding),roundi(int(row.reference)*float(profile.reserve_percent)/100.0*float(row.intimidation)))
	visit.trade.asking_price = maxi(visit.trade.reserve_price,mini(visit.trade.asking_price,new_asking))
	return "他把货挪近灯下，核过你指出的地方：‘既然凭据说清了，就照这份品相谈。’\n要价%d银元。" % visit.trade.asking_price

static func page(day: DayController, id: String) -> Dictionary:
	var model := {"body":"", "buttons":[]}
	var item := target(day,id)
	if item == null: model.body = "这件货已不在眼前。"; return model
	var definition := day.state.ghost_catalog.get_definition("items",item.definition_id) as ItemDefinition
	var book := info(day.state,item)
	var row := record(day.state,id)
	var known := ShopKnowledgeService.mastered(day.state,book.topic)
	model.body = definition.display_name + "\n"
	for index in 2:
		var checked: bool = str(index) in row.get("checks",[])
		model.body += "\n【" + String(book.checks[index]) + "】\n"
		if checked: model.body += book.observations[item.selected_variant_id][index] + "\n"
		else: model.body += "尚未细查。\n"
		_button(model,day,id,"luxury_check",str(index),("复看：" if checked else "细查：") + String(book.checks[index]) + (" · 免费" if checked else " · 10分钟"))
		if known:
			model.body += "图录：" + String(book.references[index]) + "\n"
			if row.get("matches",{}).has(str(index)): model.body += "你的配对：" + String(MATCHES[row.matches[str(index)]]) + "\n"
			if not row.get("committed",false):
				for choice in MATCHES: _button(model,day,id,"luxury_match","%d/%s" % [index,choice],"第%d处 · %s" % [index+1,MATCHES[choice]])
		else: model.body += "须先在旧账柜学习" + String(ShopKnowledgeService.TOPICS[book.topic].name) + "，才能对照图录。\n"
	model.body += "\n身份判断：" + String(IDENTITIES.get(row.get("identity",""),"尚未记录")) + "\n品相判断：" + String(CONDITIONS.get(row.get("condition",""),"尚未记录"))
	if row.get("committed",false): model.body += "\n已落笔；这是自己的鉴定结论。"
	else:
		for choice in identity_choices(day.state,item): _button(model,day,id,"luxury_identity",choice,"身份 · " + IDENTITIES[choice])
		for choice in CONDITIONS: _button(model,day,id,"luxury_condition",choice,"品相 · " + CONDITIONS[choice])
		_button(model,day,id,"luxury_commit","","将这份判断落笔")
	return model

static func _button(model: Dictionary, day: DayController, id: String, command: String, detail: String, label: String) -> void:
	var error := reason(day,command,id,detail)
	model.buttons.append({"command":command,"detail":detail,"label":label,"enabled":error.is_empty(),"reason":error})
