class_name DomainValidator
extends RefCounted


func validate_catalog(catalog: ContentCatalog) -> Array:
	var issues: Array = []
	issues.append_array(CounterDomainValidator.validate(catalog))
	issues.append_array(CommerceDomainValidator.validate(catalog))
	issues.append_array(EventDomainValidator.validate(catalog))
	issues.append_array(GhostSchema.domain(catalog))
	issues.append_array(RunExtensionSchema.domain(catalog))
	for run in catalog.get_all("runs"):
		if run.total_nights < 1 or run.time_step < 1 or run.night_minutes < 1 or run.initial_cash < 0 or run.opening_minute < 0 or run.opening_minute >= 1440 or run.seed < 0:
			issues.append(ContentIssue.new("error", "invalid_run", "ContentCatalog", "runs." + run.id, "运行定义不符合领域不变量。"))
			continue
		if run.night_minutes % run.time_step != 0:
			issues.append(ContentIssue.new("error", "invalid_duration", "ContentCatalog", "runs." + run.id, "时长与步长不一致。"))
		var ids: Array = ["open_shop", "close_shop", "wait_until_seal", "resolve_night", "continue_run"]
		for action in run.actions:
			if action.id.is_empty() or action.id in ids or action.minutes <= 0 or action.minutes > run.night_minutes or action.minutes % run.time_step != 0 or action.phases.is_empty():
				issues.append(ContentIssue.new("error", "invalid_action", "ContentCatalog", "runs." + run.id, "行动不符合领域不变量。"))
			ids.append(action.id)
			for phase in action.phases:
				if phase not in ["open", "closed_processing"]:
					issues.append(ContentIssue.new("error", "invalid_phase", "ContentCatalog", "runs." + run.id, "行动阶段无效。"))
	if not catalog.default_run_id.is_empty() and not catalog.has_definition("runs", catalog.default_run_id):
		issues.append(ContentIssue.new("error", "missing_reference", "ContentCatalog", "default_run_id", "默认运行定义不存在。"))
	for customer in catalog.get_all("customers"):
		for item_id in customer.item_pool:
			if not catalog.has_definition("items", item_id):
				issues.append(ContentIssue.new(
					ContentIssue.ERROR,
					"missing_reference",
					"ContentCatalog",
					"customers.%s.item_pool" % customer.id,
					"引用了不存在的物品：%s" % item_id
				))
	return issues
