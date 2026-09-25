extends "res://tests/gramophone_appraisal.gd"

func run() -> void:
	if not setup():quit(1);return
	# Reproduce the reported calculation independently of whether a claim is true.
	var s:=gramophone("original","clear","steady","intact","customer_wealthy_antique")
	var v:CustomerVisit=s._day.state.visits[0]
	var n:=GramophoneNegotiation.data(s._day.state,v)
	n.personality="easy"
	for part in n.rolls:n.rolls[part]=0
	check(v.trade.asking_price==637,"reported opening price")
	begin(s);ca(s,{"op":"listen"})
	check(cc(s,{"identity":"imitation","sound":"muffled","motor":"stopping"}).ok,"old forced acceptance reproduced")
	check(v.trade.asking_price==100,"all accepted claims now stop at the item minimum")
	check(v.item.goods.gramophone_value.actual==700,"a believed lie never changes real value")
	var personalities:Dictionary={};var varied_rolls:=false
	for seed_value in range(1,17):
		for scenario in ["good","wavering","stopping","rasping","muffled","worn-record","rebuilt","imitation"]:
			var t:=gramophone();t._day.state.run_seed=seed_value
			GramophonePreview.apply(t,scenario)
			var w:CustomerVisit=t._day.state.visits[0]
			var actual:=GramophoneNegotiation.data(t._day.state,w).duplicate(true)
			var owner:=GramophoneEconomy.owner(t._day.state,w).duplicate(true)
			personalities[actual.personality]=true
			for value in actual.rolls.values():varied_rolls=varied_rolls or int(value)>0
			# Recreate production initialization with the same fixed facts and seed.
			GramophoneEconomy.prepare(t._day.state,w)
			check(GramophoneEconomy.owner(t._day.state,w)==owner,"ordinary preview preserves production owner "+scenario)
			check(GramophoneNegotiation.data(t._day.state,w)==actual,"ordinary preview preserves production negotiation "+scenario)
			GramophonePreview.apply(t,scenario)
			check(GramophoneNegotiation.data(t._day.state,w)==actual,"reopening preview does not reroll "+scenario)
	check(personalities.size()>1 and varied_rolls,"ordinary samples no longer force easy/all-zero rolls")
	for scenario in ["partial","firm","exposed"]:
		var t:=gramophone();GramophonePreview.apply(t,scenario)
		var d:=GramophoneNegotiation.data(t._day.state,t._day.state.visits[0])
		check(d.personality=={"partial":"careful","firm":"firm","exposed":"easy"}[scenario],"explicit negotiation fixture retained")
		check(d.rolls.motor==(99 if scenario=="exposed" else 0),"explicit fixture outcome retained")
	print("GRAMOPHONE PREVIEW: %d passes, %d failures" % [passes,failures]);quit(0 if failures==0 else 1)
