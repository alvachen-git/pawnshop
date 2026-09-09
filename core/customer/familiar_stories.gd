class_name FamiliarStories
extends RefCounted

const NAMES := ["许文衡", "姜素云"]
const TERMS := "familiar_three_funded"

static func enabled(run: RunDefinition) -> bool:
	return run.variety.get("familiar_version", 0) == 1

static func plan(run: RunDefinition, catalog: ContentCatalog, seed_value: int) -> Dictionary:
	if not enabled(run): return {}
	var key := "%d/%d" % [catalog.get_instance_id(), seed_value]
	if run._familiar_plan_cache.has(key): return run._familiar_plan_cache[key].duplicate(true)
	var base := SevenNightPlan.plan(run, catalog, seed_value)
	var selected: Array = [VarietyService.pick(["bookkeeper", "seamstress"], seed_value, "familiar/primary")]
	if VarietyService.pick([false, true], seed_value, "familiar/second"): selected = ["bookkeeper", "seamstress"]
	var stories: Array = []
	var occupied: Array = []
	for id in selected:
		var prefix: String = "familiar/" + id
		var gaps: Array = [2, 3] if id == "bookkeeper" else [1, 2]
		var nights: Array = range(2 if id == "bookkeeper" else 3, 7).filter(func(n: int) -> bool: return not available(base, occupied, n).is_empty() and gaps.any(func(g: int) -> bool: return n + g > 7 or not available(base, occupied, n + g).is_empty()))
		var first := int(VarietyService.pick(nights, seed_value, prefix + "/night"))
		var valid_gaps: Array = gaps.filter(func(g: int) -> bool: return first + g > 7 or not available(base, occupied, first + g).is_empty())
		var follow := first + int(VarietyService.pick(valid_gaps, seed_value, prefix + "/gap"))
		var person := {"id": "familiar/" + id, "name": NAMES[0 if id == "bookkeeper" else 1], "portrait": "asset.customer_" + id}
		var story := {"id": id, "person": person, "first_night": first, "follow_night": follow, "due_night": first + 3 if id == "seamstress" else 0,
			"funds": int(VarietyService.pick(run.variety.familiar_funds, seed_value, prefix + "/funds")) if id == "seamstress" else 0}
		for stage in ["first", "follow"]:
			var night: int = first if stage == "first" else follow
			var row: Dictionary = {}
			if night <= 7:
				var candidates := available(base, occupied, night)
				assert(not candidates.is_empty(), "Familiar visit needs an unprotected ordinary seat")
				row = VarietyService.pick(candidates, seed_value, prefix + "/" + stage + "/seat").duplicate(true)
				occupied.append(row.visit_id)
			else:
				row = {"visit_id": "%s/%d/familiar_%s" % [run.id, night, id], "night": night, "arrival": int(VarietyService.pick(range(0, 451, 5), seed_value, prefix + "/future"))}
			var customer_id: String = "customer_" + id
			var item_id := ("item_fountain_pen" if stage == "first" else "item_inkstone") if id == "bookkeeper" else ("item_silver_hairpin" if stage == "first" else "item_silk_panel")
			var variants: Array = (["sound", "replacement_nib", "flawed"] if stage == "first" else ["chipped"]) if id == "bookkeeper" else (["sound"] if stage == "first" else ["sound", "faded"])
			var item := catalog.get_definition("items", item_id) as ItemDefinition
			var sources: Array = []
			for source in ["none", "authentic", "mismatch"]:
				for weight in int(item.provenance.weights[source]): sources.append(source)
			var contexts: Array = run.variety.contexts.filter(func(c: Dictionary) -> bool: return c.customer_id == customer_id and c.situation == "ordinary")
			row.merge({"customer_id": customer_id, "item_id": item_id, "variant_id": VarietyService.pick(variants, seed_value, prefix + "/" + stage + "/variant"),
				"context_id": contexts[0].id, "person": person.duplicate(true), "source": VarietyService.pick(sources, seed_value, prefix + "/" + stage + "/source"),
				"situation": "ordinary", "reaction": "explain", "terms_id": TERMS if id == "seamstress" and stage == "first" else "sample_three_redeem",
				"wait_minutes": 90, "transaction_modes": ["pawn"] if id == "seamstress" and stage == "first" else ["sell"],
				"familiar_id": id, "familiar_stage": stage, "familiar_reserved": true}, true)
			story[stage] = row
		stories.append(story)
	var result := {"version": 1, "stories": stories}
	if EarlyRedemption.enabled(run): result["early_redemption"] = true
	if run._familiar_plan_cache.size() >= 64: run._familiar_plan_cache.clear()
	run._familiar_plan_cache[key] = result
	return result.duplicate(true)

static func history_data(state: RunState) -> Dictionary:
	if not state.familiar_context.is_empty(): return state.familiar_context
	return {"familiar_plan": state.familiar_plan, "visit_history": state.visit_history, "scenario_history": state.scenario_history,
		"bargaining_history": state.bargaining_history, "inventory_instances": state.inventory_instances.map(func(i: ItemInstance) -> Dictionary: return i.to_data()),
		"pawn_tickets": state.pawn_tickets.map(func(t: PawnTicket) -> Dictionary: return t.to_data())}

static func ending(data: Dictionary, id: String, before_night := 2147483647) -> Dictionary:
	for row in data.get("visit_history", []):
		if row.visit_id == id and int(row.night) < before_night: return row
	return {}

static func branch(story: Dictionary, data: Dictionary, catalog: ContentCatalog) -> String:
	var result := ending(data, story.first.visit_id, int(story.follow_night))
	if result.is_empty(): return "pending"
	if story.id == "seamstress": return "pawned" if result.outcome == "pawned" else "ended"
	var belittled := false
	var valid := false
	var invalid := false
	var item := catalog.get_definition("items", story.first.item_id) as ItemDefinition
	for row in data.get("scenario_history", []) + data.get("bargaining_history", []):
		if row.visit_id != story.first.visit_id or int(row.night) != int(story.first_night) or not row.ok: continue
		if row.command == "belittle" and row.get("belittle_result", {}).get("used", false): belittled = true
		if row.command == "pressure":
			var clue := item.find_clue(row.detail)
			if clue != null:
				if clue.leverage > 0: valid = true
				else: invalid = true
	if result.outcome == "bought": return "guarded" if belittled else ("candid" if valid else "normal")
	if result.outcome == "rejected" and not belittled and not invalid: return "elsewhere"
	return "ended"

static func overlay(state: RunState, run: RunDefinition, catalog: ContentCatalog, rows: Array[Dictionary]) -> Array[Dictionary]:
	if not enabled(run): return rows
	state.familiar_plan = plan(run, catalog, state.run_seed)
	var data := history_data(state)
	for story in state.familiar_plan.stories:
		for stage in ["first", "follow"]:
			var scheduled: Dictionary = story[stage]
			if scheduled.night > 7: continue
			var route := "first" if stage == "first" else branch(story, data, catalog)
			for index in rows.size():
				if rows[index].visit_id != scheduled.visit_id: continue
				# Even an inactive future seat cannot be replaced by a preparation action.
				rows[index]["familiar_reserved"] = true
				if route in ["pending", "ended"]: break
				rows[index] = scheduled.duplicate(true)
				rows[index]["familiar_branch"] = route
				if stage == "follow" and EarlyRedemption.qualifies(data, story):
					rows[index]["early_redemption"] = true
					rows[index].item_id = story.first.item_id
					rows[index].variant_id = story.first.variant_id
					rows[index].source = story.first.source
				if route == "guarded": rows[index].wait_minutes = 30
				break
	return rows

static func story_for(data: Dictionary, id: String) -> Dictionary:
	for story in data.get("familiar_plan", {}).get("stories", []):
		if story.id == id: return story
	return {}

static func funds(story: Dictionary, data: Dictionary) -> int:
	var total := int(story.funds)
	var result := ending(data, story.follow.visit_id, int(story.due_night))
	if result.get("outcome") == "bought":
		for item in data.get("inventory_instances", []):
			if item.source_visit_id == story.follow.visit_id and item.acquisition_type == "purchase": total += int(item.acquisition_price); break
	return total

# Only this versioned contract consults the side-story funding. Old contracts stay fixed.
static func return_mode(ticket: Dictionary, data: Dictionary, fallback: String) -> String:
	if ticket.get("terms_id") != TERMS: return fallback
	var story := story_for(data, "seamstress")
	if story.is_empty() or ticket.get("source_visit_id") != story.first.visit_id: return "absent"
	return "redeem" if funds(story, data) >= int(ticket.redemption_amount) else "absent"

static func attach_context(state: RunState, data: Dictionary) -> void:
	state.familiar_context = data if data.has("familiar_plan") else {}

static func restore(data: Dictionary, state: RunState, run: RunDefinition, catalog: ContentCatalog) -> String:
	if not enabled(run): return "旧局不能混入熟客支线。" if data.has("familiar_plan") or data.has("familiar_progress") else ""
	var expected := plan(run, catalog, state.run_seed)
	if normalize(data.get("familiar_plan")) != expected or not data.get("familiar_progress") is Dictionary: return "熟客编排与本局种子不符。"
	# These histories are fully replayed by the original codecs after this shape guard.
	for key in ["visit_history", "scenario_history", "bargaining_history", "inventory_instances", "pawn_tickets"]:
		if not data.get(key) is Array: return "缺少熟客交易历史。"
		for row in data[key]:
			if not row is Dictionary: return "熟客交易历史结构无效。"
			if key == "visit_history" and (not CounterSaveCodec._text_fields(row, ["visit_id", "outcome"]) or not CounterSaveCodec._integers(row, ["night"])): return "熟客离场历史无效。"
			if key in ["scenario_history", "bargaining_history"]:
				if not CounterSaveCodec._text_fields(row, ["visit_id", "command"]) or not CounterSaveCodec._integers(row, ["night"]) or not row.get("ok") is bool or not row.get("detail") is String: return "熟客议价历史无效。"
				if row.has("belittle_result") and not row.belittle_result is Dictionary: return "熟客试探历史无效。"
			if key == "inventory_instances" and (not CounterSaveCodec._text_fields(row, ["source_visit_id", "acquisition_type"]) or not CounterSaveCodec._integers(row, ["acquisition_price"])): return "熟客收货记录无效。"
			if key == "pawn_tickets" and (not CounterSaveCodec._text_fields(row, ["source_visit_id", "ticket_id", "status"]) or not CounterSaveCodec._integers(row, ["redemption_amount", "due_night"])): return "熟客当票记录无效。"
	state.familiar_plan = expected
	attach_context(state, data)
	return ""

static func progress(data: Dictionary) -> Dictionary:
	var result := {}
	for story in data.get("familiar_plan", {}).get("stories", []):
		var first := ending(data, story.first.visit_id)
		var follow := ending(data, story.follow.visit_id)
		var ticket := {}
		for row in data.get("pawn_tickets", []):
			if row.source_visit_id == story.first.visit_id: ticket = row; break
		result[story.id] = {"first": first.duplicate(true), "follow": follow.duplicate(true), "ticket_id": ticket.get("ticket_id", ""),
			"ticket_status": ticket.get("status", ""), "funds": funds(story, data) if story.id == "seamstress" and not ticket.is_empty() else 0}
	return result

static func note(state: RunState) -> String:
	var lines: PackedStringArray = []
	var data := history_data(state)
	for story in state.familiar_plan.get("stories", []):
		var first := ending(data, story.first.visit_id)
		var live := state.visits.any(func(v: CustomerVisit) -> bool: return v.visit_id == story.first.visit_id and v.status == "active")
		if first.is_empty() and not live: continue
		if first.get("outcome", "") in ["shop_closed", "timed_out"] and not data.scenario_history.any(func(h: Dictionary) -> bool: return h.visit_id == story.first.visit_id): continue
		if story.id == "bookkeeper":
			var second := ending(data, story.follow.visit_id)
			lines.append("许文衡：曾带钢笔来筹盘缠。" + ("后来又带砚台来过。" if not second.is_empty() and second.outcome not in ["shop_closed", "timed_out"] else "此后的往来，尚未记下。"))
		else:
			var ticket := {}
			for row in data.pawn_tickets:
				if row.source_visit_id == story.first.visit_id: ticket = row; break
			if ticket.is_empty(): lines.append("姜素云：曾询问银簪活当，未出票。")
			else:
				var status: String = {"active": "仍在当", "redeemed": "原主已赎回", "defaulted": "到期未赎，已留货", "transferred": "到期未赎，已转当"}.get(ticket.status, "")
				if ticket.status == "redeemed" and int(ticket.closed_night) < int(ticket.due_night): status = "原主已提前赎回"
				if ticket.status == "active" and ending(data, story.follow.visit_id).get("outcome") == "redemption_deferred": status += "，已约定到期再来"
				lines.append("姜素云 · 银簪：第%d夜到期，赎金%d银元，%s。" % [ticket.due_night, ticket.redemption_amount, status])
	return "" if lines.is_empty() else "\n\n熟客往来\n" + "\n".join(lines)

static func available(base: Array[Dictionary], occupied: Array, night: int) -> Array[Dictionary]:
	if base.filter(func(r: Dictionary) -> bool: return int(r.night) == night and r.visit_id in occupied).size() >= 2: return []
	return base.filter(func(r: Dictionary) -> bool: return int(r.night) == night and not r.context_id.is_empty() and not r.has("seven_role") and r.visit_id not in occupied)

static func normalize(value: Variant) -> Variant:
	if value is Dictionary:
		var result := {}
		for key in value: result[key] = normalize(value[key])
		return result
	if value is Array:
		return value.map(func(v: Variant) -> Variant: return normalize(v))
	if value is float and is_finite(value) and value == floor(value) and abs(value) <= 2147483647: return int(value)
	return value
