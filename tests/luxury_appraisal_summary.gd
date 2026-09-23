extends "res://tests/watch_economy.gd"

func run() -> void:
	if not setup(): quit(1); return
	var covered := 0
	for cid in run_def.variety.luxury.profiles:
		for iid in (catalog.get_definition("customers",cid) as CustomerDefinition).item_pool:
			var first := ""
			for variant in ["sound","mended","flawed"]:
				var s := unit_visit(cid,iid,variant,"sell"); equip(s,2)
				var v: CustomerVisit = s._day.state.visits[0]
				var definition := catalog.get_definition("items",iid) as ItemDefinition
				v.item.goods.precision.damage = "minor"
				MarketService.sync(s._day.state,run_def)
				# Unit fixtures jump to night four; let existing night records initialize.
				s.counter_model()
				var saved := s.read_state()
				var visual: Dictionary = s.counter_model().appraisal.visual
				check(s.read_state() == saved,"summary reading never mutates state")
				check(visual.item_name == definition.display_name and visual.clues.is_empty(),"ordinary name and unrevealed clues: "+iid)
				check(visual.judgement == "暂不判断" and visual.estimate_is_range,"player judgment and range fields")
				if first.is_empty(): first = visual.estimate
				check(visual.estimate == first,"hidden authenticity never leaks via range")
				check(s.fan_command("luxury_exterior",v.item.instance_id).ok,"inspect exterior")
				visual = s.counter_model().appraisal.visual
				var lower := roundi(definition.unknown_min*.8*(.5 if iid == WatchAppraisal.ITEM else 1))
				check(visual.estimate == "%d–%d" % [lower,roundi(definition.unknown_max*.8)],"only inspected exterior narrows public range")
				check(visual.clues.size() == 1 and visual.clues[0].id == "exterior","exterior enters ordinary clue list")
				covered += 1
	var s := watch_fixture("flawed","intact","stopping")
	var v: CustomerVisit = s._day.state.visits[0]
	evidence(s,true,true,true)
	var summary: Dictionary = s.counter_model().appraisal.visual
	check(summary.estimate == "25–500","inspection never substitutes hidden value for range")
	check(summary.clues.size() == 4,"two mechanism observations and two completed listening records")
	check(summary.judgement.contains("中途停走"),"player operation judgment included")
	check(command(s,v.item.instance_id,{"op":"draft","identity":"original","condition":"intact","running":"stable"}).ok,"wrong guess can still be recorded")
	summary = s.counter_model().appraisal.visual
	check(summary.estimate == "25–500" and summary.judgement.contains("连续"),"wrong guess displayed without altering range or auto-correction")
	print("LUXURY APPRAISAL SUMMARY: %d variants; %d passes, %d failures" % [covered,passes,failures])
	quit(0 if failures == 0 else 1)
