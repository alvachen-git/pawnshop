class_name FactionBookModels
extends RefCounted

# The roster and selection use stable faction IDs; each faction owns its rules.
# Undiscovered factions never expose names, actions, or their hidden scores.
static func roster(state: RunState) -> Array:
	var result: Array = []
	if not state.social_enabled: return result
	var definitions: Array = JSON.parse_string(FileAccess.get_file_as_string("res://data/social_relations/factions.json"))
	for entry in definitions:
		if entry.id == "military" and state.social.introduced: result.append(entry)
	return result

static func attitude(state: RunState, faction: String) -> String:
	if faction != "military": return "尚无来往"
	var score := int(state.social.military)
	if score <= -80: return "话里已不留情面"
	if score <= -50: return "来往间处处为难"
	if score <= -20: return "言语渐冷，须多留心"
	if score < 20: return "照规矩往来"
	if score < 50: return "愿意给几分照应"
	if score < 80: return "有好货会先递口信"
	return "交情深了，也有事相托"

static func page(day: DayController, faction: String, section: int) -> Dictionary:
	var model := {"title":"", "body":"尚无往来可记。", "fields":[], "buttons":[]}
	if faction != "military" or not day.state.social_enabled or not day.state.social.introduced: return model
	var state := day.state
	var social: Dictionary = state.social
	if section == 2:
		model.title = "往来旧事"
		model.body = SocialReadModels.faction_history(state, faction)
		return model
	var pending: Dictionary = social.pending
	if not pending.is_empty() and section == pending_section(state):
		var letter := SocialReadModels.page(day, 0)
		model.title = {"fee":"街面照应钱", "closure":"今夜停业令", "supply":"货源来信", "claim":"旧主追索"}.get(pending.kind, "今夜来信")
		model.body = String(letter.body).trim_prefix("今夜来信").strip_edges()
		model.buttons = letter.buttons
		return model
	if section == 1:
		var rules := SocialRules.config()
		model.title = "托人送礼"
		model.body = "托人递一份薄礼，往后有事好说话。"
		model.fields = [["花费", "%d银元" % int(rules.gift_cost)], ["准备", "1次，须在开铺前办理"], ["间隔", "送到后须隔两夜再递"]]
		if social.plaque_awarded: model.body += "\n已获军方照应牌，挂在铺中；普通收购与活当可借牌压价一成，每客一次，但会损伤口碑。"
		SocialReadModels.button(model, day, "gift", "托人送礼")
		var reason := MilitaryService.reason(day, "gift")
		if not reason.is_empty(): model.body += "\n" + reason
		return model
	if not pending.is_empty():
		model.title = "另有来信待办"
		model.body = "孙大元这回的来意，记在“打点”页。先把眼前的事说清，再谈采购。"
		model.buttons = [{"command":"book_section", "detail":"1", "label":"翻到打点", "enabled":true, "reason":""}]
		return model
	var visit := CustomerManager.new().active(state)
	if visit != null:
		var supply := MilitaryService.supply_for(state, visit.visit_id)
		if not supply.is_empty():
			model.title = supply.title
			model.body = supply.cue + "\n\n实物可去鉴定页检查。"
			if supply.investigated: model.body += "\n\n已查明：" + supply.report
			else:
				model.fields = [["核查", "2银元 · 10分钟，客人仍会等待"]]
				SocialReadModels.button(model, day, "check_supply", "核查来源", visit.visit_id)
			return model
	var offered: bool = social.contract.is_empty()
	model.title = "采购棉袄" + ("" if offered else " · 已接")
	var stocks := CoatProcurement.stock(state)
	model.body = "" if offered or stocks.size() >= 3 else "还缺%d件自有棉袄；在当物不能交货。" % (3 - stocks.size())
	model.fields = [["货物", "棉袄 ×3 · 自有棉袄%d／3" % stocks.size()], ["要求", "自有现货，三件一并交付"], ["期限", "不限"], ["奖励", "50银元"]]
	if SocialRules.closed(state): model.body = "今夜停接新生意，暂不交货。采购单继续保留。"
	if offered:
		SocialReadModels.button(model, day, "accept_contract", "接下采购单")
		SocialReadModels.button(model, day, "decline_contract", "暂不接单")
	else:
		model.fields = [["交货", "自有棉袄%d／3 · 三件一并交付" % stocks.size()], ["奖励", "50银元 · 期限不限"]]
		model["stock"] = stocks.map(func(item: ItemInstance) -> Dictionary: return {"id":item.instance_id, "label":"货签%d · 棉袄 · 成本%d银元" % [state.inventory_instances.find(item) + 1, item.acquisition_price]})
		SocialReadModels.button(model, day, "deliver", "交付所选三件棉袄", "[]")
		SocialReadModels.button(model, day, "cancel_contract", "退回已经接下的采购单")
	return model

static func pending_section(state: RunState) -> int:
	return 0 if state.social.pending.get("kind", "") in ["", "supply"] else 1

static func perform(session: RunSession, faction: String, command: String, detail: String) -> void:
	if faction == "military": session.social_command(command, detail)
