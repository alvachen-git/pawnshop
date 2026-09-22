class_name ShopKnowledgeService
extends RefCounted

# Each topic has its own identity, scope and cabinet; learning one never unlocks others.
const GU_YANSHENG := "gu_yansheng"
const TOPICS := {
	GU_YANSHENG: {
		"name": "顾砚生知识", "field": "书画", "subject": "顾砚生", "cabinet": 1,
		"cabinet_name": "第一柜", "bounds": Rect2(0.239, 0.022, 0.087, 0.130),
		"description": "柜里收着顾砚生的扇画摹本与辨笔手记。翻看山石用笔，再核题款与旧折，可学会如何对照他的扇画。",
		"use": "配合二级鉴物台与扇画工具，可自行鉴别顾砚生扇画。"
	}
}

static func enabled(run: RunDefinition) -> bool:
	return FanConditionService.enabled(run)

static func mastered(state: RunState, topic: String) -> bool:
	if not TOPICS.has(topic): return false
	if state.shop_growth.get("knowledge", {}).has(topic): return true
	# Read-only compatibility: preserve old save snapshots and charged preparation history.
	return topic == GU_YANSHENG and FanAppraisalService.data(state).get("knowledge", false)

static func preparation_count(state: RunState) -> int:
	var count := 0
	for entry in state.shop_growth.get("knowledge", {}).values():
		if int(entry.night) == state.current_night_index: count += 1
	return count

static func reason(day: DayController, topic: String) -> String:
	if not enabled(day.definition) or not TOPICS.has(topic): return "柜里没有这份知识手记。"
	if mastered(day.state, topic): return "这份知识已经掌握，可免费复看。"
	if ShopGrowthService.blocked(day): return "请先处理眼前的事情。"
	if day.state.current_night_index < 2: return "先将头一夜的生意理顺，第二夜起可来学习。"
	if day.state.phase != &"pre_open" or PreparationService.used(day.state, "finish", day.state.current_night_index): return "学习须在开铺前、准备结束前进行。"
	if PreparationService.count(day.state) >= 2: return "今夜两次准备已经用完。"
	return ""

static func learn(day: DayController, topic: String) -> ActionResult:
	var error := reason(day, topic)
	if not error.is_empty(): return ActionResult.new(false, error)
	if not day.state.shop_growth.has("knowledge"): day.state.shop_growth["knowledge"] = {}
	day.state.shop_growth.knowledge[topic] = {"night": day.state.current_night_index}
	return ActionResult.new(true, "你将柜中手记细读一遍，辨认的要点已记在心里。已掌握%s，占用1次准备，不收银元。" % TOPICS[topic].name)

static func page(day: DayController, topic: String) -> Dictionary:
	if not TOPICS.has(topic): return {"title": "旧账柜", "body": "柜里没有这份知识手记。", "buttons": []}
	var info: Dictionary = TOPICS[topic]
	var known := mastered(day.state, topic)
	var error := reason(day, topic)
	var model := {"title": info.cabinet_name + " · " + info.name, "body": "", "buttons": []}
	model.body = "已掌握" if known else "尚未掌握 · 学习不收费"
	model.body += "\n\n" + info.use
	if not known: model.buttons.append({"command": "learn_knowledge", "detail": topic, "label": "学习%s · 准备1次" % info.name, "enabled": error.is_empty(), "reason": error})
	return model
