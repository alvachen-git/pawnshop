class_name BedroomMirrorFeedback
extends RefCounted

const DESCRIPTION := "镜里的墙角，多出一道细长的影子。灯火在晃，它却贴着墙缝不动。你记得，那里没有挂衣服。"

# Derive presentation from the saved encounter and response, never from lamp
# damage, inventory ownership, or a transient animation flag. No writes or rolls.
static func build(state: RunState) -> Dictionary:
	if not state.personal_risk_enabled or not state.room_enabled or state.phase not in [&"private_room", &"sleep_resolution"]: return {}
	var pursuit := MirrorEncounterService.pursuit(state, state.current_night_index)
	if pursuit.is_empty() or not RoomFlow.response(state, state.current_night_index, "personal").is_empty(): return {}
	return {"mode": &"shadow", "strength": 0.82, "event_instance": "mirror/" + String(pursuit.visit_id), "description": DESCRIPTION}
