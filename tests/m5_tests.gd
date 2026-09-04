class_name M5Tests
extends RefCounted

var _expect: Callable
var catalog: ContentCatalog
var run_def: RunDefinition
var paths: Array = []

func run(expect: Callable) -> void:
	_expect = expect
	var loaded := JsonContentProvider.new("res://tests/fixtures/m5_manifest.json").load_catalog()
	_expect.call(loaded.is_success(), "M5生产内容通过结构与领域校验")
	if not loaded.is_success():
		for issue in loaded.issues: print(issue.format_message())
		return
	catalog = loaded.catalog
	run_def = catalog.get_definition("runs", catalog.default_run_id)
	_expect.call(catalog.get_count("items") == 9 and catalog.get_count("ghost_rules") == 1 and run_def.id == "p0_m5", "M5生效铜镜与单独规则目录")
	_safe_and_market()
	_breach_and_death()
	_boundaries_and_rollback()
	_across_nights()
	_corrupt_saves()
	_content_validation()
	for path in paths: DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

func session() -> RunSession:
	var path := "user://tests/m5_%d_%d.json" % [Time.get_ticks_usec(), paths.size()]
	paths.append(path)
	return RunSession.new(run_def, catalog.content_version, SaveManager.new(path), catalog)

func events(s: RunSession) -> void:
	for guard in 10:
		var model := s.event_model()
		if model.pending_id.is_empty(): return
		_expect.call(s.event_command(model.pending_id, model.buttons[0].detail).ok, "M5兼容事件：" + model.pending_id)
	_expect.call(false, "M5事件链不能无限阻塞")

func third(s: RunSession) -> String:
	for n in 2:
		events(s)
		for command in ["open_shop", "close_shop", "wait_until_seal", "resolve_night", "continue_run"]: _expect.call(s.execute(command).ok, "三夜连续推进：" + command + " " + s.message)
	events(s)
	_expect.call(s.execute("open_shop").ok, "第三夜开铺")
	var visit: String = s.counter_model().active_id
	_expect.call(s.counter_command("appraise", visit, "observe").ok and s.counter_command("appraise", visit, "inscription").ok, "铜镜通过原鉴定流程发现血痕和规矩")
	_expect.call(s.counter_model().appraisal.body.contains("关门前"), "鉴定证据明示遮盖期限")
	_expect.call(s.counter_command("offer", visit, "", 54).ok, "铜镜按原经济入口成交")
	var id: String = s.read_state().inventory_instances.back().instance_id
	_expect.call(s.risk_model().body.contains("关门前") and s.risk_model().held_ids == [id], "入库自动显示规则与物品状态")
	return id

func seal(s: RunSession) -> void:
	events(s)
	_expect.call(s.execute("wait_until_seal").ok, "M5封铺")
	_expect.call(s.execute("resolve_night").ok, "M5夜末原子保存：" + s.message)

func _safe_and_market() -> void:
	var s := session()
	var id := third(s)
	var before := s.read_state()
	for i in 5: s.risk_model(); s.counter_model(); s.event_model()
	_expect.call(s.read_state() == before, "读取鬼货面板不耗时不改变状态")
	_expect.call(s.risk_command("cover", id).ok and s.read_state().game_minutes == before.game_minutes + 10, "红布遮盖消耗配置的10分钟")
	before = s.read_state()
	_expect.call(not s.risk_command("cover", id).ok and before == s.read_state(), "重复遮盖意图不耗时")
	_expect.call(s.risk_command("uncover", id).ok and s.risk_command("cover", id).ok, "关门前可检查后重新覆盖")
	_expect.call(s.risk_model().body.contains("香烟直上"), "营业时查看再盖不虚构关门违规")
	_expect.call(s.execute("close_shop").ok, "盖好后关门")
	seal(s)
	_expect.call(s.read_state().summaries.back().outcome == "mirror_safe", "关门前遮盖获得依规存放结局")
	before = s.read_state()
	_expect.call(s.load_checkpoint().ok and before == s.read_state(), "安全存放完整读档恢复")
	_expect.call(s.execute("continue_run").ok and s.read_state().phase == "run_ended", "安全完成连续三夜")
	var market := session()
	id = third(market)
	_expect.call(not market.commerce_command("sell", id, "buyer_mirror").ok, "午夜前无法提前兑现鬼货高价")
	while market.read_state().game_minutes < 360:
		var step := 60 if 360 - int(market.read_state().game_minutes) >= 60 else 5
		_expect.call(market._day.spend_action(step).ok, "等待高价买家消耗营业时间")
		market._counter.customers.update(market._day.state)
	_expect.call(market.commerce_command("sell", id, "buyer_mirror").ok and market.read_state().cash == 136, "00点高价卖镜实现36利润")
	seal(market)
	_expect.call(market.read_state().summaries.back().outcome == "peaceful", "关门前售出铜镜不留下库存鬼货后果")

func _breach_and_death() -> void:
	var late := session()
	var id := third(late)
	late.execute("close_shop")
	_expect.call(late.risk_model().body.contains("香灰向镜面倒伏"), "第一次漏处理先给环境异常")
	_expect.call(late.risk_command("cover", id).ok, "关门后仍能及时补盖")
	seal(late)
	_expect.call(late.read_state().summaries.back().outcome == "mirror_scar" and late.risk_model().body.contains("灯芯偏斜"), "晚补盖留下持久缠祟，不擦除入侵")
	var before := late.read_state()
	_expect.call(late.load_checkpoint().ok and late.read_state() == before, "读档保留晚补盖异常")
	var danger := session()
	id = third(danger)
	seal(danger)
	_expect.call(danger.read_state().phase == "day_summary" and danger.read_state().risk_pending == id, "第一次漏规则触发可挽救警告，不直接死亡")
	_expect.call(danger.risk_model().body.contains("别应声，也别看它的眼睛") and not danger.can_execute("continue_run"), "危险选择前给出世界内警告并阻止跳过")
	before = danger.read_state()
	_expect.call(not danger.execute("continue_run").ok and not danger.counter_command("offer", "stale", "", 1).ok and not danger.event_command("stale", "choice").ok and not danger.risk_command("retreat", "wrong").ok and danger.read_state() == before, "危机无法被过期意图或普通操作绕过")
	_expect.call(danger.load_checkpoint().ok and danger.read_state() == before, "读取危机检查点不能重抽或跳过警告")
	_expect.call(danger.risk_command("retreat", id).ok and danger.read_state().summaries.back().outcome == "mirror_survived", "明确保命选项可安全脱身")
	_expect.call(danger.risk_model().body.contains("灯芯偏斜") and danger.execute("continue_run").ok, "脱身留下缠祟但可结束试玩")
	var death := session()
	id = third(death)
	seal(death)
	_expect.call(death.risk_command("defy", id).ok and death.read_state().phase == "dead", "明知致命仍直视触发永久死亡")
	_expect.call(death.read_state().death_archive.size() == 1 and death.risk_model().history.contains("影子出镜"), "死亡与死因一起写入绝当录")
	_expect.call(death.read_state().death_archive[0].inventory_cost == 54 and death.read_state().death_archive[0].pawn_principal == 0 and death.read_state().death_archive[0].item_name == "泣血铜镜", "绝当录记录关键鬼货与真实资产占款")
	before = death.read_state()
	_expect.call(not death.execute("continue_run").ok and not death.risk_command("retreat", id).ok and before == death.read_state(), "死亡终止所有推进与反悔")
	_expect.call(death.load_checkpoint().ok and death.read_state() == before, "读档恢复死亡不能复活")
	var token: String = before.run_token
	death.new_run()
	_expect.call(death.read_state().phase == "pre_open" and death.read_state().run_token != token and death.read_state().death_archive.size() == 1, "死亡后新运行更换标识并保留绝当录")
	events(death)
	death.execute("open_shop")
	seal(death)
	var restarted := RunSession.new(run_def, catalog.content_version, SaveManager.new(death._save.path), catalog)
	_expect.call(restarted.load_checkpoint().ok and restarted.read_state().death_archive.size() == 1 and restarted.read_state().run_token != token, "新一轮覆盖检查点后绝当录仍持久存在")

func _boundaries_and_rollback() -> void:
	var s := session()
	var id := third(s)
	_expect.call(s.risk_command("cover", id).ok and s.execute("close_shop").ok and s.risk_command("uncover", id).ok, "关门后揭布失去原有遮护")
	_expect.call(s.risk_command("cover", id).ok, "主动违规则仍可重新遮盖")
	seal(s)
	_expect.call(s.read_state().summaries.back().outcome == "mirror_scar", "关门后揭开再盖不能消除异常")
	var edge := session()
	id = third(edge)
	edge._day.spend_action(535 - edge._day.state.game_minutes)
	edge._counter.customers.update(edge._day.state)
	edge.execute("close_shop")
	var before := edge.read_state()
	_expect.call(not edge.risk_command("cover", id).ok and edge.read_state() == before, "02:55关门只剩5分钟，10分钟处理不得透支")
	seal(edge)
	var failing := M4Tests.ToggleSave.new(edge._save.path)
	failing.catalog = catalog
	failing.fail = true
	edge._save = failing
	before = edge.read_state()
	_expect.call(not edge.risk_command("defy", id).ok and edge.read_state() == before, "死亡写盘失败原子回滚，保留可重试警告与旧档")
	failing.fail = false
	_expect.call(edge.risk_command("defy", id).ok and edge.read_state().death_archive.size() == 1, "重试只产生一条死亡记录")
	var exact := session()
	id = third(exact)
	exact._day.spend_action(530 - exact._day.state.game_minutes)
	exact._counter.customers.update(exact._day.state)
	_expect.call(exact.risk_command("cover", id).ok and exact.read_state().phase == "night_resolution", "02:50开始遮盖，恰好封铺时完成")
	_expect.call(exact.execute("resolve_night").ok and exact.read_state().summaries.back().outcome == "mirror_safe", "同一动作先完成处理再自动封铺")

func _corrupt_saves() -> void:
	var s := session()
	var id := third(s)
	seal(s)
	var codec := SaveCodec.new()
	var data := codec.encode(s._day.state, catalog.content_version)
	for mutation in ["outcome", "pending", "cloth", "history", "token", "archive", "old_version"]:
		var broken := data.duplicate(true)
		match mutation:
			"outcome": broken.summaries.back().outcome = "mirror_safe"
			"pending": broken.risk_pending = ""
			"cloth": broken.risk_history.back().covered = true
			"history": broken.risk_history.clear()
			"token": broken.run_token = "bad"
			"archive": broken.death_archive = [{"cause": "bad"}]
			"old_version": broken.save_version = 4
		_expect.call(codec.decode(broken, run_def, catalog.content_version, catalog) == null, "拒绝损坏鬼货存档：" + mutation)
	s.risk_command("defy", id)
	var dead := codec.encode(s._day.state, catalog.content_version)
	var previous_copy := dead.duplicate(true)
	previous_copy.death_archive[0].cause = "已知直视镜中人会熄灭命灯，仍选择对视；影子出镜，人留镜中。"
	var restored := codec.decode(previous_copy, run_def, catalog.content_version, catalog)
	_expect.call(restored != null and restored.phase == &"dead", "文案修订不使已验收M5死亡存档失效")
	if restored != null:
		var displayed := RiskReadModels.build(DayController.new(run_def, restored), RiskManager.new(catalog), "")
		_expect.call(not displayed.history.contains("已知直视") and displayed.history.contains("影子出镜"), "旧绝当录按稳定规则显示新版叙事，仍保留原始记录")
	dead.phase = "day_summary"
	dead.summaries.back().outcome = "mirror_pending"
	dead.risk_pending = id
	dead.risk_history.pop_back()
	_expect.call(codec.decode(dead, run_def, catalog.content_version, catalog) == null, "有死亡记录的同一运行不得修改成存活状态")

func _content_validation() -> void:
	var source: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/ghost_rules/rules_m5.json"))
	var row: Dictionary = source.records[0]
	for field in ["warning", "cover_minutes", "mechanic"]:
		var broken := row.duplicate(true)
		broken.erase(field)
		_expect.call(not GhostSchema.validate(broken, "fixture", "rule").is_empty(), "鬼货规则缺少字段拒绝：" + field)
	var dto := GhostRuleDTO.from_source(row)
	var definition := GhostRuleDefinition.from_dto(dto)
	dto.warning = "mutated"
	_expect.call(definition.warning == row.warning, "鬼货定义与DTO隔离")
	row.mechanic = "unknown"
	var fake := ContentCatalog.new()
	fake.add_definition("ghost_rules", GhostRuleDefinition.from_dto(GhostRuleDTO.from_source(row)))
	_expect.call(not GhostSchema.domain(fake).is_empty(), "未实现的规则机制被领域校验拒绝")

func _across_nights() -> void:
	var source: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/runs/p0_m5.json")).records[0]
	source.id = "m5_early_mirror_fixture"
	for slot in source.customer_slots:
		if slot.night_min == 1 and slot.arrival == 0:
			slot.item_id = "item_weeping_mirror"
			slot.variant_id = "weeping"
		elif slot.night_min == 3 and slot.arrival == 0:
			slot.item_id = "item_silver_hairpin"
			slot.variant_id = "flawed"
	var early_run := RunDefinition.from_dto(RunDTO.from_source(source))
	catalog.add_definition("runs", early_run)
	_expect.call(InMemoryContentProvider.new(catalog).load_catalog().is_success(), "提前来镜的跨夜夹具仍走内容校验")
	var path := "user://tests/m5_early_%d.json" % Time.get_ticks_usec()
	paths.append(path)
	var s := RunSession.new(early_run, catalog.content_version, SaveManager.new(path), catalog)
	events(s)
	s.execute("open_shop")
	_expect.call(s.counter_command("offer", s.counter_model().active_id, "", 54).ok, "首夜测试夹具实际收购铜镜")
	var id: String = s.risk_model().held_ids[0]
	s.risk_command("cover", id)
	seal(s)
	_expect.call(s.execute("continue_run").ok, "带着鬼货进入第二夜")
	var before := s.read_state()
	_expect.call(s.load_checkpoint().ok and s.read_state() == before and s.risk_model().body.contains("红布已盖"), "跨夜检查点保存红布，不凭空重置鬼货")
	events(s)
	s.execute("open_shop")
	s.execute("close_shop")
	s.risk_command("uncover", id)
	s.risk_command("cover", id)
	seal(s)
	_expect.call(s.read_state().summaries.back().outcome == "mirror_scar" and s.execute("continue_run").ok, "跨夜存放仍逐夜检查违规")
	_expect.call(s.risk_model().body.contains("灯芯偏斜") and s.load_checkpoint().ok and s.risk_model().body.contains("灯芯偏斜"), "前夜缠祟在下一夜及读档后持续存在")
	events(s)
	s.execute("open_shop")
	seal(s)
	_expect.call(s.read_state().summaries.back().outcome == "mirror_safe" and s.risk_model().body.contains("灯芯偏斜"), "后来遵守规则不会擦除已有缠祟")
