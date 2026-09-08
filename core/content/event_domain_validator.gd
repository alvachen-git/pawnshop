class_name EventDomainValidator
extends RefCounted

static func validate(catalog: ContentCatalog) -> Array:
	var issues: Array = []
	for event: EventDefinition in catalog.get_all("events"):
		if event.kind not in ["anchor", "conditional", "random"] or event.phase not in ["pre_open", "open", "closed_processing", "private_room", "sleep_resolution"] or event.night_min < 1 or event.night_max < event.night_min or event.window_start < 0 or event.window_end <= event.window_start or event.priority < 0 or event.weight < 1 or event.max_count < 1 or event.cooldown < 0 or event.choices.is_empty():
			_error(issues, event.id, "事件类型、窗口、权重、次数或选项无效。")
		# M4 guaranteed anchors run before opening, where player actions cannot skip them.
		if event.kind == "anchor" and event.presentation.is_empty() and (event.phase != "pre_open" or event.window_start != 0 or not event.required_flags.is_empty() or not event.excluded_flags.is_empty() or not event.required_items.is_empty() or not event.conflicts_with.is_empty()):
			_error(issues, event.id, "M4保底锚点须为无条件开铺前事件；条件剧情使用conditional。")
		if event.phase == "pre_open" and event.window_start != 0: _error(issues, event.id, "开铺前窗口必须从0开始。")
		for flag in event.required_flags:
			if flag in event.excluded_flags: _error(issues, event.id, "同一标记不能同时要求和排除。")
		for id in event.required_items:
			if not catalog.has_definition("items", id): _error(issues, event.id, "物品条件引用失效。")
		for id in event.conflicts_with:
			var other := catalog.get_definition("events", id) as EventDefinition
			if other == null or id == event.id or other.kind == "anchor": _error(issues, event.id, "互斥引用失效或试图排除保底锚点。")
		var choices: Array = []
		for choice in event.choices:
			if choice.id.is_empty() or choice.id in choices or choice.minutes < 0 or (event.phase in ["pre_open", "private_room", "sleep_resolution"] and choice.minutes != 0) or (event.phase != "pre_open" and choice.minutes == 0 and event.presentation.is_empty()): _error(issues, event.id, "选项ID重复或耗时不符合阶段。")
			for id in choice.required_items:
				if not catalog.has_definition("items", id): _error(issues, event.id, "选项物品条件引用失效。")
			choices.append(choice.id)
	for run: RunDefinition in catalog.get_all("runs"):
		if run.time_step < 1: continue
		var generated: Array = []
		for id in run.event_ids:
			var event := catalog.get_definition("events", id) as EventDefinition
			if event == null:
				_error(issues, run.id, "事件引用失效：" + id)
				continue
			if event.presentation.has("purchase_slot_id") and not run.customer_slots.any(func(slot: VisitSlotDefinition) -> bool: return slot.id == event.presentation.purchase_slot_id): _error(issues, id, "成交剧情引用的来访不存在。")
			var room_event := event.phase in ["private_room", "sleep_resolution"]
			if room_event and (not run.private_room or event.window_start != run.night_minutes): _error(issues, id, "房间事件须在封铺后。")
			if event.night_min > run.total_nights or event.window_end > run.night_minutes + (run.time_step if room_event else 0) or event.window_start % run.time_step != 0 or event.window_end % run.time_step != 0: _error(issues, id, "事件窗口超出运行或不匹配步长。")
			for ref in event.conflicts_with:
				if ref not in run.event_ids: _error(issues, id, "互斥事件不在同一运行中。")
			for flag in event.required_flags + event.excluded_flags:
				if flag not in run.flag_ids: _error(issues, id, "事件使用未声明标记：" + flag)
			for choice in event.choices:
				for flag in choice.required_flags + choice.excluded_flags:
					if flag not in run.flag_ids: _error(issues, id, "选项使用未声明标记。")
				if choice.minutes % run.time_step != 0 or choice.minutes >= event.window_end - event.window_start: _error(issues, id, "选项耗时无法在窗口内完成。")
				for flag in choice.grant_flags:
					if flag not in run.flag_ids: _error(issues, id, "选项写入未声明标记。")
					if flag not in generated: generated.append(flag)
		for flag in run.flag_ids:
			if flag not in generated: _error(issues, run.id, "标记没有事件来源：" + flag)
		# Fixed-point prerequisites catch chains which can never start.
		var reachable: Array = []
		for iteration in run.event_ids.size():
			for id in run.event_ids:
				var event := catalog.get_definition("events", id) as EventDefinition
				if event == null or not CounterDomainValidator._contains_all(reachable, event.required_flags): continue
				for choice in event.choices:
					for flag in choice.grant_flags:
						if flag not in reachable: reachable.append(flag)
		for id in run.event_ids:
			var event := catalog.get_definition("events", id) as EventDefinition
			if event != null and not CounterDomainValidator._contains_all(reachable, event.required_flags): _error(issues, id, "事件前置标记循环或不可达。")
		for id in run.buyer_ids:
			var buyer := catalog.get_definition("buyers", id) as BuyerDefinition
			if buyer == null: continue
			for flag in buyer.required_flags:
				if flag not in run.flag_ids: _error(issues, id, "买家要求未声明标记。")
	return issues

static func _error(issues: Array, id: String, message: String) -> void:
	issues.append(ContentIssue.new("error", "invalid_event_content", "ContentCatalog", id, message))
