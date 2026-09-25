class_name SocialReadModels
extends RefCounted

static func notice(state: RunState) -> String:
	if not state.social_enabled: return ""
	var p: Dictionary = state.social.pending
	if not p.is_empty():
		return "\n" + {"fee": "门口有人来收街面照应钱，请翻开柜台上的《往来簿》。", "closure": "停业令已送到，开门前须作处置。", "supply": "经办人带来货单，开门前可选货或谢绝。", "claim": "旧货主找上门来，请先翻看柜台上的《往来簿》。"}.get(p.kind, "有一份军方口信待看。")
	var lines := ""
	for row in state.social.notices:
		if row.night == state.current_night_index and row.text != MilitaryService.INTRODUCTION: lines = "\n" + ReputationFeedback.notice(String(row.text))
	return lines

static func button(model: Dictionary, day: DayController, command: String, label: String, detail := "") -> void:
	var error := MilitaryService.reason(day, command, detail)
	model.buttons.append({"command": command, "detail": detail, "label": label, "enabled": error.is_empty(), "reason": error})

static func page(day: DayController, section := 0) -> Dictionary:
	var model := {"body": "还没有经办人来过。", "buttons": []}
	var state := day.state
	if not state.social_enabled or not state.social.introduced: return model
	var social: Dictionary = state.social
	if section == 1:
		model.body = faction_history(state, "military")
		return model
	model.body = ""
	if SocialRules.closed(state): model.body += "\n\n今夜停接新生意；原当户可照票赎回。息费照付，受阻预约已顺延。"
	var p: Dictionary = social.pending
	if not p.is_empty():
		model.body = "今夜来信"
		match p.kind:
			"fee":
				model.body += "\n\n来人把空钱袋放在柜上，要收%d银元‘照应街面’。孙大元说这回得给个答复。" % int(p.cost)
				button(model, day, "pay", "交清%d银元" % int(p.cost))
				button(model, day, "refuse", "推回钱袋，说明不交")
			"closure":
				model.body += "\n\n停业令只管今夜。经办人说，付%d银元可办撤令。若不撤令，今夜只守铺办旧票。" % int(p.cost)
				button(model, day, "pay", "付%d银元，办理撤令" % int(p.cost))
				button(model, day, "close", "收下停业令，今夜守铺")
			"supply":
				model.body += "\n\n经办人先把货单送来。只能约其中一件；验过货再谈收不收，不必先交定钱。"
				for row in p.offers:
					model.body += "\n\n%s · 要价%d银元\n%s" % [row.title, int(row.price), row.cue]
					button(model, day, "select_supply", "约看" + row.title, row.id)
				button(model, day, "decline_supply", "谢过介绍，这回不收")
			"claim":
				var claim := MilitaryService.claim_for(state, p.id)
				var supply := MilitaryService.supply_for(state, p.id)
				model.body += "\n\n旧货主拿着原存单来了，指名要找%s。门口已有街坊停下来听。经办人也承认，当初没有取得他的出让字据。\n\n可协调退还原物、取回原货款；或付%d银元与旧主和解；也可托军方出面。" % [supply.title, ceili(float(claim.price) / 2)]
				button(model, day, "claim_return", "协调退还原物，取回货款")
				button(model, day, "claim_compensate", "付%d银元，与旧主和解" % ceili(float(claim.price) / 2))
				button(model, day, "claim_military", "请经办人出面处理")
				button(model, day, "claim_later", "说明暂时无力处理" if claim.postponed else "约旧主明夜再谈")
		return model
	var order: Dictionary = social.contract
	model.body += "\n\n采购棉袄 · 自有棉袄%d／3\n三件一并交货，完成奖励50银元，期限不限。" % CoatProcurement.stock(state).size()
	if order.is_empty(): button(model, day, "accept_contract", "接下采购单")
	else: button(model, day, "cancel_contract", "退回已经接下的采购单")
	button(model, day, "gift", "托人送礼 · 20银元 / 1行动点")
	model.body += "\n\n托人送礼：20银元，占1行动点，须在开铺前办理；送到后隔两夜再递。"
	var visit := CustomerManager.new().active(state)
	if visit != null:
		var supply := MilitaryService.supply_for(state, visit.visit_id)
		if not supply.is_empty():
			model.body += "\n\n柜前货物：%s\n%s\n实物可去鉴定页检查；核查来源需2银元、10分钟，客人仍会等待。" % [supply.title, supply.cue]
			if supply.investigated: model.body += "\n\n已查明：" + supply.report
			else: button(model, day, "check_supply", "托人核查这件货的来源 · 2银元 / 10分钟", visit.visit_id)
	return model

static func faction_history(state: RunState, faction_id: String) -> String:
	var lines: Array[String] = []
	for row in state.social.get("notices", []):
		if not faction_id.is_empty() and row.get("faction_id", "") == faction_id:
			lines.append("第%d夜\n%s" % [row.night, ReputationFeedback.notice(String(row.text))])
	return "\n\n".join(lines) if not lines.is_empty() else "尚无往来可记。"
