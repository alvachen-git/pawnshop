class_name MedicineStory
extends RefCounted

const CUSTOMER := "mirror_medicine"
const NAME := "周怀安"
const NIGHTS := [3, 9, 18, 19]
const TARGET := 200
const ENDING := "medicine/ending/heard"

static func enabled(run: RunDefinition) -> bool:
	return run.variety.get("medicine_story_version", 0) == 1

static func active(state: RunState) -> bool:
	return state.ghost_catalog != null and enabled(state.ghost_catalog.get_definition("runs",state.run_definition_id))

# Count committed payments, never the current ownership or resale value of goods.
static func funds(state: RunState) -> int:
	var ids: Array = []
	for row in state.ordinary_selections:
		if row.has("medicine_stage"): ids.append("purchase/" + String(row.visit_id))
	var amount := 0
	for entry in state.ledger_entries:
		if entry.kind == "acquisition" and entry.transaction_id in ids: amount -= int(entry.amount)
	return amount

static func pool(run: RunDefinition, catalog: ContentCatalog) -> Array:
	var result: Array = []
	for id in run.variety.customer_ids:
		var customer := catalog.get_definition("customers",id) as CustomerDefinition
		for item_id in customer.item_pool:
			var item := catalog.get_definition("items",item_id) as ItemDefinition
			if item.item_type == "normal" and item.ghost_rule_id.is_empty() and not WealthyCustomers.is_item(item_id) and item_id not in result: result.append(item_id)
	return result

static func overlay(state: RunState, run: RunDefinition, catalog: ContentCatalog, rows: Array[Dictionary]) -> Array[Dictionary]:
	if not enabled(run): return rows
	if not state.shop_growth.has("medicine_plans"): state.shop_growth.medicine_plans = {}
	var n := state.current_night_index
	if n not in NIGHTS: return rows
	var plans: Dictionary = state.shop_growth.medicine_plans
	var key := str(n)
	if not plans.has(key):
		var stage := NIGHTS.find(n)
		var id := "%s/%d/medicine_visit" % [run.id,n]
		var arrival := 90
		if n == 3:
			for row in rows:
				if row.night == 3 and row.customer_id == CUSTOMER: id = row.visit_id; arrival = row.arrival; break
		else:
			var candidates: Array = []
			for minute in range(90,211,5):
				if rows.all(func(row: Dictionary) -> bool: return row.night != n or absi(int(row.arrival)-minute) >= 15): candidates.append(minute)
			if not candidates.is_empty(): arrival = int(VarietyService.pick(candidates,state.run_seed,"medicine/arrival/"+key))
		var item_id: String = VarietyService.pick(pool(run,catalog),state.run_seed,"medicine/item/"+key)
		var item := catalog.get_definition("items",item_id) as ItemDefinition
		plans[key] = {"visit_id":id,"night":n,"arrival":arrival,"customer_id":CUSTOMER,"context_id":"","item_id":item_id,"variant_id":VarietyService.pick(item.possible_variants,state.run_seed,"medicine/variant/"+key).id,"source":"none","situation":"ordinary","reaction":"admit","terms_id":"","transaction_modes":["sell"],"wait_minutes":90,"familiar_reserved":true,"medicine_stage":stage,"medicine_funds":funds(state),"person":{"id":"medicine/huaian","name":NAME,"portrait":"medicine.huaian"}}
	var planned: Dictionary = plans[key]
	var found := false
	for i in rows.size():
		if rows[i].visit_id == planned.visit_id: rows[i] = planned.duplicate(true); found = true; break
	if not found: rows.append(planned.duplicate(true))
	return rows

static func prepare(state: RunState, visit: CustomerVisit, row: Dictionary, _item: ItemDefinition) -> void:
	if not active(state) or not row.has("medicine_stage"): return
	visit.person = row.person.duplicate(true)
	visit.voice.introduction = introduction(row)
	visit.voice.completed = "周怀安把银元数了两遍，小心包进帕里：‘这笔药钱，我记着您的情。’"
	visit.voice.rejected = "周怀安把旧物收回怀里：‘那……我再去别处问问。’"
	visit.voice.origin = "‘都是家里用过的旧物。’他低头抚平衣角。"
	if int(row.medicine_funds) >= TARGET:
		visit.purpose = "medicine_report"
		visit.transaction_modes.clear()
		visit.scenario_id = ""
	elif int(row.medicine_stage) == 3:
		visit.trade.opening_price = TARGET - int(row.medicine_funds)
		visit.trade.asking_price = visit.trade.opening_price
		visit.trade.reserve_price = maxi(1, roundi(visit.trade.opening_price * 0.7))

static func introduction(row: Dictionary) -> String:
	var amount := int(row.medicine_funds)
	var stage := int(row.medicine_stage)
	if amount >= TARGET:
		return "周怀安进门先拱了拱手：‘掌柜，药已经取回去了。我娘今早能喝下半碗粥，气色也好些。这回不卖东西，只来给您报个平安。’" if stage < 3 else "周怀安神色舒展了些：‘我娘能下地走两步了，还惦记着当铺里肯帮她儿子的掌柜。等她再养好些，我陪她来道谢。’"
	if stage == 0:
		return "青年把皱了的药单攥在手里：‘我叫周怀安，就住后街。家母病着，大夫开的药得二百银元，我实在凑不出。’\n‘这些都是家里用过的东西。掌柜，求您多估一点，能多一块是一块。药铺只肯再等十六天。’"
	if stage == 3:
		return "周怀安眼下乌青，把旧物放到柜上，手却迟迟没有收回。\n‘前头在您这儿得了%d银元，还差%d。今天是最后的期限……这件东西，我就求%d银元。’\n‘掌柜，求您救我娘一回。来世做牛做马，我也报您的恩。’" % [amount,TARGET-amount,TARGET-amount]
	return "周怀安又带来一件旧物，药单的折痕已经磨破。\n‘先前在您这儿共得了%d银元，还差%d。我娘还在等着，掌柜，这回能不能再多给一点？’" % [amount,TARGET-amount]

static func ending_due(state: RunState) -> bool:
	return active(state) and state.phase == &"pre_open" and state.current_night_index >= 20 and ENDING not in state.narrative_flags

static func dialogue(state: RunState) -> Dictionary:
	if not active(state) or state.phase not in [&"pre_open",&"open"] or MilitaryIntroduction.active(state): return {}
	if not state.pending_event_id.is_empty() or not state.risk_pending.is_empty() or not state.social.get("pending",{}).is_empty(): return {}
	if ending_due(state):
		var saved := funds(state) >= TARGET
		var text := "周怀安在门外站定，郑重向你作了一揖。\n‘掌柜，二百银元药钱凑齐了，药也用上了。我娘昨夜睡得安稳，大夫说眼下这道险关算过了。’\n‘您的情，我和我娘都记着。往后有使得着我的地方，您开口。’" if saved else "周婶提着菜篮进门，照例问了两句铺里的生意，忽然叹了口气。\n‘后街周怀安家，你晓得吧？他娘昨夜没熬过去。’\n‘那孩子这些日子，家里的东西一件件往外拿，药钱到底还是没凑齐。天不亮就守在门口，谁劝也不出声。’\n周婶把篮子换到另一只手上，声音低了下去：‘好好的一个家……唉。’"
		return {"key":ENDING,"speaker":NAME if saved else "周婶","text":text,"auto_open":true,"buttons":[],"ending":true,"saved":saved}
	var visit := CustomerManager.new().active(state)
	if visit == null: return {}
	var row := VarietySaveCodec.selection(state,visit.visit_id)
	if not row.has("medicine_stage"): return {}
	var key := "medicine/heard/" + str(row.medicine_stage)
	if key in state.narrative_flags: return {}
	return {"key":key,"speaker":NAME,"text":introduction(row),"auto_open":true,"buttons":[],"ending":false}

static func acknowledge(state: RunState, key: String) -> ActionResult:
	var model := dialogue(state)
	if model.is_empty() or model.key != key: return ActionResult.new(false,"眼前的话已经说完了。")
	state.narrative_flags.append(key)
	if model.ending:
		state.narrative_flags.append("medicine/mother_saved" if model.saved else "medicine/mother_died")
	else:
		var visit := CustomerManager.new().active(state)
		if visit != null and visit.purpose == "medicine_report":
			CustomerManager.new().finish(state,visit,"medicine_reported")
			CustomerManager.new().update(state)
	return ActionResult.new(true, "周婶说完家常，提起篮子告辞。" if model.ending and not model.saved else "周怀安向你点了点头。")

static func enrich(model: Dictionary, state: RunState) -> void:
	if not active(state): return
	var talk := dialogue(state)
	var visit := CustomerManager.new().active(state)
	var report := visit != null and visit.purpose == "medicine_report"
	if not ending_due(state) and not report: return
	if ending_due(state) and talk.is_empty(): return
	var neighbor := ending_due(state) and funds(state) < TARGET
	var speaker := "周婶" if neighbor else NAME
	model.active_id = ENDING if ending_due(state) else visit.visit_id
	model.customer = speaker + " · 串门"
	model.item = ""; model["itemless"] = true
	model.context_actions = {"customer":[{"id":"dialogue","label":"交谈","enabled":true}],"item":[]}
	model.visual = {"customer_id":"intro_neighbor" if neighbor else CUSTOMER,"customer_name":speaker,"portrait_asset":"asset.customer_citizen" if neighbor else "medicine.huaian","person_id":"","item_asset":"","item_name":"","item_status":"","estimate":"","clues":[],"speech":[],"attitude":"登门叙话","deadline":"","introduction":talk.get("text",""),"intent":"登门叙话"}
	model.trade.can_offer = false; model.trade.can_pawn = false
	model.trade.body = "这次只来叙话，没有货物可交易。"
	model.appraisal.body = "柜上没有货物。"

static func finish(state: RunState, visit: CustomerVisit, outcome: String) -> void:
	if not active(state) or outcome != "bought" or not VarietySaveCodec.selection(state,visit.visit_id).has("medicine_stage"): return
	var total := funds(state)
	visit.voice.completed = "周怀安反复数着银元，声音发颤：‘够了，药钱够了……掌柜，我这就去取药。’" if total >= TARGET else "周怀安把银元小心包好：‘前后共%d银元了，还差%d。掌柜，多谢您肯收。’" % [total,TARGET-total]
