extends "res://tests/gramophone_journey.gd"

func setup() -> bool:
	var loaded := JsonContentProvider.new("res://data/gramophone_release_manifest.json").load_catalog()
	check(loaded.is_success(),"v46 journey catalog")
	if not loaded.is_success():return false
	catalog=loaded.catalog;run_def=catalog.get_definition("runs",catalog.default_run_id);driver.check=check;driver.catalog=catalog;return true

func fresh_growth(seed_value := 42) -> RunSession:
	var store:=CountingStore.new();store.origin={"seed":seed_value,"run_token":"0123456789abcdef0123456789abcdef"}
	return RunSession.new(run_def,46,store,catalog)

func verify(s:RunSession,label:String) -> void:
	# This integration run audits complete saved history at gramophone checkpoints.
	if not label.begins_with("gramophone"): return
	InvestigationSaveCodec.clear_cache()
	var codec:=SaveCodec.new();var restored:=codec.decode(codec.encode(s._day.state,46),run_def,46,catalog,true)
	check(restored!=null,"v46 cold replay "+label+" "+codec.error_message)
	if restored!=null:check(GhostSaveCodec.same(restored.to_read_model(),s.read_state()),"exact replay "+label)

func run() -> void:
	if not setup():quit(1);return
	var initial:=run_def.initial_cash;run_def._initial_cash=2500
	for seed_value in [3,15,17,25,32,222,444,834,1074,609]:
		journey(seed_value)
		if gramophone_claims > 0: break
	run_def._initial_cash=initial
	check(gramophone_claims>0,"v46 natural gramophone negotiation and saved actions")
	print("GRAMOPHONE V46 JOURNEY: %d passes, %d failures" % [passes,failures]);quit(0 if failures==0 else 1)
