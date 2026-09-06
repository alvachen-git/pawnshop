class_name CounterVisualReadModels
extends RefCounted

# Presentation-only facts. Never export the selected variant, reserve price,
# true value, situation, or reaction before the player obtains testimony.
static func enrich(model: Dictionary, day: DayController, service: CounterService, visit: CustomerVisit) -> void:
	var customer := service.catalog.get_definition("customers", visit.customer_id) as CustomerDefinition
	var item := service.catalog.get_definition("items", visit.item.definition_id) as ItemDefinition
	var bounds := service.appraisal.valuation(visit.item, item)
	var clues: Array[Dictionary] = []
	for id in visit.item.revealed_clue_ids:
		clues.append({"id": id, "text": item.find_clue(id).text})
	var speech: Array[Dictionary] = []
	var scenario := TradeScenarioService.for_visit(day.definition, visit)
	for id in visit.asked_question_ids:
		if scenario == null:
			var question := customer.find_question(id)
			if question != null: speech.append({"question": question.prompt, "answer": question.answer})
		else:
			for question in scenario.questions:
				if question.id == id: speech.append({"question": question.prompt, "answer": question.answer(visit)})
	var terms := service.catalog.get_definition("pawn_terms", customer.pawn_terms_id) as PawnTermsDefinition
	var visual := {
		"item_name": item.display_name, "item_description": item.description,
		"item_asset": item.visual_asset_id, "customer_name": customer.terms.display_name,
		"portrait_asset": customer.portrait_asset_id,
		"introduction": (scenario.introduction if scenario != null else customer.terms.introduction) + ("\n" + String(customer.belittle.cue) if not customer.belittle.is_empty() else ""),
		"clues": clues, "speech": speech,
		"estimate": "%d–%d" % [bounds.x, bounds.y],
		"judgement": CounterReadModels.JUDGEMENTS[visit.item.judgement],
		"asking": visit.trade.asking_price, "rounds_left": visit.trade.rounds_left,
		"attitude": "显得不耐烦" if visit.trade.patience < customer.patience else "尚愿意交谈",
		"deadline": TimeController.clock_text(day.definition.opening_minute, visit.expires_at),
		"quote_minutes": customer.terms.quote_minutes, "pressure_minutes": customer.terms.pressure_minutes,
		"pawn_terms": "期限%d夜 · 息费%.0f%%" % [terms.term_nights, terms.redemption_fee_ratio * 100] if terms != null else "此客不办理活当",
		"message": "",
		"bargaining_cue": customer.belittle.get("cue", ""),
	}
	# Reuse the same user-visible operation feedback passed into the main model.
	model.visual = visual
	for feature in ["appraisal", "dialogue", "trade"]:
		model[feature].visual = visual.duplicate(true)
