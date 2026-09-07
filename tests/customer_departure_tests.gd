extends SceneTree
var failures := 0
var assertions := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	assertions += 1
	if not ok:
		failures += 1
		push_error(message)
func run() -> void:
	var helper := BargainingTests.new()
	helper.setup(check)
	for reason in ["patience", "rounds", "time", "close", "reject", "buy"]:
		var s := helper.session()
		var observer := CustomerDeparturePresenter.new()
		root.add_child(observer)
		var notices: Array = []
		observer.departed.connect(func(n: Dictionary) -> void: notices.append(n))
		observer.bind(s)
		check(s._save.save_state(s._day.state, s.definition, helper.catalog.content_version), "write initial test checkpoint")
		helper.open(s)
		var v := helper.active(s)
		var cash: int = s.read_state().cash
		match reason:
			"patience":
				v.customer_id = "customer_scholar"
				v.trade.patience = 2
				helper.action(s, "belittle")
			"rounds":
				v.trade.rounds_left = 1
				helper.action(s, "belittle")
			"time": helper.wait_to(s, v.expires_at)
			"close": s.execute("close_shop")
			"reject": helper.action(s, "reject")
			"buy": helper.action(s, "offer", "", v.trade.asking_price)
		if reason in ["reject", "buy"]:
			check(notices.is_empty(), "no duplicate result for " + reason)
		else:
			check(notices.size() == 1, "one departure notice for " + reason)
			if not notices.is_empty():
				var expected: String = {"patience": "耐心耗尽", "rounds": "议价轮次", "time": "等候期限", "close": "铺门已关"}[reason]
				check(notices[0].note.contains(expected), "explicit reason " + reason)
				check(notices[0].kind == "departure" and not notices[0].can_inspect, "not a successful receipt")
			check(s.read_state().cash == cash, "departure creates no payment")
		var count := notices.size()
		var before := s.read_state()
		s.changed.emit()
		check(before == s.read_state() and notices.size() == count, "reading does not mutate or repeat")
		s.counter_command("belittle", v.visit_id)
		check(notices.size() == count, "repeated old action cannot notify twice")
		# Binding to history, and loading a real checkpoint, never replay past notices.
		var late := CustomerDeparturePresenter.new()
		root.add_child(late)
		late.bind(s)
		late.departed.connect(func(n: Dictionary) -> void: notices.append(n))
		s.changed.emit()
		check(notices.size() == count, "binding existing history is silent")
		check(s.load_checkpoint().ok, "checkpoint loads")
		check(notices.size() == count, "checkpoint does not replay history")
		observer.free()
		late.free()
	# Simultaneous known customers are grouped; scheduled strangers stay silent.
	var s := helper.session()
	helper.open(s)
	var first := helper.active(s)
	var second: CustomerVisit = s._day.state.visits[1]
	second.status = "waiting"
	var observer := CustomerDeparturePresenter.new()
	root.add_child(observer)
	var grouped: Array = []
	observer.departed.connect(func(n: Dictionary) -> void: grouped.append(n))
	observer.bind(s)
	s.execute("close_shop")
	check(grouped.size() == 1, "one page for simultaneous departures")
	check(grouped[0].item.begins_with("2位") and grouped[0].detail.contains("铺门已关"), "only known visitors, scrollable individual reasons")
	observer.free()
	for path in helper.paths: DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	print("DEPARTURE TESTS: %d assertions, %d failures" % [assertions, failures])
	quit(0 if failures == 0 else 1)
