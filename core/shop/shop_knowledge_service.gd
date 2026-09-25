class_name ShopKnowledgeService
extends RefCounted

# Each topic has its own identity, scope and cabinet; learning one never unlocks others.
const GU_YANSHENG := "gu_yansheng"
const TOPICS := {
	"luxury_textile": {"name":"绣品知识","field":"绣品","subject":"高档绣品","cabinet":2,"cabinet_name":"绣谱柜","bounds":Rect2(0.34,0.02,0.07,0.13),"description":"针路、接色与补衬手记。","use":"二级鉴物台细查绣屏后，可对照针路与背衬图录。"},
	"luxury_metal": {"name":"金银器知识","field":"金银","subject":"金银器","cabinet":3,"cabinet_name":"金银簿柜","bounds":Rect2(0.42,0.02,0.07,0.13),"description":"戳记、式样、焊口与成色旧簿。","use":"二级鉴物台细查金镯、银器后，可对照款式与修配记录。"},
	"luxury_watch": {"name":"钟表知识","field":"钟表","subject":"进口钟表","cabinet":4,"cabinet_name":"钟表图册柜","bounds":Rect2(0.50,0.02,0.07,0.13),"description":"机芯、壳款与维修图册。","use":"二级鉴物台细查怀表、座钟后，可对照机芯与功能图录。"},
	"luxury_jade": {"name":"珠玉知识","field":"珠玉","subject":"珠玉首饰","cabinet":5,"cabinet_name":"珠玉谱柜","bounds":Rect2(0.58,0.02,0.07,0.13),"description":"孔口、珠序、玉纹与镶口手记。","use":"二级鉴物台细查珠玉后，可对照修配线索；不能凭肉眼保证珍珠的天然来源。"},
	"luxury_painting": {"name":"书画知识","field":"书画","subject":"周问石册页","cabinet":6,"cabinet_name":"册页摹本柜","bounds":Rect2(0.66,0.02,0.07,0.13),"description":"周问石的笔法、题款与旧临本对照。","use":"二级鉴物台细查册页后，可对照纸墨与笔法；不代替顾砚生扇画知识。"},
	"luxury_porcelain": {"name":"瓷器知识","field":"瓷器","subject":"古瓷小瓶","cabinet":7,"cabinet_name":"藏瓷图录柜","bounds":Rect2(0.74,0.02,0.07,0.13),"description":"器形、底足、釉面与修瓷手记。","use":"二级鉴物台细查古瓷后，可对照器形款识与修补图录。"},
	GU_YANSHENG: {
		"name": "顾砚生知识", "field": "书画", "subject": "顾砚生", "cabinet": 1,
		"cabinet_name": "第一柜", "bounds": Rect2(0.239, 0.022, 0.087, 0.130),
		"description": "柜里收着顾砚生的扇画摹本与辨笔手记。翻看山石用笔，再核题款与旧折，可学会如何对照他的扇画。",
		"use": "配合二级鉴物台与扇画工具，可自行鉴别顾砚生扇画。"
	}
}

static func enabled(run: RunDefinition) -> bool:
	return FanConditionService.enabled(run)

static func topic_info(run: RunDefinition, topic: String) -> Dictionary:
	var info: Dictionary = TOPICS[topic].duplicate(true)
	if run != null and WatchEconomy.enabled(run):
		if topic == "luxury_watch":
			info.bounds = TOPICS.luxury_textile.bounds; info.cabinet = 2; info.cabinet_name = "第二柜"; info.name = "名表鉴定指南"
		elif topic == "luxury_textile":
			info.bounds = TOPICS.luxury_watch.bounds; info.cabinet = 4
	if run != null and PearlEconomy.enabled(run) and topic == "luxury_jade":
		info.name = "珠玉鉴定指南"; info.description = "转珠看表层，放大孔口，再把整串逐粒比较。"
	if run != null and BangleEconomy.enabled(run) and topic == "luxury_metal":
		info.name = "金镯鉴定指南"; info.description = "称重对款，查看戳记与接缝，再比较火试后的局部痕迹。"
	if run != null and PorcelainEconomy.enabled(run) and topic == "luxury_porcelain":
		info.name = "青花断代图录"; info.description = "转看整器、绘纹与底足，年代与工艺分别判断。"; info.use = "对照元、明、清、民国的图样，不能单凭款识认年代。"
	if run != null and CameraEconomy.enabled(run) and topic == "luxury_textile":
		info.name = "洋相机鉴定指南"; info.field = "相机"; info.subject = "徕卡相机"; info.cabinet_name = "洋镜图册柜"
		info.description = "查看镜片、调光圈，过片后试快门，再核对铭文与镜座。"; info.use = info.description
	return info

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
	if topic.begins_with("luxury_") and not WealthyCustomers.active(day.state): return "这局的旧柜里没有这份图录。"
	if not enabled(day.definition) or not TOPICS.has(topic): return "柜里没有这份知识手记。"
	if mastered(day.state, topic): return "这份知识已经掌握，可免费复看。"
	if ShopGrowthService.blocked(day): return "请先处理眼前的事情。"
	if day.state.current_night_index < 2: return "先将头一夜的生意理顺，第二夜起可来学习。"
	if day.state.phase != &"pre_open" or PreparationService.used(day.state, "finish", day.state.current_night_index): return "学习须在开铺前、准备结束前进行。"
	if PreparationService.count(day.state) >= 2: return "今夜行动点已用完。"
	return ""

static func learn(day: DayController, topic: String) -> ActionResult:
	var error := reason(day, topic)
	if not error.is_empty(): return ActionResult.new(false, error)
	if not day.state.shop_growth.has("knowledge"): day.state.shop_growth["knowledge"] = {}
	day.state.shop_growth.knowledge[topic] = {"night": day.state.current_night_index}
	return ActionResult.new(true, "你将柜中手记细读一遍，辨认的要点已记在心里。已掌握%s，占用1行动点，不收银元。" % topic_info(day.definition,topic).name)

static func page(day: DayController, topic: String) -> Dictionary:
	if not TOPICS.has(topic): return {"title": "旧账柜", "body": "柜里没有这份知识手记。", "buttons": []}
	var info: Dictionary = TOPICS[topic]
	var known := mastered(day.state, topic)
	var error := reason(day, topic)
	var model := {"title": info.cabinet_name + " · " + info.name, "body": "", "buttons": []}
	model.body = "已掌握" if known else "尚未掌握 · 学习不收费"
	model.body += "\n\n" + info.use
	if TieredAppraisal.enabled(day.definition) and topic.begins_with("luxury_"): model.body = ("已掌握" if known else "尚未掌握 · 学习不收费")+"\n\n"+info.description+"配齐器材后可对照二级、三级图录，无须重复学习。"
	if known and topic.begins_with("luxury_") and WealthyCustomers.active(day.state):
		for id in WealthyCustomers.config(day.state).items:
			var book: Dictionary = WealthyCustomers.config(day.state).items[id]
			if book.topic != topic: continue
			var item := day.state.ghost_catalog.get_definition("items",id) as ItemDefinition
			model.body += "\n\n【" + item.display_name + "】\n" + LuxuryAppraisalService.price_guide(item)
			for index in 2: model.body += "\n\n" + String(book.checks[index]) + "\n" + String(book.references[index])
			if TieredAppraisal.enabled(day.definition):
				var spec: Dictionary = day.definition.variety.tiered_appraisal[id]
				for index in 2: model.body += "\n\n"+String(spec.deep_checks[index])+"\n"+String(spec.deep_references[index])
	if not known: model.buttons.append({"command": "learn_knowledge", "detail": topic, "label": "学习%s · 1行动点" % info.name, "enabled": error.is_empty(), "reason": error})
	return model
