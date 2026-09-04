class_name RunDTO
extends RefCounted

var id: String
var total_nights: int
var opening_minute: int
var night_minutes: int
var time_step: int
var initial_cash: int
var seed: int
var actions: Array
var customer_slots: Array = []
var tools: Array = []
var buyer_ids: Array = []

static func from_source(source: Dictionary) -> RunDTO:
	var dto := RunDTO.new()
	dto.id = source.id
	dto.total_nights = int(source.total_nights)
	dto.opening_minute = int(source.opening_minute)
	dto.night_minutes = int(source.night_minutes)
	dto.time_step = int(source.time_step)
	dto.initial_cash = int(source.initial_cash)
	dto.seed = int(source.seed)
	dto.actions = source.actions.duplicate(true)
	dto.customer_slots = source.get("customer_slots", []).duplicate(true)
	dto.tools = source.get("tools", []).duplicate()
	dto.buyer_ids = source.get("buyer_ids", []).duplicate()
	return dto
