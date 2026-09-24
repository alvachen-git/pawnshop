class_name LuxuryCarry
extends RefCounted

static func enabled(run: RunDefinition) -> bool:
	return run.variety.get("luxury_carry_version",0) == 1

static func pick(run: RunDefinition, customer: CustomerDefinition, seed_value: int, key: String) -> String:
	if not enabled(run): return VarietyService.pick(customer.item_pool,seed_value,key+"/item")
	var pool := []
	for id in run.variety.luxury_carry_weights[customer.id]:
		for i in int(run.variety.luxury_carry_weights[customer.id][id]): pool.append(id)
	return VarietyService.pick(pool,seed_value,key+"/carry38/item")

static func percent(state: RunState, visit: CustomerVisit, kind: String) -> float:
	var run: RunDefinition = state.ghost_catalog.get_definition("runs",state.run_definition_id)
	if not enabled(run): return 1.10 if kind == "asking" else .95
	return float(run.variety.luxury.profiles[visit.customer_id][kind+"_percent"])/100.0

static func origin(state: RunState, visit: CustomerVisit) -> String:
	var who := visit.customer_id.trim_prefix("customer_wealthy_")
	var sources := ["这是家中留下的旧物，暂拿来周转。","先前买下留着的，眼下要用现钱。","旧日受赠的东西，一直收着。"]
	if who == "antique": sources = ["这是前些时候收来的货，正好拿来周转。","旧藏里取出来的，另有一笔生意等着接。"]
	if who == "opera": sources = ["这是我私下留着的东西，还请您仔细些。","旧日受赠的私物，班里的开支却等不得。"]
	return VarietyService.pick(sources,state.run_seed,visit.visit_id+"/carry38/origin")

static func validate(run: RunDefinition, catalog: ContentCatalog, issues: Array) -> void:
	if not enabled(run): return
	var weights: Variant = run.variety.get("luxury_carry_weights",{})
	if not weights is Dictionary:
		CounterDomainValidator._error(issues,run.id,"携货权重须为映射。"); return
	for cid in run.variety.luxury.profiles:
		var row: Variant = weights.get(cid,{})
		if not row is Dictionary or row.size() != 10:
			CounterDomainValidator._error(issues,run.id,"每位富客须配置十种高档货。"); continue
		var total := 0
		for id in run.variety.tiered_appraisal:
			var weight: Variant = row.get(id,0)
			if not RunSchema.integer(weight) or weight <= 0 or catalog.get_definition("items",id) == null:
				CounterDomainValidator._error(issues,run.id,"携货权重须为正整数，且货物必须存在。")
			else: total += int(weight)
		if total != 100: CounterDomainValidator._error(issues,run.id,"每位富客携货权重之和须为100。")
