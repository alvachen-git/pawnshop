class_name BelittleService
extends RefCounted

static func apply(visit: CustomerVisit, customer: CustomerDefinition) -> String:
	var policy := customer.belittle
	var trade := visit.trade
	trade.belittle_used = true
	trade.rounds_left -= 1
	var before := trade.asking_price
	match policy.reaction:
		"yielding":
			var discount := int(policy.urgent_discount if visit.situation_id == "urgent" else policy.ordinary_discount)
			trade.reserve_price = maxi(1, trade.reserve_price - discount)
			trade.asking_price = maxi(trade.reserve_price, trade.asking_price - discount)
		"proud": trade.patience -= int(policy.patience_cost)
	return String(policy.response) + "\n要价 %d → %d 银元。" % [before, trade.asking_price]
