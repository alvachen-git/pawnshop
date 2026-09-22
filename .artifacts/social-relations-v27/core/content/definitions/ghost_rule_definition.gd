class_name GhostRuleDefinition
extends RefCounted

var _id: String
var id: String:
	get: return _id
var _mechanic: String
var mechanic: String:
	get: return _mechanic
var _warning: String
var warning: String:
	get: return _warning
var _crisis: String
var crisis: String:
	get: return _crisis
var _death_cause: String
var death_cause: String:
	get: return _death_cause
var _cover_minutes: int
var cover_minutes: int:
	get: return _cover_minutes
var _uncover_minutes: int
var uncover_minutes: int:
	get: return _uncover_minutes

static func from_dto(dto: GhostRuleDTO) -> GhostRuleDefinition:
	var rule := GhostRuleDefinition.new()
	rule._id = dto.id
	rule._mechanic = dto.mechanic
	rule._warning = dto.warning
	rule._crisis = dto.crisis
	rule._death_cause = dto.death_cause
	rule._cover_minutes = dto.cover_minutes
	rule._uncover_minutes = dto.uncover_minutes
	return rule
