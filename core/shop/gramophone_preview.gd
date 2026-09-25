class_name GramophonePreview
extends RefCounted

static func apply(session: RunSession, scenario: String) -> void:
	var state:=session._day.state;var visit: CustomerVisit=state.visits[0]
	if not GramophoneEconomy.handles(state,visit.item) or scenario=="natural":return
	if scenario=="guide":
		state.phase=&"pre_open";state.current_night_index=2;state.visits.clear();state.shop_growth.knowledge.clear();return
	var identity: String=scenario if scenario in ["imitation","rebuilt"] else "original"
	var sound: String=scenario if scenario in ["rasping","muffled"] else "clear"
	var motor: String=scenario if scenario in ["wavering","stopping"] else "wavering" if scenario in ["partial","firm"] else "steady"
	visit.item.goods.gramophone_value={"identity":identity,"sound":sound,"motor":motor,"record_worn":scenario=="worn-record","initial_wound":false,"engraving":"letter_swap" if identity=="imitation" else "standard","actual":GramophoneEconomy.valuation(identity,sound,motor,visit.item.goods.precision.damage)}
	visit.transaction_modes.assign(["sell"]);WealthyCustomers.trade(state,visit).funding=0
	GramophoneEconomy.prepare(state,visit)
	if scenario=="no-tools":
		state.shop_growth.bench=false;state.shop_growth.appraisal.bench_due=0;state.shop_growth.precision.due=0;return
	# Object demonstrations must keep real owner cognition and bargaining rolls.
	# Only explicitly named negotiation fixtures pin their intended outcomes.
	if scenario not in ["partial","firm","exposed"]:return
	var o:=GramophoneEconomy.owner(state,visit);o.belief={"identity":"original","sound":"clear","motor":"steady"};o.rate=100;o.urgent=false
	GramophoneEconomy.reprice_initial(state,visit);GramophoneNegotiation.prepare(state,visit)
	var n:=GramophoneNegotiation.data(state,visit);n.personality="careful" if scenario=="partial" else "firm" if scenario=="firm" else "easy"
	for part in GramophoneNegotiation.PARTS:n.rolls[part]=99 if scenario=="exposed" else 0
