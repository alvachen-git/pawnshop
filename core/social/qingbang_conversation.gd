class_name QingbangConversation
extends RefCounted
const INTRO := [
	"来人没有摘帽，把一张名帖压在柜上。\n\n‘沈伯钧。青帮在这一带的事，由我出面。码头卸货的、街口看门的，都认我这张脸。掌柜，今天也认一认。’",
	"‘你柜里收什么，门口进什么人，弟兄们都看得见。生意上有人找麻烦，我能替你压下去。可想在这条街安稳开门，照应钱就不能少。八天一回。’",
	"沈伯钧用指节敲了敲柜面。\n\n‘明晚我再来，八十银元备好。往后送来的旧货，你自己验，收不收随你；要打听来路，也可以找我。单子放《往来簿》里，记得翻。生意可以商量，别拿我的话当耳旁风。’"]
const REPLIES := ["沈管事，记下了", "这笔照应钱，什么时候收", "收下名帖，送沈管事出门"]
static func active(state: RunState) -> bool:
	return QingbangRules.active(state) and not state.social.qingbang.dialogue.is_empty()
# Legacy saves may have already dismissed the fee's opening speech. Present the
# pending fee at the counter without mutating or replaying their historical state.
static func presenting(state: RunState) -> bool:
	return active(state) or (QingbangRules.active(state) and state.social.qingbang.pending.get("kind", "") == "fee")
static func encounter(state: RunState) -> Dictionary:
	if active(state): return state.social.qingbang.dialogue
	return {"id": state.social.qingbang.pending.id, "kind": "fee", "step": 0}
static func token(state: RunState) -> String:
	var d: Dictionary = encounter(state)
	return String(d.get("id","")) + "/" + str(d.get("step",0))
static func advance(day: DayController) -> ActionResult:
	var state := day.state
	var q: Dictionary = state.social.qingbang
	var d: Dictionary = q.dialogue
	if d.kind == "intro" and int(d.step) < 2:
		d.step += 1
		return ActionResult.new(true,"")
	var text := ""
	if d.kind == "intro":
		q.introduced = true
		text = "沈伯钧登门认了脸，说明青帮照应本街。明夜收照应钱，此后每隔八天再来。名帖已夹进《往来簿》。"
	elif d.kind == "raid": text = QingbangDamage.apply(state,d)
	else: text = "沈伯钧等你答复。请翻开《往来簿》的青帮来信，选择交钱或拒交。"
	q.dialogue = {}
	QingbangRules.notice(state,text)
	return ActionResult.new(true,text)
static func model(base: Dictionary, day: DayController) -> Dictionary:
	var state := day.state
	var d: Dictionary = encounter(state)
	var text := ""
	var label := ""
	match d.kind:
		"intro":
			text = INTRO[int(d.step)]
			label = REPLIES[int(d.step)]
		"fee":
			text = "沈伯钧在柜边停住，伸手按住钱袋。\n\n‘掌柜，日子到了。这一回%d银元，拿个准话。下回第%d夜，我照样来。别让我在你门口等。’" % [int(state.social.qingbang.pending.cost),int(state.social.qingbang.next_fee)]
			label = ""
			text += "\n\n你手边有现银%d银元。" % state.cash
		"raid":
			text = "沈伯钧停在门边，身后两个人挤进铺里。\n\n‘这条街上，还轮不到你坏我的规矩。弟兄们，给掌柜长长记性。’\n\n柜架被猛地一推，货物落地。街坊在门口停住脚，几位原本想进铺的客人转身走了。"
			label = "等人散去，清点损失"
	base.active_id = d.id
	base.customer = "沈伯钧 · " + ("带人闹事" if d.kind == "raid" else "青帮来访")
	base.item = ""
	base["itemless"] = true
	base.context_actions = {"customer":[{"id":"dialogue","label":"交谈","enabled":true}],"item":[]}
	base.visual = {"customer_id":"qingbang_steward","customer_name":"沈伯钧","portrait_asset":"social.qingbang","item_asset":"","item_name":"","item_status":"","estimate":"","clues":[],"speech":[],"attitude":"青帮 · 本街管事","deadline":"","introduction":"沈伯钧带着人停在门边。" if d.kind == "raid" else "沈伯钧在柜前等你回话。","intent":"登门来访"}
	var button := {"command":"qingbang_talk","target_id":d.id,"detail":token(state),"label":label,"enabled":true,"reason":""}
	var buttons: Array = [button]
	if d.kind == "fee":
		buttons = []
		for choice in ["pay", "refuse"]:
			var why := QingbangService.reason(day, choice, d.id)
			var caption := "交清%d银元" % int(state.social.qingbang.pending.cost) if choice == "pay" else "推回钱袋：这钱我不交"
			if choice == "pay" and not why.is_empty(): caption += "（现银不足）" if state.cash < int(state.social.qingbang.pending.cost) else "（暂不能交）"
			buttons.append({"command":"qingbang_fee", "target_id":d.id, "detail":choice, "label":caption, "enabled":why.is_empty(), "reason":why})
	base.dialogue = {"body":text,"visit_id":d.id,"buttons":buttons}
	base["case_dialogue"] = {"key":token(state),"auto_open":true,"pre_open_story":true,"sentence_pages":true,"speaker":"沈伯钧","narration_speaker":"柜前","text":text,"buttons":buttons}
	base.trade.body = "来人只谈街面往来，柜上没有待当的货物。"
	base.appraisal.body = "柜上没有货物。"
	return base
