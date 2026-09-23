class_name OldShopReadModel
extends RefCounted

# An album of objects already retained, not another source of story state.
static func build(day: DayController, events: EventDirector, counter: CounterService) -> Dictionary:
	if not FirstDebt.enabled(day.definition): return {}
	var s := day.state
	var result := {"documents": [], "actions": [], "outcome": ""}
	var modern := FirstDebt.revised(s)
	var debt := FirstDebt.model(day, events, counter)
	if FirstDebt.flag(s, "aq_ticket_seen"):
		var read := FirstDebt.flag(s, "fd_ticket_read")
		result.documents.append({"id": "fd_ticket", "title": "瑞字四十七", "subtitle": "陈阿福 · 龙凤金镯一对", "category": 0, "read": read, "text": _text(s, events, "fd_ticket") if read else "", "observe_id": "fd_ticket"})
	for doc in debt.documents:
		if doc.id == "fd_ticket": continue
		var row: Dictionary = doc.duplicate()
		row.merge({"category": 2 if doc.id == "fd_mark" else 1, "read": true, "observe_id": "", "subtitle": "瑞字四十七" if doc.id in ["fd_receipt", "fd_family"] else ""})
		result.documents.append(row)
	for entry in [["aq_drawer", "旧《阴账》", "ledger"], ["aq_floorplan", "旧铺草图", "plan"], ["wm_ticket", "铜镜旧当票", "mirror_ticket"]]:
		if FirstDebt.last(s, entry[0]).is_empty(): continue
		if entry[0] == "aq_floorplan" and not FirstDebt.flag(s, "aq_plan_seen"): continue
		var body := _text(s, events, entry[0])
		if entry[0] == "aq_drawer": body = "旧《阴账》上写着：尚欠七账。没有金额，也没有收讫印记。"
		result.documents.append({"id": entry[2], "title": entry[1], "subtitle": "", "category": 0 if entry[0] == "wm_ticket" else 2, "read": true, "observe_id": "", "text": body})
	for action in debt.buttons:
		if action.target_id in ["fd_spending", "fd_chen_request", "fd_seller"]: result.actions.append(action)
	if modern:
		for document in result.documents:
			if document.id == "fd_ticket":
				document.title = "铺内存根 · 瑞字四十七"
				document.subtitle = "铺内留存 · 陈阿福"
				document.art = "res://assets/first_debt_v29/shop_stub.png"
			if document.id == "fd_family":
				document.title = "陈阿福的旧记"
				document.subtitle = "陈家私记 · 讨赎经历"
				document.art = "res://assets/first_debt_v29/family_notes.png"
			if document.id == "fd_customer_ticket":
				document.category = 0
				document.subtitle = "原件陈家持有 · 此处留抄录"
				document.art = "res://assets/first_debt_v29/customer_ticket.png"
			if document.id == "fd_protection": document.art = "res://assets/first_debt_v29/protection.png"
			if document.id == "fd_spending": document.art = "res://assets/first_debt_v29/spending.png"
			if document.id == "ledger":
				if FirstDebt.flag(s, "fd_yin_link_read"):
					document.art = "res://assets/first_debt_v29/yin_page.png"
					document.text = _text(s, events, "fd_yin_link")
					if FirstDebt.flag(s, "fd_yin_echo_seen"):
						document.ink = "清" if FirstDebt.flag(s, "fd_clear") else "和"
						document.text = FirstDebt.response(s, "fd_yin_echo", _text(s, events, "fd_yin_echo")) + "\n\n" + document.text.replace("末尾留着一道空白。", "末尾曾留着一道空白。")
					elif FirstDebt.settled(s): document.read = false; document.observe_id = "fd_yin_echo"
				elif FirstDebt.flag(s, "fd_spending_read"): document.read = false; document.observe_id = "fd_yin_link"
		# A retained original is visible before it has been deliberately read.
		if FirstDebt.flag(s, "fd_family_read") and not FirstDebt.flag(s, "fd_customer_ticket_read"):
			result.documents.append({"id": "fd_customer_ticket", "title": "陈家原票 · 瑞字四十七", "subtitle": "原件陈家持有 · 此处留抄录", "category": 0, "read": false, "observe_id": "fd_customer_ticket", "text": "", "art": "res://assets/first_debt_v29/customer_ticket.png"})
		result.documents = result.documents.filter(func(d: Dictionary) -> bool: return d.id != "fd_yin_link")
		for action in debt.buttons:
			if action.target_id == "fd_protection": result.actions.append(action)
	if DragonSearch.enabled(s) and not DragonSearch.notice(s).is_empty():
		result.documents.append({"id": "dragon_notice", "title": "龙镯口信", "subtitle": "托话记事", "category": 1, "read": true, "observe_id": "", "text": DragonSearch.notice(s)})
	result.outcome = debt.outcome if FirstDebt.settled(s) else ""
	return result

static func _text(s: RunState, events: EventDirector, id: String) -> String:
	var history := FirstDebt.last(s, id)
	if history.is_empty(): return ""
	var event := events.catalog.get_definition("events", id) as EventDefinition
	return event.find_choice(history.choice_id).result if event != null else ""
