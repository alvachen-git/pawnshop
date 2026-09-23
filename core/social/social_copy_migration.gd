class_name SocialCopyMigration
extends RefCounted

# v26 already journals text snapshots. These four aliases migrate copy only;
# commands, identifiers, money, relationship values and all other fields still
# undergo the same full replay comparison. The source save is never rewritten.
static func normalize(value: Variant) -> Variant:
	if value is String:
		return value.replace("陈经办", "孙大元").replace("军方往来可在铺务菜单查看。", "名帖已夹进柜台上的《往来簿》。").replace("先到军方往来把话说清。", "翻开柜台上的《往来簿》，把话说清。").replace("价钱和来路可在军方往来查看。", "价钱和来路写在柜台上的《往来簿》里。")
	if value is Array:
		var result: Array = []
		for entry in value: result.append(normalize(entry))
		return result
	if value is Dictionary:
		var result := {}
		for key in value: result[key] = normalize(value[key])
		return result
	return value

# Pre-fix v27 notices had no faction identifier. Derive only that missing field
# from the command replay, never from names or keywords in player-visible text.
# Existing identifiers and every other saved field still require exact equality.
static func v27_notices(expected: Dictionary, actual: Dictionary) -> void:
	var saved_social: Variant = expected.get("social")
	if not saved_social is Dictionary: return
	var saved: Variant = saved_social.get("notices")
	var replayed: Variant = actual.get("social", {}).get("notices")
	if not saved is Array or not replayed is Array or saved.size() != replayed.size(): return
	for i in saved.size():
		if not saved[i] is Dictionary: continue
		var row: Dictionary = saved[i]
		if row.get("text") == MilitaryService.LEGACY_INTRODUCTION:
			row.text = MilitaryService.INTRODUCTION
		if row.get("text") == "军阀经办孙大元递来名帖：‘营里偶尔要收几件日用旧物。掌柜愿意做，按单交货；不愿意，也先认个门。’名帖已夹进柜台上的《往来簿》。":
			row.text = MilitaryService.INTRODUCTION
		if row.get("text") == "棉袄采购已接下。自有棉袄三件一并交货，付50银元，不限期限。":
			row.text = "棉袄采购已接下。自有棉袄三件一并交货，完成奖励50银元，不限期限。"
		if row.has("faction_id"): continue
		var without_faction: Dictionary = replayed[i].duplicate(true)
		without_faction.erase("faction_id")
		if GhostSaveCodec.same(row, without_faction): row["faction_id"] = replayed[i].faction_id
