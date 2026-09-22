class_name SaveTimeline
extends RefCounted

const UNSETTLED := ["closed_processing", "night_resolution"]

static func trading_nights(state: RunState) -> int:
	return state.current_night_index - (1 if state.phase == &"pre_open" else 0)

static func closing(state: RunState, night: int) -> int:
	return int(state.summaries[night - 1].closed_at) if night <= state.summaries.size() else state.closed_at

static func unsettled(state: RunState) -> bool:
	return String(state.phase) in UNSETTLED
