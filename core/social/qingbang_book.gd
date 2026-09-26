class_name QingbangBook
extends RefCounted

static func button(model: Dictionary, day: DayController, command: String, label: String, detail := "") -> void:
	var error := QingbangService.reason(day,command,detail)
	model.buttons.append({"command":command,"detail":detail,"label":label,"enabled":error.is_empty(),"reason":error})

static func page(day: DayController, section: int) -> Dictionary:
	var state := day.state
	var q: Dictionary = state.social.qingbang
	var model := {"title":"","body":"","fields":[],"buttons":[]}
	if section == 2:
		model.title = "青帮旧事"
		model.body = SocialReadModels.faction_history(state,"qingbang")
		return model
	if section == 1:
		model.title = "托人打听来路"
		model.body = "每件10银元，下一夜回话。一次托问一件；只问出处，不替掌柜断真假。"
		for row in q.inquiries:
			model.body += "\n\n%s · %s" % [row.title,{"waiting":"第%d夜回话" % int(row.due),"delivered":"回话已送到","read":"已拆阅"}[row.status]]
			if row.status == "delivered": button(model,day,"read_inquiry","拆阅 · " + row.title,row.id)
			if row.status == "read": model.body += "\n" + row.report
		for item in state.inventory_instances:
			if QingbangSupplies.reason(day,"inquire",item.instance_id).is_empty():
				var definition := state.ghost_catalog.get_definition("items",item.definition_id) as ItemDefinition
				button(model,day,"inquire","打听 · " + definition.display_name,item.instance_id)
		return model
	model.title = "街面往来"
	model.fields = [["下回收费","第%d夜 · 每隔8天一回" % int(q.next_fee)]]
	var p: Dictionary = q.pending
	match p.get("kind",""):
		"fee":
			model.body = "沈伯钧正在柜前等你回话。请合上簿子，与他当面交谈。"
		"supply":
			model.title = p.offer.title
			model.body = p.offer.cue
			model.fields.push_front(["要价","%d银元" % int(p.offer.price)])
			button(model,day,"select_supply","约带货人登门",p.id)
			button(model,day,"decline_supply","谢绝这份货单",p.id)
		"claim":
			var source := QingbangSupplies.find(state,p.id)
			model.title = "旧主追索 · " + source.title
			model.body = "旧货主拿出凭据，指出从未同意出让。街坊已围在门口。可退原物取回货款，或出钱和解，也可请沈伯钧出面。"
			button(model,day,"claim_return","退还原物，取回货款",p.id)
			button(model,day,"claim_compensate","付%d银元和解" % ceili(float(source.paid)/2),p.id)
			button(model,day,"claim_intervene","请沈伯钧出面",p.id)
			button(model,day,"claim_later","约明夜再谈" if not QingbangSupplies.claim_for(state,p.id).postponed else "说明仍无力处置",p.id)
		_:
			model.body = "沈伯钧经手这条街的照应钱，也介绍旧货、托人打听出处。"
	var visit := CustomerManager.new().active(state)
	if visit != null:
		var source := QingbangSupplies.find(state,visit.visit_id)
		if not source.is_empty():
			model.body += "\n\n柜前：" + source.title + "\n" + source.cue
			if source.investigated: model.body += "\n已核查：" + source.report
			else: button(model,day,"check_supply","核查柜前货源 · 2银元 / 10分钟",visit.visit_id)
	if p.is_empty(): model.body += "\n备礼赔话须在开铺前办理，送到后隔两夜再递。"
	button(model,day,"gift","备礼赔话 · 20银元 / 1行动点")
	return model
