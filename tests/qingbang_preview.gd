extends RefCounted
# Debug-only, memory-only scenarios. Normal entry never calls this helper.
class MemoryStore extends GhostReplayStore:
	func save_state(_s: RunState,_r: RunDefinition,_v: int) -> bool: return true
static func apply(s: RunSession,stage: String) -> void:
	var store := MemoryStore.new()
	store.origin = s._day.state.ghost_origin.duplicate(true)
	s._save = store
	var state := RunState.create(s.definition)
	state.ghost_catalog = s._counter.catalog
	state.run_seed = 42
	state.cash = 300
	state.current_night_index = 4 if stage == "intro" else 5 if stage == "fee" else 6
	state.social.introduced = true
	state.social.intro_step = 3
	state.social.nights.append({"night":state.current_night_index,"military_checked":true,"closed":false,"reputation":0,"adjustment":0,"removed":[],"added":[]})
	state.narrative_flags.append_array(["fd_mother_gone","lu_introduced"])
	s._day.state = state
	var q: Dictionary = state.social.qingbang
	q.introduced = stage != "intro"
	q.next_fee = 5 if stage == "intro" else 13
	var id := "qingbang/preview/" + stage
	match stage:
		"intro": q.dialogue = {"id":id,"kind":"intro","step":0}
		"fee":
			q.next_fee=13
			q.pending={"kind":"fee","id":id,"night":5,"cost":80}
			q.dialogue={"id":id,"kind":"fee","step":0}
		"raid","pawn":
			q.relation=-20
			for i in 3:
				var item := ItemInstance.new()
				item.instance_id="preview/item/%d" % i;item.definition_id="item_fountain_pen";item.selected_variant_id="sound";item.acquisition_price=20
				item.ownership_state="pledged" if i==0 else "owned"
				state.inventory_instances.append(item)
			var ticket := PawnTicket.new()
			ticket.ticket_id="preview/ticket";ticket.item_instance_id="preview/item/0";ticket.source_visit_id="preview/visit";ticket.customer_id="customer_hawker";ticket.person={"id":"preview/person","name":"周掌柜","portrait":"asset.customer_hawker"};ticket.terms_id="sample_three_redeem";ticket.principal=20;ticket.redemption_amount=22;ticket.started_night=3;ticket.due_night=6
			state.pawn_tickets.append(ticket)
			state.phase=&"open"
			q.dialogue={"id":id,"kind":"raid","step":0,"items":["preview/item/0","preview/item/1"]}
			if stage=="pawn":
				QingbangDamage.apply(state,q.dialogue);q.dialogue={}
				PawnReturnService.prepare(state,state.ghost_catalog);PawnReturnService.arrive(state)
		"supply":
			var offer: Dictionary = QingbangRules.config().supplies[1].duplicate(true)
			q.pending={"kind":"supply","id":id,"offer":offer}
		"inquiry":
			var item := ItemInstance.new()
			item.instance_id="preview/inquiry";item.definition_id="item_fountain_pen";item.selected_variant_id="sound";item.acquisition_price=20
			state.inventory_instances.append(item)
	s.message=""
	s.restored.emit();s.changed.emit()
