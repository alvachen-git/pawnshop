class_name RunSession
extends RefCounted

signal changed

var definition: RunDefinition
var content_version: int
var message := "开铺前准备。查看面板不耗时；开铺后可接待顾客。"
var _day: DayController
var _save: SaveManager
var _counter: CounterService
var _commerce: CommerceService

func _init(run_definition: RunDefinition, version: int, save_manager: SaveManager, catalog: ContentCatalog = null) -> void:
	definition = run_definition
	content_version = version
	_save = save_manager
	_day = DayController.new(definition, RunState.create(definition))
	if catalog != null:
		_counter = CounterService.new(catalog)
		_commerce = CommerceService.new(catalog)
		_save.catalog = catalog
		_counter.customers.prepare_night(_day.state, definition, catalog)

func read_state() -> Dictionary:
	return _day.state.to_read_model()

func has_save() -> bool:
	return _save.exists()

func can_execute(command: String) -> bool:
	return _day.can_execute(command)

func execute(command: String) -> ActionResult:
	# Only these commands create checkpoints. Snapshot before mutation for rollback.
	var checkpoint := command in ["resolve_night", "continue_run"]
	var previous: RunState
	if checkpoint:
		previous = _copy_state(_day.state)
	if command == "resolve_night" and _day.can_execute(command) and _commerce != null:
		_commerce.pawns.resolve_maturities(_day.state, definition.night_minutes)
	var result := _day.execute(command)
	if result.ok and _counter != null:
		if command == "continue_run" and _day.state.phase == &"pre_open":
			_counter.customers.prepare_night(_day.state, definition, _counter.catalog)
		_counter.customers.update(_day.state)
	if result.ok and checkpoint:
		if not _save.save_state(_day.state, definition, content_version):
			_day.state = previous
			result = ActionResult.new(false, "未推进；请重试。" + _save.error_message)
		else:
			result.message = "夜末检查点已保存。"
	message = result.message
	changed.emit()
	return result

func load_checkpoint() -> ActionResult:
	var restored := _save.load_state(definition, content_version)
	var result := ActionResult.new(restored != null, "已恢复夜末检查点。" if restored != null else _save.error_message)
	if restored != null:
		_day.state = restored
		if _counter != null and restored.phase == &"pre_open":
			_counter.customers.prepare_night(restored, definition, _counter.catalog)
	message = result.message
	changed.emit()
	return result

func new_run() -> void:
	_day.state = RunState.create(definition)
	if _counter != null:
		_counter.customers.prepare_night(_day.state, definition, _counter.catalog)
	message = "新运行已开始；旧存档保留到本次首次夜末自动保存。"
	changed.emit()

func _copy_state(source: RunState) -> RunState:
	var copy := RunState.new()
	for key in source.to_read_model():
		if key in ["inventory_instances", "pawn_tickets"]: continue
		copy.set(key, source.get(key).duplicate(true) if source.get(key) is Array else source.get(key))
	for item in source.inventory_instances:
		var clone := ItemInstance.new()
		for key in item.to_data(): clone.set(key, item.to_data()[key])
		copy.inventory_instances.append(clone)
	for ticket in source.pawn_tickets:
		var clone := PawnTicket.new()
		for key in ticket.to_data(): clone.set(key, ticket.to_data()[key])
		copy.pawn_tickets.append(clone)
	copy.visits = source.visits.duplicate()
	return copy

func counter_command(command: String, visit_id: String, detail := "", amount := 0) -> ActionResult:
	var result := ActionResult.new(false, "当前运行未接入柜台内容。")
	if _counter != null:
		result = _counter.execute(_day, command, visit_id, detail, amount)
	message = result.message
	changed.emit()
	return result

func counter_model() -> Dictionary:
	var model := CounterReadModels.build(_day, _counter, message)
	if _commerce != null: model.merge(CommerceReadModels.build(_day, _commerce, message), true)
	return model

func commerce_command(command: String, target: String, detail := "") -> ActionResult:
	var result := ActionResult.new(false, "当前运行没有交易内容。")
	if _commerce != null:
		result = _commerce.execute(_day, command, target, detail)
		_counter.customers.update(_day.state)
	message = result.message
	changed.emit()
	return result
