extends "res://tests/special_guests_rules.gd"

func run() -> void:
	var loaded := JsonContentProvider.new("res://data/special_guests_manifest.json").load_catalog()
	catalog = loaded.catalog; run_def = catalog.get_definition("runs", catalog.default_run_id)
	driver.check = check; driver.catalog = catalog
	matrix()
	save_guards()
	closed_edges()
	scheduling()
	swap_edges()
	print("SPECIAL GUEST EDGES: %d passes, %d failures" % [passes, failures])
	quit(0 if failures == 0 else 1)

func matrix() -> void:
	var s := fresh_special()
	for kind in ["one_quote", "wet_cloth"]:
		for id in SpecialGuests.ORDINARY + SpecialGuests.LUXURY:
			var definition := catalog.get_definition("items",id) as ItemDefinition
			for variant in definition.possible_variants:
				s = fresh_special()
				var v := SpecialGuestsPreview.apply(s,kind,id,variant.id)
				var label: String = kind + "/" + id + "/" + variant.id
				check(v.item.selected_variant_id == variant.id,"truth retained " + label)
				check(v.transaction_modes == ["sell"],"sale only " + label)
				check(s.counter_model().visual.customer_name == "？？？","all goods anonymous " + label)
				var ask := v.trade.asking_price
				if kind == "one_quote": check(ask == maxi(1,roundi(definition.base_value*.9)),"hat price " + label)
				else:
					var normal := roundi(definition.base_value * 1.2)
					if id == CoatProcurement.ITEM: normal = roundi(float(SocialRules.config().coat.sound_value if variant.id == "sound" else SocialRules.config().coat.worn_value)*1.2)
					if WealthyCustomers.is_item(id):
						v.customer_id = "customer_wealthy_silk"; WealthyCustomers.prepare(s._day.state,v)
						normal = v.trade.opening_price; v.customer_id = "customer_citizen"
						SpecialGuests.prepare(s._day.state,v,VarietySaveCodec.selection(s._day.state,v.visit_id),definition)
					check(ask == maxi(1,roundi(normal*.5)),"wet half normal " + label)
				check(v.trade.reserve_price == maxi(1,roundi(ask*.85)),"reserve rule " + label)
				var snapshot := s.read_state()
				s.counter_model(); s.economy_model()
				check(snapshot == s.read_state(),"view/cancel never quote " + label)
				if WealthyCustomers.is_item(id):
					check(s.counter_command("luxury_exterior",v.visit_id).ok,"exterior " + label)
					var begin := s.fan_command("luxury_begin",v.item.instance_id,"2")
					check(begin.ok,"existing appraisal desk " + label + ": " + begin.message)
					check(v.trade.asking_price == ask and v.trade.rounds_left == (1 if kind == "one_quote" else 3),"appraisal retains price and quota " + label)
				var facts := v.item.goods.duplicate(true)
				var value := GoodsExpertise.value(v.item,definition)
				var cash := s._day.state.cash
				var failing := FailingStore.new(); failing.origin = s._day.state.ghost_origin.duplicate(true); failing.fail = true; s._save = failing
				var before_purchase := s.read_state()
				check(not s.counter_command("offer",v.visit_id,"",ask).ok and before_purchase == s.read_state(),"save failure rolls back all goods " + label)
				failing.fail = false; v = s._counter.customers.active(s._day.state)
				check(s.counter_command("offer",v.visit_id,"",ask).ok and v.item.ownership_state == "owned","buy " + label)
				check(s._day.state.cash == cash-ask and v.item.goods == facts and GoodsExpertise.value(v.item,definition) == value,"purchase retains value " + label)
				check(SpecialGuests.held_items(s._day.state).size() == (1 if kind == "wet_cloth" else 0),"instance ownership " + label)
				if kind == "wet_cloth":
					s._day.state.shop_growth.display_id = v.item.instance_id
					check(SpecialGuests.held_items(s._day.state) == [v.item.instance_id],"display held " + label)
				var buyer_id := ""
				for key in run_def.buyer_ids:
					if s._commerce.sale_reason(s._day,v.item,catalog.get_definition("buyers",key)).is_empty(): buyer_id = key; break
				check(not buyer_id.is_empty(),"resale channel " + label)
				if not buyer_id.is_empty():
					check(s.commerce_command("sell",v.item.instance_id,buyer_id).ok,"resale " + label)
					check(SpecialGuests.held_items(s._day.state).is_empty(),"sold sound stops " + label)
	# Insufficient money and rejected quotation never create a purchased instance.
	for id in SpecialGuests.ORDINARY + SpecialGuests.LUXURY:
		s = fresh_special()
		var v := SpecialGuestsPreview.apply(s,"one_quote",id)
		s._day.state.cash = 0; var snapshot := s.read_state()
		check(not s.counter_command("offer",v.visit_id,"",v.trade.asking_price).ok and snapshot == s.read_state(),"money failure atomic " + id)
		s._day.state.cash = 6000
		v = s._counter.customers.active(s._day.state)
		check(s.counter_command("offer",v.visit_id,"",1).ok and v.status != "active","one failed quote leaves " + id)
		check(s._day.state.inventory_instances.is_empty(),"failed quote no goods " + id)
	SpecialGuestsPreview.bedroom(s)
	var held := s._day.state.inventory_instances[0]
	var regular := ItemInstance.new(); regular.instance_id = "ordinary-same-name"; regular.definition_id = held.definition_id
	regular.acquisition_type = "purchase"; regular.ownership_state = "owned"; s._day.state.inventory_instances.append(regular)
	for status in ["owned","sold","delivered","exchanged_out","lost"]:
		held.ownership_state = status
		check(SpecialGuests.held_items(s._day.state) == ([held.instance_id] if status == "owned" else []),"source instance only " + status)

func closed_edges() -> void:
	var s := fresh_special()
	for stage in 3:
		for action in ["reject","appraise","offer","shop_closed","timed_out"]:
			var v := SpecialGuestsPreview.apply(s,"closed")
			var d := SpecialGuests.data(s._day.state); d.closed_stage = stage; d.closed_due = [4,8,15][stage]
			if action in ["shop_closed","timed_out"]: CustomerManager.new().finish(s._day.state,v,action)
			else:
				var detail := ""
				if action == "appraise": detail = (catalog.get_definition("items",v.item.definition_id) as ItemDefinition).appraisal_actions[0].id
				check(s.counter_command(action,v.visit_id,detail,1).ok,"closed interruption " + action)
			check(d.closed_failed and int(d.closed_stage) == stage,"chain broken stage %d %s" % [stage,action])
			check(SpecialGuests.QUEST_FLAG not in s._day.state.narrative_flags,"no failed eligibility")
		var v := SpecialGuestsPreview.apply(s,"closed")
		var d := SpecialGuests.data(s._day.state); d.closed_stage = stage; d.closed_due = [4,8,15][stage]
		s._day.state.current_night_index = d.closed_due
		MilitaryService.suspend(s._day)
		check(v.status == "suspended" and not d.closed_failed and int(d.closed_due) == s._day.state.current_night_index+1,"forced closure defers stage%d" % stage)
		# A second forced closure defers again, never records a refusal.
		s._day.state.current_night_index += 1; SpecialGuests.suspend(s._day.state)
		check(int(d.closed_due) == s._day.state.current_night_index+1,"repeat closure defers")
	var v := SpecialGuestsPreview.apply(s,"closed")
	SpecialGuests.data(s._day.state).closed_stage = 2
	CustomerManager.new().finish(s._day.state,v,"bought"); CustomerManager.new().finish(s._day.state,v,"bought")
	check(SpecialGuests.data(s._day.state).closed_stage == 3 and s._day.state.narrative_flags.count(SpecialGuests.QUEST_FLAG) == 1,"eligibility idempotent")

func scheduling() -> void:
	var s := fresh_special(); var state := s._day.state
	state.current_night_index = 8; var d := SpecialGuests.data(state)
	d.closed_stage = 1; d.closed_due = 8
	var fixed := {"night":8,"visit_id":"protected","arrival":300,"customer_id":"customer_citizen","context_id":"story","seven_role":"story","person":{"name":"故事人物"}}
	var rows: Array[Dictionary] = [fixed]
	var result := SpecialGuests.overlay(state,run_def,catalog,rows)
	check(fixed in result and result.size() == 2,"full roster retains story and bundle appointment")
	state.shop_growth.special_guests = SpecialGuests.initial(); d = SpecialGuests.data(state)
	d.closed_failed = true; d.targets = {"wet":6,"hat/0":6,"hat/1":12,"hat/2":18}
	state.current_night_index = 6
	var blocked: Array[Dictionary] = [{"night":6,"visit_id":"reserved","arrival":100,"context_id":"story","seven_role":"story"}]
	check(SpecialGuests.overlay(state,run_def,catalog,blocked) == blocked,"no protected replacement")
	state.current_night_index = 7
	var free := {"night":7,"visit_id":"free","arrival":100,"customer_id":"customer_citizen","context_id":"ordinary"}
	var available_rows: Array[Dictionary] = [free, {"night":7,"visit_id":"free2","arrival":200,"customer_id":"customer_citizen","context_id":"ordinary"}]
	result = SpecialGuests.overlay(state,run_def,catalog,available_rows)
	check(result.all(func(r:Dictionary)->bool:return r.has("special_key")),"missed hat and wet defer inside window")
	state.current_night_index = 19
	var expired: Array[Dictionary] = [{"night":19,"visit_id":"late","arrival":100,"customer_id":"customer_citizen","context_id":"ordinary"}]
	check(SpecialGuests.overlay(state,run_def,catalog,expired) == expired,"expired windows do not recover")

func swap_edges() -> void:
	var s := fresh_special(); var state := s._day.state
	var accepted := 0
	var repeated := 0
	var visitor := CustomerVisit.new()
	for seed_value in 10000:
		state.run_seed = seed_value; state.current_night_index = 12; SpecialGuests.data(state).swap_rolls.clear()
		if SpecialGuests.swap_roll(state,visitor): accepted += 1
		if SpecialGuests.swap_roll(state,visitor): repeated += 1
	check(repeated == 0,"one draw per night over 10000 seeds")
	check(accepted > 1750 and accepted < 2250,"swap 20 percent")
	for n in [4,13]:
		state.current_night_index = n; SpecialGuests.data(state).swap_rolls.clear()
		check(not SpecialGuests.swap_roll(state,visitor) and SpecialGuests.data(state).swap_rolls.is_empty(),"swap boundary no draw")

	for seed_value in 2:
		for accept in [false,true]:
			for n in [5,12]:
				s = fresh_special(); state = s._day.state
				var v := SpecialGuestsPreview.apply(s,"one_quote","item_blue_bowl")
				state.current_night_index = n; state.game_minutes = 310
				v.person = {"id":"ordinary","name":"王先生"}; v.night_policy = ""; v.arrival = 300; v.expires_at = 420
				v.visit_id = "%s/%d/%s" % [run_def.id,n,run_def.customer_slots.back().id]
				state.ordinary_selections.assign([{"visit_id":v.visit_id,"night":n,"context_id":"ordinary","customer_id":"customer_citizen"}])
				state.run_seed = seed_value
				while (VarietyService.rng(state.run_seed,"special/swap/%d" % n).randi_range(0,99) < 20) != (seed_value == 0): state.run_seed += 1
				GhostGuests.arrive(state,v)
				check(state.ghost_visits.is_empty() and SpecialGuests.data(state).swap_rolls.is_empty(),"no collateral no draw")
				var item := ItemInstance.new(); item.instance_id = "pledged"; item.definition_id = "item_blue_bowl"; item.selected_variant_id = "sound"; item.ownership_state = "pledged"
				state.inventory_instances.append(item)
				var ticket := PawnTicket.new(); ticket.ticket_id = "ticket"; ticket.item_instance_id = item.instance_id; ticket.principal = 20; ticket.due_night = 18; ticket.customer_id = "customer_citizen"; ticket.terms_id = "sample_three_redeem"
				state.pawn_tickets.append(ticket)
				OpeningPreparation.plan(state,run_def,catalog)
				SocialRules.night(state).closed = true
				GhostGuests.arrive(state,v)
				check(SpecialGuests.data(state).swap_rolls.is_empty(),"closed night no draw")
				SocialRules.night(state).closed = false
				GhostGuests.arrive(state,v)
				check(state.ghost_visits.size() == (1 if seed_value == 0 else 0),"actual swap chance night%d" % n)
				if seed_value == 0:
					check(v.person.name == "？？？" and s.counter_model().visual.customer_name == "？？？","swap anonymous everywhere")
					var cash := state.cash
					check(GhostGuests.exchange(s._day,catalog,v.visit_id,accept).ok,"swap decision")
					check(state.cash == cash + (80 if accept else 0),"80 silver only on accept")
					check(item.ownership_state == ("exchanged_out" if accept else "pledged"),"exchange original custody")
				var another := CustomerVisit.new(); another.visit_id = v.visit_id; another.arrival = 300
				state.current_night_index = mini(12,n+1) if seed_value == 0 else n; GhostGuests.arrive(state,another)
				check(another.customer_id != GhostGuests.SWAP,"actual appearance never repeats")

func save_guards() -> void:
	var s := fresh_special(); var codec := SaveCodec.new()
	var original := codec.encode(s._day.state,44)
	for field in ["closed_stage","closed_failed","seen","swap_rolls","targets","plans","history"]:
		var changed := original.duplicate(true)
		changed.shop_growth.special_guests[field] = 3 if field == "closed_stage" else true if field == "closed_failed" else ["forged"] if field == "history" else {"forged":1}
		check(codec.decode(changed,run_def,44,catalog,true) == null,"corrupt progress rejected " + field)
	var changed := original.duplicate(true); changed.narrative_flags.append(SpecialGuests.QUEST_FLAG)
	check(codec.decode(changed,run_def,44,catalog,true) == null,"forged eligibility rejected")
