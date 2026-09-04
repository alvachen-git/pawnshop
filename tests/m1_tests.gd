class_name M1Tests
extends RefCounted

class FailingSave extends SaveManager:
	var fail_writes := true
	func save_state(state: RunState, run_definition: RunDefinition, content_version: int) -> bool:
		if fail_writes:
			error_message = "测试注入：磁盘写入失败。"
			return false
		return super.save_state(state, run_definition, content_version)

var check: Callable
var definition: RunDefinition
var version: int

func run(expect: Callable) -> void:
	check = expect
	var loaded := JsonContentProvider.new("res://data/content_manifest.json").load_catalog()
	definition = loaded.catalog.get_definition("runs", loaded.catalog.default_run_id)
	version = loaded.catalog.content_version
	_schema_and_adapter()
	_day_boundaries()
	_saves_and_three_nights()
	_save_validation()
	_failures()

func _schema_and_adapter() -> void:
	var dto := RunDTO.new()
	dto.id = definition.id
	dto.total_nights = definition.total_nights
	dto.opening_minute = definition.opening_minute
	dto.night_minutes = definition.night_minutes
	dto.time_step = definition.time_step
	dto.initial_cash = definition.initial_cash
	dto.seed = definition.seed
	for action in definition.actions:
		dto.actions.append({"id": action.id, "label": action.label, "minutes": action.minutes, "phases": action.phases})
	var memory_definition := RunDefinition.from_dto(dto)
	dto.total_nights = 999
	dto.actions.clear()
	check.call(memory_definition.total_nights == definition.total_nights and memory_definition.actions.size() == definition.actions.size(), "定义不持有可变输入DTO。")
	var catalog := ContentCatalog.new()
	catalog.default_run_id = memory_definition.id
	catalog.add_definition("runs", memory_definition)
	check.call(InMemoryContentProvider.new(catalog).load_catalog().is_success(), "独立构建的内存Provider通过领域校验。")
	catalog.default_run_id = "missing"
	check.call(not InMemoryContentProvider.new(catalog).load_catalog().is_success(), "运行配置失效引用在内存Provider同样被拒绝。")
	catalog.default_run_id = memory_definition.id
	var memory_day := DayController.new(memory_definition, RunState.create(memory_definition))
	var json_day := _day()
	for command in ["open_shop", "short_task", "close_shop", "wait_until_seal", "resolve_night"]:
		memory_day.execute(command)
		json_day.execute(command)
	check.call(memory_day.state.to_read_model() == json_day.state.to_read_model(), "两种Provider驱动相同业务结果，不依赖JSON。")
	var source: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/runs/p0_daily_loop.json"))
	for mutation in ["fraction", "missing", "phase", "cost", "duplicate", "step"]:
		var invalid := source.duplicate(true)
		match mutation:
			"fraction": invalid.records[0].total_nights = 1.5
			"missing": invalid.records[0].erase("night_minutes")
			"phase": invalid.records[0].actions[0].phases = ["invalid"]
			"cost": invalid.records[0].actions[0].minutes = 0
			"duplicate": invalid.records[0].actions.append(invalid.records[0].actions[0])
			"step": invalid.records[0].time_step = 0
		check.call(not SourceSchemaValidator.new().validate_collection("runs", invalid, "memory://test").is_empty(), "运行Schema拒绝：" + mutation)
	var changed := RunDTO.new()
	changed.id = "alternate_run"
	changed.total_nights = 1
	changed.opening_minute = 1200
	changed.night_minutes = 60
	changed.time_step = 5
	changed.initial_cash = 42
	var alternate := RunDefinition.from_dto(changed)
	var alternate_day := DayController.new(alternate, RunState.create(alternate))
	for command in ["open_shop", "wait_until_seal", "resolve_night", "continue_run"]:
		alternate_day.execute(command)
	check.call(alternate_day.state.phase == &"run_ended" and alternate_day.state.cash == 42 and alternate_day.state.game_minutes == 60, "非三夜/非540分钟配置无需改业务。")

func _day_boundaries() -> void:
	var day := _day()
	check.call(not day.execute("short_task").ok, "开铺前不能消耗营业行动。")
	check.call(day.execute("open_shop").ok and not day.execute("open_shop").ok, "开铺只能执行一次。")
	var time := TimeController.new()
	for minutes in [0, -5, 1, 545]:
		check.call(not time.spend(day.state, definition, minutes).ok and day.state.game_minutes == 0, "非法耗时不修改状态：%d" % minutes)
	for index in 5:
		day.execute("wait_hour")
	check.call(TimeController.clock_text(definition.opening_minute, day.state.game_minutes) == "23:00", "行动累计到23:00。")
	day.execute("close_shop")
	check.call(day.state.closed_at == 300 and not day.can_execute("open_shop"), "早关门记录时刻且不能重开。")
	day.execute("wait_hour")
	check.call(TimeController.clock_text(definition.opening_minute, day.state.game_minutes) == "00:00", "跨午夜仍使用连续累计分钟。")
	day.execute("wait_until_seal")
	check.call(day.state.phase == &"night_resolution" and day.state.game_minutes == 540 and day.state.closed_at == 300, "03:00封铺，早关门记录不变。")
	check.call(not day.execute("short_task").ok and not day.execute("close_shop").ok, "封铺后禁止经营行动及重复关门。")
	day.execute("resolve_night")
	check.call(not day.execute("resolve_night").ok and day.state.summaries.size() == 1, "日结不重复生成。")
	var late := _day()
	late.execute("open_shop")
	for index in 8:
		late.execute("wait_hour")
	late.execute("long_task")
	late.execute("medium_task")
	late.execute("medium_task")
	check.call(TimeController.clock_text(definition.opening_minute, late.state.game_minutes) == "02:50", "晚关门测试到达02:50。")
	late.execute("close_shop")
	check.call(not late.execute("long_task").ok and late.state.game_minutes == 530, "剩余10分钟不能开始30分钟动作。")
	late.execute("medium_task")
	check.call(late.state.phase == &"night_resolution" and late.state.closed_at == 530, "恰好用尽10分钟立即封铺。")

func _saves_and_three_nights() -> void:
	var path := "user://tests/m1_%d.json" % Time.get_ticks_usec()
	var save := SaveManager.new(path)
	var session := RunSession.new(definition, version, save)
	for night in definition.total_nights:
		check.call(session.read_state().current_night_index == night + 1 and session.read_state().phase == "pre_open", "下一夜从PRE_OPEN开始。")
		session.execute("open_shop")
		session.execute("wait_until_seal")
		check.call(session.execute("resolve_night").ok, "日结自动保存成功（包括替换旧存档）。")
		var restored := RunSession.new(definition, version, SaveManager.new(path))
		check.call(restored.load_checkpoint().ok and restored.read_state() == session.read_state(), "新Session精确恢复夜末检查点。")
		check.call(not restored.execute("resolve_night").ok, "读档后不能重复结算。")
		check.call(session.execute("continue_run").ok, "进入下一夜/结束时持久化检查点。")
		check.call(restored.load_checkpoint().ok and restored.read_state() == session.read_state(), "夜次推进后的读档不会重复上一夜。")
	check.call(session.read_state().phase == "run_ended" and not session.execute("continue_run").ok and session.read_state().current_night_index == definition.total_nights, "三夜结束，不生成第四夜。")
	var read_model := session.read_state()
	read_model.summaries.clear()
	check.call(session.read_state().summaries.size() == definition.total_nights, "ReadModel不能修改权威状态。")
	session.new_run()
	check.call(session.read_state().phase == "pre_open" and save.load_state(definition, version).phase == &"run_ended", "新游戏不立即覆盖旧检查点。")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

func _save_validation() -> void:
	var day := _day()
	for command in ["open_shop", "wait_until_seal", "resolve_night"]:
		day.execute(command)
	var codec := SaveCodec.new()
	var valid := codec.encode(day.state, version)
	for mutation in ["version", "content", "id", "fraction", "time", "phase", "summaries", "closed", "cash", "count", "early_end"]:
		var invalid := valid.duplicate(true)
		match mutation:
			"version": invalid.save_version = 999
			"content": invalid.content_version = 999
			"id": invalid.run_definition_id = "absent"
			"fraction": invalid.cash = 1.5
			"time": invalid.game_minutes = 100
			"phase": invalid.phase = "open"
			"summaries": invalid.summaries = []
			"closed": invalid.closed_at = -1
			"cash": invalid.cash = -1
			"count": invalid.action_count = 999
			"early_end": invalid.phase = "run_ended"
		check.call(codec.decode(invalid, definition, version) == null, "拒绝损坏/不兼容存档：" + mutation)
	var path := "user://tests/broken_%d.json" % Time.get_ticks_usec()
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string("{broken")
	file.close()
	var session := RunSession.new(definition, version, SaveManager.new(path))
	session.execute("open_shop")
	var previous := session.read_state()
	check.call(not session.load_checkpoint().ok and session.read_state() == previous and FileAccess.get_file_as_string(path) == "{broken", "损坏存档不替换当前运行也不删除原文件。")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

func _failures() -> void:
	var session := RunSession.new(definition, version, FailingSave.new())
	session.execute("open_shop")
	session.execute("wait_until_seal")
	var previous := session.read_state()
	check.call(not session.execute("resolve_night").ok and session.read_state() == previous, "磁盘失败回滚日结，留在可重试阶段。")
	check.call(not session.execute("resolve_night").ok and session.read_state().summaries.is_empty(), "重复重试失败不会积累日结。")
	var save := FailingSave.new("user://tests/rollback_%d.json" % Time.get_ticks_usec())
	save.fail_writes = false
	var recoverable := RunSession.new(definition, version, save)
	for command in ["open_shop", "wait_until_seal", "resolve_night"]:
		recoverable.execute(command)
	var checkpoint := recoverable.read_state()
	save.fail_writes = true
	check.call(not recoverable.execute("continue_run").ok and recoverable.read_state() == checkpoint, "下一夜写入失败回滚夜次与阶段。")
	check.call(save.load_state(definition, version).to_read_model() == checkpoint, "写入失败保留上次完整存档。")
	save.fail_writes = false
	check.call(recoverable.execute("continue_run").ok and recoverable.read_state().current_night_index == 2, "磁盘恢复后可重试进入下一夜。")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(save.path))
	var day := _day()
	check.call(not SaveManager.new("user://tests/absent/path.json").load_state(definition, version), "缺失存档安全返回失败。")
	check.call(not SaveManager.new("res://project.godot/blocked/save.json").save_state(day.state, definition, version), "实际不可写目录失败可控。")

func _day() -> DayController:
	return DayController.new(definition, RunState.create(definition))
