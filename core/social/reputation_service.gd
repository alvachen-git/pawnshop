class_name ReputationService
extends RefCounted

static func eligible(state: RunState, visit: CustomerVisit) -> bool:
	if not state.social_enabled or not visit.purpose.is_empty() or not visit.night_policy.is_empty(): return false
	if visit.person.get("id", "").begins_with("familiar/"): return false
	for row in state.ordinary_selections:
		if row.visit_id == visit.visit_id:
			return OpeningPreparation.ordinary(row) and not row.get("familiar_reserved", false) and not row.get("early_redemption", false)
	return false

static func basis(state: RunState, visit: CustomerVisit) -> int:
	if WealthyCustomers.active(state) and WealthyCustomers.is_customer(visit.customer_id): return int(WealthyCustomers.trade(state, visit).reference)
	var price := maxi(1, visit.trade.opening_price - visit.trade.social_flaw_discount)
	if visit.trade.social_offer_mode == "pawn":
		var customer := state.ghost_catalog.get_definition("customers", visit.customer_id) as CustomerDefinition
		var terms := state.ghost_catalog.get_definition("pawn_terms", VarietyService.terms_for(visit, customer)) as PawnTermsDefinition
		price = maxi(1, roundi(price * terms.loan_ratio))
	return price

static func delta(price: int, base: int, outcome: String) -> int:
	var c: Dictionary = SocialRules.config().reputation
	if outcome in ["bought", "pawned"]:
		if price * 100 >= base * int(c.high_percent): return int(c.high_delta)
		if price * 100 <= base * int(c.low_percent): return int(c.low_delta)
	elif outcome in ["patience_exhausted", "rounds_exhausted", "rejected"] and price > 0 and price * 100 <= base * int(c.failed_percent): return int(c.failed_delta)
	return 0

static func finish(state: RunState, visit: CustomerVisit, outcome: String) -> void:
	if not eligible(state, visit) or visit.trade.offers.is_empty(): return
	if state.social.trades.any(func(row: Dictionary) -> bool: return row.visit_id == visit.visit_id): return
	var price: int = visit.trade.offers.back()
	var base := basis(state, visit)
	var change := delta(price, base, outcome)
	if (WatchEconomy.handles(state,visit.item) or PearlEconomy.handles(state,visit.item) or BangleEconomy.handles(state,visit.item)) and change < 0: change = 0
	# A later inspection/pressure action ending a conversation is not a rejected quote.
	if outcome in ["patience_exhausted", "rounds_exhausted"] and not visit.trade.social_last_was_quote: change = 0
	var positive := 0
	var negative := 0
	for row in state.social.trades:
		if row.night == state.current_night_index:
			positive += maxi(0, int(row.delta)); negative += maxi(0, -int(row.delta))
	var config: Dictionary = SocialRules.config().reputation
	if change > 0: change = mini(change, maxi(0, int(config.positive_cap) - positive))
	if change < 0: change = -mini(-change, maxi(0, int(config.negative_cap) - negative))
	state.social.trades.append({"visit_id": visit.visit_id, "night": state.current_night_index, "opening": visit.trade.opening_price, "flaw_discount": visit.trade.social_flaw_discount, "basis": base, "price": price, "mode": visit.trade.social_offer_mode, "outcome": outcome, "delta": change})
	if change != 0: SocialRules.change(state, "reputation", change, visit.visit_id)
	if outcome in ["bought", "pawned"] and price * 100 >= base * int(config.high_percent):
		visit.voice.completed = "他把银元数了两遍：‘比我想的还厚道，回去得跟街坊念叨一句。’"
		SocialRules.notice(state, "%s临走留下话：‘这回给的钱厚道，回去得跟街坊念叨一句。’" % visit.person.get("name", "来客"))
	elif change < 0:
		SocialRules.notice(state, "%s临走留下话：‘您这价压得紧，我得劝熟人多问几家。’" % visit.person.get("name", "来客"))

static func adjustment(value: int) -> int:
	if value <= -50: return -2
	if value <= -20: return -1
	if value >= 50: return 2
	if value >= 20: return 1
	return 0

static func ordinary(row: Dictionary) -> bool:
	return OpeningPreparation.ordinary(row) and not row.get("familiar_reserved", false) and not row.get("early_redemption", false)

static func overlay(state: RunState, run: RunDefinition, catalog: ContentCatalog, rows: Array[Dictionary]) -> Array[Dictionary]:
	if not state.social_enabled: return rows
	var snapshot := SocialRules.night(state)
	if snapshot.is_empty():
		snapshot = {"night": state.current_night_index, "reputation": state.social.reputation, "adjustment": adjustment(state.social.reputation), "removed": [], "added": [], "closed": false, "military_checked": false}
		var pool := rows.filter(func(row: Dictionary) -> bool: return row.night == state.current_night_index and ordinary(row))
		var count := mini(-int(snapshot.adjustment), maxi(0, pool.size() - 2))
		for i in maxi(0, count):
			var picked: Dictionary = VarietyService.pick(pool, state.run_seed, "social/remove/%d/%d" % [state.current_night_index, i])
			snapshot.removed.append(picked.visit_id); pool.erase(picked)
		for i in maxi(0, int(snapshot.adjustment)):
			var id := "%s/%d/reputation_%d" % [run.id, state.current_night_index, i]
			var row := OpeningPreparation.make_row(state, run, catalog, id, 75 + i * 210, "", rows + snapshot.added)
			if not row.is_empty():
				row.person.name = "街坊介绍的" + row.person.name
				snapshot.added.append(row)
		state.social.nights.append(snapshot)
		if int(snapshot.adjustment) > 0: SocialRules.notice(state, "茶摊的刘婶捎话：‘有人夸你给钱厚道，又领了街坊来认门。今夜怕要多照看几位。’")
		elif int(snapshot.adjustment) < 0: SocialRules.notice(state, "茶摊的刘婶捎话：‘街坊里有人嫌你压价紧，这两天带东西来问的人少了。掌柜不妨留心些。’")
	var result: Array[Dictionary] = []
	for row in rows:
		if row.visit_id not in snapshot.removed: result.append(row)
	for row in snapshot.added: result.append(row.duplicate(true))
	for row in state.social.deferred_visits:
		if row.night == state.current_night_index: result.append(row.duplicate(true))
	return result
