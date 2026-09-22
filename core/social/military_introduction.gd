class_name MilitaryIntroduction
extends RefCounted

# A pre-opening, itemless reception. It shares the normal counter/dialogue UI,
# but never enters the timed trading queue or consumes a random customer slot.
const SPEECH := [
	"孙大元背着手在柜前站定，目光扫过铺面。\n\n‘我叫孙大元，奉营部的差，管这一带的街面巡查，也经手军需采办。听说这里换了掌柜，今日来认个门，把规矩交代一声。’",
	"他略一点头，口气仍不紧不慢。\n\n‘城门的岗哨、街上的巡兵，都是营里的人。哪家铺子该查、该停，营部一纸命令就能定。掌柜把规矩记牢，往来办得妥当，营里有好货、有差事，自然也会想到你。’",
	"孙大元把名帖递到柜前。\n\n‘眼下营里要收棉袄，采购单会记在《往来簿》里。往后有差事，也翻这本簿子看。接不接，掌柜自定；接了，便把数目备齐，来路弄清，交货领赏。办妥了，再来见我。’"
]
const CHOICES := ["孙长官，这街上的规矩，还请指点", "孙长官，营里的差事如何承接", "收下名帖：孙长官慢走"]

static func active(state: RunState) -> bool:
	return state.social_enabled and state.phase == &"pre_open" and int(state.social.get("intro_step", -1)) in [0, 1, 2]

static func id(state: RunState) -> String:
	return "%s/%d/sun_dayuan_introduction" % [state.run_definition_id, state.current_night_index]

static func advance(day: DayController, detail: String) -> ActionResult:
	var state := day.state
	if not active(state) or detail != str(state.social.intro_step): return ActionResult.new(false, "柜前的话已往下说了，请按眼前的话头作答。")
	state.social.intro_step += 1
	if state.social.intro_step < 3: return ActionResult.new(true, "")
	state.social.introduced = true
	SocialRules.military_notice(state, MilitaryService.INTRODUCTION)
	MilitaryPlaque.award(state)
	# Draw the same day's military event only after the personal introduction.
	SocialRules.night(state).military_checked = false
	MilitaryService.dawn(state, day.definition)
	return ActionResult.new(true, "孙大元点头告辞。你将名帖夹进《往来簿》，军阀往来从此有了一页。")

static func model(base: Dictionary, state: RunState) -> Dictionary:
	var step := int(state.social.intro_step)
	base.active_id = id(state)
	base.customer = "孙大元 · 登门拜访"
	base.item = ""
	base["itemless"] = true
	base.context_actions = {"customer":[{"id":"dialogue", "label":"交谈", "enabled":true}], "item":[]}
	base.visual = {"customer_id":"sun_dayuan", "customer_name":"孙大元", "portrait_asset":"social.sun_dayuan_visit", "item_asset":"", "item_name":"", "item_status":"", "estimate":"", "clues":[], "speech":[], "attitude":"登门拜访 · 只谈往来", "deadline":"", "introduction":SPEECH[step], "intent":"登门拜访"}
	base.dialogue = {"body":SPEECH[step], "visit_id":id(state), "buttons":[{"command":"military_intro", "detail":str(step), "label":CHOICES[step], "enabled":true, "reason":""}]}
	base.trade.body = "孙大元此来只为打个招呼，没有货物可交易。"
	base.appraisal.body = "柜上没有货物。"
	return base
