class_name ContentMapper
extends RefCounted


func map_record(kind: String, source: Dictionary) -> RefCounted:
	match kind:
		"ghost_rules": return GhostRuleDefinition.from_dto(GhostRuleDTO.from_source(source))
		"events": return EventDefinition.from_dto(EventDTO.from_source(source))
		"buyers": return BuyerDefinition.from_dto(BuyerDTO.from_source(source))
		"pawn_terms": return PawnTermsDefinition.from_dto(PawnTermsDTO.from_source(source))
		"runs":
			return RunDefinition.from_dto(RunDTO.from_source(source))
		"items":
			return ItemDefinition.from_dto(ItemDTO.from_source(source))
		"customers":
			return CustomerDefinition.from_dto(CustomerDTO.from_source(source))
		_:
			return null
