extends "res://tests/fan_condition.gd"

const UNIFIED_DIR := "res://.godot/qa/unified/"

func setup() -> bool:
	var loaded := JsonContentProvider.new("res://data/unified_manifest.json").load_catalog()
	for issue in loaded.issues: print(issue.format_message())
	check(loaded.is_success(), "unified v30 catalog")
	if not loaded.is_success(): return false
	catalog = loaded.catalog; run_def = catalog.get_definition("runs", catalog.default_run_id)
	driver.check = check; driver.catalog = catalog
	return true

func fresh_growth(seed_value := 42) -> RunSession:
	var store := CountingStore.new()
	store.origin = {"seed":seed_value,"run_token":"0123456789abcdef0123456789abcdef"}
	return RunSession.new(run_def,30,store,catalog)

func verify(s: RunSession, label: String) -> void:
	var codec := SaveCodec.new()
	InvestigationSaveCodec.clear_cache()
	var restored := codec.decode(codec.encode(s._day.state,30),run_def,30,catalog,true)
	check(restored != null,"unified cold replay " + label + " " + codec.error_message)
	if restored != null: check(GhostSaveCodec.same(restored.to_read_model(),s.read_state()),"exact " + label)

func fixture(s: RunSession, label: String) -> void:
	verify(s,label)
	DirAccess.make_dir_recursive_absolute(UNIFIED_DIR)
	var file := FileAccess.open(UNIFIED_DIR + label + ".json",FileAccess.WRITE)
	file.store_string(JSON.stringify(SaveCodec.new().encode(s._day.state,30)))

func load_case(label := "ordinary") -> RunSession:
	var payload: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(UNIFIED_DIR + label + ".json"))
	var s := fresh_growth(int(payload.run_seed))
	s._day.state = SaveCodec.new().decode(payload,run_def,30,catalog,true)
	return s

func run() -> void:
	if not setup(): quit(1); return
	check(SocialRules.enabled(run_def) and FanConditionService.enabled(run_def) and MirrorDreamService.enabled(run_def) and MirrorReunionService.enabled(run_def) and AqiCompanion.enabled(run_def), "all systems enabled in the same run")
	introduction()
	create_fixtures()
	for kind in ["informed", "ordinary", "urgent"]:
		var s := load_case(kind); claim(s); fixture(s,kind + "-ready")
	condition_fixtures()
	inspection_checks()
	pricing_matrix()
	stack_checks()
	condition_boundaries()
	social_prices()
	print("UNIFIED APPRAISAL: %d passes, %d failures" % [passes, failures])
	quit(0 if failures == 0 else 1)

func introduction() -> void:
	driver.pause_military_intro = true
	var s := second_night()
	check(MilitaryIntroduction.active(s._day.state), "Sun arrives second day")
	fixture(s,"introduction")
	var before := s.read_state()
	check(not s.execute("open_shop").ok and not s.growth_command("build","bench").ok, "reception blocks business and construction")
	check(before == s.read_state(), "blocked reception actions unchanged")
	(s._save as CountingStore).fail = true
	check(not s.counter_command("military_intro",MilitaryIntroduction.id(s._day.state),"0").ok and before == s.read_state(), "failed reception save rolls back")
	(s._save as CountingStore).fail = false
	for step in 3:
		check(s.counter_command("military_intro",MilitaryIntroduction.id(s._day.state),str(step)).ok, "reception step")
		verify(s,"reception " + str(step))
	check(s._day.state.social.introduced and s.social_command("accept_contract").ok, "contract after reception")
	verify(s,"accepted procurement")
	fixture(s,"contract")
	driver.pause_military_intro = false

func social_prices() -> void:
	# Natural saved cases exercise both discount orders and actual settlement.
	for order in [["fan_pressure", "intimidate"], ["intimidate", "fan_pressure"]]:
		var s := load_case("ordinary-ready")
		var v := CustomerManager.new().active(s._day.state)
		# Boundary setup: award a plaque without changing the fan evidence.
		s._day.state.social.plaque_awarded = true
		var rep := int(s._day.state.social.reputation)
		for command in order:
			var before := FanBargainingService.asking(s._day.state,v)
			check(s.counter_command(command,v.visit_id).ok, "stack plaque " + command)
			check(FanBargainingService.asking(s._day.state,v) < before, "each concession changes actual purchase quote")
		var price := int(FanBargainingService.attempt(s._day.state,v).reserve)
		check(s.counter_command("offer",v.visit_id,"",price).ok and v.item.ownership_state == "owned", "stacked purchase")
		check(int(s._day.state.social.reputation) <= rep - 4, "plaque and dishonest true-fan purchase affect reputation")
		var after := s.read_state()
		FanBargainingService.bought(s._day,v,price)
		check(after == s.read_state(), "dishonesty recorded only once")
	var s := load_case("minor-checked")
	var v := CustomerManager.new().active(s._day.state)
	check(s.counter_command("condition_pressure",v.visit_id).ok, "legitimate damage concession")
	check(ReputationService.basis(s._day.state,v) == maxi(1,roundi(v.trade.opening_price * .8)), "damage lowers fair reputation basis")
	verify(s,"fair damage basis")
	var payload := SaveCodec.new().encode(s._day.state,30)
	payload.social.reputation += 50
	check(SaveCodec.new().decode(payload,run_def,30,catalog,true) == null, "forged social score rejected")
