class_name ItemDTO
extends RefCounted

var provenance: Dictionary = {}
var expertise: Dictionary = {}

var id: String
var name_key: String
var type: String
var category: String
var tags: Array
var base_value: float
var value_variance: float
var liquidity: float
var possible_variants: Array
var appraisal_actions: Array
var clues: Array
var valuation_rules: Array
var sell_channels: Array
var buyer_tags: Array
var ghost_rule_id: String
var visual_asset_id: String
var display_name: String
var description: String
var unknown_min: int
var unknown_max: int


static func from_source(source: Dictionary) -> ItemDTO:
	var dto := ItemDTO.new()
	dto.id = source.id
	dto.name_key = source.name_key
	dto.type = source.type
	dto.category = source.category
	dto.tags = source.tags.duplicate(true)
	dto.base_value = float(source.base_value)
	dto.value_variance = float(source.value_variance)
	dto.liquidity = float(source.liquidity)
	dto.possible_variants = source.possible_variants.duplicate(true)
	dto.appraisal_actions = source.appraisal_actions.duplicate(true)
	dto.clues = source.clues.duplicate(true)
	dto.valuation_rules = source.valuation_rules.duplicate(true)
	dto.sell_channels = source.sell_channels.duplicate(true)
	dto.buyer_tags = source.buyer_tags.duplicate(true)
	dto.ghost_rule_id = source.ghost_rule_id
	dto.visual_asset_id = source.visual_asset_id
	dto.display_name = source.get("display_name", source.name_key)
	dto.description = source.get("description", "未配置可玩鉴定资料。")
	dto.unknown_min = int(source.get("unknown_min", 0))
	dto.unknown_max = int(source.get("unknown_max", source.base_value))
	dto.expertise = source.get("expertise", {}).duplicate(true)
	dto.provenance = source.get("provenance", {}).duplicate(true)
	return dto
