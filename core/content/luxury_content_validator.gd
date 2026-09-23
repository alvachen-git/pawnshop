class_name LuxuryContentValidator
extends RefCounted

static func validate(catalog: ContentCatalog) -> Array:
	var issues: Array = []
	for run: RunDefinition in catalog.get_all("runs"):
		if not run.variety.has("luxury"): continue
		var config: Variant = run.variety.luxury
		if not config is Dictionary or config.get("version") != 1 or not config.get("profiles") is Dictionary or not config.get("items") is Dictionary:
			CounterDomainValidator._error(issues,run.id,"高档货配置缺少有效版本、职业与物品表。")
			continue
		if not SocialRules.enabled(run) or not FanAppraisalService.enabled(run) or not ShopKnowledgeService.enabled(run) or not PawnRedemptionPolicy.enabled(run):
			CounterDomainValidator._error(issues,run.id,"富客需要商誉、鉴物台、知识与三夜赎当规则。")
		if config.profiles.size() != 5 or config.items.size() != 10: CounterDomainValidator._error(issues,run.id,"首版富客需要五种职业和十种货物。")
		var ordinary_weight := 0
		for id in config.profiles:
			var profile: Variant = config.profiles[id]
			var customer := catalog.get_definition("customers",id) as CustomerDefinition
			if customer == null or not WealthyCustomers.is_customer(id) or not profile is Dictionary:
				CounterDomainValidator._error(issues,run.id,"富客职业引用不存在。")
				continue
			var valid := true
			for field in ["pawn_percent","weight","asking_percent","reserve_percent","funding_percent"]:
				if not RunSchema.integer(profile.get(field)): valid = false
			if not valid: CounterDomainValidator._error(issues,id,"富客比例须为整数。"); continue
			if id != WealthyCustomers.COMPRADOR:
				ordinary_weight += int(profile.weight)
				if profile.weight <= 0: CounterDomainValidator._error(issues,id,"四类普通富客须各有正权重。")
			if profile.pawn_percent < 0 or profile.pawn_percent > 100 or profile.weight < 0 or profile.asking_percent <= 0 or profile.reserve_percent <= 0 or profile.reserve_percent > profile.asking_percent or profile.funding_percent < 0 or profile.funding_percent > 100:
				CounterDomainValidator._error(issues,id,"富客报价、资金需求或出现权重无效。")
			var weights: Variant = profile.get("weights")
			if not weights is Array or weights.size() != 3 or weights.any(func(w: Variant) -> bool: return not RunSchema.integer(w) or w < 0) or int(weights[0])+int(weights[1])+int(weights[2]) != 100:
				CounterDomainValidator._error(issues,id,"三种货况的权重须合计100。")
			for iid in customer.item_pool:
				if not config.items.has(iid): CounterDomainValidator._error(issues,id,"富客携货缺少鉴定图录。")
		if not config.profiles.has(WealthyCustomers.COMPRADOR): CounterDomainValidator._error(issues,run.id,"缺少洋行大买办配置。")
		if ordinary_weight <= 0: CounterDomainValidator._error(issues,run.id,"普通富客权重总和须大于零。")
		for id in config.items:
			var item := catalog.get_definition("items",id) as ItemDefinition
			var book: Variant = config.items[id]
			if item == null or not WealthyCustomers.is_item(id) or not book is Dictionary:
				CounterDomainValidator._error(issues,run.id,"高档货图录引用不存在。"); continue
			if not ShopKnowledgeService.TOPICS.has(book.get("topic","")): CounterDomainValidator._error(issues,id,"图录缺少对应知识。")
			for field in ["checks","references"]:
				if not book.get(field) is Array or book[field].size() != 2 or book[field].any(func(v: Variant) -> bool: return not v is String or v.is_empty()): CounterDomainValidator._error(issues,id,"须有两项细查与两段图录。")
			for field in ["observations","identity","condition"]:
				if not book.get(field) is Dictionary: CounterDomainValidator._error(issues,id,"鉴定变体表缺失。"); continue
				for variant in ["sound","mended","flawed"]:
					var value: Variant = book[field].get(variant)
					if item.find_variant(variant) == null: CounterDomainValidator._error(issues,id,"缺少高档货变体。"); continue
					if field == "observations":
						if not value is Array or value.size() != 2 or value.any(func(v: Variant) -> bool: return not v is String or v.is_empty()): CounterDomainValidator._error(issues,id,"每种货况须有两项实物证据。")
					elif field == "identity" and not LuxuryAppraisalService.IDENTITIES.has(value): CounterDomainValidator._error(issues,id,"身份判断无效。")
					elif field == "condition" and not LuxuryAppraisalService.CONDITIONS.has(value): CounterDomainValidator._error(issues,id,"品相判断无效。")
		if run.variety.has("tiered_appraisal_version"):
			validate_tiers(catalog,run,issues)
	return issues

static func validate_tiers(catalog: ContentCatalog, run: RunDefinition, issues: Array) -> void:
	var config: Variant = run.variety.get("tiered_appraisal")
	if catalog.content_version < 32 or run.variety.tiered_appraisal_version != 1 or not config is Dictionary:
		CounterDomainValidator._error(issues,run.id,"精鉴配置版本无效。"); return
	if config.size() != 10: CounterDomainValidator._error(issues,run.id,"十件高档货均须配备分级图录。")
	for id in run.variety.luxury.items:
		var row: Variant = config.get(id)
		if not row is Dictionary: CounterDomainValidator._error(issues,id,"缺少分级鉴定配置。"); continue
		if row.get("kit") not in ["","display","metal","clock","jewel"] or row.get("deep_kit") not in ["optics","balance","clock_deep"]:
			CounterDomainValidator._error(issues,id,"鉴定器材引用无效。")
		for key in ["damage","deep_checks","deep_references","ambiguous"]:
			var entries: Variant = row.get(key)
			if not entries is Array or entries.size() != (3 if key == "damage" else 2) or entries.any(func(v: Variant) -> bool: return not v is String or v.is_empty()):
				CounterDomainValidator._error(issues,id,"分级观察或图录缺失："+key)
		var observations: Variant = row.get("deep_observations")
		if not observations is Dictionary: CounterDomainValidator._error(issues,id,"缺少深查货况表。")
		else:
			for variant in ["sound","mended","flawed"]:
				var entries: Variant = observations.get(variant)
				if not entries is Array or entries.size() != 2 or entries.any(func(v: Variant) -> bool: return not v is String or v.is_empty()): CounterDomainValidator._error(issues,id,"每种货况须有两处深查证据。")
		if not row.get("atlas") is String or not FileAccess.file_exists(row.get("atlas","")): CounterDomainValidator._error(issues,id,"缺少物品与细节图。")
