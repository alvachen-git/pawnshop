class_name FanAppraisalService
extends RefCounted

const FACILITY_COMMANDS := ["fan_manual", "bench_two", "fan_tools", "fan_study"]
const COSTS := {"bench_two": 80, "fan_tools": 30}
const LABELS := {"sound": "顾砚生真作", "mended": "同时期临摹", "flawed": "后添名款"}
const DISPLAY_LABELS := {"sound": "顾砚生真迹", "mended": "临摹画", "flawed": "假画"}
const REFERENCE := {
	"brush": "图录记：顾砚生画山石，转折处先收后放，浓淡随势接续；临摹常在转折停笔描齐。只看纸旧，辨不出是谁的笔。",
	"inscription": "图录记：本款的墨色与画面相融，经过旧折处一同磨损。若字压在已经破损的旧折上，须留意是否后来添款。临本也可能写着同样的名字。"
}
const OBSERVATIONS := {
	"sound": {"brush": "石脊转折先收后放，枯润连在一笔里；几处细节都与图录所记相合。", "inscription": "题款与画面墨色相融，旧折穿过字画，磨损一致，没有压在折痕上的新墨。"},
	"mended": {"brush": "石脊轮廓相近，转折却有停笔后重描的接头，浓淡被描齐了。", "inscription": "题款与画面一同旧去，旧折处磨损相近；名字虽对得上，不能单凭这一点定作者。"},
	"flawed": {"brush": "石脊转折平直，枯润不相接，几处用笔与图录所记不合。", "inscription": "款字的浓墨压住了旧折缺口，画面在折处已磨白，款字却接得完整。"}
}

static func enabled(run: RunDefinition) -> bool:
	return run.variety.get("fan_appraisal_version", 0) == 1

static func initial() -> Dictionary:
	return {"manual": false, "bench_due": 0, "tools": false, "knowledge": false, "standing": 0, "preparations": [], "records": {}}

static func data(state: RunState) -> Dictionary:
	return state.shop_growth.get("appraisal", {})

static func knowledge_reason(day: DayController) -> String:
	if ShopKnowledgeService.enabled(day.definition):
		return "" if ShopKnowledgeService.mastered(day.state, ShopKnowledgeService.GU_YANSHENG) else "尚未掌握顾砚生知识。开铺前到旧账柜第一柜学习，需1次准备。"
	return "" if data(day.state).get("knowledge", false) else "先研习工具册中的扇画图录。"

static func bench_level(state: RunState) -> int:
	var due: int = state.shop_growth.get("precision",{}).get("due",0)
	if TieredAppraisal.active(state) and due > 0 and state.current_night_index >= due: return 3
	var a := data(state)
	if not a.is_empty() and int(a.bench_due) > 0 and state.current_night_index >= int(a.bench_due): return 2
	return 1 if state.shop_growth.get("bench", false) else 0

static func preparation_count(state: RunState) -> int:
	return data(state).get("preparations", []).filter(func(row: Dictionary) -> bool: return row.night == state.current_night_index).size()

static func facility_reason(day: DayController, command: String, detail := "") -> String:
	if not enabled(day.definition): return "这局没有这项铺务。"
	if command not in FACILITY_COMMANDS or not detail.is_empty(): return "没有这项铺务。"
	var state := day.state
	var a := data(state)
	if ShopGrowthService.blocked(day): return "请先处理眼前的事情。"
	if command == "fan_manual":
		if a.manual: return "工具册已经找出，可免费复看。"
		if state.shop_growth.exploration.is_empty(): return "先整理旧账，查到旧柜目录。"
		if state.phase != &"closed_processing" or state.closed_at < 0 or state.closed_at >= day.definition.night_minutes: return "提前关门后，可循目录找工具册。"
		if state.game_minutes + 10 > day.definition.night_minutes: return "到03:00前来不及找完，留待明夜。"
		return ""
	if state.current_night_index < 2 or state.phase != &"pre_open" or PreparationService.used(state, "finish", state.current_night_index): return "须在第二夜起、开铺前准备时办理。"
	# v29 separates construction from learning; earlier runs retain their original gate.
	if not a.manual and (not FanConditionService.enabled(day.definition) or command == "fan_study"): return "先循旧柜目录找出工具册和扇画图录。"
	match command:
		"bench_two":
			if not state.shop_growth.bench: return "先整修一级鉴物台。"
			if int(a.bench_due) > 0: return "专用台已建成。" if bench_level(state) >= 2 else "木匠正在赶工，不必重复委托。"
		"fan_tools":
			if a.tools: return "扇画工具已经配齐。"
			if bench_level(state) < 2: return "专用台完工后，才好安装扇画工具。"
		"fan_study":
			if ShopKnowledgeService.mastered(state, ShopKnowledgeService.GU_YANSHENG): return "这份知识已掌握，随时可以复看。"
	if PreparationService.count(state) >= 2: return "今夜两次准备已经用完。"
	if state.cash < int(COSTS.get(command, 0)): return "现银不足，需要%d银元。" % int(COSTS[command])
	return ""

static func facility(day: DayController, command: String, detail := "") -> ActionResult:
	var error := facility_reason(day, command, detail)
	if not error.is_empty(): return ActionResult.new(false, error)
	var state := day.state
	var a := data(state)
	if command == "fan_manual":
		day.spend_action(10)
		a.manual = true
		return ActionResult.new(true, "循目录翻到旧工具册，夹页里还有《顾砚生扇画摹存》。册中记着展扇台的尺寸、工具摆法与两处辨笔要点。它与那张旧票不是一份材料。图册收在鉴物台，可免费复看。")
	if COSTS.has(command):
		var cost: int = COSTS[command]
		EconomyManager.new().commit(state, -cost, "", "facility/" + command, "facility_investment")
		state.shop_growth.investments.append({"facility": command, "night": state.current_night_index, "amount": cost, "preparation": 1})
	if command == "bench_two":
		a.bench_due = state.current_night_index + 2
		return ActionResult.new(true, "木匠收下80银元，约在第%d夜开铺前装妥专用台。占用一次准备，期间一级台仍可使用。" % int(a.bench_due))
	if command == "fan_tools":
		a.tools = true
		return ActionResult.new(true, "展扇夹、侧光镜和比对尺已安好。付出30银元，占用一次准备；还须掌握图录，才好辨认笔法与题款。")
	a.knowledge = true
	a.preparations.append({"night": state.current_night_index, "action": "fan_study"})
	return ActionResult.new(true, "你依图录试着辨了几处：先看转笔，再看题款是否与画面一同旧去。要点已抄妥，可随时免费复看。占用一次准备。")

static func target(day: DayController, item_id: String) -> ItemInstance:
	var held := InventoryManager.new().find(day.state, item_id)
	if held != null: return held if held.ownership_state == "owned" else null
	var visit := CustomerManager.new().active(day.state)
	if visit != null and visit.purpose.is_empty() and visit.item.instance_id == item_id: return visit.item
	return null

static func record(state: RunState, item_id: String) -> Dictionary:
	return data(state).get("records", {}).get(item_id, {})

static func access_reason(day: DayController, item_id: String) -> String:
	if not enabled(day.definition): return "这局没有扇画比对。"
	if ShopGrowthService.blocked(day) or MirrorEndingService.active(day.state): return "请先处理眼前的事情。"
	if day.state.phase not in [&"open", &"closed_processing"]: return "营业中或提前关门后，可取扇比对。"
	var item := target(day, item_id)
	if item == null or item.definition_id != GoodsExpertise.FAN: return "只能比对眼前待收的折扇或铺中自有折扇。"
	if not ShopGrowthService.item_reason(day.state, item).is_empty() and item.ownership_state == "owned": return "货上的异状尚未处理，暂不能展开比对。"
	return ""

static func reason(day: DayController, command: String, item_id: String, detail := "") -> String:
	if command == "condition": return FanConditionService.reason(day, item_id, detail)
	if command in ["draft", "clear_draft", "commit"]: return draft_reason(day, command, item_id, detail)
	if command == "compare":
		var pair := FanEvidence.parse(detail)
		if pair.is_empty(): return "先在图录与折扇上各圈一处笔锋，或各圈一处题款，再记下看法。"
		return reason(day, pair.kind, item_id)
	var error := access_reason(day, item_id)
	if not error.is_empty(): return error
	if command not in ["brush", "inscription", "verdict"]: return "没有这项比对。"
	var a := data(day.state)
	if bench_level(day.state) < 2: return "须先建成二级专用鉴物台。"
	if not a.tools: return "尚未配齐扇画工具。"
	var missing_knowledge := knowledge_reason(day)
	if not missing_knowledge.is_empty(): return missing_knowledge
	var item := target(day, item_id)
	if item.expert_reviewed: return "已有鉴赏结论，可免费复看。"
	var row := record(day.state, item_id)
	if not String(row.get("verdict", "")).is_empty(): return "这次判断已经记下。若仍存疑，可在收货后请行家复核。"
	if command == "verdict":
		if not LABELS.has(detail): return "请按图录选择判断。"
		if not row.get("checks", []).has("brush") or not row.get("checks", []).has("inscription"): return "先比对笔法和题款，再下判断。"
	else:
		if not detail.is_empty(): return "请按眼前这处细节比对。"
		if command in row.get("checks", []): return "这处已查过，可免费复看。"
		if day.state.game_minutes + 10 >= day.definition.night_minutes: return "来不及在03:00前完成比对。"
	if day.state.game_minutes >= day.definition.night_minutes: return "已经到了封铺时候。"
	return ""

static func perform(day: DayController, command: String, item_id: String, detail := "") -> ActionResult:
	var error := reason(day, command, item_id, detail)
	if not error.is_empty(): return ActionResult.new(false, error)
	if command == "condition": return FanConditionService.inspect(day, item_id, detail)
	if command in ["draft", "clear_draft", "commit"]: return perform_draft(day, command, item_id, detail)
	if command == "compare":
		var pair := FanEvidence.parse(detail)
		var checked := perform(day, pair.kind, item_id)
		var entry := record(day.state, item_id)
		if not checked.ok or pair.kind not in entry.get("checks", []): return checked
		if not entry.has("pairs"): entry["pairs"] = {}
		entry.pairs[pair.kind] = pair
		return ActionResult.new(true, "%s记作「%s」。圈点与手记已留在货签上，尚未经行家复核。" % [FanEvidence.TITLES[pair.kind], FanEvidence.NOTES[pair.note]])
	var state := day.state
	var item := target(day, item_id)
	var visit := CustomerManager.new().active(state)
	var counter_target: bool = visit != null and visit.item == item and not InventoryManager.new().contains(state, item_id)
	if command != "verdict":
		day.spend_action(10)
		CustomerManager.new().update(state)
		if counter_target:
			if visit.status != "active": return ActionResult.new(true, "用了10分钟，客人却已收扇离开；这处比对没有完成。")
			var customer := state.ghost_catalog.get_definition("customers", visit.customer_id) as CustomerDefinition
			if customer.guest_rule == "no_appraisal":
				CustomerManager.new().finish(state, visit, "inspection_refused")
				CustomerManager.new().update(state)
				return ActionResult.new(true, "你刚要展扇，那人便收回包裹：‘说过了，不许验货。’未取得比对记录。")
	var rows: Dictionary = data(state).records
	if not rows.has(item_id): rows[item_id] = {"checks": [], "verdict": "", "reviewed": false}
	var row: Dictionary = rows[item_id]
	if command != "verdict":
		row.checks.append(command)
		return ActionResult.new(true, OBSERVATIONS[String(item.selected_variant_id)][command])
	row.verdict = detail
	# A self judgement is a claim, not an oracle or an expert certificate.
	# Its market weight is fixed when written, so old offers and claims stay stable.
	item.goods["fan_claim"] = detail
	item.goods["fan_weight"] = clampi(20 + int(data(state).standing) * 5, 0, 60)
	return ActionResult.new(true, "你将两处比对记在货签上，判为%s。这是掌柜自鉴，买家只按你已有的鉴定名声酌量认价；收货后可请行家复核。" % LABELS[detail])

static func notes(state: RunState, item_id: String) -> Dictionary:
	var row := record(state, item_id)
	# An explicit empty draft must not resurrect cleared legacy circles.
	return row.get("draft_pairs", row.get("pairs", {}))

static func commit_minutes(state: RunState, item_id: String) -> int:
	# Legacy checks already paid ten minutes each. New drafts never add checks.
	var checks: Array = record(state, item_id).get("checks", [])
	return 0 if "brush" in checks or "inscription" in checks else 10

static func tentative(pairs: Dictionary) -> String:
	if not pairs.has("brush") or not pairs.has("inscription"): return "两处草稿齐备后，可合看下判断。"
	var brush: String = pairs.brush.note
	var inscription: String = pairs.inscription.note
	if brush == "unsure" or inscription == "unsure": return "暂难定论"
	if brush == "same" and inscription == "same": return "倾向真迹"
	if brush == "different" and inscription == "different": return "倾向假画"
	return "疑为假画" if brush == "same" else "疑为临摹画，需再斟酌"

static func claim_label(choice: String) -> String:
	return "掌柜自鉴 · " + {"sound": "真迹", "mended": "临摹画", "flawed": "假画"}.get(choice, "待定")

static func draft_access(day: DayController, item_id: String) -> String:
	var error := access_reason(day, item_id)
	if not error.is_empty(): return error
	var a := data(day.state)
	if bench_level(day.state) < 2: return "须先建成二级专用鉴物台。"
	if not a.tools: return "尚未配齐扇画工具。"
	var missing_knowledge := knowledge_reason(day)
	if not missing_knowledge.is_empty(): return missing_knowledge
	if target(day, item_id).expert_reviewed: return "已有鉴赏结论，可免费复看。"
	if not String(record(day.state, item_id).get("verdict", "")).is_empty(): return "已经正式落笔，手记可免费复看；收货后可请行家复核。"
	if day.state.game_minutes >= day.definition.night_minutes: return "已经到了封铺时候。"
	return ""

static func draft_reason(day: DayController, command: String, item_id: String, detail: String) -> String:
	var error := draft_access(day, item_id)
	if not error.is_empty(): return error
	var pairs := notes(day.state, item_id)
	if command == "draft":
		var pair := FanEvidence.parse(detail)
		if pair.is_empty(): return "先在图录与折扇上各圈一处对应细节，再记下看法。"
		if pairs.get(pair.kind, {}) == pair: return "这处草稿没有变化。"
		return ""
	if command == "clear_draft":
		if detail not in ["brush", "inscription", "all"]: return "请选择要清除的草稿。"
		if pairs.is_empty() or (detail != "all" and not pairs.has(detail)): return "这处没有草稿可清除。"
		return ""
	if not LABELS.has(detail): return "请先选择本次自鉴结论。"
	if not pairs.has("brush") or not pairs.has("inscription"): return "先记好笔锋与题款两处草稿，再落笔。"
	var finish := day.state.game_minutes + commit_minutes(day.state, item_id)
	if finish >= day.definition.night_minutes: return "来不及在03:00前完成鉴定，草稿可留待下次。"
	var visit := CustomerManager.new().active(day.state)
	if visit != null and visit.item == target(day, item_id) and not InventoryManager.new().contains(day.state, item_id):
		if finish >= visit.expires_at: return "客人等不到鉴定完，未扣时间；草稿仍留着。"
	return ""

static func perform_draft(day: DayController, command: String, item_id: String, detail: String) -> ActionResult:
	var state := day.state
	var pairs := notes(state, item_id).duplicate(true)
	if command in ["draft", "clear_draft"]:
		if command == "draft":
			var pair := FanEvidence.parse(detail)
			pairs[pair.kind] = pair
		elif detail == "all": pairs.clear()
		else: pairs.erase(detail)
		var rows: Dictionary = data(state).records
		if not rows.has(item_id): rows[item_id] = {"checks": [], "verdict": "", "reviewed": false}
		rows[item_id]["draft_pairs"] = pairs
		return ActionResult.new(true, "草稿已改好，可继续重选；确认落笔才计时。" if command == "draft" else "草稿已清除，可以重新圈点。")
	var item := target(day, item_id)
	var visit := CustomerManager.new().active(state)
	var counter_target: bool = visit != null and visit.item == item and not InventoryManager.new().contains(state, item_id)
	var minutes := commit_minutes(state, item_id)
	if minutes > 0:
		var spent := day.spend_action(minutes)
		if not spent.ok: return spent
	CustomerManager.new().update(state)
	if counter_target:
		if visit.status != "active": return ActionResult.new(true, "客人已经收扇离开，未落下鉴定结论；草稿仍留着。")
		var customer := state.ghost_catalog.get_definition("customers", visit.customer_id) as CustomerDefinition
		if customer.guest_rule == "no_appraisal":
			CustomerManager.new().finish(state, visit, "inspection_refused")
			CustomerManager.new().update(state)
			return ActionResult.new(true, "你刚要展扇，那人便收回包裹：‘说过了，不许验货。’未落下鉴定结论。")
	var row := record(state, item_id)
	row["pairs"] = pairs
	row.erase("draft_pairs")
	row["checks"] = ["brush", "inscription"]
	row.verdict = detail
	item.goods["fan_claim"] = detail
	item.goods["fan_weight"] = clampi(20 + int(data(state).standing) * 5, 0, 60)
	return ActionResult.new(true, claim_label(detail) + "。尚未经行家复核，买家只依落笔时的鉴定名声酌量认价。")

static func standing_text(state: RunState) -> String:
	var points: int = data(state).get("standing", 0)
	if points < 0: return "近来的判断有过差池，买家对自鉴更为谨慎。"
	if points >= 6: return "几次复核都经得住推敲，已有买家认可你的眼力。"
	if points >= 2: return "已有几份经行家核过的手记，买家开始参考你的判断。"
	return "鉴定名声尚浅，自鉴对认价只有少量影响。"

static func expert_confirmation(day: DayController, item: ItemInstance) -> String:
	if not enabled(day.definition): return ""
	var row := record(day.state, item.instance_id)
	if String(row.get("verdict", "")).is_empty() or row.get("reviewed", false): return ""
	if FanBargainingService.enabled(day.definition): return FanBargainingService.expert_confirmation(day, item, row)
	row.reviewed = true
	var matches: bool = row.verdict == String(item.selected_variant_id)
	var a := data(day.state)
	a.standing = clampi(int(a.standing) + (1 if matches else -2), -4, 8)
	return "\n\n行家将结论与原手记对过：" + ("这次判断相合，给你的眼力多添一份凭据。" if matches else "原先的判断不合，这份差池也记下了。") + "今后的自鉴认价会参考这份记录。"
