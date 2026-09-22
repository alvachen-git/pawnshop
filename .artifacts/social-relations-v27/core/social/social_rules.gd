class_name SocialRules
extends RefCounted

const RUN := "social_relations_ten"
const VERSION := 27
static var _rules: Dictionary = {}

static func enabled(run: RunDefinition) -> bool:
	return String(run.id) == RUN or String(run.id).begins_with("social_preview_")

static func config() -> Dictionary:
	if _rules.is_empty(): _rules = JSON.parse_string(FileAccess.get_file_as_string("res://data/social_relations/rules.json"))
	return _rules.duplicate(true)

static func initial() -> Dictionary:
	return {"intro_step": -1, "reputation": 0, "military": 0, "changes": [], "trades": [], "nights": [], "gifts": [], "introduced": false, "warned": false, "threatened": false, "first_fee_due": false, "fee_seen": false, "last_event": -99, "last_closure": -99, "last_contract": -99, "last_supply": "", "plaque_awarded": false, "intimidations": [], "pending": {}, "contract": {}, "contracts": [], "supplies": [], "claims": [], "notices": [], "deferred_visits": [], "buyer_delays": {}}

static func initial_for(run: RunDefinition) -> Dictionary:
	var result := initial()
	# Separate, explicit scenario definitions; the normal run always starts at zero.
	if String(run.id).begins_with("social_preview_"):
		var preview: Dictionary = run.variety.get("social_preview", {})
		result.military = int(preview.get("military", 0))
		result.reputation = int(preview.get("reputation", 0))
		if result.military < -20:
			result.warned = true; result.fee_seen = true; result.threatened = true
			result.notices.append({"night": 1, "text": "孙大元旧日的警告还压在账下：‘照应街面的钱不交，下回就等停业令。’", "faction_id": "military"})
	return result

static func change(state: RunState, key: String, amount: int, cause: String) -> void:
	var before: int = state.social[key]
	state.social[key] = clampi(before + amount, -100, 100)
	state.social.changes.append({"night": state.current_night_index, "key": key, "before": before, "after": state.social[key], "reason": cause})
	if key == "military": MilitaryPlaque.award(state)
	if key == "military" and int(state.social.military) <= -20 and not state.social.warned:
		state.social.warned = true
		state.social.first_fee_due = true
		military_notice(state, "孙大元托人带话：‘营里近来翻过您的账，掌柜得留些现钱，有人要来问话。’")

static func notice(state: RunState, words: String, faction_id := "") -> void:
	state.social.notices.append({"night": state.current_night_index, "text": words, "faction_id": faction_id})

static func military_notice(state: RunState, words: String) -> void:
	notice(state, words, "military")

static func night(state: RunState) -> Dictionary:
	for row in state.social.get("nights", []):
		if row.night == state.current_night_index: return row
	return {}

static func closed(state: RunState) -> bool:
	return state.social_enabled and night(state).get("closed", false)

static func preparation_count(state: RunState) -> int:
	if not state.social_enabled: return 0
	return state.social.gifts.filter(func(row: Dictionary) -> bool: return row.night == state.current_night_index).size()

static func blocked(state: RunState) -> bool:
	return state.social_enabled and not state.social.pending.is_empty()
