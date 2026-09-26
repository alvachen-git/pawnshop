class_name WetGoodsRisk
extends RefCounted

const SOURCE := "wet_goods_holding"
const PRESSURE := [
	"你刚躺下，胸口便像压了一块湿石。耳边的低语变成断断续续的哭声，捂住耳朵也遮不住。命灯的火苗短了一截。",
	"那股无形的重压又沉了几分。哭声贴着耳根，一声比一声近。你撑着床沿喘气，命灯又暗下去一截。",
	"你几乎被那股重压按得直不起身。哭声在脑中回荡，整夜没有散去。命灯在桌上颤着，暖意越来越薄。"
]

static func enabled(state: RunState) -> bool:
	return SpecialGuests.active(state) and int(SpecialGuests.config(state).get("version", 1)) >= 2

static func age(state: RunState, item: ItemInstance) -> int:
	return maxi(0, state.current_night_index - item.acquired_night + 1) if item.acquired_night > 0 else 0

static func warning(state: RunState) -> String:
	if not enabled(state): return ""
	for id in SpecialGuests.held_items(state):
		var item := InventoryManager.new().find(state, id)
		if age(state, item) >= int(SpecialGuests.config(state).wet_harm_start_night):
			return "那件湿包里收来的货还压在铺里。你一挨床沿，胸口便沉得发闷，耳边隐约有人哭。命灯朝楼下偏去，火苗颤个不停。"
		if age(state, item) == int(SpecialGuests.config(state).wet_harm_start_night) - 1:
			return "楼下的潮气爬上了床沿。你躺近些，胸口就沉一分；那件湿包里收来的货，像是不能再久留了。"
	return ""

static func sleep(state: RunState) -> void:
	if not enabled(state): return
	for id in SpecialGuests.held_items(state):
		var item := InventoryManager.new().find(state, id)
		if age(state, item) < int(SpecialGuests.config(state).wet_harm_start_night): continue
		var count := 0
		for record in state.personal_risk_history:
			if record.source == SOURCE and record.kind == "damage": count += 1
		# One charge per item and bedtime; replay and healing cannot charge twice.
		PersonalRisk.damage(state, "wet_holding/%s/%d" % [id, state.current_night_index], 1, PRESSURE[mini(count, PRESSURE.size() - 1)], SOURCE)

static func item_note(state: RunState, item: ItemInstance) -> String:
	if not enabled(state) or item.instance_id not in SpecialGuests.held_items(state): return ""
	return "湿包中收来的货，留铺第%d夜。擦干的水痕又渗了出来，摸久了，胸口也发凉。" % age(state, item)

static func bedtime_text(state: RunState) -> String:
	if not enabled(state): return ""
	for record in state.personal_risk_history:
		if record.source == SOURCE and int(record.night) == state.current_night_index and record.kind == "damage": return record.cause
	return ""
