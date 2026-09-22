class_name RunSchema
extends RefCounted

static func validate(record: Variant, path: String, location: String) -> Array:
	var errors: Array = []
	if not record is Dictionary:
		return [ContentIssue.new("error", "invalid_record", path, location, "运行定义必须为对象。")]
	for key in ["id", "total_nights", "opening_minute", "night_minutes", "time_step", "initial_cash", "seed", "actions"]:
		if not record.has(key):
			errors.append(ContentIssue.new("error", "missing_field", path, location + "." + key, "缺少必填字段。"))
	if not errors.is_empty():
		return errors
	if not record.id is String or record.id.is_empty():
		errors.append(ContentIssue.new("error", "invalid_id", path, location + ".id", "需要非空字符串ID。"))
	for key in ["total_nights", "opening_minute", "night_minutes", "time_step", "initial_cash", "seed"]:
		if not integer(record[key]) or record[key] < 0 or record[key] > 2147483647:
			errors.append(ContentIssue.new("error", "invalid_integer", path, location + "." + key, "需要非负有限整数。"))
	if not errors.is_empty():
		return errors
	if record.total_nights < 1 or record.time_step < 1 or record.night_minutes < 1 or record.opening_minute >= 1440:
		errors.append(ContentIssue.new("error", "invalid_range", path, location, "夜数、时间步长及总时长须大于0，开铺时间须在一天内。"))
	elif int(record.night_minutes) % int(record.time_step) != 0:
		errors.append(ContentIssue.new("error", "invalid_time_step", path, location, "总时长必须是时间步长的整数倍。"))
	if not record.actions is Array:
		errors.append(ContentIssue.new("error", "invalid_type", path, location + ".actions", "需要行动数组。"))
		return errors
	if record.has("private_room") and not record.private_room is bool:
		errors.append(ContentIssue.new("error", "invalid_type", path, location + ".private_room", "房间开关必须为布尔值。"))
	if record.has("batch_selling") and not record.batch_selling is bool:
		errors.append(ContentIssue.new("error", "invalid_type", path, location, "批量出售开关必须为布尔值。"))
	var ids: Array = ["open_shop", "close_shop", "wait_until_seal", "resolve_night", "continue_run", "enter_room", "sleep", "finish_sleep"]
	for index in record.actions.size():
		var action: Variant = record.actions[index]
		var at := location + ".actions[%d]" % index
		if not action is Dictionary or not action.has_all(["id", "label", "minutes", "phases"]):
			errors.append(ContentIssue.new("error", "invalid_action", path, at, "行动需要id/label/minutes/phases。"))
			continue
		if not action.id is String or action.id.is_empty() or action.id in ids:
			errors.append(ContentIssue.new("error", "duplicate_action", path, at + ".id", "行动ID无效、重复或与控制命令冲突。"))
		ids.append(action.id)
		if not action.label is String or action.label.is_empty():
			errors.append(ContentIssue.new("error", "invalid_label", path, at + ".label", "行动名称不能为空。"))
		if not integer(action.minutes) or action.minutes <= 0:
			errors.append(ContentIssue.new("error", "invalid_cost", path, at + ".minutes", "耗时必须为正整数。"))
		elif record.time_step > 0 and (int(action.minutes) % int(record.time_step) != 0 or action.minutes > record.night_minutes):
			errors.append(ContentIssue.new("error", "invalid_cost", path, at + ".minutes", "耗时须匹配时间步长且不超过一夜。"))
		if not action.phases is Array or action.phases.is_empty():
			errors.append(ContentIssue.new("error", "invalid_phase", path, at + ".phases", "需要非空允许阶段数组。"))
		else:
			for phase in action.phases:
				if phase not in ["open", "closed_processing"]:
					errors.append(ContentIssue.new("error", "invalid_phase", path, at + ".phases", "仅支持营业/关门处理阶段。"))
	errors.append_array(RunExtensionSchema.validate(record, path, location))
	return errors

static func integer(value: Variant) -> bool:
	return typeof(value) == TYPE_INT or (typeof(value) == TYPE_FLOAT and is_finite(value) and value == floor(value))
