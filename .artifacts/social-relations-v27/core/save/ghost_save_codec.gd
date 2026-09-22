class_name GhostSaveCodec
extends RefCounted

const COMMANDS := {"execute": [1, 2], "counter_command": [2, 4], "commerce_command": [2, 3], "sell_batch": [2, 3], "event_command": [2, 2], "risk_command": [2, 3], "mirror_command": [2, 2], "choose_pawn_disposal": [2, 2], "bell_command": [1, 2], "study_command": [2, 2], "inspect_customer": [1, 1]}
var error_message := "铜镜与换物记录无法重放，原档未覆盖。"

func restore(data: Variant, run: RunDefinition, catalog: ContentCatalog, extended: bool) -> RunState:
	if not data is Dictionary or catalog == null or not LivingMirror.enabled(run): return null
	if data.get("content_version") != 22 or data.get("save_version") != 22 or data.get("run_definition_id") != String(run.id): return null
	if not data.get("ghost_origin") is Dictionary or not data.get("ghost_commands") is Array or data.ghost_commands.size() > 8192: return null
	var origin: Dictionary = data.ghost_origin
	if origin.size() != 2 or not RunSchema.integer(origin.get("seed")) or origin.seed < 0 or origin.seed > 2147483647 or not origin.get("run_token") is String or origin.run_token.length() != 32: return null
	if origin.seed != data.get("run_seed") or origin.run_token != data.get("run_token"): return null
	if not RiskSaveCodec.valid_archive(data.get("death_archive")) or not FeeSaveCodec.valid_archive(data.get("bankruptcy_archive")): return null
	if data.get("phase") not in SaveCodec.CHECKPOINTS + (SaveTimeline.UNSETTLED if extended else []): return null
	var store := GhostReplayStore.new()
	store.origin = origin.duplicate(true)
	store.prior_deaths = data.death_archive.filter(func(row: Dictionary) -> bool: return row.run_token != origin.run_token)
	store.prior_bankruptcies = data.bankruptcy_archive.filter(func(row: Dictionary) -> bool: return row.run_token != origin.run_token)
	var session := RunSession.new(run, 22, store, catalog)
	for row in data.ghost_commands:
		if not row is Dictionary or row.size() != 2 or not row.get("method") is String or not COMMANDS.has(row.method) or not row.get("args") is Array: return null
		var limits: Array = COMMANDS[row.method]
		if row.args.size() < limits[0] or row.args.size() > limits[1] or not valid_args(row.method, row.args): return null
		session._counter.quote_before_timeout = recorded_quote_first(data, row, session._day.state)
		session.callv(row.method, row.args)
	var actual := session.read_state()
	var expected: Dictionary = data.duplicate(true)
	expected.erase("save_version")
	expected.erase("content_version")
	if not same(actual, expected):
		for key in actual:
			if not same(actual[key], expected.get(key)): error_message = "铜镜与换物记录不一致：" + key; break
		return null
	error_message = ""
	return session._day.state

static func recorded_quote_first(data: Dictionary, command: Dictionary, state: RunState) -> bool:
	if command.method != "counter_command" or command.args[0] not in ["offer", "pawn"]: return true
	for key in ["scenario_history", "bargaining_history"]:
		if not data.get(key) is Array: continue
		for row in data[key]:
			if row is Dictionary and row.get("command") == command.args[0] and row.get("visit_id") == command.args[1] and row.get("night") == state.current_night_index and row.get("start") == state.game_minutes and row.get("ok") is bool:
				return row.ok
	return true

static func valid_args(method: String, args: Array) -> bool:
	for i in args.size():
		if method == "sell_batch" and i >= 1:
			if not args[i] is Array or args[i].size() > 256: return false
			if i == 1 and not args[i].all(func(v: Variant) -> bool: return v is String): return false
			if i == 2 and not args[i].all(func(v: Variant) -> bool: return v is Array and v.size() == 2 and v.all(func(id: Variant) -> bool: return id is String)): return false
		elif method == "counter_command" and i == 3:
			if not RunSchema.integer(args[i]) or abs(args[i]) > 1000000: return false
		elif not args[i] is String or args[i].length() > 2048: return false
	return true

static func same(a: Variant, b: Variant) -> bool:
	if a is Dictionary:
		if not b is Dictionary or a.size() != b.size(): return false
		for k in a:
			if not b.has(k) or not same(a[k], b[k]): return false
		return true
	if a is Array:
		if not b is Array or a.size() != b.size(): return false
		for i in a.size():
			if not same(a[i], b[i]): return false
		return true
	return a == b
