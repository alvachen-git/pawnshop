class_name MirrorDreamService
extends RefCounted

const EVENT := "wm_dream"
const FLAG := "wm_dream_heard"
const CALL := "wm_dream_call"
const MORNING := "wm_dream_morning"
const ENTERED := "wm_dream_entered"

static func call_enabled(run: RunDefinition) -> bool:
	return run.variety.get("mirror_dream_call", 0) == 1

static func call_eligible(state: RunState) -> bool:
	if state.phase != &"sleep_resolution" or not state.risk_pending.is_empty() or MirrorEndingService.finished(state): return false
	if FLAG in state.narrative_flags or ENTERED in state.narrative_flags: return false
	var count := 0
	for row in state.event_history:
		if row.event_id != CALL: continue
		count += 1
		if row.night == state.current_night_index: return false
	if count >= 2: return false
	var item := LivingMirror.held(state)
	if item == null: return false
	for posting in state.ledger_entries:
		if posting.kind == "acquisition" and posting.item_instance_id == item.instance_id:
			var elapsed := state.current_night_index - int(posting.night)
			return elapsed in [1, 2]
	return false

static func enabled(run: RunDefinition) -> bool:
	return run.variety.get("mirror_dream", 0) == 1

static func eligible(state: RunState, requires_call := false) -> bool:
	if state.phase != &"sleep_resolution" or not state.risk_pending.is_empty() or MirrorEndingService.finished(state): return false
	if FLAG in state.narrative_flags or state.event_history.any(func(row: Dictionary) -> bool: return row.event_id == EVENT): return false
	var item := LivingMirror.held(state)
	if item == null: return false
	if requires_call:
		return ENTERED in state.narrative_flags and state.event_history.any(func(row: Dictionary) -> bool: return row.event_id == CALL and row.choice_id == "inspect" and row.night == state.current_night_index)
	for posting in state.ledger_entries:
		if posting.kind == "acquisition" and posting.item_instance_id == item.instance_id:
			return state.current_night_index == int(posting.night) + 1
	return false

static func morning_text(state: RunState) -> String:
	var hint := guidance(state).replace("她托我寻找离家的丈夫。", "").replace("可先", "先").replace("可循", "循").replace("可照", "照").replace("可核对", "核对").replace("可再", "再").replace("可翻看", "翻看")
	return "梦里的女子托我找她丈夫，还提起铺里留下的旧当票。\n" + hint

static func guidance(state: RunState) -> String:
	if FLAG not in state.narrative_flags or MirrorEndingService.finished(state): return ""
	for row in [["wm_notes", "可先翻看顾先生的用镜短记。"], ["wm_ticket", "可循镜背的典物号，查一查旧当存根。"], ["wm_life", "可照旧当存根上的住址，去问问柳巷的街坊。"], ["wm_identity", "可核对旧物与来客的身份，寻找她丈夫的下落。"], ["wm_concealed", "可再对照铺里的两册旧记录。"], ["wm_motive", "可翻看顾先生夹在旧档里的旁记。"]]:
		if not state.event_history.any(func(event: Dictionary) -> bool: return event.event_id == row[0]): return "她托我寻找离家的丈夫。" + row[1]
	return "她托我寻找离家的丈夫。已找到的线索收在旧档里，后续可到「托人查访」查看。"
