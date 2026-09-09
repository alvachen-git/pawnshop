class_name PawnReturnService
extends RefCounted

# Return visits reference existing collateral. They never enter the acquisition queue.
static func plan(tickets: Array, night: int, catalog: ContentCatalog, context: Dictionary = {}) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	if catalog == null: return rows
	for ticket in tickets:
		if ticket is Dictionary and not ticket.get("person", {}) is Dictionary: return []
		if not ticket is Dictionary or not CounterSaveCodec._text_fields(ticket, ["ticket_id", "terms_id", "customer_id", "item_instance_id"]) or not RunSchema.integer(ticket.get("started_night")) or not ticket.get("extensions") is Array: return []
		var terms := catalog.get_definition("pawn_terms", ticket.terms_id) as PawnTermsDefinition
		if terms == null: continue
		var mode := FamiliarStories.return_mode(ticket, context, terms.return_mode)
		if mode == "absent": continue
		var due: int = int(ticket.started_night) + terms.term_nights
		var extended := false
		for extension in ticket.extensions:
			if not extension is Dictionary or not CounterSaveCodec._integers(extension, ["night", "new_due"]): return []
			if int(extension.night) < night:
				due = int(extension.new_due)
				extended = true
		if due != night: continue
		if not EarlyRedemption.recorded(ticket, context).is_empty(): continue
		var command := "extend" if mode == "extend_once" and not extended else "redeem"
		rows.append({"id": "return/%d/%s" % [night, ticket.ticket_id], "ticket_id": ticket.ticket_id,
			"customer_id": ticket.customer_id, "item_instance_id": ticket.item_instance_id,
			"night": night, "command": command, "minutes": terms.extend_minutes if command == "extend" else terms.redeem_minutes,
			"status": "scheduled", "start": -1, "minute": -1})
	for row in rows:
		for ticket in tickets:
			if ticket.ticket_id == row.ticket_id and not ticket.get("person", {}).is_empty(): row.person = ticket.person.duplicate(true)
	return rows

static func prepare(state: RunState, catalog: ContentCatalog) -> int:
	var rows := plan(state.pawn_tickets.map(func(t: PawnTicket) -> Dictionary: return t.to_data()), state.current_night_index, catalog, FamiliarStories.history_data(state))
	var delay := 0
	for row in rows:
		delay += int(row.minutes)
		if not state.pawn_returns.any(func(old: Dictionary) -> bool: return old.id == row.id): state.pawn_returns.append(row)
	return delay

static func current(state: RunState) -> Dictionary:
	if state.phase != &"open": return {}
	for row in state.pawn_returns:
		if row.night == state.current_night_index and row.status == "waiting": return row
	return {}

static func arrive(state: RunState) -> void:
	if state.phase != &"open": return
	for row in state.pawn_returns:
		if row.night == state.current_night_index and row.status == "scheduled": row.status = "waiting"

static func delay_for(data: Dictionary, night: int, catalog: ContentCatalog) -> int:
	if not data.get("pawn_tickets", []) is Array: return 0
	if night < int(data.get("pawn_rules_start_night", 2147483647)): return 0
	var delay := 0
	for row in plan(data.get("pawn_tickets", []), night, catalog, data): delay += int(row.minutes)
	return delay

static func validate(data: Dictionary, state: RunState, run: RunDefinition, catalog: ContentCatalog) -> String:
	if not data.get("pawn_returns") is Array: return "缺少当户回访记录。"
	var expected: Array[Dictionary] = []
	for night in range(state.pawn_rules_start_night, state.current_night_index + 1):
		var earliest := 0
		for planned in plan(data.pawn_tickets, night, catalog, data):
			if expected.size() >= data.pawn_returns.size(): return "当户回访记录不完整。"
			var row: Variant = data.pawn_returns[expected.size()]
			if not row is Dictionary or row.size() != planned.size() or not row.get("status") is String: return "当户回访结构无效。"
			for key in planned:
				if key in ["status", "start", "minute"]: continue
				if row.get(key) != planned[key]: return "当户、原物或回访顺序不符。"
			if not CounterSaveCodec._integers(row, ["start", "minute"]): return "回访办理时刻无效。"
			if night > SaveTimeline.trading_nights(state):
				if row.status != "scheduled" or row.start != -1 or row.minute != -1: return "开铺前回访状态无效。"
			else:
				if row.status != "completed" or row.start < earliest or row.minute != row.start + row.minutes or int(row.start) % run.time_step != 0 or row.minute > SaveTimeline.closing(state, night): return "到店当户尚未办结或耗时重叠。"
				var ticket := PawnController.new().find(state, row.ticket_id)
				if ticket == null: return "回访当票不存在。"
				if row.command == "redeem":
					if ticket.status != "redeemed" or ticket.closed_night != night or ticket.closed_minute != row.minute: return "赎回与回访不符。"
				elif not ticket.extensions.any(func(e: Dictionary) -> bool: return e.night == night and e.minute == row.minute): return "续当与回访不符。"
				earliest = int(row.minute)
			var normalized: Dictionary = row.duplicate(true)
			for key in ["night", "minutes", "start", "minute"]: normalized[key] = int(row[key])
			expected.append(normalized)
	if expected.size() != data.pawn_returns.size(): return "重复或多余的当户回访。"
	state.pawn_returns.assign(expected)
	return ""
