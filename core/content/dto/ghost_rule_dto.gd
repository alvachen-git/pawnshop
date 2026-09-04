class_name GhostRuleDTO
extends RefCounted

var id: String
var mechanic: String
var warning: String
var crisis: String
var death_cause: String
var cover_minutes: int
var uncover_minutes: int

static func from_source(row: Dictionary) -> GhostRuleDTO:
	var dto := GhostRuleDTO.new()
	dto.id = String(row.id)
	dto.mechanic = String(row.mechanic)
	dto.warning = String(row.warning)
	dto.crisis = String(row.crisis)
	dto.death_cause = String(row.death_cause)
	dto.cover_minutes = int(row.cover_minutes)
	dto.uncover_minutes = int(row.uncover_minutes)
	return dto
