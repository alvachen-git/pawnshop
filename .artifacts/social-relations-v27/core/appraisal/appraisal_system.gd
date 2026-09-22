class_name AppraisalSystem
extends RefCounted

func can_perform(item: ItemInstance, definition: ItemDefinition, action_id: String, tools: Array) -> bool:
	var action := definition.find_action(action_id)
	if action == null or action_id in item.completed_action_ids: return false
	if not action.required_tool.is_empty() and action.required_tool not in tools: return false
	for clue_id in action.requires_clues:
		if clue_id not in item.revealed_clue_ids: return false
	return true

func perform(item: ItemInstance, definition: ItemDefinition, action_id: String) -> String:
	var action := definition.find_action(action_id)
	var truth := definition.find_variant(item.selected_variant_id)
	var messages: PackedStringArray = []
	item.completed_action_ids.append(action_id)
	for clue_id in action.reveals:
		if clue_id in truth.clue_ids and clue_id not in item.revealed_clue_ids:
			item.revealed_clue_ids.append(clue_id)
			messages.append(definition.find_clue(clue_id).text)
	return "\n".join(messages) if not messages.is_empty() else "本次检查没有得到新证据。"

func valuation(item: ItemInstance, definition: ItemDefinition) -> Vector2i:
	var bounds := Vector2i(definition.unknown_min, definition.unknown_max)
	for clue_id in item.revealed_clue_ids:
		var clue := definition.find_clue(clue_id)
		bounds.x = maxi(bounds.x, clue.min_value)
		bounds.y = mini(bounds.y, clue.max_value)
	return bounds
