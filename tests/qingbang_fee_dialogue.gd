extends "res://tests/qingbang.gd"

func run() -> void:
	var loaded := JsonContentProvider.new("res://data/qingbang_manifest.json").load_catalog()
	check(loaded.is_success(), "fee dialogue content")
	if not loaded.is_success(): quit(1); return
	catalog = loaded.catalog; run_def = catalog.get_definition("runs", catalog.default_run_id)
	for decision in ["pay", "refuse"]:
		var s := fixture()
		QingbangService.dawn(s._day.state, run_def)
		var id: String = s._day.state.social.qingbang.pending.id
		var model := s.counter_model()
		check(model.case_dialogue.buttons.size() == 2, "two counter choices")
		check(not QingbangBook.page(s._day, 0).buttons.any(func(b: Dictionary)->bool: return b.command in ["pay", "refuse"]), "no book payment actions")
		MarketService.sync(s._day.state, run_def)
		var before := s.read_state()
		(s._save as Store).fail = true
		check(not s.counter_command("qingbang_fee", id, decision).ok and before == s.read_state(), "fee rollback " + decision)
		(s._save as Store).fail = false
		check(s.counter_command("qingbang_fee", id, decision).ok, "counter decision " + decision)
		var state := s._day.state
		check(state.cash == (220 if decision == "pay" else 300), "cash once")
		check(state.social.qingbang.relation == (5 if decision == "pay" else -20), "relationship once")
		check(not QingbangConversation.presenting(state) and state.social.qingbang.fees.size() == 1, "visitor finished")
		before = s.read_state()
		check(not s.counter_command("qingbang_fee", id, decision).ok and before == s.read_state(), "duplicate decision rejected")
	var s := fixture()
	QingbangService.dawn(s._day.state, run_def)
	s._day.state.cash = 79
	var id: String = s._day.state.social.qingbang.pending.id
	var buttons: Array = s.counter_model().case_dialogue.buttons
	check(not buttons[0].enabled and buttons[1].enabled, "cash shortage disables pay only")
	check(not s.counter_command("qingbang_fee", id, "pay").ok, "cash shortage cannot pay")
	check(s.counter_command("qingbang_fee", id, "refuse").ok, "cash shortage can refuse")
	s = fixture()
	QingbangService.dawn(s._day.state, run_def)
	talk(s) # The released preview used this command to dismiss the opening speech.
	check(not QingbangConversation.active(s._day.state) and QingbangConversation.presenting(s._day.state), "legacy pending fee remains visible")
	check(s.counter_model().case_dialogue.buttons.size() == 2, "legacy counter choices recovered")
	id = s._day.state.social.qingbang.pending.id
	check(s.counter_command("qingbang_fee", id, "pay").ok, "legacy pending fee can pay at counter")
	if "--focused" not in OS.get_cmdline_user_args(): natural() # Real journals and cold save decoding.
	print("QINGBANG FEE DIALOGUE: %d passes, %d failures" % [passes, failures])
	quit(0 if failures == 0 else 1)

func drain(s: RunSession, strategy := "pay") -> void:
	if QingbangRules.active(s._day.state) and s._day.state.social.qingbang.pending.get("kind", "") == "fee":
		check(s.counter_command("qingbang_fee", s._day.state.social.qingbang.pending.id, "pay" if strategy == "pay" else "refuse").ok, "natural counter fee choice")
	super.drain(s, strategy)
