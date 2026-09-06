class_name MarketTests
extends VarietyTests

var report: Array = []

func run(expect: Callable) -> void:
	_expect = expect
	var loaded := JsonContentProvider.new("res://data/content_manifest.json").load_catalog()
	_expect.call(loaded.is_success(), "v12生产内容加载")
	for issue in loaded.issues: print(issue.format_message())
	if not loaded.is_success(): return
	catalog = loaded.catalog
	run_def = catalog.get_definition("runs", catalog.default_run_id)
	_expect.call(catalog.content_version == 12 and not run_def.market.is_empty(), "默认开启批量行情")
	_market_contract()
	_batch_rules()
	_price_matrix()
	_checkpoints()
	_compatibility()
	_business_samples()
	for path in paths:
		if FileAccess.file_exists(path): DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

func seeded(seed_value: int) -> RunSession:
	var s := super.seeded(seed_value)
	MarketService.sync(s._day.state, run_def)
	return s

func fixture(minute := 0) -> RunSession:
	var s := seeded(42)
	open(s)
	s._day.state.visits.clear()
	s._day.state.game_minutes = minute
	MarketService.sync(s._day.state, run_def)
	return s

func stock(s: RunSession, definition_id := "item_blue_bowl", variant := "sound", cost := 10) -> ItemInstance:
	var item := ItemInstance.new()
	item.instance_id = "fixture/%d" % s._day.state.inventory_instances.size()
	item.definition_id = definition_id
	item.selected_variant_id = variant
	item.acquisition_price = cost
	item.acquired_night = s._day.state.current_night_index
	s._day.state.inventory_instances.append(item)
	return item

func _market_contract() -> void:
	var found := {}
	for seed_value in 128:
		var rows := MarketService.plan(run_def, seed_value)
		_expect.call(rows.size() == 4 and rows == MarketService.plan(run_def, seed_value), "行情随机序列稳定")
		for index in rows.size():
			found[rows[index].demand_id] = true
			if index == 0: continue
			_expect.call(rows[index].minute >= 120 and rows[index].minute <= 300 and int(rows[index].minute) % 5 == 0 and rows[index].demand_id != rows[index - 1].demand_id, "消息时间与偏好替换")
		_expect.call(MarketService.current(run_def, seed_value, 2, 0) == rows[1], "偏好跨夜保留")
	_expect.call(found.size() == 6, "六种外部需求均可出现")
	var s := seeded(42)
	var before := s.read_state()
	for n in 5: s.counter_model(); s.event_model()
	_expect.call(s.read_state() == before, "查看行情不变动状态或重抽")
	var original := MarketService.plan(run_def, 42)
	stock(s)
	_expect.call(original == MarketService.plan(run_def, 42), "行情与库存独立")
	var source: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/runs/p0_market.json"))
	source.records[0].market.demands = [7]
	_expect.call(not SourceSchemaValidator.new().validate_collection("runs", source, "fixture").is_empty(), "坏需求结构可诊断")

func _batch_rules() -> void:
	var s := fixture()
	var ids: Array = []
	for n in 5: ids.append(stock(s).instance_id)
	var before := s.read_state()
	_expect.call(not s.sell_batch("buyer_introduced", ids).ok and s.read_state() == before, "没有介绍不能向商会交货")
	for key in ["pending_event_id", "risk_pending"]:
		s._day.state.set(key, "pending")
		var blocked := s.read_state()
		_expect.call(not s.sell_batch("buyer_recycler", ids).ok and s.read_state() == blocked, "待办剧情危机不能绕过 " + key)
		s._day.state.set(key, "")
	for invalid in [[], [ids[0], ids[0]], [ids[0], "missing"], [12]]:
		_expect.call(not s.sell_batch("buyer_recycler", invalid).ok and s.read_state() == before, "无效整批不耗时不改货款")
	var guest := CustomerVisit.new()
	guest.status = "active"
	s._day.state.visits.append(guest)
	for status in ["active", "waiting"]:
		guest.status = status
		before = s.read_state()
		_expect.call(not s.sell_batch("buyer_recycler", ids).ok and s.read_state() == before, "在店客人阻止出货 " + status)
		_expect.call(not s.commerce_command("sell", ids[0], "buyer_recycler").ok, "单件入口不能绕过在店门槛")
	s._day.state.visits.clear()
	s._day.state.pawn_returns.append({"night": 1, "status": "waiting"})
	_expect.call(not s.sell_batch("buyer_recycler", ids).ok, "赎当客阻止出货")
	s._day.state.pawn_returns.clear()
	before = s.read_state()
	var receipts: Array = []
	s.transaction_completed.connect(func(r: Dictionary) -> void: receipts.append(r))
	_expect.call(s.sell_batch("buyer_recycler", ids).ok, "五件超过旧额度仍可一批卖出")
	_expect.call(s.read_state().game_minutes == 20 and s.read_state().action_count == before.action_count + 1, "五件只耗20分钟和一次行动")
	_expect.call(s.read_state().cash == before.cash + 180 and s.read_state().sale_records.size() == 5 and s.read_state().sale_batches.size() == 1, "逐件与总款一致")
	_expect.call(receipts.size() == 1 and receipts[0].amount == 180 and receipts[0].before == before.cash and receipts[0].after == before.cash + 180, "整批只有一张汇总凭据")
	before = s.read_state()
	_expect.call(not s.sell_batch("buyer_recycler", ids).ok and s.read_state() == before, "重复提交不收款")
	for state_name in ["pledged", "sold", "redeemed", "transferred"]:
		var invalid := stock(s)
		invalid.ownership_state = state_name
		before = s.read_state()
		_expect.call(not s.sell_batch("buyer_recycler", [invalid.instance_id]).ok and before == s.read_state(), "不可出售权属 " + state_name)
	for minute in [220, 520, 535]:
		var late := fixture(minute)
		var item := stock(late)
		var buyer := "buyer_collector" if minute == 220 else "buyer_recycler"
		before = late.read_state()
		_expect.call(not late.sell_batch(buyer, [item.instance_id]).ok and before == late.read_state(), "截止边界前阻止 " + str(minute))
	var boundary := fixture(215)
	_expect.call(boundary.sell_batch("buyer_collector", [stock(boundary).instance_id]).ok and boundary.read_state().game_minutes == 235, "截止前可完成")
	var incoming := fixture(80)
	var incoming_item := stock(incoming)
	var visit := CustomerVisit.new()
	visit.status = "scheduled"; visit.arrival = 90; visit.expires_at = 150
	incoming._day.state.visits.append(visit)
	_expect.call(incoming.sell_batch("buyer_recycler", [incoming_item.instance_id]).ok and visit.status == "active" and incoming.read_state().game_minutes == 100, "途中客人到达，返回后正常接待")
	_expect.call(not incoming.sell_batch("buyer_recycler", [stock(incoming).instance_id]).ok, "新到客人阻止下一趟")
	var expiry := fixture(80)
	visit = CustomerVisit.new()
	visit.status = "scheduled"; visit.arrival = 85; visit.expires_at = 95
	expiry._day.state.visits.append(visit)
	_expect.call(expiry.sell_batch("buyer_recycler", [stock(expiry).instance_id]).ok and visit.status == "timed_out", "途中等待过期不暂停")

func _price_matrix() -> void:
	var service := CommerceService.new(catalog)
	var buyer: BuyerDefinition = catalog.get_definition("buyers", "buyer_lu")
	for seed_value in 64:
		var s := fixture()
		s._day.state.run_seed = seed_value
		var wanted := MarketService.category(s._day)
		for definition: ItemDefinition in catalog.get_all("items"):
			for variant: ItemVariantDefinition in definition.possible_variants:
				var item := stock(s, definition.id, variant.id)
				var expected := maxi(1, roundi(variant.true_value * 1.4))
				_expect.call(service.quote(item, buyer) == expected, "各品相140%报价")
				item.provenance = {"status": "verified"}
				_expect.call(service.quote(item, buyer) == expected + floori(expected * 0.15), "核实来源追加15%向下取整")
				_expect.call(service.item_reason(s._day, item, buyer).is_empty() == (definition.category == wanted), "仅收当前偏好品类")
	var across := fixture()
	var change: Dictionary = MarketService.plan(run_def, 42)[1]
	across._day.state.game_minutes = int(change.minute) - 10
	MarketService.sync(across._day.state, run_def)
	var wanted := MarketService.category(across._day)
	for definition: ItemDefinition in catalog.get_all("items"):
		if definition.category != wanted: continue
		var item := stock(across, definition.id, definition.possible_variants[0].id)
		var price := service.quote(item, buyer)
		_expect.call(across.sell_batch("buyer_lu", [item.instance_id]).ok and across.read_state().sale_records.back().price == price, "途中换偏好仍按出发时成交")
		_expect.call(across.read_state().sale_batches.back().market_id == "market/0" and across.read_state().market_history.back().id == "market/1", "批次行情与返回后消息分别记录")
		break

func buy_first_three(s: RunSession) -> Array:
	open(s)
	var ids: Array = []
	for n in 3:
		if n > 0: wait_to(s, [0, 90, 210][n])
		var visit := active(s)
		if visit == null: continue
		var result := action(s, "offer", "", visit.trade.reserve_price)
		_expect.call(result.ok and visit.status == "bought", "实际收货形成批次库存")
		if visit.status == "bought": ids.append(visit.item.instance_id)
	return ids

func _checkpoints() -> void:
	var s := seeded(1)
	var ids := buy_first_three(s)
	_expect.call(s.sell_batch("buyer_recycler", ids).ok, "真实多件出售")
	if not finish(s): return
	resume(s, "批次售货夜末")
	var payload := SaveCodec.new().encode(s._day.state, 12)
	for key in ["market", "start", "items", "missing", "price", "shape", "batch_id"]:
		var changed: Dictionary = payload.duplicate(true)
		match key:
			"market": changed.sale_batches[0].market_id = "market/99"
			"start": changed.sale_batches[0].start -= 5
			"items": changed.sale_batches[0].item_ids.pop_back()
			"missing": changed.sale_batches.clear()
			"price": changed.sale_records[0].price += 1
			"shape": changed.market_history = [4]
			"batch_id": changed.sale_records[0].batch_id = "bad"
		_expect.call(SaveCodec.new().decode(changed, run_def, 12, catalog) == null, "拒绝损坏批次 " + key)
	finish_room(s)
	s.execute("continue_run")
	resume(s, "跨夜行情")
	var original := FileAccess.get_file_as_string(s._save.path)
	open(s)
	s.execute("close_shop"); s.execute("wait_until_seal"); events(s)
	var before := s.read_state()
	var failed_path := s._save.path + "/blocked.json"
	var normal_path := s._save.path
	s._save.path = failed_path
	_expect.call(not s.execute("resolve_night").ok and before == s.read_state(), "写档失败回滚行情和结算")
	s._save.path = normal_path
	_expect.call(FileAccess.get_file_as_string(normal_path) == original, "失败不覆盖旧文件")

func _compatibility() -> void:
	for version in [9, 10, 11]:
		var old_catalog := JsonContentProvider.new("res://data/legacy/content_v%d.json" % version).load_catalog().catalog
		var old_run: RunDefinition = old_catalog.get_definition("runs", old_catalog.default_run_id)
		var path := "user://tests/market_legacy%d.json" % version
		paths.append(path)
		var old := RunSession.new(old_run, version, SaveManager.new(path), old_catalog)
		open(old)
		var visit := active(old)
		old.counter_command("offer", visit.visit_id, "", visit.trade.reserve_price)
		var item: ItemInstance = old._day.state.inventory_instances[0]
		_expect.call(old.commerce_command("sell", item.instance_id, "buyer_recycler").ok, "旧局保留10分钟单件卖货")
		if not finish(old): continue
		var before := old.read_state()
		var modern := RunSession.new(run_def, 12, SaveManager.new(path), catalog)
		_expect.call(modern.load_checkpoint().ok and modern.content_version == version and modern.read_state() == before, "v%d含销售旧档原规则恢复" % version)
		modern.new_run()
		_expect.call(modern.content_version == 12 and not modern.definition.market.is_empty(), "重新开局使用新机制")

func _business_samples() -> void:
	for seed_value in [0, 1, 7, 42, 73, 121, 255, 511]:
		var s := seeded(seed_value)
		for night in 3:
			open(s)
			for guard in 150:
				events(s)
				var visit := active(s)
				if visit != null:
					var item: ItemDefinition = catalog.get_definition("items", visit.item.definition_id)
					if item.item_type == "normal":
						for step in item.appraisal_actions: action(s, "appraise", step.id)
						for clue in visit.item.revealed_clue_ids:
							if item.find_clue(clue).leverage > 0 and s._counter.reason(s._day, "pressure", visit.visit_id, clue).is_empty(): action(s, "pressure", clue)
						var offer := s._counter.appraisal.valuation(visit.item, item).x
						if visit.status == "active" and s.read_state().cash >= offer: action(s, "offer", "", offer)
					if visit.status == "active": action(s, "reject")
				var sold := sell_profitable(s)
				if s._day.state.game_minutes >= 515: break
				if not sold: s.execute("short_task")
			if not finish(s): break
			resume(s, "经营样本%d第%d夜" % [seed_value, night + 1])
			finish_room(s)
			s.execute("continue_run")
		_expect.call(s.read_state().phase == "run_ended", "经营样本走完三夜")
		var margin := 0
		var special_sales := 0
		for sale in s._day.state.sale_records:
			margin += sale.realized_profit
			if sale.buyer_id == "buyer_lu": special_sales += 1
		var financial := FinancialSummary.build(s._day.state)
		report.append({"seed": seed_value, "cash": s._day.state.cash, "sales": s._day.state.sale_records.size(), "lu_sales": special_sales, "margin": margin, "stock": financial.inventory_count, "stock_cost": financial.inventory_cost, "sale_minutes": s._day.state.sale_batches.size() * 20})
	_expect.call(report.any(func(row: Dictionary) -> bool: return row.lu_sales > 0 and row.margin > 0), "新增销路实际获利")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://.godot/qa"))
	var f := FileAccess.open("res://.godot/qa/market_samples.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(report, "\t"))
	print("MARKET SAMPLES ", JSON.stringify(report))

func sell_profitable(s: RunSession) -> bool:
	var model: Dictionary = s.counter_model().inventory.sales
	var best: Dictionary = {}
	for buyer in model.buyers:
		if not buyer.reason.is_empty(): continue
		var ids: Array = []
		var margin := 0
		for row in buyer.stock:
			if row.reason.is_empty() and row.price > row.cost:
				ids.append(row.id)
				margin += row.price - row.cost
		if not ids.is_empty() and margin > best.get("margin", 0): best = {"id": buyer.id, "ids": ids, "margin": margin}
	return false if best.is_empty() else s.sell_batch(best.id, best.ids).ok
