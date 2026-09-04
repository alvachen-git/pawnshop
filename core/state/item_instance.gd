class_name ItemInstance
extends RefCounted

var instance_id: String
var definition_id: String
var selected_variant_id: String
var revealed_clue_ids: Array = []
var completed_action_ids: Array = []
var judgement := "unknown"
var acquisition_price := 0
var acquired_night := 0
var source_visit_id := ""
var acquisition_type := "purchase"
var ownership_state := "owned"

func to_data() -> Dictionary:
	return {"instance_id": instance_id, "definition_id": definition_id, "selected_variant_id": selected_variant_id, "revealed_clue_ids": revealed_clue_ids.duplicate(), "completed_action_ids": completed_action_ids.duplicate(), "judgement": judgement, "acquisition_price": acquisition_price, "acquired_night": acquired_night, "source_visit_id": source_visit_id, "acquisition_type": acquisition_type, "ownership_state": ownership_state}
