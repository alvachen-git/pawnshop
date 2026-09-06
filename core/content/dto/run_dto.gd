class_name RunDTO
extends RefCounted

var market: Dictionary = {}
var variety: Dictionary = {}

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
var ghost_rule_ids: Array = []
var event_ids: Array = []
var flag_ids: Array = []
var buyer_ids: Array = []
var fee_policy: Dictionary = {}
var mirror_encounters: Array = []
var trade_scenarios: Array = []
var randomize_seed := false
var private_room := false

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
	dto.ghost_rule_ids = source.get("ghost_rule_ids", []).duplicate()
	dto.event_ids = source.get("event_ids", []).duplicate()
	dto.flag_ids = source.get("flag_ids", []).duplicate()
	dto.fee_policy = source.get("fee_policy", {}).duplicate(true)
	dto.mirror_encounters = source.get("mirror_encounters", []).duplicate(true)
	dto.trade_scenarios = source.get("trade_scenarios", []).duplicate(true)
	dto.randomize_seed = source.get("randomize_seed", false)
	dto.private_room = source.get("private_room", false)
	dto.market = source.get("market", {}).duplicate(true)
	dto.variety = source.get("variety", {}).duplicate(true)
	return dto
