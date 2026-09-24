class_name BanglePreview
extends RefCounted

static func apply(session: RunSession, scenario: String) -> void:
	if scenario == "natural": return
	var state := session._day.state; var visit: CustomerVisit = state.visits[0]
	if not BangleEconomy.handles(state,visit.item): return
	if scenario == "guide":
		state.phase = &"pre_open"; state.current_night_index = 2; state.visits.clear(); state.shop_growth.knowledge.clear(); return
	if scenario == "no-tools":
		state.shop_growth.bench = false; state.shop_growth.appraisal.bench_due = 0; state.shop_growth.appraisal.tools = false; state.shop_growth.precision.kits = []; return
	var kind := "lower" if scenario=="lower" else "plated" if scenario in ["plated","matched"] else "fine"
	visit.item.selected_variant_id = {"fine":"sound","lower":"mended","plated":"flawed"}[kind]
	var facts: Dictionary = visit.item.goods.bangle_value
	facts.material = kind; facts.repair = "altered" if scenario in ["repaired","partial","firm"] else "intact"
	facts.weight = 30 if scenario=="matched" else BangleEconomy.WEIGHTS[kind][0]
	facts.actual = BangleEconomy.valuation(kind,facts.repair,visit.item.goods.precision.damage)
	visit.transaction_modes.assign(["sell"]); WealthyCustomers.trade(state,visit).funding = 0
	BangleEconomy.prepare(state,visit)
	var owner := BangleEconomy.owner(state,visit)
	owner.belief = {"material":"fine","repair":"intact"}; owner.rate = 100; owner.urgent = false
	BangleEconomy.reprice_initial(state,visit); BangleNegotiation.prepare(state,visit)
	var d := BangleNegotiation.data(state,visit)
	d.personality = "careful" if scenario == "partial" else "firm" if scenario == "firm" else "easy"
	for part in BangleNegotiation.PARTS: d.rolls[part] = 99 if scenario == "exposed" else 0
