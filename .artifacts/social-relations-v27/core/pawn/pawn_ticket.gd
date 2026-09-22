class_name PawnTicket
extends RefCounted

var replacement_instance_id := ""
var person: Dictionary = {}
var ticket_id := ""
var terms_id := ""
var customer_id := ""
var item_instance_id := ""
var source_visit_id := ""
var principal := 0
var started_night := 0
var due_night := 0
var redemption_amount := 0
var status := "active"
var extensions: Array[Dictionary] = []
var closed_night := 0
var closed_minute := -1

func to_data() -> Dictionary:
	var data := {"person": person.duplicate(true), "ticket_id": ticket_id, "terms_id": terms_id, "customer_id": customer_id, "item_instance_id": item_instance_id, "source_visit_id": source_visit_id, "principal": principal, "started_night": started_night, "due_night": due_night, "redemption_amount": redemption_amount, "status": status, "extensions": extensions.duplicate(true), "closed_night": closed_night, "closed_minute": closed_minute}

	if not replacement_instance_id.is_empty(): data.replacement_instance_id = replacement_instance_id
	return data

func collateral_id() -> String:
	return replacement_instance_id if not replacement_instance_id.is_empty() else item_instance_id
