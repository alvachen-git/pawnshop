class_name RoomTests
extends M7Tests

func run(expect: Callable) -> void:
	_expect = expect
	var loaded := JsonContentProvider.new("res://data/legacy/content_v9.json").load_catalog()
	_expect.call(loaded.is_success(), "房间生产内容加载")
	if not loaded.is_success():
		for issue in loaded.issues: print(issue.format_message())
		return
	catalog = loaded.catalog
	run_def = catalog.get_definition("runs", catalog.default_run_id)
	_quiet_cycle()
	_split_risks()
	_bankruptcy_priority()
	_rollback_and_corruption()
	_response_rollback()
	_import_v7()
	for path in paths: DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

func resume(s: RunSession, label: String) -> void:
	var before := s.read_state()
	var result := s.load_checkpoint()
	_expect.call(result.ok and s.read_state() == before, label + " 恢复：" + result.message)

func finish_room(s: RunSession) -> void:
	for command in ["enter_room", "sleep", "finish_sleep"]:
		var result := s.execute(command)
		_expect.call(result.ok, command + ": " + result.message)

func empty_night(s: RunSession) -> void:
	open(s)
	seal(s)
	finish_room(s)

func third(s: RunSession) -> String:
	for n in 2:
		empty_night(s)
		_expect.call(s.execute("continue_run").ok, "进入次夜")
	open(s)
	var visit: String = s.counter_model().active_id
	_expect.call(s.counter_command("appraise", visit, "observe").ok, "观察铜镜")
	_expect.call(s.counter_command("appraise", visit, "inscription").ok, "查镜规矩")
	_expect.call(s.counter_command("offer", visit, "", 54).ok, "收镜")
	return s.read_state().inventory_instances.back().instance_id

func _quiet_cycle() -> void:
	var s := session()
	for cash in [92, 84, 76]:
		open(s)
		_expect.call(s.execute("close_shop").ok, "提前关门")
		seal(s)
		_expect.call(s.read_state().phase == "shop_resolution" and s.read_state().cash == cash, "先结财务再回房")
		resume(s, "铺内收尾")
		_expect.call(not s.execute("continue_run").ok, "不能跳过房间")
		_expect.call(s.execute("enter_room").ok, "进入房间")
		resume(s, "回房")
		var before := s.read_state()
		for command in ["open_shop", "close_shop", "wait_until_seal", "resolve_night", "enter_room", "continue_run"]:
			_expect.call(not s.execute(command).ok and before == s.read_state(), "房间拒绝 " + command)
		_expect.call(s.execute("sleep").ok and s.read_state().phase == "sleep_resolution", "床提交就寝")
		resume(s, "就寝")
		_expect.call(not s.execute("sleep").ok, "就寝不可重复")
		_expect.call(s.execute("finish_sleep").ok and s.read_state().cash == cash, "睡眠完成不重复扣费")
		resume(s, "日结")
		_expect.call(s.execute("continue_run").ok, "日结后推进")
	_expect.call(s.read_state().phase == "run_ended", "三夜流程结束")
	resume(s, "三夜收尾")

func _split_risks() -> void:
	for route in ["covered", "shop_safe", "shop_dead", "personal_safe", "personal_dead", "both", "sold"]:
		var s := session()
		var id := midnight(s) if route in ["personal_safe", "personal_dead", "both", "sold"] else third(s)
		if route in ["personal_safe", "personal_dead", "both", "sold"]:
			s.risk_command("uncover", id)
			_expect.call(s.mirror_command("midnight_old_ticket", "peek").ok, "窥镜 " + route)
			_expect.call(s.mirror_command("midnight_old_ticket", "pursue").ok, "追看 " + route)
		if route in ["covered", "personal_safe", "personal_dead", "sold"]: s.risk_command("cover", id)
		if route == "sold": _expect.call(s.commerce_command("sell", id, "buyer_mirror").ok, "追看后卖镜")
		seal(s)
		var shop_pending: bool = route in ["shop_safe", "shop_dead", "both"]
		_expect.call((not s.read_state().risk_pending.is_empty()) == shop_pending, "铺内危机只取决于存放 " + route)
		resume(s, "封铺 " + route)
		if shop_pending:
			_expect.call(not s.execute("enter_room").ok, "不能携未决铺内危机回房")
			_expect.call(s.risk_command("defy" if route == "shop_dead" else "retreat", id).ok, "铺内应对 " + route)
			resume(s, "铺内应对 " + route)
		if route == "shop_dead":
			_expect.call(s.read_state().phase == "dead", "铺内致命违规")
			continue
		_expect.call(s.execute("enter_room").ok, "危机后回房 " + route)
		resume(s, "房间 " + route)
		_expect.call(s.read_state().risk_pending.is_empty(), "回房观察先于睡眠危机")
		_expect.call(s.execute("sleep").ok, "就寝 " + route)
		var personal: bool = route in ["personal_safe", "personal_dead", "both", "sold"]
		_expect.call((not s.read_state().risk_pending.is_empty()) == personal, "睡眠只处理个人纠缠 " + route)
		resume(s, "睡眠 " + route)
		if personal:
			_expect.call(not s.execute("finish_sleep").ok, "未决索命不能到天亮")
			_expect.call(s.risk_command("defy" if route == "personal_dead" else "retreat", id).ok, "个人应对 " + route)
			resume(s, "个人应对 " + route)
		if route == "personal_dead":
			_expect.call(s.read_state().phase == "dead" and s.read_state().bankruptcy_archive.is_empty(), "个人死亡只归档死亡")
		else:
			_expect.call(s.execute("finish_sleep").ok, "天明 " + route)
			resume(s, "结束 " + route)

func _bankruptcy_priority() -> void:
	var source: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/runs/p0_room.json")).records[0]
	source.initial_cash = 5
	var s := RunSession.new(RunDefinition.from_dto(RunDTO.from_source(source)), catalog.content_version, session()._save, catalog)
	empty_night(s)
	s.execute("continue_run")
	empty_night(s)
	_expect.call(s.read_state().phase == "bankrupt" and s.read_state().bankruptcy_archive.size() == 1, "睡眠后欠款到期破产")
	resume(s, "经营失败")
	# A real transaction sequence supplies simultaneous arrears and personal pursuit.
	for die in [false, true]:
		var combined := combined_session()
		_expect.call(combined.read_state().phase == "shop_resolution" and FeeService.overdue(combined._day.state) == 1, "欠款不抢先结束待决睡眠")
		combined.execute("enter_room")
		combined.execute("sleep")
		var id: String = combined.read_state().risk_pending
		_expect.call(combined.risk_command("defy" if die else "retreat", id).ok, "欠款并存时应对")
		if not die: combined.execute("finish_sleep")
		_expect.call(combined.read_state().phase == ("dead" if die else "bankrupt"), "死亡优先，生还后才判破产")
		_expect.call(combined.read_state().death_archive.size() + combined.read_state().bankruptcy_archive.size() == 1, "只产生一种终局")
		resume(combined, "合并终局")

func low_cash(cash: int) -> RunSession:
	var source: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/runs/p0_room.json")).records[0]
	source.initial_cash = cash
	# The combined cash-flow fixture needs the sound watch's resale value.
	source.randomize_seed = false
	source.seed = seed_for("n2_visit1", "sound")
	return RunSession.new(RunDefinition.from_dto(RunDTO.from_source(source)), catalog.content_version, session()._save, catalog)

func combined_session() -> RunSession:
	var s := low_cash(140)
	empty_night(s)
	s.execute("continue_run")
	open(s)
	_expect.call(s.counter_command("offer", s.counter_model().active_id, "", 125).ok, "第二夜收表占款")
	seal(s)
	finish_room(s)
	s.execute("continue_run")
	open(s)
	var watch: String = s.read_state().inventory_instances[0].instance_id
	s.execute("wait_hour")
	events(s)
	_expect.call(s.commerce_command("sell", watch, "buyer_introduced").ok, "第三夜卖表回款")
	_expect.call(s.counter_command("offer", s.counter_model().active_id, "", 100).ok, "收镜占尽现银")
	var id: String = s.read_state().inventory_instances.back().instance_id
	wait_to(s, 360)
	_expect.call(s.mirror_command("midnight_old_ticket", "peek").ok, "欠款时窥镜")
	_expect.call(s.mirror_command("midnight_old_ticket", "pursue").ok, "欠款时追看")
	s.risk_command("cover", id)
	seal(s)
	return s

func _rollback_and_corruption() -> void:
	var s := session()
	open(s)
	s.execute("wait_until_seal")
	var failing := M4Tests.ToggleSave.new(s._save.path)
	failing.catalog = catalog
	s._save = failing
	for command in ["resolve_night", "enter_room", "sleep", "finish_sleep"]:
		var before := s.read_state()
		failing.fail = true
		_expect.call(not s.execute(command).ok and s.read_state() == before, "失败完整回滚 " + command)
		failing.fail = false
		_expect.call(s.execute(command).ok, "重试成功 " + command)
		resume(s, "重试 " + command)
	var payload := SaveCodec.new().encode(s._day.state, catalog.content_version)
	_expect.call(payload.save_version == 10, "当前统一保存容器使用v10")
	for index in payload.room_history.size():
		var bad: Dictionary = payload.duplicate(true)
		bad.room_history.remove_at(index)
		_expect.call(SaveCodec.new().decode(bad, run_def, catalog.content_version, catalog) == null, "删阶段拒读 %d" % index)
	for phase in ["private_room", "sleep_resolution", "dead", "bankrupt"]:
		var bad: Dictionary = payload.duplicate(true)
		bad.phase = phase
		_expect.call(SaveCodec.new().decode(bad, run_def, catalog.content_version, catalog) == null, "伪造阶段拒读 " + phase)

func _response_rollback() -> void:
	for personal in [false, true]:
		for die in [false, true]:
			var s := session()
			var id := midnight(s) if personal else third(s)
			if personal:
				s.risk_command("uncover", id)
				s.mirror_command("midnight_old_ticket", "peek")
				s.mirror_command("midnight_old_ticket", "pursue")
				s.risk_command("cover", id)
			seal(s)
			if personal:
				s.execute("enter_room")
				s.execute("sleep")
			var before := s.read_state()
			var bytes := FileAccess.get_file_as_bytes(s._save.path)
			var failing := M4Tests.ToggleSave.new(s._save.path)
			failing.catalog = catalog
			s._save = failing
			failing.fail = true
			var action := "defy" if die else "retreat"
			_expect.call(not s.risk_command(action, id).ok and s.read_state() == before, "危机应对写盘失败完整回滚")
			_expect.call(FileAccess.get_file_as_bytes(s._save.path) == bytes, "应对失败保留旧检查点")
			failing.fail = false
			resume(s, "应对失败后仍有危机")
			_expect.call(s.risk_command(action, id).ok, "应对写盘重试")
			var after := s.read_state()
			_expect.call(not s.risk_command(action, id).ok and s.read_state() == after, "重复应对不重复归档")
			resume(s, "应对重试后")
			var payload := SaveCodec.new().encode(s._day.state, catalog.content_version)
			for field in ["scope", "minute", "item_id"]:
				var bad: Dictionary = payload.duplicate(true)
				bad.risk_history.back()[field] = "shop" if field == "scope" and personal else "personal" if field == "scope" else 0 if field == "minute" else "missing"
				_expect.call(SaveCodec.new().decode(bad, run_def, catalog.content_version, catalog) == null, "拒绝伪造危机 " + field)
	var fresh := session()
	empty_night(fresh)
	fresh.execute("continue_run")
	var payload := SaveCodec.new().encode(fresh._day.state, catalog.content_version)
	payload.risk_pending = "invented"
	_expect.call(SaveCodec.new().decode(payload, run_def, catalog.content_version, catalog) == null, "开铺前不能伪造未决危机")

func _import_v7() -> void:
	var old := M7Tests.new()
	old._expect = _expect
	old.catalog = JsonContentProvider.new("res://tests/fixtures/m7_manifest.json").load_catalog().catalog
	old.run_def = old.catalog.get_definition("runs", old.catalog.default_run_id)
	var legacy := old.session()
	var id := old.third(legacy)
	old.seal(legacy)
	legacy.risk_command("defy", id)
	var bytes := FileAccess.get_file_as_bytes(legacy._save.path)
	var fresh := session()
	fresh._save.prior_version_path = legacy._save.path
	fresh = RunSession.new(run_def, catalog.content_version, fresh._save, catalog)
	_expect.call(fresh.read_state().death_archive.size() == 1 and fresh.read_state().current_night_index == 1, "v7只导入账册，不迁移进度")
	empty_night(fresh)
	_expect.call(FileAccess.get_file_as_bytes(legacy._save.path) == bytes, "v7字节不变")
	for path in old.paths: DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
