extends SceneTree

class CountingSession extends RunSession:
	var builds := 0
	func counter_model() -> Dictionary:
		builds += 1
		return {"inventory": {"cash": _day.state.cash}}

class CountingPanel extends IntentPanel:
	var renders := 0
	var latest := {}
	func _ready() -> void: pass
	func render(model: Dictionary) -> void:
		renders += 1
		latest = model

var failures := 0
var checks := 0
func check(ok: bool, detail: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(detail)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var catalog = JsonContentProvider.new("res://data/mirror_living_manifest.json").load_catalog().catalog
	var run_def = catalog.get_definition("runs", catalog.default_run_id)
	var store := GhostReplayStore.new()
	store.origin = {"seed": 23, "run_token": "0123456789abcdef0123456789abcdef"}
	var session := CountingSession.new(run_def, 22, store, catalog)
	var drawer := Control.new()
	root.add_child(drawer)
	var panel := CountingPanel.new()
	drawer.add_child(panel)
	panel.hide()
	var presenter := InventoryPresenter.new()
	root.add_child(presenter)
	presenter.bind(session, panel)
	check(session.builds == 0, "binding hidden drawer does not build")
	session._day.state.cash = 123
	session.changed.emit()
	check(session.builds == 0, "hidden state update does not build")
	panel.show()
	check(panel.renders == 1 and panel.latest.cash == 123, "opening immediately shows latest state")
	session._day.state.cash = 124
	session.changed.emit()
	check(panel.renders == 2 and panel.latest.cash == 124, "visible drawer updates")
	drawer.hide()
	session._day.state.cash = 125
	session.changed.emit()
	check(panel.renders == 2, "hidden ancestor also defers refresh")
	drawer.show()
	check(panel.renders == 3 and panel.latest.cash == 125, "ancestor reopening refreshes")
	print("HIDDEN DRAWERS: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
