class_name CustomerDefinition
extends RefCounted
var _belittle: Dictionary
var belittle: Dictionary:
	get: return _belittle.duplicate(true)

var _persona: Dictionary = {}
var persona: Dictionary:
	get: return _persona.duplicate(true)
var _pawn_terms_id: String
var _pawn_redemption_chance := -1
var pawn_redemption_chance: int:
	get: return _pawn_redemption_chance
var pawn_terms_id: String:
	get: return _pawn_terms_id

var _id: String
var id: String:
	get: return _id
var _name_key: String
var name_key: String:
	get: return _name_key
var _portrait_asset_id: String
var portrait_asset_id: String:
	get: return _portrait_asset_id
var _identity_tags: Array
var identity_tags: Array:
	get: return _identity_tags.duplicate()
var _wealth_band: String
var wealth_band: String:
	get: return _wealth_band
var _urgency_range: Array
var urgency_range: Array:
	get: return _urgency_range.duplicate()
var _honesty_profile: String
var honesty_profile: String:
	get: return _honesty_profile
var _patience: int
var patience: int:
	get: return _patience
var _max_quote_rounds: int
var max_quote_rounds: int:
	get: return _max_quote_rounds
var _alertness: float
var alertness: float:
	get: return _alertness
var _transaction_modes: Array
var transaction_modes: Array:
	get: return _transaction_modes.duplicate()
var _item_pool: Array
var item_pool: Array:
	get: return _item_pool.duplicate()
var _dialogue_profile_id: String
var dialogue_profile_id: String:
	get: return _dialogue_profile_id
var _preferred_categories: Array
var preferred_categories: Array:
	get: return _preferred_categories.duplicate()
var _schedule_tags: Array
var schedule_tags: Array:
	get: return _schedule_tags.duplicate()
var _terms: CustomerTermsDefinition
var terms: CustomerTermsDefinition:
	get: return _terms
var _questions: Array[QuestionDefinition] = []
var questions: Array[QuestionDefinition]:
	get: return _questions.duplicate()


static func from_dto(dto: CustomerDTO) -> CustomerDefinition:
	var definition := CustomerDefinition.new()
	definition._belittle = dto.belittle.duplicate(true)
	definition._persona = dto.persona.duplicate(true)
	definition._pawn_terms_id = dto.pawn_terms_id
	definition._pawn_redemption_chance = dto.pawn_redemption_chance
	definition._id = dto.id
	definition._name_key = dto.name_key
	definition._portrait_asset_id = dto.portrait_asset_id
	definition._identity_tags = dto.identity_tags.duplicate(true)
	definition._wealth_band = dto.wealth_band
	definition._urgency_range = dto.urgency_range.duplicate(true)
	definition._honesty_profile = dto.honesty_profile
	definition._patience = dto.patience
	definition._max_quote_rounds = dto.max_quote_rounds
	definition._alertness = dto.alertness
	definition._transaction_modes = dto.transaction_modes.duplicate(true)
	definition._item_pool = dto.item_pool.duplicate(true)
	definition._dialogue_profile_id = dto.dialogue_profile_id
	definition._preferred_categories = dto.preferred_categories.duplicate(true)
	definition._schedule_tags = dto.schedule_tags.duplicate(true)
	if not dto.counter_terms.is_empty():
		var t := dto.counter_terms
		definition._terms = CustomerTermsDefinition.new(t.display_name, t.introduction, int(t.wait_minutes), int(t.quote_minutes), int(t.pressure_minutes), int(t.reject_minutes), float(t.ask_multiplier), float(t.reserve_ratio), int(t.counter_step), int(t.failed_quote_cost), int(t.false_pressure_cost))
	for question in dto.questions:
		definition._questions.append(QuestionDefinition.new(question.id, question.prompt, question.answer, int(question.minutes)))
	return definition

func find_question(key: String) -> QuestionDefinition:
	for question in questions:
		if question.id == key: return question
	return null
