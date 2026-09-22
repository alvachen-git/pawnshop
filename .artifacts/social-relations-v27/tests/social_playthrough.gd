extends "res://tests/social_relations.gd"

func run() -> void:
	if not setup(): quit(1); return
	traffic()
	for policy in ["cheap", "generous", "gifts", "refuse", "cautious"]: play_ten(policy)
	print("SOCIAL PLAYTHROUGH: %d passes, %d failures" % [passes, failures])
	quit(0 if failures == 0 else 1)

func finish_night(s: RunSession) -> void:
	driver.drain(s)
	if s._day.state.phase == &"open": act(s, "close_shop")
	if s._day.state.phase == &"closed_processing": act(s, "wait_until_seal")
	for ticket in s.pawn_disposal_model(): s.choose_pawn_disposal(ticket.id, "keep")
	act(s, "resolve_night")
	if s._day.state.phase in [&"dead", &"bankrupt"]: return
	act(s, "enter_room"); driver.drain(s)
	act(s, "sleep"); driver.drain(s)
	act(s, "finish_sleep")
	if s._day.state.phase not in [&"dead", &"bankrupt"]: act(s, "continue_run")

func traffic() -> void:
	var sizes: Array = []
	for id in [SocialRules.RUN, "social_preview_respected", "social_preview_disliked"]:
		run_def = catalog.get_definition("runs", id)
		var s := second_night()
		var rows := s._day.state.visits.filter(func(v: CustomerVisit) -> bool: return ReputationService.eligible(s._day.state, v))
		sizes.append(rows.size())
		var snap := SocialRules.night(s._day.state).duplicate(true)
		var identities: Array = s._day.state.visits.map(func(v: CustomerVisit) -> String: return v.visit_id)
		for i in 5:
			s.counter_model(); SocialReadModels.page(s._day); OpeningPreparation.plan(s._day.state, run_def, catalog)
		check(SocialRules.night(s._day.state) == snap, "read-only stable snapshot")
		check(s.execute("prep_attract").ok, "player extra customer")
		check(s._day.state.visits.size() == identities.size() + 1, "extra customer stacks")
		var count: int = s._day.state.visits.size()
		SocialRules.change(s._day.state, "reputation", 100, "boundary-only fixture")
		OpeningPreparation.refresh_visits(s._day.state, run_def, catalog)
		check(s._day.state.visits.size() == count and SocialRules.night(s._day.state) == snap, "current night locked even after reputation change")
	check(sizes[1] == sizes[0] + 2 and sizes[2] == maxi(2, sizes[0] - 2), "high/neutral/low real traffic")
	run_def = catalog.get_definition("runs", SocialRules.RUN)

func pending(s: RunSession, policy: String) -> void:
	driver.drain(s)
	var p: Dictionary = s._day.state.social.pending
	if p.is_empty(): return
	match p.kind:
		"fee": check(s.social_command("refuse" if policy == "refuse" or s._day.state.cash < int(p.cost) else "pay").ok, "fee choice")
		"closure": check(s.social_command("close").ok, "accept suspended night")
		"supply": check(s.social_command("select_supply", p.offers[0].id).ok, "supply selection")
		"claim": check(s.social_command("claim_military" if int(s._day.state.social.military) >= 20 else "claim_later").ok, "claim resolution")

func liquidate(s: RunSession) -> void:
	if SocialRules.closed(s._day.state): return
	var best := ""
	var best_ids: Array = []
	var best_total := 0
	for buyer_id in s.definition.buyer_ids:
		var buyer := catalog.get_definition("buyers", buyer_id) as BuyerDefinition
		if not s._commerce.trip_reason(s._day, buyer).is_empty(): continue
		var ids: Array = []
		var total := 0
		for item in s._day.state.inventory_instances:
			if s._commerce.item_reason(s._day, item, buyer).is_empty():
				ids.append(item.instance_id); total += s._commerce.quote(item,buyer)
		if total > best_total: best = buyer_id; best_total = total; best_ids = ids
	if not best_ids.is_empty(): check(s.sell_batch(best,best_ids).ok, "liquidate real stock")

func work_day(s: RunSession, policy: String) -> void:
	for step in 180:
		driver.drain(s)
		if s._day.state.phase != &"open" or s._day.state.game_minutes >= 510: return
		var returning := PawnReturnService.current(s._day.state)
		if not returning.is_empty():
			check(s.counter_command("redeem", returning.id).ok, "redeem remains available")
			continue
		var v := s._counter.customers.active(s._day.state)
		if v == null:
			liquidate(s)
			if not s.bell_command("wait").ok: s.execute("short_task")
			continue
		var customer := catalog.get_definition("customers", v.customer_id) as CustomerDefinition
		if customer.guest_rule == "swap": s.counter_command("swap_reject",v.visit_id); continue
		if v.purpose == "display_buyer": s.counter_command("reject", v.visit_id); continue
		if v.purpose == "husband_meeting": s.counter_command("meeting_end", v.visit_id); continue
		if v.night_policy != "" or customer.guest_rule != "" or v.item.definition_id == "item_weeping_mirror":
			s.counter_command("reject", v.visit_id); continue
		if policy == "cautious": s.counter_command("reject",v.visit_id); continue
		var mode := "offer" if "sell" in v.transaction_modes else "pawn"
		var ratio := 1.0
		if mode == "pawn": ratio = (catalog.get_definition("pawn_terms", VarietyService.terms_for(v, customer)) as PawnTermsDefinition).loan_ratio
		var price := maxi(1, roundi(v.trade.reserve_price * ratio))
		if policy == "generous": price = ceili(v.trade.opening_price * ratio * 1.2)
		if s._day.state.cash - price < 30: s.counter_command("reject", v.visit_id); continue
		var result := s.counter_command(mode, v.visit_id, "", price)
		check(result.ok, "real quote " + policy + " " + result.message)
		if s._counter.customers.active(s._day.state) == v: s.counter_command("reject", v.visit_id)
	check(false, "night loop terminates")

func play_ten(policy: String) -> void:
	run_def = catalog.get_definition("runs", "social_preview_hostile" if policy == "refuse" else SocialRules.RUN)
	var s := fresh_growth(42)
	var report: Array = []
	for night in range(1,11):
		pending(s, policy)
		if policy == "gifts" and MilitaryService.reason(s._day, "gift").is_empty(): check(s.social_command("gift").ok, "gift policy")
		if policy in ["cheap", "gifts"] and MilitaryService.reason(s._day, "accept_contract").is_empty(): s.social_command("accept_contract")
		if not s._day.state.social.contract.is_empty():
			for item in s._day.state.inventory_instances.duplicate():
				if MilitaryService.reason(s._day, "deliver", item.instance_id).is_empty(): s.social_command("deliver", item.instance_id); break
		act(s, "open_shop")
		work_day(s, policy)
		var row := {"night":night,"cash":s._day.state.cash,"reputation":s._day.state.social.reputation,"military":s._day.state.social.military,"visitors":s._day.state.visits.size(),"closed":SocialRules.closed(s._day.state),"sales":s._day.state.sale_records.size(),"inventory":s._day.state.inventory_instances.filter(func(i: ItemInstance) -> bool: return i.ownership_state == "owned").size()}
		report.append(row)
		finish_night(s)
		verify(s, "%s night %d" % [policy,night])
		if s._day.state.phase in [&"dead", &"bankrupt"]: break
	check(s._day.state.phase in [&"run_ended", &"bankrupt"], "resolved business outcome " + policy)
	if policy == "cautious": check(s._day.state.phase == &"run_ended" and s._day.state.summaries.size() == 10, "complete ten-night lifecycle")
	DirAccess.make_dir_recursive_absolute("res://.godot/qa/social-relations")
	var file := FileAccess.open("res://.godot/qa/social-relations/economy-" + policy + ".json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"  "))
	print("ECONOMY ", policy, " ", JSON.stringify(report))
