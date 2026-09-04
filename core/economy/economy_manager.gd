class_name EconomyManager
extends RefCounted

# Initialization/restore aside, this is the only cash mutation entry point.
func can_pay(state: RunState, amount: int, transaction_id: String) -> bool:
	if amount <= 0 or state.cash < amount: return false
	for entry in state.ledger_entries:
		if entry.transaction_id == transaction_id: return false
	return true

func pay_acquisition(state: RunState, amount: int, item_id: String, transaction_id: String) -> void:
	commit(state, -amount, item_id, transaction_id, "acquisition")

# Application services validate first; no signal or await inside an atomic commit.
func commit(state: RunState, amount: int, item_id: String, transaction_id: String, kind: String, profit := 0) -> void:
	state.cash += amount
	state.ledger_entries.append({"transaction_id": transaction_id, "item_instance_id": item_id, "night": state.current_night_index, "minute": state.game_minutes, "amount": amount, "balance": state.cash, "kind": kind, "realized_profit": profit})
