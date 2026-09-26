class_name InvestigationSaveCodec
extends RefCounted

var error_message := "十夜存档与实际办理记录不符，原档已保留。"

# One private, verified replay prefix. Never retain the caller's mutable state.
# This is an in-memory optimization only: disk format and publication stay atomic.
static var _checkpoint: Dictionary = {}
var replayed_actions := 0

static func clear_cache() -> void:
	_checkpoint.clear()

static func _content_value(value: Variant, objects: Dictionary) -> Variant:
	if value is Array:
		var result: Array = []
		for entry in value:
			result.append(_content_value(entry, objects) if entry is Array or entry is Dictionary or entry is RefCounted else entry)
		return result
	if value is Dictionary:
		var result := {}
		for key in value:
			var entry: Variant = value[key]
			result[key] = _content_value(entry, objects) if entry is Array or entry is Dictionary or entry is RefCounted else entry
		return result
	if value is RefCounted:
		var identity: int = value.get_instance_id()
		if objects.has(identity): return {"ref": identity}
		objects[identity] = true
		var script_path: String = value.get_script().resource_path
		var result := {"script": script_path, "identity": identity}
		if not objects.has(script_path):
			var properties: Array = value.get_property_list()
			var names := {}
			var fields: Array[String] = []
			for property in properties: names[property.name] = true
			for property in properties:
				# Definitions expose defensive-copy getters backed by _name fields.
				if property.usage & PROPERTY_USAGE_SCRIPT_VARIABLE and not names.has("_" + property.name): fields.append(property.name)
			objects[script_path] = fields
		for field in objects[script_path]:
			var entry: Variant = value.get(field)
			result[field] = _content_value(entry, objects) if entry is Array or entry is Dictionary or entry is RefCounted else entry
		return result
	return value

func restore(data: Variant, run: RunDefinition, catalog: ContentCatalog, extended: bool) -> RunState:
	error_message = "十夜存档与实际办理记录不符，原档已保留。"
	replayed_actions = 0
	if not data is Dictionary or catalog == null or not InvestigationService.enabled(run): return null
	var version := catalog.content_version
	if data.get("content_version") != version or data.get("save_version") != version or data.get("run_definition_id") != String(run.id): return null
	if not data.get("action_journal") is Array or (not FirstDebt.enabled(run) and data.action_journal.size() > 4096): return null
	if not data.get("ghost_origin") is Dictionary: return null
	var origin: Dictionary = data.ghost_origin
	if origin.size() != 2 or not RunSchema.integer(origin.get("seed")) or origin.seed < 0 or origin.seed > 2147483647 or not origin.get("run_token") is String or origin.run_token.length() != 32 or not origin.run_token.is_valid_hex_number(): return null
	if origin.seed != data.get("run_seed") or origin.run_token != data.get("run_token"): return null
	if not RiskSaveCodec.valid_archive(data.get("death_archive")) or not FeeSaveCodec.valid_archive(data.get("bankruptcy_archive")): return null
	if data.get("phase") not in SaveCodec.CHECKPOINTS + ["open"] + (SaveTimeline.UNSETTLED if extended or ShopGrowthService.enabled(run) else []): return null
	var store := GhostReplayStore.new()
	var legacy_intro: bool = SocialRules.enabled(run) and catalog.content_version == 27 and data.get("social") is Dictionary and not data.social.has("intro_step")
	store.set_meta("legacy_social_intro", legacy_intro)
	store.origin = origin.duplicate(true)
	store.prior_deaths = data.death_archive.filter(func(row: Dictionary) -> bool: return row.run_token != origin.run_token)
	store.prior_bankruptcies = data.bankruptcy_archive.filter(func(row: Dictionary) -> bool: return row.run_token != origin.run_token)
	var session := RunSession.new(run, version, store, catalog)
	session.replaying = true
	# Include actual content, not just a run id: editor/test changes invalidate the
	# prefix too. Prior attempts affect archives even when the current seed matches.
	var objects := {}
	var context := JSON.stringify([_content_value(catalog, objects), _content_value(run, objects), origin, store.prior_deaths, store.prior_bankruptcies])
	if SocialRules.enabled(run): context += JSON.stringify([SocialRules.config(), legacy_intro])
	if QingbangRules.enabled(run): context += JSON.stringify(QingbangRules.config())
	var start := 0
	if _checkpoint.get("context", "") == context:
		var verified: RunState = _checkpoint.state
		if data.action_journal.size() >= verified.action_journal.size() and GhostSaveCodec.same(data.action_journal.slice(0, verified.action_journal.size()), verified.action_journal):
			session._day.state = RunSnapshot.copy(verified)
			session._day.state.ghost_catalog = catalog
			session._pawn_choices = _checkpoint.pawn_choices.duplicate(true)
			start = verified.action_journal.size()
	var commands := GhostSaveCodec.COMMANDS.duplicate(true)
	commands["investigation_command"] = [2, 2]
	if FirstDebt.enabled(run): commands["observe_document"] = [1, 1]
	if MirrorEndingService.enabled(run): commands["mirror_resolution_command"] = [2, 2]
	if "aq_coat" in run.event_ids: commands["observe_room"] = [1, 1]
	if ShopGrowthService.enabled(run): commands["growth_command"] = [2, 2]
	if FanAppraisalService.enabled(run): commands["fan_command"] = [3, 3]
	if SocialRules.enabled(run): commands["social_command"] = [2, 2]
	var chen_revision := session._day.state.action_journal.any(func(r: Dictionary) -> bool: return r.has("chen_visits"))
	for index in range(start, data.action_journal.size()):
		var row: Variant = data.action_journal[index]
		if not row is Dictionary or not row.get("method") is String or not commands.has(row.method) or not row.get("args") is Array: return null
		if row.has("chen_visits"):
			if not DragonSearch.enabled(session._day.state) or row.size() != 3 or row.chen_visits != 1: return null
			chen_revision = true
		elif row.size() != 2 or chen_revision: return null
		session._day.state.set_meta("legacy_chen_visits", DragonSearch.enabled(session._day.state) and not chen_revision)
		var limits: Array = commands[row.method]
		if row.args.size() < limits[0] or row.args.size() > limits[1] or not GhostSaveCodec.valid_args(row.method, row.args): return null
		var args: Array = row.args.duplicate(true)
		if row.method == "counter_command" and args.size() == 4: args[3] = int(args[3])
		var result: ActionResult = session.callv(row.method, args)
		if DragonSearch.enabled(session._day.state) and row.method == "execute" and (str(row.args[0]).begins_with("prep_dragon_") or row.args[0] in ["prep_chen_invite", "prep_phoenix_invite"]) and not result.ok: return null
		if row.method in ["growth_command", "fan_command", "social_command"] and not result.ok: return null
		if row.method == "counter_command" and (row.args[0] in ["fan_pressure", "condition_pressure", "watch_bluff", "watch_claim", "pearl_claim", "gramophone_claim", "camera_claim", "porcelain_claim", "bangle_claim"] or String(row.args[0]).begins_with("luxury_")) and not result.ok: return null
		if SocialRules.enabled(run) and row.method == "counter_command" and row.args[0] in ["military_intro", "intimidate"] and not result.ok: return null
		if FirstDebt.enabled(run) and not result.ok and (row.method == "observe_document" or (row.method == "event_command" and str(row.args[0]).begins_with("fd_")) or (row.method == "execute" and row.args[0] == "finish_trial")): return null
		if ShopGrowthService.enabled(run) and row.method == "counter_command" and row.args[0] in ["display_accept", "display_counter"] and not result.ok: return null
		replayed_actions += 1
	session._day.state.set_meta("legacy_chen_visits", false)
	var expected: Dictionary = data.duplicate(true)
	expected.erase("save_version"); expected.erase("content_version")
	if SocialRules.enabled(run) and catalog.content_version == 26: expected = SocialCopyMigration.normalize(expected)
	var actual := session.read_state()
	if SocialRules.enabled(run) and catalog.content_version == 27: SocialCopyMigration.v27_notices(expected, actual)
	if not GhostSaveCodec.same(actual, expected):
		for key in actual:
			if not GhostSaveCodec.same(actual[key], expected.get(key)): error_message += "（" + key + "）"; break
		return null
	# Only a successful full-state comparison can advance the trusted prefix.
	# A failed disk publication may later roll back; that shorter/different journal
	# simply falls back to a cold replay. Returned state cannot poison this copy.
	_checkpoint = {"context": context, "state": RunSnapshot.copy(session._day.state), "pawn_choices": session._pawn_choices.duplicate(true)}
	error_message = ""
	return session._day.state
