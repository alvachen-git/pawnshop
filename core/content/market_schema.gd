class_name MarketSchema
extends RefCounted

static func validate(record: Dictionary, path: String, at: String) -> Array:
	var issues: Array = []
	if not record.has("market"): return issues
	var config: Variant = record.market
	if not config is Dictionary:
		issues.append(ContentIssue.new("error", "invalid_market", path, at, "行情须为对象。"))
		return issues
	CounterSchema._fields(config, {"buyer_id": "text", "trip_minutes": "positive", "change_start": "nonnegative", "change_end": "positive"}, path, at + ".market", issues)
	if not config.get("demands") is Array:
		issues.append(ContentIssue.new("error", "invalid_market", path, at, "行情缺少需求列表。"))
		return issues
	for entry in config.demands:
		if not entry is Dictionary:
			issues.append(ContentIssue.new("error", "invalid_market", path, at, "需求须为对象。"))
			continue
		CounterSchema._fields(entry, {"id": "text", "category": "text", "name": "text", "title": "text", "body": "text"}, path, at + ".market.demands", issues)
	return issues

static func domain(run: RunDefinition, catalog: ContentCatalog) -> Array:
	var issues: Array = []
	if run.market.is_empty(): return issues
	var config := run.market
	var buyer := catalog.get_definition("buyers", config.buyer_id) as BuyerDefinition
	if buyer == null or config.buyer_id not in run.buyer_ids or config.trip_minutes != 20 or config.change_start < 0 or config.change_end < config.change_start or config.change_end + config.trip_minutes >= run.night_minutes or run.time_step < 1:
		issues.append(ContentIssue.new("error", "invalid_market", "ContentCatalog", run.id, "行情买家、时间或往返耗时无效。"))
		return issues
	if int(config.change_start) % run.time_step != 0 or int(config.change_end) % run.time_step != 0 or int(config.trip_minutes) % run.time_step != 0:
		issues.append(ContentIssue.new("error", "invalid_market", "ContentCatalog", run.id, "行情时间须与行动步长一致。"))
	var ids: Array = []
	var categories: Array = []
	for entry in config.demands:
		if entry.id in ids or entry.category in categories or entry.category not in buyer.categories or entry.category == "ghost":
			issues.append(ContentIssue.new("error", "invalid_market", "ContentCatalog", run.id, "需求重复或不属于普通收货品类。"))
		ids.append(entry.id)
		categories.append(entry.category)
	if ids.size() < 2:
		issues.append(ContentIssue.new("error", "invalid_market", "ContentCatalog", run.id, "至少两种需求才能更换偏好。"))
	for id in run.buyer_ids:
		var other := catalog.get_definition("buyers", id) as BuyerDefinition
		if other != null and (other.action_minutes != config.trip_minutes or other.capacity_per_night != 0):
			issues.append(ContentIssue.new("error", "invalid_market", "ContentCatalog", id, "批量出货须统一耗时且不限量。"))
	return issues
