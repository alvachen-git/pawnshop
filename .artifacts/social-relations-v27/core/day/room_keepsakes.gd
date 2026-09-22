class_name RoomKeepsakes
extends RefCounted

const COMMANDS := ["photo_place", "photo_store"]
const LETTERS := [{"id": "gu_jingtang", "title": "顾敬堂的信", "body_key": "opening.letter.permanent", "required_flag": "INTRO_LETTER_STORED"}]

static func available(state: RunState) -> bool:
	return state.personal_risk_enabled and state.room_enabled and state.phase == &"private_room" and "INTRO_ROOM_SEEN" in state.narrative_flags and state.pending_event_id.is_empty() and state.risk_pending.is_empty()

static func photo_placed(state: RunState) -> bool:
	if state.personal_risk_enabled and not state.room_photo_position.is_empty(): return state.room_photo_position == "desk"
	return "INTRO_MANQING_PHOTO_PLACED" in state.narrative_flags

static func can_execute(state: RunState, command: String) -> bool:
	return available(state) and command in COMMANDS and photo_placed(state) != (command == "photo_place")

static func execute(state: RunState, command: String) -> ActionResult:
	if not can_execute(state, command): return ActionResult.new(false, "照片仍在原处。")
	state.room_photo_position = "desk" if command == "photo_place" else "drawer"
	return ActionResult.new(true, "你把照片摆在桌上。" if command == "photo_place" else "你将照片轻轻收进抽屉。")

static func read_model(state: RunState) -> Dictionary:
	var letters: Array[Dictionary] = []
	for letter in LETTERS:
		if letter.required_flag in state.narrative_flags:
			letters.append({"id": letter.id, "title": letter.title, "body_key": letter.body_key})
	return {"enabled": state.personal_risk_enabled, "available": available(state), "photo_placed": photo_placed(state), "place_label": "摆回桌上" if state.room_photo_position == "drawer" else "摆到桌上", "letters": letters}
