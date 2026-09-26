class_name SpecialGuestsPreview
extends RefCounted

# Isolated QA fixture; never writes a player save or claims replay validity.
static func apply(session: RunSession, kind := "one_quote", item_id := CameraEconomy.ITEM, variant := "sound") -> CustomerVisit:
	PrecisionPreview.apply(session, 3, "camera", "sound", "intact", false)
	var state := session._day.state
	state.current_night_index = 6
	state.phase = &"open"
	state.game_minutes = 0
	state.cash = 6000
	state.pending_event_id = ""; state.risk_pending = ""
	state.social.pending.clear(); state.social.intro_step = -1
	state.ordinary_selections.clear(); state.visits.clear(); state.pawn_returns.clear()
	state.inventory_instances.clear()
	state.shop_growth["special_guests"] = SpecialGuests.initial()
	state.shop_growth.precision.kits.assign(TieredAppraisal.KITS.keys())
	var old := {"visit_id":"special-preview/6/customer", "night":6, "arrival":0}
	var row := SpecialGuests.make_row(state, state.ghost_catalog, old, "wet" if kind == "wet_cloth" else "closed/0" if kind == "closed" else "hat/1", kind)
	if SpecialGuests.timed(state):
		row.arrival = int(SpecialGuests.window(state, kind)[0])
		state.game_minutes = row.arrival
	if kind != "closed": row.item_id = item_id
	var item := state.ghost_catalog.get_definition("items",row.item_id) as ItemDefinition
	row.variant_id = variant if item.find_variant(variant) != null else item.possible_variants[0].id
	var rows := [row]
	GoodsExpertise.attach(rows,session.definition,state.run_seed)
	state.ordinary_selections.append(row)
	var customer := state.ghost_catalog.get_definition("customers",row.customer_id) as CustomerDefinition
	var visit := CustomerVisit.new()
	visit.visit_id = row.visit_id; visit.customer_id = row.customer_id; visit.person = row.person.duplicate(true)
	visit.status = "active"; visit.arrival = 0; visit.expires_at = 300
	visit.voice = customer.persona.duplicate(true); visit.transaction_modes.assign(["sell"])
	visit.item = ItemInstance.new(); visit.item.instance_id = "item/" + visit.visit_id
	visit.item.definition_id = row.item_id; visit.item.selected_variant_id = row.variant_id
	visit.item.goods = row.get("goods",{}).duplicate(true)
	visit.trade.patience = customer.patience; visit.trade.rounds_left = customer.max_quote_rounds
	visit.trade.opening_price = roundi(item.base_value * customer.terms.ask_multiplier)
	visit.trade.asking_price = visit.trade.opening_price; visit.trade.reserve_price = roundi(visit.trade.asking_price * customer.terms.reserve_ratio)
	NightMarketPlan.prepare(visit,row,session.definition,item)
	SpecialGuests.prepare(state,visit,row,item)
	state.visits.append(visit); SpecialGuests.activate(state,visit)
	MarketService.sync(state,session.definition)
	session.message = ""
	return visit

static func bedroom(session: RunSession, held_nights := 1) -> void:
	var visit := apply(session,"wet_cloth","item_blue_bowl")
	var state := session._day.state
	visit.item.acquisition_type = "purchase"; visit.item.ownership_state = "owned"
	visit.item.source_visit_id = visit.visit_id
	state.current_night_index = maxi(state.current_night_index, held_nights + 1)
	visit.item.acquired_night = state.current_night_index - held_nights + 1
	state.inventory_instances.append(visit.item)
	state.visits.clear(); state.phase = &"private_room"
	state.summaries.append({"night": state.current_night_index, "opening_cash": state.cash, "closing_cash": state.cash, "closed_at": 540, "action_count": 0, "outcome": "peaceful"})
	state.summaries.back().merge(FinancialSummary.build(state))
