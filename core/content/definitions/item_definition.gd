class_name ItemDefinition
extends RefCounted

var _expertise: Dictionary = {}
var expertise: Dictionary:
	get: return _expertise.duplicate(true)

var _provenance: Dictionary = {}
var provenance: Dictionary:
	get: return _provenance.duplicate(true)

var _id: String
var id: String:
	get: return _id
var _name_key: String
var name_key: String:
	get: return _name_key
var _item_type: String
var item_type: String:
	get: return _item_type
var _category: String
var category: String:
	get: return _category
var _tags: Array
var tags: Array:
	get: return _tags.duplicate()
var _base_value: float
var base_value: float:
	get: return _base_value
var _value_variance: float
var value_variance: float:
	get: return _value_variance
var _liquidity: float
var liquidity: float:
	get: return _liquidity
var _possible_variants: Array[ItemVariantDefinition] = []
var possible_variants: Array[ItemVariantDefinition]:
	get: return _possible_variants.duplicate()
var _appraisal_actions: Array[AppraisalActionDefinition] = []
var appraisal_actions: Array[AppraisalActionDefinition]:
	get: return _appraisal_actions.duplicate()
var _clues: Array[ClueDefinition] = []
var clues: Array[ClueDefinition]:
	get: return _clues.duplicate()
var _display_name: String
var display_name: String:
	get: return _display_name
var _description: String
var description: String:
	get: return _description
var _unknown_min: int
var unknown_min: int:
	get: return _unknown_min
var _unknown_max: int
var unknown_max: int:
	get: return _unknown_max
var _valuation_rules: Array
var valuation_rules: Array:
	get: return _valuation_rules.duplicate()
var _sell_channels: Array
var sell_channels: Array:
	get: return _sell_channels.duplicate()
var _buyer_tags: Array
var buyer_tags: Array:
	get: return _buyer_tags.duplicate()
var _ghost_rule_id: String
var ghost_rule_id: String:
	get: return _ghost_rule_id
var _visual_asset_id: String
var visual_asset_id: String:
	get: return _visual_asset_id


static func from_dto(dto: ItemDTO) -> ItemDefinition:
	var definition := ItemDefinition.new()
	definition._expertise = dto.expertise.duplicate(true)
	definition._provenance = dto.provenance.duplicate(true)
	definition._id = dto.id
	definition._name_key = dto.name_key
	definition._item_type = dto.type
	definition._category = dto.category
	definition._tags = dto.tags.duplicate(true)
	definition._base_value = dto.base_value
	definition._value_variance = dto.value_variance
	definition._liquidity = dto.liquidity
	definition._display_name = dto.display_name
	definition._description = dto.description
	definition._unknown_min = dto.unknown_min
	definition._unknown_max = dto.unknown_max
	for variant in dto.possible_variants:
		definition._possible_variants.append(ItemVariantDefinition.new(variant.id, int(variant.get("true_value", dto.base_value)), float(variant.weight), variant.get("clue_ids", [])))
	for action in dto.appraisal_actions:
		definition._appraisal_actions.append(AppraisalActionDefinition.new(action.id, action.label, int(action.minutes), action.required_tool, action.requires_clues, action.reveals))
	for clue in dto.clues:
		var mapped := ClueDefinition.new(clue.id, clue.text, int(clue.min_value), int(clue.max_value), int(clue.leverage), clue.judgement)
		mapped.bargain_line = clue.get("bargain_line", "")
		mapped.bargain_response = clue.get("bargain_response", "")
		definition._clues.append(mapped)
	definition._valuation_rules = dto.valuation_rules.duplicate(true)
	definition._sell_channels = dto.sell_channels.duplicate(true)
	definition._buyer_tags = dto.buyer_tags.duplicate(true)
	definition._ghost_rule_id = dto.ghost_rule_id
	definition._visual_asset_id = dto.visual_asset_id
	return definition

func find_variant(key: String) -> ItemVariantDefinition:
	for entry in possible_variants:
		if entry.id == key: return entry
	return null

func find_clue(key: String) -> ClueDefinition:
	for entry in clues:
		if entry.id == key: return entry
	return null

func find_action(key: String) -> AppraisalActionDefinition:
	for entry in appraisal_actions:
		if entry.id == key: return entry
	return null
