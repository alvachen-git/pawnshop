class_name SevenNightPlan
extends RefCounted

static func enabled(run: RunDefinition) -> bool:
	return run.variety.get("seven_version", 0) == 1

static func context(run: RunDefinition, id: String) -> Dictionary:
	for row in run.variety.get("contexts", []):
		if row.id == id: return row
	return {}

static func plan(run: RunDefinition, catalog: ContentCatalog, seed_value: int) -> Array[Dictionary]:
	var key := "%d/%d" % [catalog.get_instance_id(), seed_value]
	if not run._seven_plan_cache.has(key):
		if run._seven_plan_cache.size() >= 64: run._seven_plan_cache.clear()
		run._seven_plan_cache[key] = generate(run, catalog, seed_value)
	return run._seven_plan_cache[key].duplicate(true)

static func generate(run: RunDefinition, catalog: ContentCatalog, seed_value: int, attempt := 0) -> Array[Dictionary]:
	var config := run.variety
	var context_by_id := {}
	for c in config.contexts: context_by_id[c.id] = c
	var rows: Array[Dictionary] = []
	var roles := {}
	var anchors := {}
	for anchor in config.get("story_slots", []):
		for slot in run.customer_slots:
			if slot.id == anchor.slot_id: anchors[int(anchor.index)] = slot
	var available: Array = range(18).filter(func(i: int) -> bool: return not anchors.has(i))
	for role in ["flaw", "invalid", "urgent", "source", "pawn"]:
		var slots: Array = available.filter(func(i: int) -> bool: return i >= 12 if role == "pawn" else i > 0)
		# The authored midnight watch excludes adjacent urgent watch sellers.
		if not anchors.is_empty() and role == "urgent": slots = slots.filter(func(i: int) -> bool: return i < 12)
		if OpeningPreparation.enabled(run):
			# Leave an ordinary position for targeted buying; reserve the third-night pawn too.
			slots = slots.filter(func(i: int) -> bool: return available.filter(func(j: int) -> bool: return j / 6 == i / 6).size() > (2 if i >= 12 and role != "pawn" else 1))
		var slot: int = VarietyService.pick(slots, seed_value, "seven/role/" + role)
		roles[slot] = role
		available.erase(slot)
	var pen4_slots: Array = range(18, 24).filter(func(i: int) -> bool: return not anchors.has(i))
	var pen4: int = 18 + VarietyService.rng(seed_value, "seven/pen4").randi_range(0, 5)
	if anchors.has(pen4): pen4 = VarietyService.pick(pen4_slots, seed_value, "seven/pen4/reserved")
	roles[pen4] = "pen4"
	roles[24 + VarietyService.rng(seed_value, "seven/pen5").randi_range(1 if roles.get(23, "") == "pen4" else 0, 5)] = "pen5"
	var swapped := VarietyService.rng(seed_value, "seven/pen_variant").randi_range(0, 1) == 1
	var names: Array = FamiliarStories.NAMES.duplicate() if FamiliarStories.enabled(run) else []
	for night in range(1, 8):
		var times: Array = []
		for band in [[0, 120], [120, 300], [300, 450]]:
			var random := VarietyService.rng(seed_value, "seven/arrival/%d/%d" % [night, band[0]])
			var a := 0 if night == 1 and band[0] == 0 else random.randi_range(band[0] / 5, (band[1] - 15) / 5) * 5
			var b := random.randi_range((a + 15) / 5, band[1] / 5) * 5
			# Adjacent bands share a boundary; reserve fifteen minutes after the previous arrival.
			if not times.is_empty(): a = maxi(a, int(times.back()) + 15); b = maxi(b, a + 15)
			times.append(a)
			times.append(b)
		if config.get("fixed_arrivals", {}).has(str(night)): times = config.fixed_arrivals[str(night)].duplicate()
		for seat in 6:
			var index := rows.size()
			if anchors.has(index):
				rows.append(story_row(run, catalog, anchors[index], night))
				continue
			var role: String = roles.get(index, "")
			var id := "%s/%d/n%d_visit%d" % [run.id, night, night, seat + 1]
			var candidates: Array = []
			for c in config.contexts:
				var customer := catalog.get_definition("customers", c.customer_id) as CustomerDefinition
				if not rows.is_empty() and rows.back().customer_id == customer.id: continue
				if anchors.has(index + 1) and anchors[index + 1].customer_id == customer.id: continue
				var modes: Array = c.transaction_modes.duplicate()
				if night < 3: modes.erase("pawn")
				if modes.is_empty(): continue
				for item_id in customer.item_pool:
					var item := catalog.get_definition("items", item_id) as ItemDefinition
					if roles.get(index + 1, "") in ["pen4", "pen5"] and item_id == "item_fountain_pen": continue
					if roles.get(index + 1, "") == "invalid" and item_id == "item_blue_bowl": continue
					if anchors.has(index + 1) and anchors[index + 1].item_id == item_id: continue
					if item.item_type != "normal" or (not rows.is_empty() and rows.back().item_id == item_id): continue
					var recent := rows.slice(maxi(0, rows.size() - 6)).any(func(old: Dictionary) -> bool: return old.customer_id == customer.id and old.item_id == item_id and old.context_id == c.id)
					if recent: continue
					var variant: String = VarietyService.pick(item.possible_variants, seed_value, id + "/" + item_id).id
					match role:
						"flaw":
							var flaws := {"item_blue_bowl": "repaired", "item_inkstone": "chipped", "item_silver_hairpin": "mended"}
							if not flaws.has(item_id): continue
							variant = flaws[item_id]
						"invalid":
							if item_id != "item_blue_bowl" or customer.id not in ["customer_citizen", "customer_teahouse"]: continue
							variant = "sound"
						"urgent":
							if item_id not in ["item_pocket_watch", "item_fountain_pen"] or c.situation != "urgent" or "sell" not in modes: continue
							variant = "sound"
						"source":
							if item_id not in ["item_silver_hairpin", "item_fountain_pen", "item_silk_panel"]: continue
							variant = "sound"
						"pawn":
							if "pawn" not in modes or c.situation == "urgent": continue
							variant = "sound"
						"pen4", "pen5":
							if item_id != "item_fountain_pen" or "sell" not in modes: continue
							variant = "replacement_nib" if (role == "pen4") == swapped else "sound"
					if item.find_variant(variant) == null: continue
					candidates.append({"customer_id": customer.id, "item_id": item_id, "variant_id": variant, "context_id": c.id, "transaction_modes": ["pawn"] if role == "pawn" else modes})
			if candidates.is_empty():
				if attempt == 100: print("EXHAUST seed=", seed_value, " index=", index, " role=", role, " previous=", rows.back())
				assert(attempt < 100, "Seven-night compatible pool exhausted")
				return generate(run, catalog, seed_value, attempt + 1)
			var row: Dictionary = VarietyService.pick(candidates, seed_value, id + "/choice/%d" % attempt).duplicate(true)
			var customer := catalog.get_definition("customers", row.customer_id) as CustomerDefinition
			var item := catalog.get_definition("items", row.item_id) as ItemDefinition
			var c: Dictionary = context_by_id[row.context_id]
			var weights: Dictionary = item.provenance.weights
			var sources: Array = []
			for key in ["none", "authentic", "mismatch"]:
				for weight in int(weights[key]): sources.append(key)
			row.merge({"visit_id": id, "night": night, "arrival": int(times[seat]), "wait_minutes": int(c.wait_minutes), "situation": c.situation,
				"source": VarietyService.pick(["authentic", "mismatch"] if role == "source" else sources, seed_value, id + "/source"),
				"reaction": VarietyService.pick(["admit", "explain", "evade"], seed_value, id + "/reaction"),
				"terms_id": "sample_three_redeem" if role == "pawn" else VarietyService.pick(config.terms_ids, seed_value, id + "/terms")})
			if not role.is_empty(): row["seven_role"] = role
			var given: Array = customer.persona.names
			var surnames: Array = config.surnames
			var first := VarietyService.rng(seed_value, id + "/name").randi_range(0, given.size() * surnames.size() - 1)
			for offset in given.size() * surnames.size():
				var n := (first + offset) % (given.size() * surnames.size())
				var person_name: String = surnames[n / given.size()] + given[n % given.size()]
				if person_name in names: continue
				names.append(person_name)
				row.person = {"id": "person/" + id, "name": person_name, "portrait": customer.portrait_asset_id}
				break
			rows.append(row)
	return rows

# Story positions use authored identities and truth; ordinary positions keep seeded variety.
static func story_row(run: RunDefinition, catalog: ContentCatalog, slot: VisitSlotDefinition, night: int) -> Dictionary:
	var customer := catalog.get_definition("customers", slot.customer_id) as CustomerDefinition
	var id := "%s/%d/%s" % [run.id, night, slot.id]
	return {"visit_id": id, "night": night, "arrival": slot.arrival, "customer_id": customer.id,
		"item_id": slot.item_id, "variant_id": slot.variant_id, "context_id": "", "source": "none" if not (catalog.get_definition("items", slot.item_id) as ItemDefinition).provenance.is_empty() else "",
		"situation": slot.tutorial.get("story_situation", "ordinary"), "reaction": "admit", "terms_id": customer.pawn_terms_id,
		"wait_minutes": customer.terms.wait_minutes, "transaction_modes": ["sell"],
		"person": {"id": "person/" + id, "name": customer.terms.display_name, "portrait": customer.portrait_asset_id}}
