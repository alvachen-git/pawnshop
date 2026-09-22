extends "res://tests/run_living_mirror.gd"

const Fixture = preload("res://tests/living_fixture.gd")
class FailingStore extends GhostReplayStore:
	func save_state(_state: RunState, _definition: RunDefinition, _version: int) -> bool: return false

func run() -> void:
	catalog = JsonContentProvider.new("res://data/mirror_living_manifest.json").load_catalog().catalog
	run_def = catalog.get_definition("runs", catalog.default_run_id)
	for protected in ["known", "attract", "target", "seek", "role", "familiar", "before_23", "no_pawn", "ghost_goods"]:
		var s := Fixture.guest(catalog, GhostGuests.SWAP)
		var state := s._day.state
		var v := CustomerManager.new().active(state)
		v.customer_id = state.ghost_visits[0].original_customer_id
		state.ghost_visits.clear()
		var row := VarietySaveCodec.selection(state, v.visit_id)
		match protected:
			"known": state.preparation_history.append({"night": state.current_night_index, "action": "visitors", "visit_ids": [v.visit_id]})
			"attract", "target", "seek": state.preparation_history.append({"night": state.current_night_index, "action": protected, "change": {"visit_id": v.visit_id}})
			"role": row.seven_role = "pawn"
			"familiar": row.familiar_reserved = true
			"before_23": state.game_minutes = 295
			"no_pawn": state.pawn_tickets.clear()
			"ghost_goods": InventoryManager.new().find(state, state.pawn_tickets[0].item_instance_id).definition_id = "item_weeping_mirror"
		GhostGuests.arrive(state, v)
		check(v.customer_id != GhostGuests.SWAP and state.ghost_visits.is_empty(), "preserve ordinary fallback " + protected)
	var known := Fixture.guest(catalog, GhostGuests.CLOSED)
	var known_visit := CustomerManager.new().active(known._day.state)
	check(known.inspect_customer(known_visit.visit_id).ok, "known result before repeat")
	known_visit.expires_at = known._day.state.game_minutes + 3
	check(not known.inspect_customer(known_visit.visit_id).ok, "repeat expires")
	check(known._day.state.soul_history[-2].result == "ghost" and known._day.state.soul_history[-1].result == "expired" and not known.risk_model().history.contains("此客不是活人") and not known.risk_model().history.contains("未能辨清"), "scan records remain in state but are absent from item notes")
	var purchased := Fixture.guest(catalog, GhostGuests.CLOSED)
	var seller := CustomerManager.new().active(purchased._day.state)
	check(purchased.counter_command("offer", seller.visit_id, "", seller.trade.asking_price).ok, "buy under no-inspection rule")
	check(purchased.commerce_command("inquire", seller.item.instance_id).ok, "after purchase existing source inquiry works")
	var boundary := Fixture.guest(catalog, GhostGuests.SWAP)
	var boundary_guest := CustomerManager.new().active(boundary._day.state)
	boundary_guest.expires_at = boundary._day.state.game_minutes + 5
	var boundary_cash := boundary._day.state.cash
	check(not boundary.counter_command("swap_accept", boundary_guest.visit_id).ok, "handover cannot finish on departure deadline")
	check(boundary._day.state.cash == boundary_cash and boundary._day.state.exchange_history.is_empty(), "expired handover creates no money or replacement")
	for condition in ["covered", "sold", "late", "depart", "event", "crisis"]:
		var s := Fixture.guest(catalog, GhostGuests.CLOSED)
		var state := s._day.state
		var v := CustomerManager.new().active(state)
		var m := LivingMirror.held(state)
		match condition:
			"covered": s.risk_command("cover", m.instance_id)
			"sold": m.ownership_state = "sold"
			"late": state.game_minutes = run_def.night_minutes - 2; v.expires_at = run_def.night_minutes
			"depart": v.expires_at = state.game_minutes + 3
			"event": state.pending_event_id = "blocked"
			"crisis": state.risk_pending = m.instance_id
		var before := state.game_minutes
		var count := state.soul_history.size()
		check(not s.inspect_customer(v.visit_id).ok, "mirror blocked " + condition)
		check(state.game_minutes == before + (5 if condition == "depart" else 0), "mirror exact time " + condition)
		check(state.soul_history.size() == count + (1 if condition == "depart" else 0), "mirror no invented result")
		if condition == "depart": check(state.soul_history.back().result == "expired", "left during scan")
	for kind in ["observe", "local", "source", "late", "pawn"]:
		var s := Fixture.guest(catalog, GhostGuests.CLOSED)
		var v := CustomerManager.new().active(s._day.state)
		var item := catalog.get_definition("items", v.item.definition_id) as ItemDefinition
		var action := item.appraisal_actions[0]
		if kind == "local":
			for candidate in item.appraisal_actions:
				if not candidate.requires_clues.is_empty(): continue
				action = candidate
		var command := "appraise"
		var detail := String(action.id)
		if kind == "source":
			# Use a normal sourced object to exercise the separate receipt-vs-item route.
			for id in run_def.variety.get("item_ids", []):
				var def := catalog.get_definition("items", id) as ItemDefinition
				if not def.provenance.is_empty(): item = def; break
			if item.provenance.is_empty():
				item = catalog.get_definition("items", "item_folding_fan")
			v.item.definition_id = item.id
			v.item.provenance = {"truth": "authentic", "status": "unchecked", "evidence": [], "investigated": false}
			v.asked_question_ids.append("origin")
			command = "verify_source"; detail = ""
		if kind == "late": s._day.state.game_minutes = run_def.night_minutes - 1; v.expires_at = run_def.night_minutes
		if kind == "pawn": command = "pawn"; detail = ""
		var minute := s._day.state.game_minutes
		var result := s.counter_command(command, v.visit_id, detail, 40 if kind == "pawn" else 0)
		if kind in ["late", "pawn"]:
			check(not result.ok and v.status == "active" and s._day.state.game_minutes == minute, "invalid inspection/pawn has no effect")
		else:
			check(result.ok and v.status == "inspection_refused", "all inspection paths eject " + kind + ": " + result.message)
			check(v.item.revealed_clue_ids.is_empty() and v.item.completed_action_ids.is_empty(), "no evidence after forbidden inspection")
	for disposition in ["redeem", "extend", "keep", "transfer", "future"]:
		var s := Fixture.guest(catalog, GhostGuests.SWAP)
		var state := s._day.state
		var v := CustomerManager.new().active(state)
		var t := GhostGuests.target_ticket(state)
		var principal := t.principal
		check(not s.counter_command("swap_accept", v.visit_id, "", 160).ok, "cannot alter fixed exchange payment")
		check(s.counter_command("swap_accept", v.visit_id).ok, "swap " + disposition)
		var replacement := InventoryManager.new().find(state, t.collateral_id())
		check(InventoryManager.new().find(state, t.item_instance_id).ownership_state == "exchanged_out", "original unavailable")
		check(replacement.instance_id != t.item_instance_id and not replacement.expert_reviewed and replacement.completed_action_ids.is_empty(), "replacement is independent")
		check(not s.sell_batch("buyer_collector", [replacement.instance_id]).ok, "pledged substitute cannot sell")
		state.current_night_index = t.due_night
		state.game_minutes = 0
		state.phase = &"open"
		var terms := catalog.get_definition("pawn_terms", t.terms_id) as PawnTermsDefinition
		if disposition in ["redeem", "extend", "future"]:
			if disposition == "extend": terms._return_mode = "extend_once"
			if disposition == "future": state.current_night_index = 7; t.due_night = 7
			var command := "extend" if disposition == "extend" else "redeem"
			state.pawn_returns.clear()
			state.pawn_returns.append({"id": "unit-return", "ticket_id": t.ticket_id, "customer_id": t.customer_id, "item_instance_id": t.item_instance_id, "person": t.person, "night": state.current_night_index, "command": command, "status": "waiting"})
			check(PawnController.new().execute(s._day, t, terms, command).ok, "current collateral " + disposition)
			terms._return_mode = "redeem"
		else:
			state.phase = &"night_resolution"
			PawnController.new().resolve_maturities(state, 480, catalog, {t.ticket_id: disposition})
		check(t.principal == principal, "principal unchanged")
		if disposition == "future": state.phase = &"run_ended"
		else: state.current_night_index += 1; state.phase = &"pre_open"
		GhostGuests.dawn(state); GhostGuests.dawn(state)
		check(state.person_deaths.size() == (1 if disposition == "redeem" else 0), "only actual redemption next day " + disposition)
		check(replacement.ownership_state == {"redeem": "redeemed", "extend": "pledged", "keep": "owned", "transfer": "transferred", "future": "redeemed"}[disposition], "physical disposition")
	var s := Fixture.before(catalog, func(session: RunSession, row: Dictionary) -> bool: return session._day.state.current_night_index == 6 and row.method == "execute" and row.args[0] == "continue_run")
	var before := s.read_state()
	s._save = FailingStore.new()
	check(not s.execute("continue_run").ok, "failed save")
	check(GhostSaveCodec.same(before, s.read_state()), "failed save restores death/date/money/inventory/journal")
	s._save = GhostReplayStore.new()
	check(s.execute("continue_run").ok and s._day.state.person_deaths.size() == 1, "retry delivers once")
	var data := SaveCodec.new().encode(s._day.state, 22)
	for field in ["amount", "replacement", "date", "notice"]:
		var forged := data.duplicate(true)
		match field:
			"amount": forged.exchange_history[0].amount = 160
			"replacement": forged.pawn_tickets[0].replacement_instance_id = forged.pawn_tickets[0].item_instance_id
			"date": forged.pawn_tickets[0].closed_night = 5
			"notice": forged.person_deaths[0].night = 6
		check(SaveCodec.new().decode(forged, run_def, 22, catalog) == null, "reject forged " + field)
	print("LIVING EDGES: %d passes, %d failures" % [passes, failures])
	quit(0 if failures == 0 else 1)
