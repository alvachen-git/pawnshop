class_name PrecisionPreview
extends RefCounted

# Deliberately constructed debug preview, never a replay-valid production save.
# The launcher isolates APPDATA; this store cannot publish player progress.
static func apply(session: RunSession, level: int, short := "porcelain_vase", variant := "mended", damage := "minor", hidden := true, holder := "") -> void:
	var state := session._day.state
	var id := "item_luxury_"+short
	if short == "silver_set": id = "item_luxury_silver_service"
	if not session.definition.variety.tiered_appraisal.has(id): id = "item_luxury_porcelain_vase"
	var customer_id := ""
	for cid in WealthyCustomers.config(state).profiles:
		var customer := state.ghost_catalog.get_definition("customers",cid) as CustomerDefinition
		if id in customer.item_pool: customer_id = cid; break
	if LuxuryCarry.enabled(session.definition):
		var preferred := "customer_wealthy_"+(holder if not holder.is_empty() else "opera" if short == "pearl_necklace" else "factory" if short == "gold_watch" else "antique")
		if preferred in WealthyCustomers.config(state).profiles: customer_id = preferred
	var customer := state.ghost_catalog.get_definition("customers",customer_id) as CustomerDefinition
	state.phase = &"open"; state.current_night_index = 6; state.game_minutes = 0; state.cash = 2000
	state.pending_event_id = ""; state.social.pending.clear(); state.social.intro_step = -1
	state.visits.clear(); state.pawn_returns.clear()
	# Replacing an isolated preset also replaces its prior evidence and trades.
	state.shop_growth["luxury"] = WealthyCustomers.initial()
	session._negotiation_reactions = NegotiationReactions.new()
	state.shop_growth["knowledge"] = {}
	state.shop_growth.bench = level >= 1; state.shop_growth.appraisal.bench_due = 6 if level >= 2 else 0
	state.shop_growth["precision"] = {"due":6 if level >= 3 else 0,"kits":TieredAppraisal.KITS.keys() if level >= 3 else ["display","metal","clock","jewel"] if level == 2 else []}
	state.shop_growth.appraisal.tools = level >= 2
	if level >= 2:
		state.shop_growth["knowledge"] = {}
		for topic in ShopKnowledgeService.TOPICS: state.shop_growth.knowledge[topic] = {"night":2}
	var visit := CustomerVisit.new()
	visit.visit_id = "precision-preview/6/customer"; visit.customer_id = customer_id; visit.status = "active"; visit.arrival = 0; visit.expires_at = customer.terms.wait_minutes
	if WealthyCustomers.fixed_people(session.definition): visit.person = WealthyCustomers.person(customer)
	visit.item = ItemInstance.new(); visit.item.instance_id = "item/"+visit.visit_id; visit.item.definition_id = id
	visit.item.selected_variant_id = variant if variant in ["sound","mended","flawed"] else "mended"
	visit.item.goods["precision"] = {"damage":damage if damage in TieredAppraisal.RETAIN else "minor","hidden":hidden}
	visit.transaction_modes.assign(["pawn"]); visit.voice = customer.persona; visit.pawn_terms_id = "sample_three_redeem"
	visit.trade.patience = customer.patience; visit.trade.rounds_left = customer.max_quote_rounds
	state.visits.append(visit); state.ordinary_selections.append({"visit_id":visit.visit_id,"context_id":"precision/preview"})
	WealthyCustomers.prepare(state,visit)
	var store := GhostReplayStore.new(); store.origin = state.ghost_origin.duplicate(true)
	session._save = store
	session.message = "鉴定测试预置 · 本次进度不保存"

static func from_arguments(session: RunSession) -> bool:
	if not OS.is_debug_build() or not TieredAppraisal.enabled(session.definition): return false
	var args := {}
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--precision-"): args[argument.get_slice("=",0)] = argument.get_slice("=",1)
	if not args.has("--precision-preview"): return false
	var level: int = {"basic":0,"standard":2,"deep":3}.get(args["--precision-preview"],0)
	apply(session,level,args.get("--precision-item","porcelain_vase"),args.get("--precision-condition","mended"),args.get("--precision-damage","minor"),args.get("--precision-difficulty","hidden") == "hidden",args.get("--precision-holder",""))
	if WatchEconomy.enabled(session.definition) and args.has("--precision-watch-case"): watch_case(session,args["--precision-watch-case"])
	if PearlEconomy.enabled(session.definition) and args.has("--precision-pearl-case"): PearlPreview.apply(session,args["--precision-pearl-case"])
	if BangleEconomy.enabled(session.definition) and args.has("--precision-bangle-case"): BanglePreview.apply(session,args["--precision-bangle-case"])
	return true

static func watch_case(session: RunSession, scenario: String) -> void:
	if scenario == "natural": return
	var state := session._day.state
	var visit := state.visits[0] as CustomerVisit
	if not WatchEconomy.handles(state,visit.item): return
	if scenario == "guide":
		state.phase = &"pre_open"; state.current_night_index = 2
		state.visits.clear(); state.shop_growth.knowledge.clear()
		return
	visit.item.selected_variant_id = "flawed" if scenario in ["overpriced","engraving","gears"] else "sound"
	if WatchMovementPatterns.enabled(session.definition) and scenario in ["engraving","gears"]:
		visit.item.goods.watch_value["pattern"] = "lettering" if scenario == "engraving" else "gears"
	visit.item.goods.precision.damage = "intact"
	var operation := "positional" if scenario in ["fault","firm","partial"] else "stable"
	visit.item.goods.watch_value.operation = operation
	visit.item.goods.watch_value.actual = WatchEconomy.valuation(visit.item.selected_variant_id,"intact",operation)
	visit.transaction_modes.assign(["sell"])
	var row := WealthyCustomers.trade(state,visit); row.funding = 0
	var o: Dictionary = row.watch_owner
	o.skill = "novice"; o.belief = "flawed" if scenario == "bargain" else "sound"; o.rate = 100; o.urgent = scenario == "urgent"
	o.bluff_roll = 0 if scenario == "spotted" else 99
	WatchEconomy.reprice(state,visit,true); visit.trade.opening_price = visit.trade.asking_price
	if WatchNegotiation.enabled(session.definition):
		WatchNegotiation.prepare(state,visit)
		var negotiation := WatchNegotiation.data(state,visit)
		negotiation.personality = "firm" if scenario == "firm" else "careful" if scenario == "partial" else "easy"
		for part in WatchNegotiation.PARTS: negotiation.rolls[part] = 99 if scenario in ["spotted","exposed"] else 0
	visit.voice.introduction = "我只当普通旧表使，您给些现钱就成。" if scenario == "bargain" else "眼下急等钱用，现付就好谈。" if scenario == "urgent" else "这块名表，请您掌眼。"
