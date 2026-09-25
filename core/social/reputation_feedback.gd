class_name ReputationFeedback
extends RefCounted

# Presentation only: stored notices and deltas remain unchanged for save replay.
static func effect(delta: int) -> String:
	if delta > 0: return "铺子的好名声又传开了一些。"
	if delta < 0: return "铺子的口碑受了损。"
	return "铺子的口碑暂无变化。"

static func summary(state: RunState, financial: Dictionary, night: int) -> String:
	var trade := "生意积累：" + effect(int(financial.get("reputation_growth", 0)))
	var advertising := "宣传回音：今夜未托人宣传。"
	for row in WealthyCustomers.data(state).get("advertisements", []):
		if int(row.night) != night: continue
		advertising = "宣传回音：" + (effect(int(row.delta)) if row.settled else "口信已托人送出，收铺后听回音。")
		break
	return "累计收购与放当 %d 笔\n%s\n%s" % [int(financial.get("reputation_trade_count", 0)), trade, advertising]

static func notice(words: String) -> String:
	var pattern := RegEx.new()
	pattern.compile("商誉([+-][0-9]+)。")
	var match_result := pattern.search(words)
	if match_result == null: return words
	var delta := int(match_result.get_string(1))
	# The old milestone notice promised growth even when the hidden value was capped.
	if words.begins_with("又办成十笔收当生意，街坊认门的多了。"):
		words = words.replace("又办成十笔收当生意，街坊认门的多了。", "又办成十笔收当生意。")
	return words.replace(match_result.get_string(), effect(delta))
