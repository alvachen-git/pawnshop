extends "res://tests/bangle_appraisal.gd"

func setup() -> bool:
	var loaded:=JsonContentProvider.new("res://data/first_debt_recovery_release_manifest.json").load_catalog()
	for issue in loaded.issues: print(issue.format_message())
	check(loaded.is_success(),"v41 catalog")
	if not loaded.is_success(): return false
	catalog=loaded.catalog; run_def=catalog.get_definition("runs",catalog.default_run_id)
	driver.check=check; driver.catalog=catalog; return true

func fresh_growth(seed_value := 42) -> RunSession:
	var store:=CountingStore.new(); store.origin={"seed":seed_value,"run_token":"0123456789abcdef0123456789abcdef"}
	return RunSession.new(run_def,41,store,catalog)
