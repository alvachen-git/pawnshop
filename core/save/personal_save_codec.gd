class_name PersonalSaveCodec
extends RefCounted

# v22 validates the exact public command transcript, including live trading.
# Replaying uses the real services with all I/O disabled; an early ending never
# invents a close, visit departure, nightly settlement or interest charge.
const COMMANDS := {"execute": [TYPE_STRING, TYPE_STRING], "counter_command": [TYPE_STRING, TYPE_STRING, TYPE_STRING, TYPE_INT], "commerce_command": [TYPE_STRING, TYPE_STRING, TYPE_STRING], "event_command": [TYPE_STRING, TYPE_STRING], "risk_command": [TYPE_STRING, TYPE_STRING, TYPE_STRING], "mirror_command": [TYPE_STRING, TYPE_STRING], "study_command": [TYPE_STRING, TYPE_STRING], "bell_command": [TYPE_STRING, TYPE_STRING], "choose_pawn_disposal": [TYPE_STRING, TYPE_STRING], "sell_batch": [TYPE_STRING, TYPE_ARRAY, TYPE_ARRAY]}
var error_message := "命灯存档与实际操作记录不符；原文件已保留。"

class ReplayStore extends SaveManager:
	func read_archive() -> Array[Dictionary]: return []
	func read_bankruptcy_archive() -> Array[Dictionary]: return []
	func save_state(_state: RunState, _run: RunDefinition, _version: int) -> bool: return true

func decode(data: Dictionary, run: RunDefinition, version: int, catalog: ContentCatalog) -> RunState:
	if version != 22 or data.get("save_version") != 22 or data.get("content_version") != 22 or data.get("run_definition_id") != String(run.id) or catalog == null: return null
	if not data.get("action_journal") is Array or data.action_journal.size() > 4096: return null
	if not RunSchema.integer(data.get("run_seed")) or data.run_seed < 0 or data.run_seed > 2147483647: return null
	if not data.get("run_token") is String or data.run_token.length() != 32 or not data.run_token.is_valid_hex_number(): return null
	if not RiskSaveCodec.valid_archive(data.get("death_archive")) or not FeeSaveCodec.valid_archive(data.get("bankruptcy_archive")): return null
	for row in data.action_journal:
		if not valid_command(row): return null
	var session := RunSession.new(run, version, ReplayStore.new(), catalog)
	session.replaying = true
	session._day.state = RunState.create(run)
	session._day.state.run_seed = int(data.run_seed)
	session._day.state.run_token = data.run_token
	session._counter.customers.prepare_night(session._day.state, run, catalog)
	MarketService.sync(session._day.state, run)
	session._events.poll(session._day.state, run)
	for row in data.action_journal:
		var args: Array = row.args.duplicate(true)
		for index in args.size():
			if COMMANDS[row.method][index] == TYPE_INT: args[index] = int(args[index])
		session.callv(row.method, args)
	var state := session._day.state
	var expected: Dictionary = JSON.parse_string(JSON.stringify(state.to_read_model()))
	var actual: Dictionary = JSON.parse_string(JSON.stringify(data))
	actual.erase("save_version")
	actual.erase("content_version")
	for key in ["death_archive", "bankruptcy_archive"]:
		var own: Array = actual[key].filter(func(row: Dictionary) -> bool: return row.run_token == state.run_token)
		if own != expected[key]: return null
		expected[key] = actual[key]
	if expected != actual:
		for key in expected:
			if expected[key] != actual.get(key): error_message += "（" + key + "）"; break
		return null
	state.death_archive.assign(data.death_archive)
	state.bankruptcy_archive.assign(data.bankruptcy_archive)
	error_message = ""
	return state

static func valid_command(row: Variant) -> bool:
	if not row is Dictionary or row.size() != 2 or not row.get("method") is String or not COMMANDS.has(row.method) or not row.get("args") is Array: return false
	var schema: Array = COMMANDS[row.method]
	if row.args.size() != schema.size(): return false
	for index in schema.size():
		var value: Variant = row.args[index]
		if schema[index] == TYPE_INT:
			if not RunSchema.integer(value) or abs(value) > 2147483647: return false
		elif typeof(value) != schema[index]: return false
		if value is String and value.length() > 2048: return false
		if value is Array:
			if value.size() > 100: return false
			for entry in value:
				if index == 1:
					if not entry is String: return false
				elif not entry is Array or entry.size() != 2 or not entry[0] is String or not entry[1] is String: return false
	return true
