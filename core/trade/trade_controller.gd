class_name TradeController
extends RefCounted

func quote(trade: TradeSession, customer: CustomerDefinition, price: int, threshold := -1) -> bool:
	trade.rounds_left -= 1
	trade.offers.append(price)
	if price >= (trade.reserve_price if threshold < 0 else threshold): return true
	trade.patience -= customer.terms.failed_quote_cost
	trade.asking_price = maxi(trade.reserve_price, trade.asking_price - customer.terms.counter_step)
	return false

func pressure(trade: TradeSession, customer: CustomerDefinition, clue: ClueDefinition) -> bool:
	trade.rounds_left -= 1
	trade.used_clue_ids.append(clue.id)
	if clue.leverage <= 0:
		trade.patience -= customer.terms.false_pressure_cost
		return false
	trade.reserve_price = maxi(1, trade.reserve_price - clue.leverage)
	trade.asking_price = maxi(trade.reserve_price, trade.asking_price - clue.leverage)
	return true
