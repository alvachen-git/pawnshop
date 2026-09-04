class_name M7Tests
extends M6Tests

func run(expect: Callable) -> void:
	_expect = expect
	var loaded := JsonContentProvider.new("res://data/content_manifest.json").load_catalog()
	_expect.call(loaded.is_success(), "M7生产内容通过校验")
	if not loaded.is_success():
		for issue in loaded.issues: print(issue.format_message())
		return
	catalog = loaded.catalog
	run_def = catalog.get_definition("runs", catalog.default_run_id)
	_seed_contract()
	_bowl_and_holder()
	_watch_combinations()
	_history_and_rollback()
	_content_contract()
	_visual_contract()
	_basic_fees()
	_mirror_routes()
	_mirror_evidence()
	_prior_archives()
	for path in paths: DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

func seeded(seed_value: int) -> RunSession:
	var s := session()
	s._day.state.run_seed = seed_value
	s._day.state.scenario_selections.clear()
	s._counter.customers.prepare_night(s._day.state, run_def, catalog)
	return s

func active(s: RunSession) -> CustomerVisit:
	return s._counter.customers.active(s._day.state)

func action(s: RunSession, command: String, detail := "", amount := 0) -> ActionResult:
	return s.counter_command(command, s.counter_model().active_id, detail, amount)

func open(s: RunSession) -> void:
	events(s)
	_expect.call(s.execute("open_shop").ok, "样板开铺")

func wait_to(s: RunSession, minute: int) -> void:
	while s.read_state().game_minutes < minute:
		events(s)
		s.execute("wait_hour" if minute - int(s.read_state().game_minutes) >= 60 else "short_task")
	events(s)

func seed_for(slot_id: String, variant_id: String, situation := "ordinary") -> int:
	var scenario := TradeScenarioService.for_slot(run_def, slot_id)
	for seed_value in 300:
		var visit := CustomerVisit.new()
		visit.item = ItemInstance.new()
		TradeScenarioService.prepare(visit, scenario, seed_value)
		if visit.item.selected_variant_id == variant_id and visit.situation_id == situation: return seed_value
	_expect.call(false, "未找到测试种子")
	return 0

func _seed_contract() -> void:
	var combinations: Dictionary = {}
	var bowl: Dictionary = {}
	var holder: Dictionary = {}
	for seed_value in 64:
		var s := seeded(seed_value)
		var other := seeded(seed_value)
		_expect.call(s.read_state().scenario_selections == other.read_state().scenario_selections, "相同种子还原同一情境：%d" % seed_value)
		bowl[s._day.state.visits[0].item.selected_variant_id] = true
		holder[s._day.state.visits[1].item.selected_variant_id] = true
		s._day.state.current_night_index = 2
		s._counter.customers.prepare_night(s._day.state, run_def, catalog)
		var watch := s._day.state.visits[0]
		combinations[watch.item.selected_variant_id + "/" + watch.situation_id] = true
		_expect.call(watch.expires_at == (60 if watch.situation_id == "urgent" else 140), "急客60分钟、普通客140分钟")
		s._day.state.current_night_index = 3
		s._counter.customers.prepare_night(s._day.state, run_def, catalog)
		_expect.call(s._day.state.visits[3].item.selected_variant_id == "flawed" and s._day.state.visits[3].scenario_id.is_empty(), "铜镜关联表保持故障")
	_expect.call(bowl.size() == 2 and holder.size() == 2 and combinations.size() == 4, "三件品相和四种怀表组合均出现")
	var s := session()
	var seeds: Dictionary = {}
	for index in 8:
		seeds[s.read_state().run_seed] = true
		s.new_run()
	_expect.call(seeds.size() > 1, "新经营产生新种子")
	s = seeded(7)
	open(s)
	var before := s.read_state()
	for index in 8: s.counter_model()
	_expect.call(s.read_state() == before, "只读界面不重抽、不耗时")
	var original := active(s).item.selected_variant_id
	action(s, "offer", "", 1)
	_expect.call(active(s).item.selected_variant_id == original and s.read_state().run_seed == 7, "拒绝报价不重抽")

func _bowl_and_holder() -> void:
	for variant in ["sound", "repaired"]:
		var seed_value := seed_for("n1_visit1", variant)
		var s := seeded(seed_value)
		open(s)
		_expect.call(s.counter_model().appraisal.images.size() == 2, "初见仅有共用正背面信息")
		_expect.call(not action(s, "question", "seam").ok, "无口供物证不能针对接缝追问")
		action(s, "question", "repairs")
		var bounds: String = s.counter_model().appraisal.body
		_expect.call(active(s).item.revealed_clue_ids.is_empty() and bounds.contains("10–75"), "卖家说法不收窄估值")
		_expect.call(action(s, "appraise", "light").ok and active(s).item.completed_action_ids == ["light"], "可以直接选择侧光，不必先看底足")
		var images: Array = s.counter_model().appraisal.images
		_expect.call(images.size() == 3 and images.back().id == variant, "细节与取证同时解锁，只有本局品相")
		var reserve := active(s).trade.reserve_price
		if variant == "repaired":
			_expect.call(action(s, "question", "seam").ok and active(s).trade.reserve_price == reserve - 40, "矛盾追问采用原40银元瑕疵让价")
			var before := s.read_state()
			_expect.call(not action(s, "pressure", "repair").ok and before == s.read_state(), "口供与实物不能重复折价、拒绝不耗时")
		else:
			_expect.call(not action(s, "question", "seam").ok, "完好碗不会出现不存在的裂缝追问")
		_expect.call(action(s, "offer", "", active(s).trade.reserve_price).ok and active(s) == null, "两种品相均可完成交易")
		seal(s)
		_expect.call(s.load_checkpoint().ok, "碗问答、物证、成交能重载：" + s.message)
	# Reverse order: physical leverage first, follow-up still tells the story without another round/discount.
	var s := seeded(seed_for("n1_visit1", "repaired"))
	open(s)
	action(s, "appraise", "base")
	_expect.call(active(s).item.revealed_clue_ids == ["mark"], "底足提供来历线索，不证明修补")
	action(s, "appraise", "light"); action(s, "pressure", "repair"); action(s, "question", "repairs")
	var price := active(s).trade.reserve_price
	var rounds := active(s).trade.rounds_left
	action(s, "question", "seam")
	_expect.call(active(s).trade.reserve_price == price and active(s).trade.rounds_left == rounds, "先压价再追问，不重复让价或议价轮次")
	action(s, "offer", "", price); seal(s)
	_expect.call(s.load_checkpoint().ok, "逆序压价保存成功")
	s = seeded(1); open(s)
	var patience := active(s).trade.patience
	action(s, "question", "doubt")
	_expect.call(active(s).trade.patience == patience - 1 and active(s).item.revealed_clue_ids.is_empty(), "空口怀疑消耗耐心、不生成物证")
	for variant in ["brass", "plated"]:
		s = seeded(seed_for("n1_visit2", variant)); open(s); action(s, "reject"); wait_to(s, 90)
		_expect.call(action(s, "appraise", "magnet").ok, "磁针可独立检查")
		_expect.call(s.counter_model().appraisal.images.size() == 2, "磁针不能揭露尚未检查的划痕图")
		if variant == "plated": action(s, "pressure", "attracts")
		_expect.call(action(s, "appraise", "scratch").ok, "划痕提供独立可读物证")
		_expect.call(s.counter_model().appraisal.images.size() == 3, "划痕图跟随取证解锁")
		if variant == "plated":
			_expect.call(not action(s, "pressure", "iron_core").ok, "磁针与铁芯证据共用26银元收益组")
			_expect.call(active(s).trade.reserve_price == 9, "镀铜让价保留原额度")
		action(s, "offer", "", active(s).trade.reserve_price); seal(s)
		_expect.call(s.load_checkpoint().ok, "烛台不同取证来源均可还原")

func _watch_combinations() -> void:
	for variant in ["sound", "flawed"]:
		for situation in ["ordinary", "urgent"]:
			var s := seeded(seed_for("n2_visit1", variant, situation))
			empty_night(s); s.execute("continue_run")
			var before := s.read_state()
			_expect.call(s.load_checkpoint().ok and before == s.read_state(), "第二夜开铺前情境保存、重载不换表")
			open(s)
			var visit := active(s)
			_expect.call(not action(s, "concession").ok, "未核实处境不可索要急售优惠")
			action(s, "question", "reason"); action(s, "question", "deadline")
			_expect.call(visit.item.revealed_clue_ids.is_empty(), "船票证据只说明处境，不证明机芯")
			action(s, "appraise", "observe"); action(s, "appraise", "inspect")
			if variant == "flawed": action(s, "pressure", "flaw")
			var reserve := visit.trade.reserve_price
			var patience := visit.trade.patience
			var rounds := visit.trade.rounds_left
			action(s, "concession")
			_expect.call(visit.trade.reserve_price == reserve - (5 if situation == "urgent" else 0) and visit.trade.patience == patience - (1 if situation == "ordinary" else 0) and visit.trade.rounds_left == rounds - 1, "处境让价独立于品相、普通客被催价损耐心")
			before = s.read_state()
			_expect.call(not action(s, "concession").ok and before == s.read_state(), "急售机会不能重复使用")
			action(s, "offer", "", visit.trade.reserve_price)
			_expect.call(s.read_state().inventory_instances.size() == 1, "怀表四种组合都可提前成交")
			seal(s)
			_expect.call(s.load_checkpoint().ok, "怀表让价与证据逐步验证：" + s.message)
	# Timeout while asking: time spent, no answer/concession; round-trip remains valid.
	var s := seeded(seed_for("n2_visit1", "flawed", "urgent"))
	empty_night(s); s.execute("continue_run"); open(s); wait_to(s, 55)
	_expect.call(not action(s, "question", "reason").ok and s.read_state().game_minutes == 60, "到点离店的询问不产生口供")
	seal(s)
	_expect.call(s.load_checkpoint().ok, "超时行动保持可校验")

func _history_and_rollback() -> void:
	# No/partial/full inspection all supported; never require every question to buy.
	for inspections in [[], ["base"], ["observe", "base", "light"]]:
		var s := seeded(0); open(s)
		for id in inspections: action(s, "appraise", id)
		action(s, "offer", "", 60); seal(s)
		_expect.call(s.load_checkpoint().ok and s.read_state().inventory_instances.size() == 1, "不同检查深度都能完成买卖与保存")
	var s := seeded(seed_for("n1_visit1", "repaired")); open(s)
	action(s, "question", "repairs"); action(s, "appraise", "light"); action(s, "question", "seam"); action(s, "offer", "", 14)
	events(s); s.execute("wait_until_seal")
	var before := s.read_state()
	var old_path := s._save.path
	s._save.path = "res://project.godot/no_save.json"
	_expect.call(not s.execute("resolve_night").ok and s.read_state() == before, "写入失败回滚情境与息费，无重复付款")
	s._save.path = old_path
	_expect.call(s.execute("resolve_night").ok, "恢复可写路径后正常结算")
	var payload := SaveCodec.new().encode(s._day.state, catalog.content_version)
	for kind in ["selection", "seed", "erase", "lie_as_evidence", "double_discount", "time", "price", "reorder"]:
		var bad := payload.duplicate(true)
		match kind:
			"selection": bad.scenario_selections[0].variant_id = "sound"
			"seed": bad.run_seed += 100
			"erase": bad.scenario_history.clear()
			"lie_as_evidence": bad.scenario_history[0].clues = ["repair"]
			"double_discount": bad.scenario_history.insert(3, bad.scenario_history[2].duplicate(true))
			"time": bad.scenario_history[1].start = 0
			"price": bad.scenario_history.back().amount = 1
			"reorder": bad.scenario_history.reverse()
		_expect.call(SaveCodec.new().decode(bad, run_def, catalog.content_version, catalog) == null, "拒绝篡改情境：" + kind)
		_expect.call(SaveCodec.new().decode(JSON.parse_string(JSON.stringify(bad)), run_def, catalog.content_version, catalog) == null, "JSON写盘后仍拒绝篡改情境：" + kind)
	var encoded: Dictionary = JSON.parse_string(JSON.stringify(payload))
	var restored := SaveCodec.new().decode(encoded, run_def, catalog.content_version, catalog)
	_expect.call(restored != null and restored.scenario_history == s.read_state().scenario_history, "JSON数字类型规范化后完整重建问答与物证历史")
	var legacy := payload.duplicate(true); legacy.save_version = 6
	_expect.call(SaveCodec.new().decode(legacy, run_def, catalog.content_version, catalog) == null, "旧进度版本不静默重解释")

func _content_contract() -> void:
	var source: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/runs/p0_judgement.json")).records[0]
	for key in ["questions", "images", "benefit_groups", "situations"]:
		var bad := source.duplicate(true)
		bad.trade_scenarios[0][key] = 42
		_expect.call(not RunSchema.validate(bad, "test", "run").is_empty(), "情境内容结构拒绝：" + key)
	var def := TradeScenarioService.for_slot(run_def, "n1_visit1")
	var copy := def.images; copy[0].path = "bad"
	_expect.call(def.images[0].path.is_empty(), "定义数据只读副本、待交付美术未加载")

func _visual_contract() -> void:
	var s := seeded(seed_for("n1_visit1", "repaired")); open(s)
	var model: Dictionary = s.counter_model().appraisal
	var views := CounterVisualCatalog.images(model.visual, model.images)
	_expect.call(views.size() == 2, "表现层取证前不添加隐藏细节")
	action(s, "appraise", "light")
	model = s.counter_model().appraisal
	var configured: Array = model.images.duplicate(true)
	configured.back().path = "res://assets/art02/items/bowl_repair.svg"
	views = CounterVisualCatalog.images(model.visual, configured)
	_expect.call(views.size() == 3 and views.back().id == "repaired" and views.back().path == configured.back().path, "交付图替换同一细节视图，不叠加旧占位图")
	s = seeded(seed_for("n1_visit2", "plated")); open(s); action(s, "reject"); wait_to(s, 90)
	action(s, "question", "material"); action(s, "appraise", "magnet")
	_expect.call(action(s, "question", "magnetic_core").ok and active(s).trade.reserve_price == 9, "仅用磁针也能针对整铜口供追问")
	action(s, "appraise", "scratch")
	var rounds := active(s).trade.rounds_left
	_expect.call(action(s, "question", "core").ok and active(s).trade.reserve_price == 9 and active(s).trade.rounds_left == rounds, "再问划痕不重复消耗议价收益")
	action(s, "offer", "", 9); seal(s)
	_expect.call(s.load_checkpoint().ok, "磁针质疑与后续划痕口供均可写盘重载")

func _prior_archives() -> void:
	var legacy_catalog := JsonContentProvider.new("res://tests/fixtures/m6_manifest.json").load_catalog().catalog
	var helper := M6Tests.new()
	helper._expect = _expect; helper.catalog = legacy_catalog
	helper.run_def = legacy_catalog.get_definition("runs", legacy_catalog.default_run_id)
	var old := helper.low_cash(5); helper.empty_night(old); old.execute("continue_run"); helper.empty_night(old)
	var old_payload := JSON.parse_string(FileAccess.get_file_as_string(old._save.path)) as Dictionary
	old_payload.save_version = 6
	var file := FileAccess.open(old._save.path, FileAccess.WRITE); file.store_string(JSON.stringify(old_payload)); file.close()
	var bytes := FileAccess.get_file_as_bytes(old._save.path)
	var fresh := session(); fresh._save.prior_version_path = old._save.path
	fresh = RunSession.new(run_def, catalog.content_version, fresh._save, catalog)
	_expect.call(fresh.read_state().bankruptcy_archive.size() == 1 and fresh.read_state().cash == 100 and fresh.read_state().fee_history.is_empty(), "只导入旧破铺录，新经营不补扣费")
	empty_night(fresh)
	_expect.call(FileAccess.get_file_as_bytes(old._save.path) == bytes, "M6旧存档逐字节保留")
	for path in helper.paths: DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
