class_name CustomerDTO
extends RefCounted

var id: String
var name_key: String
var portrait_asset_id: String
var identity_tags: Array
var wealth_band: String
var urgency_range: Array
var honesty_profile: String
var patience: int
var max_quote_rounds: int
var alertness: float
var transaction_modes: Array
var item_pool: Array
var dialogue_profile_id: String
var preferred_categories: Array
var schedule_tags: Array
var belittle: Dictionary
var counter_terms: Dictionary
var questions: Array
var pawn_terms_id: String


static func from_source(source: Dictionary) -> CustomerDTO:
	var dto := CustomerDTO.new()
	dto.id = source.id
	dto.name_key = source.name_key
	dto.portrait_asset_id = source.portrait_asset_id
	dto.identity_tags = source.identity_tags.duplicate(true)
	dto.wealth_band = source.wealth_band
	dto.urgency_range = source.urgency_range.duplicate(true)
	dto.honesty_profile = source.honesty_profile
	dto.patience = int(source.patience)
	dto.max_quote_rounds = int(source.max_quote_rounds)
	dto.alertness = float(source.alertness)
	dto.transaction_modes = source.transaction_modes.duplicate(true)
	dto.item_pool = source.item_pool.duplicate(true)
	dto.dialogue_profile_id = source.dialogue_profile_id
	dto.preferred_categories = source.preferred_categories.duplicate(true)
	dto.schedule_tags = source.schedule_tags.duplicate(true)
	dto.belittle = source.get("belittle", {}).duplicate(true)
	dto.counter_terms = source.get("counter_terms", {}).duplicate(true)
	dto.questions = source.get("questions", []).duplicate(true)
	dto.pawn_terms_id = source.get("pawn_terms_id", "")
	return dto
