class_name ProvenanceConfirmation
extends RefCounted

static func show_for(panel: Control, callback: Callable, target: String, quote: String) -> void:
	var dialog := ConfirmationDialog.new()
	dialog.title = "委托调查"
	dialog.dialog_text = quote + "\n可能查无实据，每件物品只调查一次。\n调查费记入经营费用，不改变货物成本。"
	dialog.ok_button_text = "付费调查"
	dialog.cancel_button_text = "暂不调查"
	panel.add_child(dialog)
	dialog.confirmed.connect(func() -> void: callback.call("inquire", target, ""); dialog.queue_free())
	dialog.canceled.connect(dialog.queue_free)
	dialog.popup_centered(Vector2i(420, 180))
