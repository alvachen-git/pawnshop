class_name MirrorReunionScript
extends RefCounted

# UI-only page IDs and stage directions. The domain transcript remains unchanged
# so historical journal snapshots and replay validation retain their old wording.
static func page(id: String, speaker: String, text: String, wife := "waiting", husband := "evasive", motion := "", cg := "", sound := "") -> Dictionary:
	return {"id": id, "speaker": speaker, "text": text, "wife": wife, "husband": husband, "motion": motion, "cg": cg, "sound": sound}

static func original(action: String, index: int, wife: String, husband: String, motion := "", cg := "", sound := "") -> Dictionary:
	var line: Array = MirrorReunionService.PAGES[action][index]
	return page(action + "/" + str(index), line[0], line[1], wife, husband, motion, cg, sound)

static func pages(action: String, state: RunState) -> Array:
	var result: Array = []
	match action:
		"reveal":
			for i in 9:
				result.append(original(action, i, "sorrow" if i in [5, 6] else ("waiting" if i == 0 else "questioning"), "surprise" if i < 4 else "evasive", "appear" if i == 0 else "", "", "mirror" if i == 0 else ""))
		"press", "mediate":
			result.append(original(action, 0, "questioning", "evasive"))
			result.append_array(pages(state.mirror_resolution.husband, state))
		"apology":
			for i in 3: result.append(original(action, i, "sorrow", "remorse"))
		"angry":
			for i in 5: result.append(original(action, i, "reaching" if i >= 3 else "questioning", "terrified" if i >= 3 else "angry", "grasp" if i == 3 else "", "", "cloth" if i == 3 else ""))
		"evasive":
			for i in 3: result.append(original(action, i, "disappointed", "evasive"))
		"acknowledged":
			result = [
				page("acknowledged/silence", "", "女子没有马上回答。她低下头，攥紧的手一点点松开。", "sorrow", "remorse", "release", "", "cloth"),
				page("acknowledged/forgive", "女子", "这句道歉，我等了太久。好，我原谅你。", "relief", "remorse"),
				page("acknowledged/child", "女子", "可孩子已经不在了，我们也回不到从前了。", "sorrow", "remorse"),
				page("acknowledged/farewell", "女子", "我不再等你了。", "relief", "remorse", "", "acknowledged"),
				original(action, 2, "relief", "remorse", "depart", "", "cloth"),
			]
		"released":
			result = [
				original(action, 0, "reaching", "terrified"),
				original(action, 1, "sorrow", "terrified"),
				original(action, 2, "relief", "terrified", "release", "released", "cloth"),
				page("released/forgive", "女子", "我原谅你了。往后你过得怎样，都与我无关。", "relief", "terrified", "", "released"),
				page("released/farewell", "女子", "我不会再等你了。", "relief", "terrified", "", "released"),
				original(action, 4, "relief", "terrified", "depart_slump", "", "cloth"),
			]
		"resentment":
			result = [original(action, 0, "reaching", "terrified"), original(action, 1, "reaching", "terrified"), original(action, 2, "reaching", "terrified", "attack", "resentment", "attack"), original(action, 3, "reaching", "terrified", "empty")]
		"disappointed":
			result = [
				page("disappointed/silence", "", "两人都沉默了。女子垂下眼，等了一会儿，他仍没有看她。", "disappointed", "evasive"),
				original(action, 0, "disappointed", "evasive"),
				page("disappointed/give_up", "女子", "算了。我以为见到你，就能问个明白。", "disappointed", "evasive", "", "disappointed"),
				page("disappointed/farewell", "女子", "现在看来，再问也没用了。", "disappointed", "evasive", "", "disappointed"),
				original(action, 2, "disappointed", "evasive", "depart", "", "cloth"),
			]
	return result
