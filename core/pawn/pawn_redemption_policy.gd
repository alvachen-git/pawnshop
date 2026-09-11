class_name PawnRedemptionPolicy
extends RefCounted

const CHANCES := [20, 50, 80]
const REDEEM := "sample_three_redeem"
const DEFAULT := "sample_three_default"

static func enabled(run: RunDefinition) -> bool:
	return run.variety.get("pawn_redemption_version", 0) == 1

static func succeeds(chance: int, roll: int) -> bool:
	return roll < chance

static func terms_for(run: RunDefinition, customer: CustomerDefinition, seed_value: int, visit_id: String, legacy_terms: String) -> String:
	if not enabled(run): return legacy_terms
	assert(customer.pawn_redemption_chance in CHANCES, "Ordinary customer needs a redemption probability")
	var roll := VarietyService.rng(seed_value, visit_id + "/pawn-redemption").randi_range(0, 99)
	return REDEEM if succeeds(customer.pawn_redemption_chance, roll) else DEFAULT

static func background(run: RunDefinition, customer: CustomerDefinition, row: Dictionary) -> String:
	if not enabled(run) or row.get("context_id", "").is_empty() or row.has("familiar_id") or row.get("seven_role", "") == "pawn" or "pawn" not in row.get("transaction_modes", []): return ""
	return String(customer.persona.get("pawn_background", ""))
