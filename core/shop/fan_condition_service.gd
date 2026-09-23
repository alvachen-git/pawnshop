class_name FanConditionService
extends RefCounted

const RETAIN := {"intact": 100, "minor": 80, "major": 50}
const LABELS := {"intact": "完整", "minor": "轻损", "major": "重损"}
const TEXT := {"intact": "未见明显裂口与缺损。", "minor": "扇缘有小裂口，扇骨仍齐整。", "major": "扇缘有明显缺口，扇骨存在断损。"}

static func enabled(run: RunDefinition) -> bool:
	return run.variety.get("fan_condition_version", 0) == 1

static func applies(item: ItemInstance) -> bool:
	return item != null and item.definition_id == GoodsExpertise.FAN and item.goods.has("fan_condition")

static func attach(rows: Array, run: RunDefinition, seed_value: int) -> void:
	if not enabled(run): return
	for row in rows:
		if row.item_id != GoodsExpertise.FAN: continue
		if not row.has("goods"): row.goods = {}
		if row.goods.has("fan_condition"): continue
		var roll := VarietyService.rng(seed_value, String(row.visit_id) + "/fan/condition").randi_range(0, 99)
		row.goods.fan_condition = "intact" if roll < 60 else "minor" if roll < 90 else "major"

static func adjusted(item: ItemInstance, value: int) -> int:
	return maxi(1, roundi(value * int(RETAIN[item.goods.fan_condition]) / 100.0)) if applies(item) else value

static func checked(item: ItemInstance) -> bool:
	return applies(item) and item.goods.get("condition_checked", false)

static func note(item: ItemInstance) -> String:
	return "品相：" + LABELS[item.goods.fan_condition] + "。" + TEXT[item.goods.fan_condition] if checked(item) else "品相待查，暂不作完整估价。"

static func estimate(item: ItemInstance, definition: ItemDefinition) -> String:
	if not checked(item): return "品相待查"
	var basis := "行家复核" if item.expert_reviewed else "掌柜自鉴" if item.goods.has("fan_claim") else "未鉴真伪"
	return "%d · %s" % [GoodsExpertise.value(item, definition), basis]

static func desk_reason(day: DayController, item_id: String) -> String:
	var error := FanAppraisalService.access_reason(day, item_id)
	if not error.is_empty(): return error
	if not enabled(day.definition): return ""
	if FanAppraisalService.bench_level(day.state) < 2: return "须先建成二级专用鉴物台。"
	var a := FanAppraisalService.data(day.state)
	if not a.tools: return "尚未配齐扇画工具。"
	if not ShopKnowledgeService.mastered(day.state, ShopKnowledgeService.GU_YANSHENG): return "尚未掌握顾砚生知识。开铺前到旧账柜第一柜学习，需1次准备。"
	return ""

static func reason(day: DayController, item_id: String, detail := "") -> String:
	if not enabled(day.definition): return "这局没有这项检查。"
	var error := FanAppraisalService.access_reason(day, item_id)
	if not error.is_empty(): return error
	var item := FanAppraisalService.target(day, item_id)
	if not applies(item) or not detail.is_empty(): return "请选好眼前的折扇。"
	if checked(item): return "破损已经查过，可免费复看。"
	var finish := day.state.game_minutes + 5
	if finish >= day.definition.night_minutes: return "来不及在03:00前查完，未开始检查。"
	var visit := CustomerManager.new().active(day.state)
	if visit != null and visit.item == item and finish >= visit.expires_at: return "来不及在客人离开前查完，未开始检查。"
	return ""

static func inspect(day: DayController, item_id: String, detail := "") -> ActionResult:
	var error := reason(day, item_id, detail)
	if not error.is_empty(): return ActionResult.new(false, error)
	var item := FanAppraisalService.target(day, item_id)
	var visit := CustomerManager.new().active(day.state)
	day.spend_action(5)
	if visit != null and visit.item == item:
		var customer := day.state.ghost_catalog.get_definition("customers", visit.customer_id) as CustomerDefinition
		if customer.guest_rule == "no_appraisal":
			CustomerManager.new().finish(day.state, visit, "inspection_refused")
			CustomerManager.new().update(day.state)
			return ActionResult.new(true, "你的手刚伸向扇子，那人便收回包裹：‘说过了，不许验货。’未查得品相。")
	item.goods.condition_checked = true
	CustomerManager.new().update(day.state)
	return ActionResult.new(true, note(item) + "\n这只是品相，真假还须到鉴物台比对。")

static func pressure_reason(day: DayController, visit: CustomerVisit, detail: String, amount: int) -> String:
	if not enabled(day.definition) or visit == null or not visit.purpose.is_empty() or not visit.night_policy.is_empty() or EarlyRedemption.is_visit(visit): return "眼前这笔生意不适合这样谈价。"
	if ShopGrowthService.blocked(day) or MirrorEndingService.active(day.state): return "请先处理眼前的事情。"
	if not checked(visit.item): return "先检查破损，再拿实物谈价。"
	if visit.item.goods.fan_condition == "intact": return "未查见明显破损，没有这处让价可谈。"
	var customer := day.state.ghost_catalog.get_definition("customers", visit.customer_id) as CustomerDefinition
	if not customer.guest_rule.is_empty(): return "这位客人不接受这样的谈价。"
	if not detail.is_empty() or amount != 0: return "先谈破损，再另行报价。"
	if visit.item.goods.has("condition_pressure"): return "这处破损已经折进价里。"
	if visit.trade.rounds_left <= 0 or visit.trade.patience <= 0: return "客人已经不肯再谈价。"
	if day.state.game_minutes + 5 >= mini(visit.expires_at, day.definition.night_minutes): return "来不及把这轮价谈完，未开始压价。"
	return ""

static func pressure_words(item: ItemInstance) -> String:
	return "扇缘缺了一块，扇骨也断了，价钱得减半。" if checked(item) and item.goods.fan_condition == "major" else "扇缘裂了口，这份价得再让两成。"

static func pressure(day: DayController, visit: CustomerVisit) -> String:
	var keep: int = RETAIN[visit.item.goods.fan_condition]
	var t := visit.trade
	if day.state.social_enabled:
		var fair_basis := maxi(1, t.opening_price - t.social_flaw_discount)
		t.social_flaw_discount += fair_basis - maxi(1, roundi(fair_basis * keep / 100.0))
	var row := {"before_asking": t.asking_price, "before_reserve": t.reserve_price, "retain": keep,
		"minute": day.state.game_minutes, "night": day.state.current_night_index}
	t.asking_price = maxi(1, roundi(t.asking_price * keep / 100.0))
	t.reserve_price = maxi(1, roundi(t.reserve_price * keep / 100.0))
	row.asking = t.asking_price; row.reserve = t.reserve_price
	var fake := FanBargainingService.attempt(day.state, visit)
	if fake.get("accepted", false):
		row.purchase_before_asking = fake.asking; row.purchase_before_reserve = fake.reserve
		fake.asking = maxi(1, roundi(int(fake.asking) * keep / 100.0))
		fake.reserve = maxi(1, roundi(int(fake.reserve) * keep / 100.0))
		row.purchase_asking = fake.asking; row.purchase_reserve = fake.reserve
	visit.item.goods.condition_pressure = row
	t.rounds_left -= 1
	return "他顺着你指的破口看了看：‘这处确实伤了，就照您说的让。’\n破损已折进收购与活当要价，仍须另行报价。"
