extends "res://tests/watch_negotiation_journey.gd"

func setup() -> bool:
	var loaded := JsonContentProvider.new("res://data/watch_patterns_manifest.json").load_catalog()
	check(loaded.is_success(),"v36 catalog")
	if not loaded.is_success(): return false
	catalog = loaded.catalog; run_def = catalog.get_definition("runs",catalog.default_run_id)
	driver.check = check; driver.catalog = catalog; return true

func fresh_growth(seed_value := 42) -> RunSession:
	var store := CountingStore.new(); store.origin = {"seed":seed_value,"run_token":"0123456789abcdef0123456789abcdef"}
	return RunSession.new(run_def,36,store,catalog)

func verify(s: RunSession, label: String) -> void:
	InvestigationSaveCodec.clear_cache()
	var codec := SaveCodec.new(); var restored := codec.decode(codec.encode(s._day.state,36),run_def,36,catalog,true)
	check(restored != null,"v36 cold replay "+label+" "+codec.error_message)
	if restored != null: check(GhostSaveCodec.same(restored.to_read_model(),s.read_state()),"exact v36 replay "+label)

func negotiate(s: RunSession, v: CustomerVisit) -> void:
	if not WatchNegotiation.handles(s._day.state,v.item): super.negotiate(s,v); return
	check(s.counter_command("watch_claim",v.visit_id,'{"identity":"imitation","running":"stopping"}').ok,"new pattern claims")
	watch_claims += 1
	verify(s,"pattern persists with evidence and responses")
