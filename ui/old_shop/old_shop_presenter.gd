class_name OldShopPresenter
extends RefCounted

var session: RunSession
var view: OldShopView

func bind(target: OldShopView, source: RunSession) -> void:
	view = target
	session = source
	view.read_requested.connect(read_document)
	view.action_requested.connect(act)
	session.changed.connect(refresh)
	view.visibility_changed.connect(refresh)

func refresh() -> void:
	if view.visible: view.render(session.old_shop_model())

func read_document(id: String) -> void:
	for document in session.old_shop_model().get("documents", []):
		if document.id != id: continue
		if not document.read:
			var result := session.observe_document(document.observe_id)
			if not result.ok:
				view.show_message(result.message)
				return
		refresh()
		view.show_document(id)
		return

func act(id: String, choice: String) -> void:
	var result := session.observe_document(id) if id in FirstDebt.DOCUMENTS else session.event_command(id, choice)
	refresh()
	if result.ok and id in FirstDebt.DOCUMENTS: view.show_document(id)
	else: view.show_message(result.message)
