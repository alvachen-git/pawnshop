class_name MeritFeedbackPresenter
extends Node

var session: RunSession
var screen: CounterScreen
var stage: CounterStage
var retry: ConfirmationDialog
var _failed := false
var _committing := false

func bind(value: RunSession, owner_screen: CounterScreen) -> void:
	session = value
	screen = owner_screen
	stage = screen._counter_view.get_node("Room")
	retry = ConfirmationDialog.new()
	retry.title = "保存失败"
	retry.ok_button_text = "重试"
	retry.cancel_button_text = "稍后"
	screen.add_child(retry)
	retry.confirmed.connect(func() -> void: _failed = false)
	session.changed.connect(func() -> void:
		if not _committing and not retry.visible: _failed = false
	)
	session.restored.connect(func() -> void:
		stage.stop_merit_echo(); retry.hide(); _failed = false
	)

func _process(_delta: float) -> void:
	if session == null or _committing: return
	var model := session.merit_feedback_model()
	if not model.safe or stage.smoke_wrong or not screen.is_visible_in_tree():
		stage.stop_merit_echo()
		return
	if not model.pending or _failed or retry.visible: return
	# Closing the RPG dialogue releases the retained portrait before this frame.
	if screen._bell_blocked() or screen._counter_view.conversation_held: return
	var main := screen.get_parent()
	if "title_menu" in main and main.title_menu != null and main.title_menu.visible: return
	_committing = true
	var result := session.event_command(HiddenMerit.ECHO, "seen")
	_committing = false
	if result.ok:
		stage.play_merit_echo()
	else:
		_failed = true
		retry.dialog_text = result.message
		retry.popup_centered(Vector2i(460, 180))
