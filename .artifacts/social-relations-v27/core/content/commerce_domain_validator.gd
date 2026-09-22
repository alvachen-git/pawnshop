class_name CommerceDomainValidator
extends RefCounted

static func validate(catalog: ContentCatalog) -> Array:
	var issues: Array = []
	for buyer: BuyerDefinition in catalog.get_all("buyers"):
		if buyer.categories.is_empty() or not is_finite(buyer.value_multiplier) or buyer.value_multiplier <= 0 or buyer.value_multiplier > 100 or buyer.night_min < 1 or buyer.night_max < buyer.night_min or buyer.window_start < 0 or buyer.window_end <= buyer.window_start or buyer.action_minutes <= 0 or buyer.capacity_per_night < 0:
			_error(issues, buyer.id, "买家偏好、倍率、窗口或额度无效。")
	for terms: PawnTermsDefinition in catalog.get_all("pawn_terms"):
		if not is_finite(terms.loan_ratio) or terms.loan_ratio <= 0 or terms.loan_ratio > 1 or terms.term_nights < 1 or terms.extension_nights < 1 or terms.redeem_minutes < 1 or terms.extend_minutes < 1 or terms.window_start < 0 or terms.window_end <= terms.window_start or terms.return_mode not in ["redeem", "extend_once", "absent"]:
			_error(issues, terms.id, "当约比例、期限、窗口或返当行为无效。")
		for fee in [terms.redemption_fee_ratio, terms.extension_fee_ratio, terms.transfer_ratio]:
			if not is_finite(fee) or fee <= 0 or fee > 1: _error(issues, terms.id, "当约费用比例无效。")
	for customer: CustomerDefinition in catalog.get_all("customers"):
		if not customer.pawn_terms_id.is_empty() and (not catalog.has_definition("pawn_terms", customer.pawn_terms_id) or "pawn" not in customer.transaction_modes):
			_error(issues, customer.id, "当约引用失效或顾客不支持活当。")
	for run: RunDefinition in catalog.get_all("runs"):
		var ids: Array = []
		for id in run.buyer_ids:
			var buyer := catalog.get_definition("buyers", id) as BuyerDefinition
			if buyer == null or id in ids:
				_error(issues, run.id, "买家引用无效或重复。")
				continue
			ids.append(id)
			_check_window(issues, run, buyer.id, buyer.window_start, buyer.window_end, buyer.action_minutes)
		var return_minutes: Dictionary = {}
		for slot in run.customer_slots:
			var customer := catalog.get_definition("customers", slot.customer_id) as CustomerDefinition
			if customer == null or customer.pawn_terms_id.is_empty(): continue
			var terms := catalog.get_definition("pawn_terms", customer.pawn_terms_id) as PawnTermsDefinition
			if terms == null: continue
			if terms.return_mode != "absent":
				for origin in range(maxi(1, slot.night_min), mini(run.total_nights, slot.night_max) + 1):
					var due := origin + terms.term_nights
					return_minutes[due] = int(return_minutes.get(due, 0)) + (terms.extend_minutes if terms.return_mode == "extend_once" else terms.redeem_minutes)
					if terms.return_mode == "extend_once":
						due += terms.extension_nights
						return_minutes[due] = int(return_minutes.get(due, 0)) + terms.redeem_minutes
			_check_window(issues, run, terms.id, terms.window_start, terms.window_end, terms.redeem_minutes)
			_check_window(issues, run, terms.id, terms.window_start, terms.window_end, terms.extend_minutes)
		for night in return_minutes:
			if night <= run.total_nights and return_minutes[night] >= run.night_minutes: _error(issues, run.id, "当户回访耗时须留出新客营业时间。")
	return issues

static func _check_window(issues: Array, run: RunDefinition, id: String, start: int, end: int, cost: int) -> void:
	if run.time_step < 1: return
	if end > run.night_minutes or end - start <= cost or start % run.time_step != 0 or end % run.time_step != 0 or cost % run.time_step != 0:
		_error(issues, id, "窗口/耗时不符合运行长度与步长。")

static func _error(issues: Array, id: String, message: String) -> void:
	issues.append(ContentIssue.new("error", "invalid_commerce_content", "ContentCatalog", id, message))
