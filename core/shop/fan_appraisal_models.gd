class_name FanAppraisalModels
extends RefCounted

static func button(day: DayController, command: String, label: String) -> Dictionary:
	var error := FanAppraisalService.facility_reason(day, command)
	return {"command": command, "detail": "", "label": label, "enabled": error.is_empty(), "reason": error}

static func facility(day: DayController) -> Dictionary:
	if FanConditionService.enabled(day.definition): return independent_facility(day)
	var state := day.state
	var a := FanAppraisalService.data(state)
	var level := FanAppraisalService.bench_level(state)
	var model := {"title": "鉴物台 · " + ["待整修", "一级", "二级专用台"][level], "body": "", "buttons": []}
	if a.is_empty(): return model
	if not a.manual:
		model.body = "更细的比对需要展扇台和专门图录。旧账柜的目录里，或许还记着旧工具放在哪里。"
		return model
	model.body = "旧工具册与《顾砚生扇画摹存》已找出。\n台体、工具与识画的知识各有用处，缺一项便不能自行鉴赏。"
	if int(a.bench_due) == 0:
		model.buttons.append(button(day, "bench_two", "改造二级鉴物台 · 80银元 / 准备1次 / 两夜工期"))
	elif level < 2:
		model.body += "\n\n木匠施工中：第%d夜开铺前完工。一级台照常可用。" % int(a.bench_due)
	else: model.body += "\n\n二级专用台已完工，可展开折扇并置图录。"
	model.body += "\n扇画工具：" + ("展扇夹、侧光镜、比对尺已齐。" if a.tools else "尚未添置。")
	model.body += "\n扇画知识：" + ("已研习，可自行比对。" if a.knowledge else "图录已在，尚未研习。")
	model.body += "\n\n鉴定名声\n" + FanAppraisalService.standing_text(state) + "\n收货后请行家复核，可验证此前的自鉴。"
	if not a.tools: model.buttons.append(button(day, "fan_tools", "添置扇画工具 · 30银元 / 准备1次"))
	if not a.knowledge: model.buttons.append(button(day, "fan_study", "研习扇画图录 · 准备1次 / 不收费"))
	if a.knowledge and a.tools and level == 2: model.body += "\n\n接到折扇时，从鉴定页进入「扇画比对」；自有折扇可从库存进入。笔锋与题款先留草稿，可免费重选；确认落笔一次耗10分钟。客人仍会按时离开。"
	model.body += "\n\n图录要点 · 免费复看\n" + FanAppraisalService.REFERENCE.brush + "\n\n" + FanAppraisalService.REFERENCE.inscription
	return model

static func archive(model: Dictionary, day: DayController) -> void:
	if not FanAppraisalService.enabled(day.definition): return
	if ShopKnowledgeService.enabled(day.definition):
		model.body += "\n\n柜中知识\n开铺前可按柜查阅，每学会一项占用1次准备；已掌握的可免费复看。"
		for topic in ShopKnowledgeService.TOPICS:
			var knowledge := ShopKnowledgeService.page(day, topic)
			model.body += "\n\n" + knowledge.title + " · " + ("已掌握" if ShopKnowledgeService.mastered(day.state, topic) else "尚未掌握")
			model.buttons.append_array(knowledge.buttons)
		return
	var a := FanAppraisalService.data(day.state)
	if a.manual:
		model.body += "\n\n旧工具册与扇画图录已收在鉴物台。工具册只记台体尺寸与辨笔要点，不解开旧票的来历。"
	elif not day.state.shop_growth.exploration.is_empty():
		model.body += "\n\n目录末页另记着一册旧工具簿，页边写有‘扇画摹存’。可顺着另查，不影响核对柜号。"
		model.buttons.append(button(day, "fan_manual", "循目录找工具册 · 10分钟 / 不收费"))

static func independent_facility(day: DayController) -> Dictionary:
	var a := FanAppraisalService.data(day.state)
	var level := FanAppraisalService.bench_level(day.state)
	var model := {"title": "鉴物台 · " + ["待整修", "一级", "二级专用台"][level], "body": "", "buttons": []}
	if a.is_empty(): return model
	model.body = "暂无可用能力" if level == 0 else "普通工具检查 · 10 → 5分钟"
	if level == 1 and int(a.bench_due) == 0:
		model.buttons.append(button(day, "bench_two", "改造二级鉴物台 · 80银元 / 准备1次 / 两夜工期"))
	elif level == 1 and int(a.bench_due) > 0:
		model.body += "\n改造中 · 第%d夜完工" % int(a.bench_due)
	if level == 2 and not a.tools: model.buttons.append(button(day, "fan_tools", "添置扇画工具 · 30银元 / 准备1次"))
	var known := ShopKnowledgeService.mastered(day.state, ShopKnowledgeService.GU_YANSHENG)
	if a.tools and level == 2:
		model.body += "\n顾砚生扇画比对 · 已开放" if known else "\n扇画工具 · 已配齐"
	return model

static func enrich(model: Dictionary, day: DayController) -> void:
	if not FanAppraisalService.enabled(day.definition): return
	var visit := CustomerManager.new().active(day.state)
	if visit != null and visit.purpose.is_empty() and visit.item.definition_id == GoodsExpertise.FAN and (not FanConditionService.enabled(day.definition) or PawnReturnService.current(day.state).is_empty()):
		if FanConditionService.enabled(day.definition):
			model.appraisal.buttons = model.appraisal.buttons.filter(func(b: Dictionary) -> bool: return b.command not in ["appraise", "judge"])
			var why := FanConditionService.reason(day, visit.item.instance_id)
			model.appraisal.buttons.push_front({"command": "condition", "detail": visit.item.instance_id, "label": "检查破损 · 5分钟" if not FanConditionService.checked(visit.item) else "破损已查 · 免费复看", "enabled": why.is_empty(), "reason": why})
		var error := FanConditionService.desk_reason(day, visit.item.instance_id)
		if FanConditionService.enabled(day.definition) and not error.is_empty(): model.appraisal.visual.goods_note += "\n鉴物台：" + error
		model.appraisal.buttons.append({"command": "fan_open", "detail": visit.item.instance_id, "label": "送上鉴物台 · 辨认真假" if FanConditionService.enabled(day.definition) else "扇画比对 · 查看图录与手记", "enabled": error.is_empty(), "reason": error})
	for item in day.state.inventory_instances:
		if item.definition_id != GoodsExpertise.FAN or item.ownership_state != "owned": continue
		if FanConditionService.enabled(day.definition):
			var why := FanConditionService.reason(day, item.instance_id)
			model.inventory.buttons.append({"command": "condition", "target_id": item.instance_id, "detail": "", "label": "检查破损 · 5分钟" if not FanConditionService.checked(item) else "破损已查 · 免费复看", "enabled": why.is_empty(), "reason": why})
		var error := FanConditionService.desk_reason(day, item.instance_id)
		model.inventory.buttons.append({"command": "fan_open", "target_id": item.instance_id, "detail": "", "label": "送上鉴物台 · 辨认真假" if FanConditionService.enabled(day.definition) else "扇画比对 · 查看图录与手记", "enabled": error.is_empty(), "reason": error})

static func comparison(day: DayController, item_id: String) -> Dictionary:
	# Legacy text view retained for compatibility tests. The live desk uses drafts.
	var model := {"title": "扇画比对", "body": "", "reference": {}, "observations": {}, "buttons": [], "verdict": "", "access": FanAppraisalService.access_reason(day, item_id)}
	if not model.access.is_empty():
		model.body = model.access
		return model
	var a := FanAppraisalService.data(day.state)
	var item := FanAppraisalService.target(day, item_id)
	var row := FanAppraisalService.record(day.state, item_id)
	model.body = "先看笔法，再核题款。两处各用10分钟；翻阅与下判断不耗时。\n下判断只记一次，拿不准可以暂放。" + FanAppraisalService.standing_text(day.state)
	var visit := CustomerManager.new().active(day.state)
	if visit != null and visit.item == item and not InventoryManager.new().contains(day.state, item_id):
		model.body += "\n客人等到%s，比对时钟照常推进。" % TimeController.clock_text(day.definition.opening_minute, visit.expires_at)
		var customer := day.state.ghost_catalog.get_definition("customers", visit.customer_id) as CustomerDefinition
		if customer.guest_rule == "no_appraisal": model.body += "\n他将扇子按住：‘不许验货。’"
	else: model.body += "\n这是铺中自有折扇。"
	for key in ["brush", "inscription"]:
		model.reference[key] = FanAppraisalService.REFERENCE[key] if a.manual else "尚未取得扇画图录。可先循旧柜目录寻找。"
		model.observations[key] = FanAppraisalService.OBSERVATIONS[String(item.selected_variant_id)][key] if key in row.get("checks", []) else "尚未展开比对。"
		if key not in row.get("checks", []) and not item.expert_reviewed and String(row.get("verdict", "")).is_empty():
			var error := FanAppraisalService.reason(day, key, item_id)
			model.buttons.append({"command": key, "detail": "", "label": ("比对笔法" if key == "brush" else "比对题款") + " · 10分钟", "enabled": error.is_empty(), "reason": error})
	if item.expert_reviewed:
		model.verdict = GoodsExpertise.description(item, day.state.ghost_catalog.get_definition("items", item.definition_id))
	elif not String(row.get("verdict", "")).is_empty():
		model.verdict = "掌柜自鉴：" + FanAppraisalService.DISPLAY_LABELS[row.verdict] + "。买家仅按这份手记落笔时的鉴定名声酌量认价；尚未判定对错，收货后可请行家复核。"
	else:
		for verdict in ["sound", "mended", "flawed"]:
			var error := FanAppraisalService.reason(day, "verdict", item_id, verdict)
			model.buttons.append({"command": "verdict", "detail": verdict, "label": "判为" + FanAppraisalService.DISPLAY_LABELS[verdict], "enabled": error.is_empty(), "reason": error})
	return model
