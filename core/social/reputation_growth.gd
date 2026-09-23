class_name ReputationGrowth
extends RefCounted

const FEEDBACK := ["传话的人把字号说岔了，街坊误会了一场。", "告示贴出去了，街面上暂时没什么回音。", "有人记住了铺子的字号，顺路来认了门。", "茶摊替铺子传开了话，几条街的人都听说了。", "口信传得顺，几位老街坊也帮着荐了这间铺子。"]

static func advertise(state: RunState) -> void:
	var roll := VarietyService.rng(state.run_seed,"wealthy/advertise/%d" % state.current_night_index).randi_range(-1,3)
	WealthyCustomers.data(state).advertisements.append({"night":state.current_night_index,"roll":roll,"settled":false,"delta":0})

static func settle(state: RunState) -> void:
	if not WealthyCustomers.active(state): return
	for row in WealthyCustomers.data(state).advertisements:
		if row.night != state.current_night_index or row.settled: continue
		var before := int(state.social.reputation)
		var change := int(row.roll)
		if change > 0: change = mini(change,maxi(0,80-before))
		if change != 0: SocialRules.change(state,"reputation",change,"advertising/%d" % row.night)
		row.delta = int(state.social.reputation) - before
		row.settled = true
		SocialRules.notice(state,FEEDBACK[int(row.roll)+1] + " 商誉%+d。" % int(row.delta))

static func acquired(state: RunState, visit: CustomerVisit, outcome: String) -> void:
	if not WealthyCustomers.active(state) or outcome not in ["bought","pawned"]: return
	var id := ("purchase/" if outcome == "bought" else "loan/") + visit.visit_id
	if not state.ledger_entries.any(func(row: Dictionary) -> bool: return row.transaction_id == id and row.amount < 0 and row.item_instance_id == visit.item.instance_id): return
	var history: Array = WealthyCustomers.data(state).transactions
	if id in history: return
	history.append(id)
	if history.size() % 10 != 0: return
	var before := int(state.social.reputation)
	SocialRules.change(state,"reputation",1,"trade_milestone/%d" % history.size())
	WealthyCustomers.data(state).milestones.append({"night":state.current_night_index,"count":history.size(),"delta":int(state.social.reputation)-before})
	SocialRules.notice(state,"又办成十笔收当生意，街坊认门的多了。累计%d笔，商誉%+d。" % [history.size(),int(state.social.reputation)-before])
