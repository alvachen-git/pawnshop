extends "res://tests/fan_condition.gd"

func run() -> void:
	if not setup(): quit(1); return
	var report := []
	for stage in ["no-bench", "minor-pressed", "minor-fan_pressure-offer"]:
		var payload: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(CONDITION_DIR+stage+".json"))
		InvestigationSaveCodec.clear_cache()
		var verifier:=InvestigationSaveCodec.new()
		var start:=Time.get_ticks_usec()
		var restored:=verifier.restore(payload,run_def,catalog,true)
		var cold:=(Time.get_ticks_usec()-start)/1000.0
		check(restored!=null and verifier.replayed_actions==payload.action_journal.size(),"full cold replay " + stage)
		var warm:=[]
		for repeat in 5:
			start=Time.get_ticks_usec()
			check(verifier.restore(payload,run_def,catalog,true)!=null and verifier.replayed_actions==0,"cached prefix retained " + stage)
			warm.append((Time.get_ticks_usec()-start)/1000.0)
		var forged:=payload.duplicate(true)
		forged.shop_growth.fan_bargaining.reputation_events.append({"id":"forged","delta":-2})
		check(verifier.restore(forged,run_def,catalog,true)==null,"warm path rejects altered ledger")
		var session:=load_case(stage); var before:=session.read_state()
		start=Time.get_ticks_usec()
		for repeat in 20: session.counter_model()
		var model_ms:=(Time.get_ticks_usec()-start)/20000.0
		check(before==session.read_state(),"read models never mutate")
		report.append({"stage":stage,"actions":payload.action_journal.size(),"cold_ms":cold,"warm_ms":warm,"model_ms":model_ms})
	DirAccess.make_dir_recursive_absolute("res://docs/qa/fan-condition")
	FileAccess.open("res://docs/qa/fan-condition/performance.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("FAN CONDITION PERFORMANCE: %d passes, %d failures; %s" % [passes,failures,JSON.stringify(report)])
	quit(0 if failures==0 else 1)
