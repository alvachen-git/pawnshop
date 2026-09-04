class_name InventoryManager
extends RefCounted

func find(state: RunState, instance_id: String) -> ItemInstance:
	for item in state.inventory_instances:
		if item.instance_id == instance_id: return item
	return null

func contains(state: RunState, instance_id: String) -> bool:
	for item in state.inventory_instances:
		if item.instance_id == instance_id: return true
	return false

func acquire(state: RunState, item: ItemInstance, visit_id: String, price: int) -> void:
	item.acquisition_price = price
	item.acquired_night = state.current_night_index
	item.source_visit_id = visit_id
	state.inventory_instances.append(item)
