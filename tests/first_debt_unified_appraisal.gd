extends "res://tests/pearl_appraisal.gd"

func setup() -> bool:
	var loaded := JsonContentProvider.new("res://data/first_debt_unified_manifest.json").load_catalog()
	for issue in loaded.issues: print(issue.format_message())
	check(loaded.is_success(),"v39 catalog")
	if not loaded.is_success(): return false
	catalog = loaded.catalog; run_def = catalog.get_definition("runs",catalog.default_run_id)
	driver.check = check; driver.catalog = catalog; return true

func fresh_growth(seed_value := 42) -> RunSession:
	var store := CountingStore.new(); store.origin = {"seed":seed_value,"run_token":"0123456789abcdef0123456789abcdef"}
	return RunSession.new(run_def,39,store,catalog)

func verify(s: RunSession, label: String) -> void:
	InvestigationSaveCodec.clear_cache()
	var codec := SaveCodec.new(); var restored := codec.decode(codec.encode(s._day.state,39),run_def,39,catalog,true)
	check(restored != null,"v39 cold replay "+label+" "+codec.error_message)
	if restored != null: check(GhostSaveCodec.same(restored.to_read_model(),s.read_state()),"exact replay "+label)
