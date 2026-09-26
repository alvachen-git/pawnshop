class_name TownLifePreview
extends RefCounted

# Development fixtures are deliberately separate from replay-valid player saves.
static func apply(session: RunSession, profession := "porter", item_key := "", condition := "sound", military := 0) -> CustomerVisit:
	PrecisionPreview.apply(session, 3)
	var state := session._day.state
	state.current_night_index = 6; state.phase = &"open"; state.game_minutes = 0; state.cash = 6000
	state.visits.clear(); state.ordinary_selections.clear(); state.inventory_instances.clear(); state.ledger_entries.clear()
	state.pending_event_id = ""; state.risk_pending = ""; state.pawn_returns.clear()
	state.social.pending.clear(); state.social.intro_step = -1; state.social.military = military; state.social.introduced = true
	state.shop_growth["town_life"] = TownLife.initial()
	for flag in [PawnInterestPolicy.FLAG, LuIntroduction.FLAG]:
		if flag not in state.narrative_flags: state.narrative_flags.append(flag)
	var short: String = {"porter":"kerosene_lamp","musician":"erhu","washerwoman":"padded_vest","soldier":"leather_suitcase","goods":String(TownLife.items(session.definition)[0]).trim_prefix("item_"),"military":"padded_vest"}.get(profession,"abacus") if item_key.is_empty() else item_key.trim_prefix("item_")
	var cid := "customer_" + ("citizen" if profession in ["goods","military"] else profession)
	var customer := state.ghost_catalog.get_definition("customers", cid) as CustomerDefinition
	var definition := state.ghost_catalog.get_definition("items", "item_" + short) as ItemDefinition
	var visit := CustomerVisit.new()
	visit.visit_id = "town-preview/6/" + profession; visit.customer_id = cid
	visit.person = {"id":"person/"+visit.visit_id,"name":String(customer.persona.names[0]),"portrait":customer.portrait_asset_id}
	visit.voice = customer.persona.duplicate(true); visit.voice.introduction = customer.terms.introduction
	visit.arrival = 0; visit.expires_at = customer.terms.wait_minutes; visit.status = "active"
	visit.pawn_terms_id = "sample_three_redeem" if customer.pawn_redemption_chance == 80 else "sample_three_default"
	visit.transaction_modes.assign(customer.transaction_modes)
	visit.item = ItemInstance.new(); visit.item.instance_id = "item/"+visit.visit_id; visit.item.definition_id = definition.id
	visit.item.selected_variant_id = condition if definition.find_variant(condition) != null else definition.possible_variants[0].id
	visit.item.provenance = {"truth":"none","status":"unchecked","evidence":[],"investigated":false} if not definition.provenance.is_empty() else {}
	var value: float = definition.find_variant(visit.item.selected_variant_id).true_value if TownLife.clothing(state, definition.id) else definition.base_value
	visit.trade.opening_price = maxi(1,roundi(value*customer.terms.ask_multiplier)); visit.trade.asking_price = visit.trade.opening_price
	visit.trade.reserve_price = maxi(1,roundi(visit.trade.opening_price*customer.terms.reserve_ratio))
	visit.trade.patience = customer.patience; visit.trade.rounds_left = customer.max_quote_rounds
	var scenario := TradeScenarioService.for_item(session.definition, definition.id)
	if scenario != null: visit.scenario_id = scenario.id; visit.situation_id = "ordinary"; visit.reaction_id = "admit"
	var row := {"visit_id":visit.visit_id,"night":6,"arrival":0,"wait_minutes":customer.terms.wait_minutes,"customer_id":cid,"item_id":definition.id,"variant_id":visit.item.selected_variant_id,"person":visit.person.duplicate(true),"context_id":"","source":"none","situation":"ordinary","reaction":"admit","terms_id":visit.pawn_terms_id,"transaction_modes":visit.transaction_modes.duplicate()}
	state.ordinary_selections.append(row); state.visits.append(visit)
	TownLife.prepare(state,visit,definition); TownLife.activate(state,visit)
	MarketService.sync(state,session.definition)
	if profession == "military":
		state.visits.clear(); state.phase = &"pre_open"; state.social.contract = MilitaryService.contract_template(state)
		state.social.contract.merge({"accepted":6,"due":0,"number":1})
		for i in 5:
			var item := ItemInstance.new(); item.instance_id = "town-preview/clothing/"+str(i)
			item.definition_id = "item_cotton_coat" if i == 0 else "item_padded_vest"
			item.selected_variant_id = "sound" if i in [0,1,4] else "worn" if i == 2 else "flawed"
			item.ownership_state = "pledged" if i == 4 else "owned"; item.acquired_night = 6; item.acquisition_price = 10
			state.inventory_instances.append(item)
	SocialRules.night(state)
	session.counter_model() # Initialize the same existing presentation caches as a real arrival.
	session.message = ""
	return visit
