class_name QingbangRules
extends RefCounted

static var _config: Dictionary = {}

static func enabled(run: RunDefinition) -> bool:
	return run.variety.get("qingbang_version", 0) == 1

static func active(state: RunState) -> bool:
	return state.social_enabled and state.social.has("qingbang")

static func config() -> Dictionary:
	if _config.is_empty(): _config = JSON.parse_string(FileAccess.get_file_as_string("res://data/qingbang/rules.json"))
	return _config.duplicate(true)

static func initial() -> Dictionary:
	return {"relation":0, "introduced":false, "intro_step":-1, "next_fee":5, "last_refusal":-99, "last_raid":-99, "last_gift":-99, "last_trade_reward":-99, "last_supply":-99, "last_supply_id":"", "checked":[], "opening_checked":[], "pending":{}, "dialogue":{}, "fees":[], "raids":[], "gifts":[], "supplies":[], "claims":[], "inquiries":[], "complaints":[], "changes":[]}

static func change(state: RunState, delta: int, reason: String) -> void:
	var q: Dictionary = state.social.qingbang
	var previous := int(q.relation)
	q.relation = clampi(previous + delta, -100, 100)
	q.changes.append({"night":state.current_night_index, "before":previous, "after":q.relation, "reason":reason})

static func notice(state: RunState, words: String) -> void:
	SocialRules.notice(state, words, "qingbang")

static func fee(relation: int) -> int:
	for row in config().fees:
		if relation <= int(row.max): return int(row.cost)
	return 50

static func busy(state: RunState) -> bool:
	return active(state) and (not state.social.qingbang.pending.is_empty() or not state.social.qingbang.dialogue.is_empty())
