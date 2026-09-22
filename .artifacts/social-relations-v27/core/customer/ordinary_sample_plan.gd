class_name OrdinarySamplePlan
extends RefCounted

const ROLES := ["pawn", "hold", "flaw", "invalid", "urgent", "source"]

static func enabled(run: RunDefinition) -> bool:
	return run.variety.get("sample_version", 0) == 1

# This transformation has its own version; the v10 generator above it is frozen.
static func apply(rows: Array[Dictionary], run: RunDefinition, catalog: ContentCatalog, seed_value: int) -> Array[Dictionary]:
	var available: Array = range(rows.size())
	for role in ROLES:
		var slots := available.filter(func(i: int) -> bool: return rows[i].night == 1 if role == "pawn" else (rows[i].night <= 2 if role == "hold" else true))
		var index: int = VarietyService.pick(slots, seed_value, "sample/slot/" + role)
		available.erase(index)
		var combinations: Array = []
		for customer_id in run.variety.customer_ids:
			var customer := catalog.get_definition("customers", customer_id) as CustomerDefinition
			for item_id in customer.item_pool:
				var item := catalog.get_definition("items", item_id) as ItemDefinition
				if item.item_type != "normal": continue
				var variant := "sound"
				match role:
					"pawn":
						if "pawn" not in customer.transaction_modes or item.find_variant(variant) == null: continue
					"flaw":
						var flaws := {"item_blue_bowl": "repaired", "item_inkstone": "chipped", "item_silver_hairpin": "mended"}
						if not flaws.has(item_id): continue
						variant = flaws[item_id]
					"invalid":
						if item_id != "item_blue_bowl" or customer_id not in ["customer_citizen", "customer_teahouse"]: continue
					"urgent":
						if item_id not in ["item_pocket_watch", "item_fountain_pen"] or "sell" not in customer.transaction_modes: continue
					"source":
						if item_id not in ["item_silver_hairpin", "item_fountain_pen", "item_silk_panel"]: continue
					"hold":
						if item_id not in ["item_pocket_watch", "item_fountain_pen", "item_silk_panel"] or "sell" not in customer.transaction_modes: continue
				combinations.append({"customer_id": customer_id, "item_id": item_id, "variant_id": variant})
		var choice: Dictionary = VarietyService.pick(combinations, seed_value, "sample/combination/" + role)
		var row: Dictionary = rows[index]
		row.merge(choice, true)
		row["sample_role"] = role
		row.situation = "urgent" if role == "urgent" else "ordinary"
		if role == "urgent": row["wait_minutes"] = 30
		if role == "source": row.source = VarietyService.pick(["authentic", "mismatch"], seed_value, "sample/source")
		if role == "pawn":
			row["transaction_modes"] = ["pawn"]
			row.terms_id = "sample_three_redeem"
	# Assign names after all template overrides, retaining unique identities.
	var names: Array = []
	for row in rows:
		var customer := catalog.get_definition("customers", row.customer_id) as CustomerDefinition
		var given: Array = customer.persona.names
		var surnames: Array = run.variety.surnames
		var first := VarietyService.rng(seed_value, row.visit_id + "/sample_name").randi_range(0, given.size() * surnames.size() - 1)
		for offset in given.size() * surnames.size():
			var n := (first + offset) % (given.size() * surnames.size())
			var person_name: String = surnames[int(n / given.size())] + given[n % given.size()]
			if person_name in names: continue
			names.append(person_name)
			row.person = {"id": "person/" + row.visit_id, "name": person_name, "portrait": customer.portrait_asset_id}
			break
	return rows

static func appointment(rows: Array[Dictionary], catalog: ContentCatalog, seed_value: int) -> Dictionary:
	for row in rows:
		if row.get("sample_role") != "hold": continue
		var item := catalog.get_definition("items", row.item_id) as ItemDefinition
		return {"buyer_id": "buyer_appointment", "visit_id": row.visit_id, "night": VarietyService.rng(seed_value, "sample/buyer_night").randi_range(int(row.night) + 1, 4), "category": String(item.category), "window_start": 60, "window_end": 180, "capacity": 1}
	return {}

static func buyer_reason(state: RunState, buyer_id: String, category: String, night: int, minute: int) -> String:
	if buyer_id != "buyer_appointment": return ""
	var entry := state.buyer_appointment
	if entry.is_empty(): return "尚无这桩收货约定。"
	if night != entry.night or minute < entry.window_start or minute >= entry.window_end: return "约定第%d夜19:00–21:00收货，额度1件。" % entry.night
	if category != entry.category: return "这次约定不收此类货。"
	return ""

static func notice(state: RunState) -> String:
	if state.buyer_appointment.is_empty(): return ""
	var row := state.buyer_appointment
	var names := {"watches": "钟表", "stationery": "文房用具", "textile": "绣片"}
	return "收货消息：商会托人捎话，第%d夜19:00–21:00收%s，限1件。过时不候，价钱验货后再议。" % [row.night, names.get(row.category, row.category)]
