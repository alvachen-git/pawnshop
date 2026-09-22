class_name NightMarketPlan
extends RefCounted

# Overlay only expendable seats, after the authored and familiar reservations.
static func enabled(run: RunDefinition) -> bool:
	return run.variety.get("night_market", {}).get("version", 0) == 1

static func band(minute: int) -> int:
	return 0 if minute < 180 else (1 if minute < 360 else (2 if minute < 480 else 3))

static func protected(row: Dictionary) -> bool:
	return row.get("context_id", "").is_empty() or row.has("seven_role") or row.get("familiar_reserved", false)

static func overlay(rows: Array[Dictionary], run: RunDefinition, catalog: ContentCatalog, seed_value: int) -> Array[Dictionary]:
	if not enabled(run): return rows
	var config: Dictionary = run.variety.night_market
	var eligible: Array = []
	for night in range(2, 8):
		if rows.any(func(r: Dictionary) -> bool: return r.night == night and not protected(r)): eligible.append(night)
	var first: int = VarietyService.pick(eligible.filter(func(n: int) -> bool: return n <= 3), seed_value, "late/first")
	var second: int = VarietyService.pick(eligible.filter(func(n: int) -> bool: return n > first and n <= 5), seed_value, "late/second")
	var remaining: Array = eligible.filter(func(n: int) -> bool: return n not in [first, second])
	var third: int = VarietyService.pick(remaining, seed_value, "late/third")
	remaining.erase(third)
	var fourth: int = VarietyService.pick(remaining, seed_value, "late/fourth")
	var special := {first: "one_quote", second: "wet_cloth", third: "one_quote", fourth: "wet_cloth"}
	for night in range(1, 8):
		var ordinary: Array = rows.filter(func(r: Dictionary) -> bool: return r.night == night and not protected(r))
		var fixed: Array = rows.filter(func(r: Dictionary) -> bool: return r.night == night and protected(r))
		var occupied: Array = fixed.map(func(r: Dictionary) -> int: return int(r.arrival))
		var counts: Array = [0, 0, 0, 0]
		for minute in occupied: counts[band(minute)] += 1
		if special.has(night):
			var chosen: Dictionary = VarietyService.pick(ordinary, seed_value, "late/seat/%d" % night)
			ordinary.erase(chosen)
			var policy: String = special[night]
			var target_band := 1 if policy == "one_quote" else int(VarietyService.pick([2, 3], seed_value, "late/band/%d" % night))
			chosen.arrival = _time(occupied, target_band, seed_value, "late/special/%d" % night)
			occupied.append(chosen.arrival)
			counts[target_band] += 1
			var item_id: String = VarietyService.pick(["item_pocket_watch", "item_fountain_pen"] if policy == "one_quote" else ["item_blue_bowl", "item_inkstone"], seed_value, "late/item/%d" % night)
			var item := catalog.get_definition("items", item_id) as ItemDefinition
			var variant: String = VarietyService.pick(item.possible_variants, seed_value, "late/variant/%d" % night).id
			var customer_id := "customer_hawker" if policy == "one_quote" else "customer_citizen"
			# Use a content-backed existing portrait and question pool.
			var customer := catalog.get_definition("customers", customer_id) as CustomerDefinition
			var contexts: Array = run.variety.contexts.filter(func(c: Dictionary) -> bool: return c.customer_id == customer_id)
			var weights: Array = config.outcomes[str(target_band)] if policy == "wet_cloth" else [100, 0, 0]
			var roll := VarietyService.rng(seed_value, "late/aftermath/%d" % night).randi_range(0, 99)
			var aftermath := "fright" if roll < int(weights[0]) else ("item" if roll < int(weights[0]) + int(weights[1]) else "haunt")
			chosen.merge({"customer_id": customer_id, "context_id": contexts[0].id, "item_id": item_id, "variant_id": variant, "source": "none", "situation": "ordinary", "reaction": "evade", "transaction_modes": ["sell"], "wait_minutes": int(config.wait_minutes), "night_policy": policy, "night_band": target_band, "night_aftermath": aftermath,
				"person": {"id": "night_guest/" + chosen.visit_id, "name": "戴旧毡帽的客人" if policy == "one_quote" else "抱湿包的客人", "portrait": customer.portrait_asset_id}}, true)
		for row in ordinary:
			var desired := 0
			for b in 4:
				if int(counts[b]) < int([2, 2, 1, 1][b]): desired = b; break
			row.arrival = _time(occupied, desired, seed_value, "late/ordinary/" + row.visit_id)
			occupied.append(row.arrival)
			counts[desired] += 1
	return rows

static func _time(occupied: Array, target: int, seed_value: int, key: String) -> int:
	var limits: Array = [[0, 175], [180, 355], [360, 475], [480, 500]][target]
	var times: Array = []
	for minute in range(int(limits[0]), int(limits[1]) + 1, 5):
		if occupied.all(func(old: int) -> bool: return absi(old - minute) >= 15): times.append(minute)
	# Protected authored arrivals win. A crowded forbidden band may use 02:25–02:40.
	if times.is_empty():
		for minute in range(480, 521, 5):
			if occupied.all(func(old: int) -> bool: return absi(old - minute) >= 15): times.append(minute)
	assert(not times.is_empty(), "No legal night-market seat")
	return int(VarietyService.pick(times, seed_value, key))

static func prepare(visit: CustomerVisit, row: Dictionary, run: RunDefinition, item: ItemDefinition) -> void:
	if not row.has("night_policy"): return
	visit.expires_at = mini(visit.expires_at, run.night_minutes)
	visit.night_policy = row.night_policy
	visit.night_aftermath = row.night_aftermath
	var config: Dictionary = run.variety.night_market
	visit.trade.opening_price = maxi(1, roundi(item.base_value * float(config.ask_ratios[visit.night_policy])))
	visit.trade.asking_price = visit.trade.opening_price
	visit.trade.reserve_price = maxi(1, roundi(visit.trade.asking_price * float(config.reserve_ratio)))
	if visit.night_policy == "one_quote": visit.trade.rounds_left = 1
	visit.voice.belittle_cue = ""
	visit.voice.introduction = "他把毡帽压低，东西搁在柜上：‘货可以看，价只报一回。不合适，我就走。’" if visit.night_policy == "one_quote" else "包布滴着水，地上却没有湿痕。‘东西可以看，来处莫问。包布留下，天亮前照旧规封好。’\n封存包布需20分钟。"
	visit.voice.refused = "他扣住毡帽：‘这一回价说完了。’" if visit.night_policy == "one_quote" else "他把湿布往回拽了半寸：‘再想想。’"
	visit.voice.completed = "帽檐一低，他收了银元，转身挤进夜色。" if visit.night_policy == "one_quote" else "银元落进袖口，没有相碰的声响。那块包布留在了柜边。"
	visit.voice.rejected = "他将旧物裹好，没再开口。"
	visit.voice.timed_out = "再抬头时，门边只剩一道尚未平下的帘褶。"

static func command_reason(visit: CustomerVisit, command: String) -> String:
	if visit.night_policy == "one_quote" and command in ["pressure", "belittle", "concession"]: return "这位客人只听一次正式报价，不接受另行压价。"
	return ""
