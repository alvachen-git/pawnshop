class_name PearlPreview
extends RefCounted

static func apply(session: RunSession, scenario: String) -> void:
	if scenario == "natural": return
	var state := session._day.state; var visit: CustomerVisit = state.visits[0]
	if not PearlEconomy.handles(state,visit.item): return
	if scenario == "guide":
		state.phase = &"pre_open"; state.current_night_index = 2; state.visits.clear(); state.shop_growth.knowledge.clear(); return
	if scenario == "no-tools":
		state.shop_growth.bench = false; state.shop_growth.appraisal.bench_due = 0; state.shop_growth.appraisal.tools = false; state.shop_growth.precision.kits = []; return
	var kind := "lower" if scenario == "lower" else "mixed" if scenario in ["few","many"] else "imitation" if scenario == "imitation" else "fine"
	visit.item.selected_variant_id = "sound" if kind == "fine" else "flawed" if kind == "imitation" else "mended"
	var count := 4 if kind == "lower" else 2 if scenario == "few" else 16 if scenario == "many" else 32 if kind == "imitation" else 0
	var beads: Array = visit.item.goods.pearl_value.beads
	var order := range(32); var rng := VarietyService.rng(state.run_seed,visit.item.instance_id+"/pearl38/preset/"+scenario)
	for i in range(31,0,-1):
		var j := rng.randi_range(0,i); var saved: int = order[i]; order[i] = order[j]; order[j] = saved
	for bead in beads: bead.quality = ("lower" if kind == "lower" else "imitation") if int(bead.index) in order.slice(0,count) else "fine"
	visit.item.goods.pearl_value.kind = kind
	visit.item.goods.pearl_value.actual = PearlEconomy.value(beads,visit.item.goods.precision.damage)
	visit.transaction_modes.assign(["sell"]); WealthyCustomers.trade(state,visit).funding = 0
	PearlEconomy.prepare(state,visit)
	var owner := PearlEconomy.owner(state,visit)
	owner.belief = {"material":"none","repair":"intact"}; owner.rate = 100; owner.urgent = false
	PearlEconomy.reprice_initial(state,visit); PearlNegotiation.prepare(state,visit)
	var d := PearlNegotiation.data(state,visit)
	d.personality = "careful" if scenario == "partial" else "firm" if scenario == "firm" else "easy"
	for part in PearlNegotiation.PARTS: d.rolls[part] = 99 if scenario == "exposed" else 0
