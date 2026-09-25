extends "res://tests/gramophone_appraisal.gd"

func sample(kind: String, cid: String, mode: String) -> RunSession:
	var item_id := CameraEconomy.ITEM if kind == "camera" else GramophoneEconomy.ITEM
	var s := unit_visit(cid,item_id,"flawed",mode)
	equip(s,2)
	var v: CustomerVisit = s._day.state.visits[0]
	v.item.goods.precision = {"damage":"major","hidden":false}
	if kind == "camera":
		v.item.goods.camera_value = {"identity":"imitation","lens":"scratched","mechanism":"stuck","fault_at":"both","actual":20}
		CameraEconomy.prepare(s._day.state,v)
	else:
		v.item.goods.gramophone_value = {"identity":"imitation","sound":"muffled","motor":"stopping","initial_wound":false,"record_worn":false,"actual":16}
		GramophoneEconomy.prepare(s._day.state,v)
	return s

func bargain(s: RunSession, kind: String) -> void:
	var v: CustomerVisit = s._day.state.visits[0]
	var o := CameraEconomy.owner(s._day.state,v) if kind == "camera" else GramophoneEconomy.owner(s._day.state,v)
	o.rate = 60; o.urgent = true
	o.belief = {"identity":"original","lens":"clear","mechanism":"smooth"} if kind == "camera" else {"identity":"original","sound":"clear","motor":"steady"}
	if kind == "camera":
		CameraEconomy.reprice_initial(s._day.state,v); CameraNegotiation.prepare(s._day.state,v)
	else:
		GramophoneEconomy.reprice_initial(s._day.state,v); GramophoneNegotiation.prepare(s._day.state,v)
	var n := CameraNegotiation.data(s._day.state,v) if kind == "camera" else GramophoneNegotiation.data(s._day.state,v)
	n.personality = "easy"
	for part in n.rolls: n.rolls[part] = 0
	begin(s)
	if kind == "gramophone": check(ca(s,{"op":"listen"}).ok,"listen before claims")
	else:
		check(s.fan_command("luxury_camera",v.item.instance_id,'{"op":"group","group":"lens"}').ok,"view lens")
		check(s.fan_command("luxury_camera",v.item.instance_id,'{"op":"shutter"}').ok,"test mechanism")
	var claims := {"identity":"imitation","lens":"scratched","mechanism":"stuck"} if kind == "camera" else {"identity":"imitation","sound":"muffled","motor":"stopping"}
	var result := s.counter_command(kind+"_claim",v.visit_id,JSON.stringify(claims))
	check(result.ok,"all claims submitted "+result.message)
	check(result.message.contains("最低") or result.message.contains("至少得筹"),"floor explanation on concession")

func run() -> void:
	if not setup(): quit(1); return
	for kind in ["camera","gramophone"]:
		for cid in WealthyCustomers.NAMES:
			for mode in ["sell","pawn"]:
				var s := sample(kind,cid,mode)
				var v: CustomerVisit = s._day.state.visits[0]
				var minimum := maxi(120 if kind == "camera" else 100,int(WealthyCustomers.trade(s._day.state,v).funding))
				var fixed := v.item.goods.duplicate(true)
				bargain(s,kind)
				check(v.trade.asking_price == minimum and v.trade.reserve_price == minimum,"maximum concession stops at floor "+kind+cid+mode)
				check(s.counter_command("intimidate",v.visit_id).ok == false,"no free intimidation without plaque")
				s._day.state.social.plaque_awarded = true
				check(s.counter_command("intimidate",v.visit_id).ok,"plaque action")
				check(v.trade.asking_price == minimum and v.trade.reserve_price == minimum,"plaque cannot bypass floor")
				# Deliberately stale quoted values cannot bypass settlement checks.
				v.trade.reserve_price = 1; v.trade.asking_price = 1
				var cash := s._day.state.cash
				var command := "pawn" if mode == "pawn" else "offer"
				var rejected := s.counter_command(command,v.visit_id,"medium" if command == "pawn" and PawnInterestPolicy.enabled(run_def) else "",minimum-1)
				check(rejected.ok and v.status == "active" and s._day.state.cash == cash,"below floor refused without acquisition or payment")
				check(rejected.message.contains(str(minimum)),"refusal states minimum")
				check(v.trade.reserve_price >= minimum and v.trade.asking_price >= minimum,"settlement restores floor")
				var before := s.read_state(); (s._save as CountingStore).fail = true
				check(not s.counter_command(command,v.visit_id,"medium" if command == "pawn" and PawnInterestPolicy.enabled(run_def) else "",minimum).ok and before == s.read_state(),"floor trade save failure rolls back")
				(s._save as CountingStore).fail = false
				v = s._day.state.visits[0]
				check(s.counter_command(command,v.visit_id,"medium" if command == "pawn" and PawnInterestPolicy.enabled(run_def) else "",minimum).ok,"floor price can trade")
				check(v.status == ("pawned" if mode == "pawn" else "bought") and s._day.state.cash == cash-minimum,"actual settlement at minimum")
				check(v.item.goods == fixed,"fixed real value independent of seller minimum")
				for buyer_id in run_def.buyer_ids:
					var buyer: BuyerDefinition = catalog.get_definition("buyers",buyer_id)
					var actual: int = fixed[kind+"_value"].actual
					check(s._commerce.base_quote(v.item,buyer) == maxi(1,roundi(actual*buyer.value_multiplier)),"resale does not inherit seller floor")
	# v43 content has no floor; other luxury goods are not silently rebalanced.
	var old := JsonContentProvider.new("res://data/camera_manifest.json").load_catalog()
	var old_state := RunState.create(old.catalog.get_definition("runs",old.catalog.default_run_id)); old_state.ghost_catalog = old.catalog
	var v := CustomerVisit.new(); v.item = ItemInstance.new(); v.item.definition_id = CameraEconomy.ITEM
	check(WealthyCustomers.item_minimum(old_state,v) == 0,"old camera entry retains original semantics")
	var s := sample("camera","customer_wealthy_antique","sell")
	v = s._day.state.visits[0]; v.item.definition_id = PearlEconomy.ITEM
	check(WealthyCustomers.item_minimum(s._day.state,v) == 0,"other goods unchanged")
	print("LUXURY MINIMUM: %d passes, %d failures" % [passes,failures]); quit(0 if failures == 0 else 1)
