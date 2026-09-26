extends "res://tests/medicine_huaian_v47.gd"

func fresh_special(seed_value := 42) -> RunSession:
	var store := FailingStore.new(); store.origin = {"seed":seed_value,"run_token":"0123456789abcdef0123456789abcdef"}
	return RunSession.new(run_def,catalog.content_version,store,catalog)

func verify(s: RunSession, label: String) -> void:
	InvestigationSaveCodec.clear_cache()
	var codec := SaveCodec.new(); var payload := codec.encode(s._day.state,catalog.content_version)
	var restored := codec.decode(payload,run_def,catalog.content_version,catalog,true)
	check(restored != null,"cold replay " + label + " " + codec.error_message)
	if restored != null: check(GhostSaveCodec.same(restored.to_read_model(),s.read_state()),"exact replay " + label)

func run() -> void:
	var loaded := JsonContentProvider.new("res://data/town_life_v50_manifest.json" if "v50" in OS.get_cmdline_user_args() else "res://data/town_life_v49_manifest.json" if "v49" in OS.get_cmdline_user_args() else "res://data/town_life_manifest.json").load_catalog()
	for issue in loaded.issues: print(issue.format_message())
	check(loaded.is_success(),"town content")
	if not loaded.is_success(): quit(1); return
	catalog = loaded.catalog; run_def = catalog.get_definition("runs",catalog.default_run_id)
	driver.check = check; driver.catalog = catalog
	if "journey" in OS.get_cmdline_user_args():
		run_def._initial_cash = 6000
		for mode in ["early","short"]: journey(mode)
	else:
		profession_rules(); goods_rules(); military_rules(); distribution(); privacy(); special_prices()
	print("TOWN LIFE: %d passes, %d failures" % [passes,failures])
	quit(0 if failures == 0 else 1)

func profession_rules() -> void:
	for minute in [0,10,15,16,20]:
		var s := fresh_special(); var v := TownLifePreview.apply(s,"porter")
		s._day.state.game_minutes = minute
		var price := TownLife.fast_price(s._day.state,v)
		check(s.counter_command("offer",v.visit_id,"",price).ok,"porter formal quote")
		check((v.status == "bought") == (minute <= 15),"porter submission boundary " + str(minute))
		check(s._day.state.game_minutes == minute+5,"quote costs five minutes")
	var s := fresh_special(); var v := TownLifePreview.apply(s,"porter")
	check(s.counter_command("offer",v.visit_id,"",1).ok,"first offer refused")
	check(not TownLife.fast_available(s._day.state,v),"failed first offer consumes discount")
	check(s.counter_command("offer",v.visit_id,"",TownLife.fast_price(s._day.state,v)).ok and v.status != "bought","second quote regular floor")
	s=fresh_special();v=TownLifePreview.apply(s,"porter","kerosene_lamp","flawed")
	s.counter_command("appraise",v.visit_id,"observe");s.counter_command("appraise",v.visit_id,"inspect")
	check(s.counter_command("pressure",v.visit_id,"flawed").ok,"use actual evidence")
	check(v.trade.reserve_price < TownLife.fast_price(s._day.state,v),"evidence lower legal price")
	check(s.counter_command("offer",v.visit_id,"",v.trade.reserve_price).ok and v.status == "bought","discount does not undo evidence")
	s=fresh_special();v=TownLifePreview.apply(s,"musician")
	check(not s.counter_command("offer",v.visit_id,"",100).ok,"erhu sale blocked")
	check(s.counter_command("pawn",v.visit_id,"high",100).ok and v.status == "active","erhu refuses high interest")
	check(s.counter_command("pawn",v.visit_id,"medium",100).ok and v.status == "pawned","erhu medium pawn")
	for condition in ["sound","worn","flawed"]:
		s=fresh_special();v=TownLifePreview.apply(s,"washerwoman","padded_vest",condition)
		var before := v.trade.patience
		check(s.counter_command("question",v.visit_id,TownLife.REPAIR).ok,"repair question")
		check(condition in v.item.revealed_clue_ids and v.item.revealed_clue_ids.size()==1,"one truthful condition")
		check(v.trade.patience==before and s._day.state.game_minutes==5,"no patience loss")
		check(not s.counter_command("question",v.visit_id,TownLife.REPAIR).ok,"cannot repeat repair question")
	for relation in [-20,0,20]:
		s=fresh_special();v=TownLifePreview.apply(s,"soldier","leather_suitcase","sound",relation)
		var expected := roundi(55*(1.5 if relation==-20 else 1.35 if relation==0 else 1.15))
		check(v.trade.opening_price==expected,"soldier price band")
		check(v.trade.patience==(1 if relation==-20 else 2),"soldier patience band")
		var snapshot := s.read_state();s.counter_model();s.counter_model()
		check(snapshot==s.read_state(),"UI reads stable")
		s._day.state.social.military=100;TownLife.activate(s._day.state,v)
		check(v.trade.opening_price==expected,"attitude fixed on arrival")
		check(s.counter_command("reject",v.visit_id).ok and s._day.state.social.military==100,"rejection no new military penalty")
	for profession in TownLife.PROFESSIONS.map(func(id:String)->String:return id.trim_prefix("customer_")):
		s=fresh_special();v=TownLifePreview.apply(s,profession)
		MilitaryService.suspend(s._day)
		check(v.status=="suspended","military closes ordinary town visit "+profession)
		check(s._counter.customers.active(s._day.state)==null,"no ordinary visitor after forced closure")
	print("profession boundaries checked")

func goods_rules() -> void:
	for id in TownLife.items(run_def):
		var item := catalog.get_definition("items",id) as ItemDefinition
		for variant in item.possible_variants:
			var s := fresh_special();var v := TownLifePreview.apply(s,"goods",id,variant.id)
			check(s.counter_command("appraise",v.visit_id,"observe").ok,"observe "+id)
			check(s.counter_command("appraise",v.visit_id,"inspect").ok,"inspect "+variant.id)
			check(variant.id in v.item.revealed_clue_ids,"true condition "+id)
			check(s.counter_command("offer",v.visit_id,"",100).ok and v.status=="bought","purchase "+id)
			s._day.state.phase=&"pre_open";s._day.state.game_minutes=0
			check(s.sell_batch(RecyclerPolicy.BUYER,[v.item.instance_id]).ok,"normal sale command "+id)
			check(v.item.ownership_state=="sold","sell "+id)
			check(CounterItemArt.front_path(item.visual_asset_id).ends_with(".png"),"painted asset")
	var generated := {};var high:=0
	for seed_value in 3000:
		var id := SpecialGuests.pick_item(seed_value,"town-pool",80,TownLife.items(run_def))
		generated[id]=true
		if id in SpecialGuests.LUXURY: high+=1
	check(generated.size()==29 and high>500 and high<700,"expanded special pool keeps 80/20")
	for id in TownLife.items(run_def):check(id in MedicineStory.pool(run_def,catalog),"medicine pool "+id)

func military_rules() -> void:
	for coats in range(4):
		var s := fresh_special();TownLifePreview.apply(s,"military")
		var state:=s._day.state;state.inventory_instances.clear();var ids:Array=[]
		for i in 3:
			var item:=ItemInstance.new();item.instance_id="mix/"+str(i);item.definition_id=CoatProcurement.ITEM if i<coats else "item_padded_vest";item.selected_variant_id="sound" if i%2==0 else "worn";state.inventory_instances.append(item);ids.append(item.instance_id)
			var source:=CustomerVisit.new();source.visit_id="military-source/"+str(i);source.customer_id="customer_soldier";source.item=item;TownLife.register_origin(state,source)
		var history:Dictionary=state.shop_growth.town_life.origins.duplicate(true)
		var detail:=JSON.stringify({"ids":ids,"order":1});var cash:=state.cash
		check(s.social_command("deliver",detail).ok,"mixed combination "+str(coats))
		check(state.cash==cash+50 and CoatProcurement.stock(state).is_empty(),"single payout")
		check(history==state.shop_growth.town_life.origins,"military delivery retains source history")
		check(not s.social_command("deliver",detail).ok,"repeat delivery denied")
	var s:=fresh_special();TownLifePreview.apply(s,"military");var state:=s._day.state
	check(CoatProcurement.stock(state).size()==3,"exclude torn and pledged vest")
	for ids in [["town-preview/clothing/0","town-preview/clothing/0","town-preview/clothing/1"],["town-preview/clothing/0","town-preview/clothing/1","town-preview/clothing/3"],["town-preview/clothing/0","town-preview/clothing/1","town-preview/clothing/4"]]:
		var before:=s.read_state();check(not s.social_command("deliver",JSON.stringify({"ids":ids,"order":1})).ok,"invalid selection denied");check(before==s.read_state(),"invalid delivery atomic")
	var store:=FailingStore.new();store.origin=state.ghost_origin.duplicate(true);store.fail=true;s._save=store
	var before:=s.read_state();var ids:=CoatProcurement.stock(state).map(func(i:ItemInstance)->String:return i.instance_id)
	check(not s.social_command("deliver",JSON.stringify({"ids":ids,"order":1})).ok,"save failure returned")
	check(GhostSaveCodec.same(before,s.read_state()),"failed military settlement rolls back all")

func distribution() -> void:
	var counts:Dictionary={};var candidate:Array=[]
	for c in run_def.variety.customer_ids:
		for i in (10 if c=="customer_porter" else 1):candidate.append({"customer_id":c,"item_id":str(i),"context_id":"test"})
	for seed_value in 12000:
		var row:=TownLife.pick_candidate(candidate,seed_value,"equal");counts[row.customer_id]=int(counts.get(row.customer_id,0))+1
	for c in counts:check(int(counts[c])>850 and int(counts[c])<1150,"profession equal weight "+c)
	for item_id in TownLife.items(run_def):
		var item:=catalog.get_definition("items",item_id) as ItemDefinition;var variants:Dictionary={}
		for seed_value in 2000:
			var id:=TownLife.variant(item,seed_value,"weights");variants[id]=int(variants.get(id,0))+1
		check(int(variants.get("sound",0))>1080 and int(variants.get("sound",0))<1320,"60% sound "+item_id)
		check(int(variants.get("flawed",0))>140 and int(variants.get("flawed",0))<260,"10% flawed "+item_id)
	var supply_session:=fresh_special();var supply:=supply_session._day.state
	var channel:Array[Dictionary]=[]
	for i in 5000:channel.append({"visit_id":"supply/"+str(i),"context_id":"ordinary","customer_id":"customer_soldier","item_id":"item_pocket_watch","variant_id":"sound"})
	CoatProcurement.overlay(supply,channel)
	var selected:=channel.filter(func(row:Dictionary)->bool:return row.get("coat_assigned",false))
	check(selected.size()>880 and selected.size()<1120,"one 20% clothing supply channel")
	var vests:=selected.filter(func(row:Dictionary)->bool:return row.item_id=="item_padded_vest").size()
	check(vests>selected.size()*.43 and vests<selected.size()*.57,"half coats half vests")
	check(selected.all(func(row:Dictionary)->bool:return row.variant_id in ["sound","worn"]),"supply clothing always wearable")
	var frozen:=channel.duplicate(true);CoatProcurement.overlay(supply,channel)
	check(channel==frozen,"supply channel does not double draw")
	for seed_value in 8:
		var rows:=SevenNightPlan.plan(run_def,catalog,seed_value)
		check(rows.all(func(row:Dictionary)->bool:return row.night>=3 or row.customer_id not in TownLife.PROFESSIONS),"third-night unlock")

func privacy() -> void:
	var s:=fresh_special();var v:=TownLifePreview.apply(s,"soldier");var state:=s._day.state;var stolen:=0
	for i in 2000:
		v.visit_id="origin-test/"+str(i);v.item.instance_id="item/"+v.visit_id;TownLife.register_origin(state,v)
		var record:=TownLife.internal_origin(state,v.item.instance_id)
		if record.kind=="looted_from_dead":stolen+=1
		TownLife.register_origin(state,v);check(record==TownLife.internal_origin(state,v.item.instance_id),"origin stable")
	check(stolen>330 and stolen<470,"20% hidden origin")
	var internal:=TownLife.internal_origin(state,v.item.instance_id)
	var before:=JSON.stringify(s.counter_model());state.shop_growth.town_life.origins[v.item.instance_id].kind="ordinary" if internal.kind=="looted_from_dead" else "looted_from_dead"
	check(JSON.stringify(s.counter_model())==before,"secret has no player-model effect")
	for token in ["looted_from_dead","source_customer","source_person","origins"]:check(not before.contains(token),"secret excluded "+token)
	var record:=TownLife.internal_origin(state,v.item.instance_id)
	InventoryManager.new().acquire(state,v.item,v.visit_id,20)
	var owned_model:=JSON.stringify(s.counter_model())
	state.shop_growth.town_life.origins[v.item.instance_id].kind=internal.kind
	check(JSON.stringify(s.counter_model())==owned_model,"owned inventory ledger and appraisal hide secret")
	state.shop_growth.town_life.origins[v.item.instance_id]=record
	CommerceService.commit_sale(state,v.item,"buyer_recycler",25,"origin-sale")
	check(record==TownLife.internal_origin(state,v.item.instance_id),"history retained after disposal")

func special_prices() -> void:
	for policy in ["one_quote","wet_cloth"]:
		for id in SpecialGuests.LUXURY:
			var s:=fresh_special();var v:=SpecialGuestsPreview.apply(s,policy,id)
			check(WealthyCustomers.item_minimum(s._day.state,v)==0,"special wealthy minimum bypass "+id)
			var initial:=v.trade.asking_price
			var item:=catalog.get_definition("items",id) as ItemDefinition
			if policy=="one_quote":check(initial==maxi(1,roundi(item.base_value*.9)),"hat authored price")
			check(not s._counter.reason(s._day,"gramophone_claim",v.visit_id,"{}",0).is_empty(),"no extra gramophone claim")
			check(s.counter_command("offer",v.visit_id,"",v.trade.reserve_price).ok and v.status=="bought","special sale settles at its own floor "+id)
	var s:=fresh_special();var v:=TownLifePreview.apply(s,"porter")
	var store:=FailingStore.new();store.origin=s._day.state.ghost_origin.duplicate(true);store.fail=true;s._save=store
	var before:=s.read_state()
	check(not s.counter_command("offer",v.visit_id,"",TownLife.fast_price(s._day.state,v)).ok,"failed purchase save")
	check(GhostSaveCodec.same(before,s.read_state()),"purchase restores discount money and item on failure")
