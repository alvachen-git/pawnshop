class_name LuIntroduction
extends RefCounted

const EVENTS := ["lu_visit_greeting", "lu_visit_trade", "lu_visit_letters"]
const FLAG := "lu_letters_unlocked"

static func enabled(run: RunDefinition) -> bool:
	return EVENTS[0] in run.event_ids

static func unlocked(state: RunState, run: RunDefinition) -> bool:
	return not enabled(run) or FLAG in state.narrative_flags

static func active(state: RunState) -> bool:
	return state.phase == &"pre_open" and state.pending_event_id in EVENTS and not MilitaryIntroduction.active(state)

static func model(base: Dictionary, day: DayController, catalog: ContentCatalog) -> Dictionary:
	var event := catalog.get_definition("events", day.state.pending_event_id) as EventDefinition
	var choice := event.choices[0]
	base.active_id = String(event.id)
	base.customer = "陆掌眼 · 登门拜访"
	base.item = ""
	base["itemless"] = true
	base.context_actions = {"customer": [{"id": "dialogue", "label": "交谈", "enabled": true}], "item": []}
	base.visual = {"customer_id": "fd_lu", "portrait_asset": "fd.lu_elderly", "customer_name": "陆掌眼", "attitude": "顾掌柜的老朋友", "deadline": "", "introduction": event.body, "intent": "登门叙话", "item_asset": "", "item_name": "", "item_status": "", "estimate": "", "clues": [], "speech": []}
	base.visual.introduction = ["新掌柜吧？敝姓陆，来认认人。", "替各家商号跑货，也替老朋友寻个买主。", "收货的需求变了，我便托人送信来。"][EVENTS.find(String(event.id))]
	base.dialogue = {"body": event.body, "visit_id": base.active_id, "buttons": [{"command": "lu_intro", "detail": String(choice.id), "label": choice.label, "enabled": true, "reason": ""}]}
	base["case_dialogue"] = {"key": base.active_id, "auto_open": true, "pre_open_story": true, "sentence_pages": true, "speaker": "陆掌眼", "narration_speaker": "柜前", "text": event.body, "buttons": [{"command": "lu_intro", "target_id": base.active_id, "detail": String(choice.id), "label": choice.label, "enabled": true, "reason": ""}]}
	base.trade.body = "陆掌眼此来认门叙话。"
	base.appraisal.body = "柜上没有待验的货物。"
	return base
