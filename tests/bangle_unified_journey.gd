extends "res://tests/bangle_journey.gd"

func setup() -> bool:
	var loaded := JsonContentProvider.new("res://data/bangle_unified_manifest.json").load_catalog()
	check(loaded.is_success(),"v40 catalog")
	if not loaded.is_success(): return false
	catalog = loaded.catalog; run_def = catalog.get_definition("runs",catalog.default_run_id)
	driver.check = check; driver.catalog = catalog; return true

func fresh_growth(seed_value := 42) -> RunSession:
	var store := CountingStore.new(); store.origin = {"seed":seed_value,"run_token":"0123456789abcdef0123456789abcdef"}
	return RunSession.new(run_def,40,store,catalog)

func verify(s: RunSession, label: String) -> void:
	InvestigationSaveCodec.clear_cache()
	var codec := SaveCodec.new(); var restored := codec.decode(codec.encode(s._day.state,40),run_def,40,catalog,true)
	check(restored != null,"v40 cold replay "+label+" "+codec.error_message)
	if restored != null: check(GhostSaveCodec.same(restored.to_read_model(),s.read_state()),"exact v40 replay "+label)

func run() -> void:
	if not setup():quit(1);return
	var initial:=run_def.initial_cash
	journey(609)
	run_def._initial_cash=2500
	journey(5)
	run_def._initial_cash=initial
	check(bangle_claims>0,"naturally generated bangle cold replay")
	print("BANGLE UNIFIED JOURNEY: bangle=%d pearl=%d watch=%d; %d passes, %d failures" % [bangle_claims,pearl_claims,watch_claims,passes,failures]);quit(0 if failures==0 else 1)
