class_name ShopGrowthReadModels
extends RefCounted

static func inventory(model: Dictionary, day: DayController) -> void:
	if not day.state.shop_growth_enabled: return
	for item in day.state.inventory_instances:
		if item.ownership_state != "owned": continue
		var shown: bool = day.state.shop_growth.display_id == item.instance_id
		var command := "withdraw" if shown else "display"
		var error := ShopGrowthService.reason(day, command, "" if shown else item.instance_id)
		model.inventory.buttons.append({"command": "growth_" + command, "target_id": item.instance_id, "detail": "", "label": "撤下陈列货" if shown else "放入陈列柜 · 不耗准备", "enabled": error.is_empty(), "reason": error})
		for row in model.inventory.visual.stock:
			if row.id == item.instance_id and shown: row.stamp = "陈列中"

static func buyer(model: Dictionary, day: DayController, visit: CustomerVisit, message: String) -> Dictionary:
	var row := ShopGrowthService.opportunity(day.state)
	var item := day.state.ghost_catalog.get_definition("items", visit.item.definition_id) as ItemDefinition
	var deadline := TimeController.clock_text(day.definition.opening_minute, visit.expires_at)
	var introduction := "‘柜里这件%s，正合我用。我出%d银元，掌柜肯割爱么？’" % [item.display_name, int(row.get("offer", 0))]
	model.active_id = visit.visit_id
	model.customer = "看中陈列货的客人\n" + introduction
	model.item = item.display_name + " · 铺中自有陈列货"
	model.context_actions = {"customer": [{"id": "dialogue", "label": "对话", "enabled": true}, {"id": "trade", "label": "议价售货", "enabled": true}], "item": []}
	model.visual = {"customer_id": visit.customer_id, "portrait_asset": "asset.customer_hawker", "customer_name": visit.person.name, "item_asset": item.visual_asset_id, "item_name": item.display_name, "item_status": "铺中陈列货 · 货款当面结清", "estimate": "", "clues": [], "speech": [], "attitude": "等你回话", "deadline": deadline, "introduction": introduction, "intent": "买陈列货"}
	model.dialogue = {"visit_id": visit.visit_id, "body": introduction + "\n\n他将钱袋搁在手边，等到%s。可去议价售货，或谢绝他。" % deadline, "buttons": []}
	model.appraisal = {"visit_id": visit.visit_id, "body": "客人来买铺中现货。已有物品资料可在库存免费复看。", "buttons": []}
	var error := ShopGrowthService.trade_reason(day, "display_counter", visit.visit_id, "", int(row.get("offer", 0)) + 1)
	model.trade = {"visit_id": visit.visit_id, "display_buyer": true, "body": introduction + "\n\n买家开价：%d银元\n客人最迟留到%s。接受或回价各耗5分钟，拒绝不耗时。\n回价只可一次，须高于开价；谈不拢便送客。" % [int(row.get("offer", 0)), deadline], "buttons": [], "can_offer": false, "can_pawn": false, "can_counter": error.is_empty(), "counter_reason": error, "opening_offer": int(row.get("offer", 0)), "max_input": 1000000, "asking_price": 1, "pawn_asking": 1}
	if int(row.get("source_premium", 0)) > 0: model.trade.body += "\n已证实的来源已计入这份报价。"
	if not message.is_empty(): model.trade.body += "\n\n" + message
	for action in [["display_accept", "接受报价 · 5分钟"], ["reject", "谢绝买家 · 不耗时"]]:
		error = ShopGrowthService.trade_reason(day, action[0], visit.visit_id)
		model.trade.buttons.append({"command": action[0], "detail": "", "label": action[1], "enabled": error.is_empty(), "reason": error})
	return model

static func page(day: DayController, section: int) -> Dictionary:
	var model := {"body": "这局没有开办修缮与查铺。", "buttons": []}
	if not day.state.shop_growth_enabled: return model
	var state := day.state
	if section == 0:
		model.body = "工具架与陈列位\n\n今夜准备已用%d / 2次 · 现银%d银元\n整修在第二夜起、开铺前办理，当晚可用。" % [PreparationService.count(state), state.cash]
		model.body += "\n\n鉴物台：" + ("已整修。普通货使用放大镜、灯或磁铁的10分钟检查，缩至5分钟。" if state.shop_growth.bench else "旧毡起皱，工具散在台角。整平台面、安好工具架，检查更利落。")
		model.body += "\n\n陈列柜：" + ("已整修，提供1个位置。开铺前可选换货物；成交须掌柜亲自谈。" if state.shop_growth.display else "玻璃蒙灰，柜门合不拢。修好后可陈列一件自有普通现货。")
		for id in ["bench", "display"]: _button(model, day, "build", id, "整修%s · %d银元 / 1次准备" % [ShopGrowthService.NAMES[id], ShopGrowthService.COSTS[id]])
	elif section == 1:
		model.body = "陈列位 · 一位一货\n\n只能放自有普通现货。营业中可撤下或另售，换货须等下次开铺前。\n陈列持续到撤下或售出；有没有识货的人来，须等门开后才知道。"
		var id: String = state.shop_growth.display_id
		var item := InventoryManager.new().find(state, id)
		if item == null: model.body += "\n\n柜位空着。可到库存选货，也可在下面选一件。"
		else:
			model.body += "\n\n眼前陈列：" + (state.ghost_catalog.get_definition("items", item.definition_id) as ItemDefinition).display_name
			_button(model, day, "withdraw", "", "撤下陈列货 · 不耗时")
		for stock in state.inventory_instances:
			if stock.ownership_state != "owned" or not ShopGrowthService.item_reason(state, stock).is_empty() or stock.instance_id == id: continue
			_button(model, day, "display", stock.instance_id, "陈列：" + (state.ghost_catalog.get_definition("items", stock.definition_id) as ItemDefinition).display_name)
	else:
		var count: int = state.shop_growth.exploration.size()
		model.body = "沿柜查铺\n\n提前关门后，可在03:00前慢慢核查。不收银元，不占准备次数。"
		for i in range(count - 1, -1, -1): model.body += "\n\n" + ShopGrowthService.MATERIALS[i]
		if count < 3:
			if count == 0: model.body += "\n\n旧账堆在最里头的柜脚，灰下还露着几张目录。"
			_button(model, day, "explore", str(count), "%s · %d分钟" % [ShopGrowthService.STEPS[count], ShopGrowthService.MINUTES[count]])
		else: model.body += "\n\n这处柜格已查完。抄录留在此页，可随时免费复看。"
	return model

static func _button(model: Dictionary, day: DayController, command: String, detail: String, label: String) -> void:
	var error := ShopGrowthService.reason(day, command, detail)
	model.buttons.append({"command": command, "detail": detail, "label": label, "enabled": error.is_empty(), "reason": error})
