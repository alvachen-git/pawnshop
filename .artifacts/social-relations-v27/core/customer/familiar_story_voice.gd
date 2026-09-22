class_name FamiliarStoryVoice
extends RefCounted

static func apply(visit: CustomerVisit, row: Dictionary, state: RunState, catalog: ContentCatalog) -> void:
	if not row.has("familiar_id"): return
	if row.get("early_redemption", false):
		visit.voice = {"early_redemption": true, "introduction": "姜素云把原当票和钱袋一并放上柜。‘工钱结下来了，赎簪的钱已经够数。还没到票上的日子，掌柜能否先替我办了？’", "timed_out": "姜素云看看门外，收起当票：‘今日来不及，那我照票上的日子再来。’"}
		return
	var story := FamiliarStories.story_for(FamiliarStories.history_data(state), row.familiar_id)
	var first: bool = row.familiar_stage == "first"
	var intro := ""
	var circumstance := ""
	var origin := ""
	var completed := ""
	var rejected := ""
	if row.familiar_id == "bookkeeper":
		if first:
			intro = "许文衡把钢笔放在旧帕上，露出袖口里折好的介绍信。‘外埠有家商号缺账房，我还差些盘缠。笔卖给您，价钱请说实在些。’"
			circumstance = "他按住介绍信：‘明日去问工，路上总得留几个钱。这笔只卖，不办活当。’"
			origin = "自己记账用过的笔，旧铺散伙后带在身边。"
			completed = "许文衡数过银元，把旧帕收回袖里：‘盘缠有着落了，我去试试。’"
			rejected = "许文衡把笔裹好：‘您不收，我再问问别家。’"
		else:
			circumstance = "‘商号让我先抄几日账，还没到结钱的时候。这方砚台我用不上，想换些现钱。’"
			origin = "与那支钢笔一样，是从前记账时自用的旧物；来源仍可核对。"
			completed = "他把银元拢进掌心：‘这几天的饭钱够了，砚台就留您这里。’"
			rejected = "许文衡收好砚台：‘那我再寻个收文房的地方。’"
			match row.familiar_branch:
				"guarded":
					intro = "许文衡又来了，放下砚台却没解外衣。‘上回那支笔的价钱，您说了算。这回我只留%d分钟，价钱谈两轮就定。’" % (visit.expires_at - visit.arrival)
					visit.trade.rounds_left = mini(visit.trade.rounds_left, 2)
				"candid":
					var item := catalog.get_definition("items", visit.item.definition_id) as ItemDefinition
					var flaw := item.find_clue("condition_chipped")
					visit.trade.asking_price = maxi(1, visit.trade.asking_price - flaw.leverage)
					visit.trade.reserve_price = maxi(1, visit.trade.reserve_price - flaw.leverage)
					visit.trade.used_clue_ids.append(flaw.id)
					intro = "许文衡把砚台转了半圈：‘上回您指出笔上的问题，我记着。这回砚角有缺，我先说明白。’\n缺角已折入报价，让%d银元，现要%d银元；原物仍可检查。" % [flaw.leverage, visit.trade.asking_price]
				"elsewhere": intro = "许文衡放下一方砚台：‘上回那支笔，在别家卖了。这回带的是砚，您看看合不合适。’"
				_: intro = "许文衡认得柜上的茶盏，先点了点头：‘上回在您这里卖过笔。短工找着了，还有件旧物想请您看看。’"
	else:
		if first:
			intro = "姜素云捏着银簪，迟迟没有松手。‘绣坊的工钱还欠着，家里要用钱。这支簪子我舍不得卖，只办活当。’"
			circumstance = "‘先挪过去这几日，三夜后来赎。赎金多少，烦请写清楚。’"
			origin = "自己的旧首饰，平日收在针线匣底。"
			completed = "她把当票折得整齐：‘日子和数目我都记下了。簪子先搁您这里。’"
			rejected = "姜素云把银簪插回发间：‘那我再想别的法子。’"
		else:
			var ticket := {}
			for t in FamiliarStories.history_data(state).get("pawn_tickets", []):
				if t.source_visit_id == story.first.visit_id: ticket = t; break
			var due := int(ticket.get("redemption_amount", 0))
			var gap := maxi(0, due - int(story.funds))
			origin = "自己做的绣活，一直留在家中，不是替绣坊处置的货。"
			if gap == 0:
				intro = "姜素云拿出一块绣片，神色比上回松快些。‘赎簪的钱留好了。这块是我自己的绣活，想换些针线钱，好接下一份活。’\n她说另已筹到%d银元，银簪赎金%d银元，已经够数。" % [story.funds, due]
				circumstance = "‘票上是第%d夜，赎金%d银元，我已经另包好了。这块绣片卖了添置针线，不动那笔钱。’" % [story.due_night, due]
				completed = "姜素云收好银元：‘这笔留着添针线。赎簪的钱另包好了，到日子再来。’"
				rejected = "她小心卷起绣片：‘那我带去别家问问，票上的日子再来。’"
			else:
				intro = "姜素云这回拿来一块绣片，当票仍压在衣襟里。‘工钱还没结清，赎簪的钱还缺些。这块是我自己的绣活，想卖了补上。’\n她说另已筹到%d银元，银簪赎金%d银元，还差%d银元。" % [story.funds, due, gap]
				circumstance = "‘票上是第%d夜，赎金%d银元。手里另有%d银元，这块绣片能卖多少，您照货看。’" % [story.due_night, due, story.funds]
				completed = "姜素云把银元另包了一包：‘这笔先留着，到票上的日子再来。’"
				rejected = "她小心卷起绣片：‘簪子的票还在，我再凑凑。’"
	visit.voice.merge({"introduction": intro, "circumstance": circumstance, "origin": origin, "completed": completed, "rejected": rejected,
		"refused": "客人看了看货，又把自己的价钱说了一遍。", "bargain_context": "客人把旧物转向灯下，听你指明依据。",
		"timed_out": "门外催着时辰，客人收起东西：‘今夜只能谈到这里了。’", "condition": "实物还在柜上，细处请您核对。", "evidence": "先按眼前这件货来说。"}, true)
	if row.familiar_id == "seamstress":
		visit.voice["belittle_cue"] = "她捏着包角，把价钱又轻声念了一遍。"
		visit.voice["belittle_response"] = "她迟疑了一下：‘掌柜既这么说，我再让些。’"
		visit.voice["bargain_context"] = "她把绣片铺平了一些。" if not first else "她看着灯下的簪脚，等你把话说完。"

static func redemption(ticket: PawnTicket, state: RunState) -> String:
	if ticket.terms_id != FamiliarStories.TERMS: return ""
	var story := FamiliarStories.story_for(FamiliarStories.history_data(state), "seamstress")
	if story.is_empty(): return ""
	if int(story.funds) >= ticket.redemption_amount: return "姜素云取出原票：‘赎簪的钱我一直另放着，您点点。’"
	var second := FamiliarStories.ending(FamiliarStories.history_data(state), story.follow.visit_id)
	return "姜素云取出原票：‘绣片的钱也攒在这包里，您点点。’" if second.get("outcome") == "bought" else "姜素云取出原票：‘从别处凑齐了，来把簪子赎回去。’"
