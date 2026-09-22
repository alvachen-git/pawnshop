class_name FanAppraisalView
extends CanvasLayer

const ART := "res://assets/appraisal/"
const UNSELECTED := Vector2(-1, -1)
var session: RunSession
var item_id := ""
var stage: Control
var book: FanDeskObject
var fan: FanDeskObject
var close_button: Button
var stamp: Button
var verdict: Label
var feedback: Label
var heading: Label
var deadline: Label
var clock_label: Label
var pair_title: Label
var pair_hint: Label
var reference_crop: TextureRect
var object_crop: TextureRect
var note_buttons: Dictionary = {}
var record_buttons: Dictionary = {}
var choice_buttons: Dictionary = {}
var clear_all: Button
var confirm_button: Button
var decision_error: Label
var _choice := ""
var decision: Control
var zoom: Control
var zoom_reference: TextureRect
var zoom_object: TextureRect
var _root: Control
var _link: EvidenceLink
var _kind := ""
var _access := ""
var _last_message := ""
var _refreshing := false
var _art_variant := ""

class EvidenceLink extends Control:
	var first: FanDeskObject
	var second: FanDeskObject
	func _draw() -> void:
		if first == null or second == null or first.marker.x < 0 or second.marker.x < 0: return
		var a := first.position + first.marker * first.size
		var b := second.position + second.marker * second.size
		draw_dashed_line(a, b, Color("e0b77db0"), 2, 9, true, true)

static func open(owner_view: Control, value: RunSession, target_id: String) -> FanAppraisalView:
	var existing := owner_view.get_tree().root.get_node_or_null("FanAppraisalOverlay") as FanAppraisalView
	if existing != null: return existing
	var view := FanAppraisalView.new()
	view.name = "FanAppraisalOverlay"
	view.session = value
	view.item_id = target_id
	owner_view.get_tree().root.add_child(view)
	owner_view.tree_exiting.connect(view.queue_free, CONNECT_ONE_SHOT)
	return view

func _ready() -> void:
	layer = 90
	_root = Control.new()
	_root.theme = CounterTheme.build()
	add_child(_root)
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shade := ColorRect.new()
	shade.color = Color("17110d")
	_root.add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stage = Control.new()
	stage.size = Vector2(1600, 900)
	stage.clip_contents = true
	_root.add_child(stage)
	_picture(stage, load(ART + "desk.png"), Rect2(0, 0, 1600, 900))
	heading = _label(stage, "鉴物台 · 案上对证", Rect2(44, 24, 690, 65), 42, "ecddba", true)
	deadline = _label(stage, "", Rect2(48, 94, 1100, 32), 22, "ecddba")
	close_button = Button.new()
	close_button.name = "CloseFanStudy"
	close_button.accessibility_name = "返回柜台"
	close_button.tooltip_text = "返回柜台 · Esc"
	stage.add_child(close_button)
	_rect(close_button, Rect2(1507, 28, 64, 44))
	FacilitiesRoomView.navigation_arrow(close_button, true)
	close_button.pressed.connect(queue_free)
	_button(stage, "归位", Rect2(1390, 88, 84, 37), _reset_objects).tooltip_text = "将图录与折扇摆回原处，不耗时"
	book = _object("reference", load(ART + "reference-book.png"), Rect2(24, 145, 760, 525))
	fan = _object("object", load(ART + "fan-sound.png"), Rect2(808, 155, 760, 570))
	_label(book, "顾砚生扇画摹存", Rect2(55, 49, 297, 43), 28, "34271c", true)
	_label(book, "山水 · 真迹图录", Rect2(78, 99, 260, 30), 19)
	_label(book, "笔势有收放，墨色随笔而转。\n旧纸未必出自旧人之手。", Rect2(66, 391, 297, 86), 19)
	_label(book, "笔法转折", Rect2(418, 63, 270, 28), 21, "34271c", true)
	_label(book, "题款与旧折", Rect2(418, 253, 270, 28), 21, "34271c", true)
	_label(book, "旧折处，字与画应一同磨损。", Rect2(416, 445, 275, 57), 17)
	_tab(book, "图录真迹", Rect2(47, -11, 143, 39))
	_tab(fan, "客人物件", Rect2(73, 0, 146, 39))
	_link = EvidenceLink.new()
	_link.first = book
	_link.second = fan
	_link.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(_link)
	_link.size = stage.size
	_build_notes()
	stamp = _button(stage, "落\n笔", Rect2(1430, 741, 113, 112), _open_decision)
	stamp.name = "WriteAppraisal"
	stamp.add_theme_font_size_override("font_size", 31)
	for state_name in ["normal", "hover", "pressed", "disabled"]:
		stamp.add_theme_stylebox_override(state_name, CounterTheme.painted_paper(Color("994b35") if state_name != "disabled" else Color("695243")))
		stamp.add_theme_color_override("font_color" if state_name == "normal" else "font_" + state_name + "_color", Color("f5dfb7"))
	clock_label = _label(stage, "", Rect2(49, 861, 410, 29), 21, "e9d5b0", true)
	feedback = _label(stage, "拖动摆齐 · 点击圈选 · 右键或滚轮细看", Rect2(470, 858, 1000, 34), 20, "e9d5b0")
	_build_decision()
	_build_zoom()
	session.changed.connect(refresh)
	session.restored.connect(queue_free)
	get_viewport().size_changed.connect(_layout)
	_layout()
	refresh()
	close_button.grab_focus()

static func _rect(control: Control, rect: Rect2) -> void:
	control.position = rect.position
	control.size = rect.size

func _label(parent: Node, text_value: String, rect: Rect2, font_size := 20, color := "34291f", display := false) -> Label:
	var label := Label.new()
	label.text = text_value
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color(color))
	if display: label.add_theme_font_override("font", CounterTheme.display_font())
	parent.add_child(label)
	_rect(label, rect)
	return label

func _picture(parent: Node, texture: Texture2D, rect: Rect2) -> TextureRect:
	var image := TextureRect.new()
	image.texture = texture
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_SCALE
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(image)
	_rect(image, rect)
	return image

func _paper(parent: Node, rect: Rect2) -> Panel:
	var panel := Panel.new()
	panel.add_theme_stylebox_override("panel", CounterTheme.painted_paper(Color("efe0bd")))
	parent.add_child(panel)
	_rect(panel, rect)
	return panel

func _tab(parent: Node, text_value: String, rect: Rect2) -> void:
	var paper := _paper(parent, rect)
	paper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label(paper, text_value, Rect2(9, 4, rect.size.x - 18, 30), 23, "34271c", true)

func _button(parent: Node, text_value: String, rect: Rect2, action: Callable) -> Button:
	var button := Button.new()
	button.text = text_value
	CounterTheme.style_paper_button(button)
	button.add_theme_font_size_override("font_size", 22)
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	parent.add_child(button)
	_rect(button, rect)
	button.pressed.connect(action)
	return button

func _object(side: String, texture: Texture2D, rect: Rect2) -> FanDeskObject:
	var object := FanDeskObject.new()
	object.side = side
	object.texture = texture
	object.name = "ReferenceBook" if side == "reference" else "CustomerFan"
	object.tooltip_text = "拖动摆齐；点击圈选；右键或滚轮放大"
	stage.add_child(object)
	_rect(object, rect)
	object.selected.connect(_select)
	object.moved.connect(func() -> void: _link.queue_redraw())
	object.grabbed.connect(_raise_object)
	object.detail_requested.connect(_detail)
	return object

func _raise_object(side: String) -> void:
	var object := book if side == "reference" else fan
	stage.move_child(object, _link.get_index() - 1)

func _reset_objects() -> void:
	book.position = Vector2(24, 145)
	fan.position = Vector2(808, 155)
	_link.queue_redraw()

func _build_notes() -> void:
	var slip := _paper(stage, Rect2(53, 707, 1300, 137))
	pair_title = _label(slip, "对照手记", Rect2(19, 10, 130, 34), 25, "34271c", true)
	pair_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	clear_all = _button(slip, "清空草稿", Rect2(19, 79, 130, 43), _clear)
	clear_all.add_theme_font_size_override("font_size", 18)
	clear_all.tooltip_text = "清空笔锋与题款两处草稿；单处看法可直接改选"
	clear_all.add_theme_stylebox_override("disabled", CounterTheme.painted_paper(Color("f0e7d2")))
	clear_all.add_theme_color_override("font_disabled_color", Color("78694f"))
	reference_crop = _picture(slip, null, Rect2(161, 9, 153, 110))
	object_crop = _picture(slip, null, Rect2(325, 9, 153, 110))
	_label(slip, "图录", Rect2(165, 112, 146, 24), 16)
	_label(slip, "折扇", Rect2(328, 112, 146, 24), 16)
	pair_hint = _label(slip, "先在图录上圈一处笔锋或题款，\n再找扇面上的对应位置。", Rect2(500, 12, 495, 61), 19)
	for i in 3:
		var key: String = FanEvidence.NOTES.keys()[i]
		var button := _button(slip, FanEvidence.NOTES[key], Rect2(510 + i * 113, 79, 101, 43), _note.bind(key))
		button.name = "Note_" + key
		button.tooltip_text = FanEvidence.EXPLANATIONS[key] + "；落笔前可以重新选择"
		note_buttons[key] = button
	for i in 2:
		var key: String = ["brush", "inscription"][i]
		var button := _button(slip, "笔锋 · 未记" if i == 0 else "题款 · 未记", Rect2(1005, 15 + i * 55, 266, 44), _review.bind(key))
		button.add_theme_font_size_override("font_size", 20)
		record_buttons[key] = button
	_button(slip, "放大", Rect2(875, 78, 91, 43), _show_zoom)

func _build_decision() -> void:
	decision = Control.new()
	stage.add_child(decision)
	decision.size = stage.size
	var shade := ColorRect.new()
	shade.color = Color(0.06, 0.04, 0.02, 0.72)
	decision.add_child(shade)
	shade.size = stage.size
	var paper := _paper(decision, Rect2(425, 150, 750, 600))
	_label(paper, "落笔 · 自己的判断", Rect2(35, 26, 480, 45), 30, "34271c", true)
	verdict = _label(paper, "", Rect2(36, 82, 678, 156), 21)
	for i in 3:
		var key: String = ["sound", "mended", "flawed"][i]
		var button := _button(paper, "判为" + FanAppraisalService.DISPLAY_LABELS[key], Rect2(37, 247 + i * 61, 675, 48), _choose.bind(key))
		choice_buttons[key] = button
	_label(paper, "这是你自己的判断；对客说法在议价时另选。\n正式落笔后，手记与结论不再修改。", Rect2(38, 425, 670, 51), 18)
	decision_error = _label(paper, "", Rect2(38, 481, 670, 34), 16, "782d21")
	confirm_button = _button(paper, "确认落笔 · 10分钟", Rect2(37, 525, 407, 49), _decide)
	confirm_button.add_theme_stylebox_override("disabled", CounterTheme.painted_paper(Color("f0e7d2")))
	confirm_button.add_theme_color_override("font_disabled_color", Color("78694f"))
	_button(paper, "返回修改", Rect2(471, 525, 240, 49), func() -> void: decision.hide())
	decision.hide()

func _build_zoom() -> void:
	zoom = Control.new()
	stage.add_child(zoom)
	zoom.size = stage.size
	var shade := ColorRect.new()
	shade.color = Color(0.06, 0.04, 0.02, 0.78)
	zoom.add_child(shade)
	shade.size = stage.size
	var paper := _paper(zoom, Rect2(262, 162, 1076, 548))
	_label(paper, "并置细看", Rect2(26, 20, 400, 50), 31, "34271c", true)
	_label(paper, "图录", Rect2(29, 80, 410, 30), 23)
	_label(paper, "折扇", Rect2(550, 80, 410, 30), 23)
	zoom_reference = _picture(paper, null, Rect2(27, 123, 495, 356))
	zoom_object = _picture(paper, null, Rect2(551, 123, 495, 356))
	_button(paper, "收起放大", Rect2(864, 493, 181, 39), func() -> void: zoom.hide())
	_label(paper, "只看图，不替你下判断。", Rect2(31, 498, 690, 33), 20)
	zoom.hide()

func _layout() -> void:
	if stage == null: return
	var viewport_size := get_viewport().get_visible_rect().size
	var ratio := minf(viewport_size.x / 1600.0, viewport_size.y / 900.0)
	stage.scale = Vector2.ONE * ratio
	stage.position = (viewport_size - stage.size * ratio) / 2

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		if zoom.visible: zoom.hide()
		elif decision.visible: decision.hide()
		else: queue_free()

func _select(side: String, point: Vector2) -> void:
	if not _access.is_empty(): return
	if side == "reference":
		_kind = FanEvidence.region(side, point)
		fan.set_marker(UNSELECTED)
		if _kind.is_empty(): _last_message = "图录右页有笔法与旧折两幅摹图，点在图上即可圈选。"
		else: _last_message = "已圈图录，再到扇面找对应的" + FanEvidence.TITLES[_kind] + "。"
	else:
		if _kind.is_empty(): _last_message = "先在图录右页选一处，再圈扇面。"
		elif FanEvidence.region(side, point) != _kind: _last_message = "这两处不便并看，请在扇面找同类的笔锋或题款。"
		else: _last_message = "把两处放在一起看，再在手记上记下你的看法。"
	_update_pair()
	_link.queue_redraw()

func _update_pair() -> void:
	reference_crop.texture = _crop(book.texture, book.marker)
	object_crop.texture = _crop(fan.texture, fan.marker)
	pair_title.text = FanEvidence.TITLES.get(_kind, "对照手记")
	var paired := _paired()
	var error := ""
	if paired: error = FanAppraisalService.draft_access(session._day, item_id)
	for button in note_buttons.values(): button.disabled = not paired or not error.is_empty()
	pair_hint.text = "先在图录上圈一处笔锋或题款，\n再找扇面上的对应位置。"
	if paired:
		pair_hint.text = "相合：符合特征 · 有异：发现差异\n看不准：观察不足；草稿可重选。" if error.is_empty() else error
	if not _access.is_empty(): pair_hint.text = _access
	feedback.text = _last_message if not _last_message.is_empty() else "拖动摆齐 · 点击圈选 · 右键或滚轮细看"

func _paired() -> bool:
	return not _kind.is_empty() and book.marker.x >= 0 and fan.marker.x >= 0 and FanEvidence.region("object", fan.marker) == _kind

static func _crop(texture: Texture2D, point: Vector2) -> Texture2D:
	if texture == null or point.x < 0: return null
	var atlas := AtlasTexture.new()
	atlas.atlas = texture
	var dimensions := texture.get_size()
	var extent := Vector2(1, 110.0 / 153.0) * dimensions.x * 0.23
	var start := (point * dimensions - extent / 2).clamp(Vector2.ZERO, dimensions - extent)
	atlas.region = Rect2(start, extent)
	atlas.filter_clip = true
	return atlas

func _detail(side: String, point: Vector2) -> void:
	if not _access.is_empty(): return
	_select(side, point)
	(book if side == "reference" else fan).set_marker(point)
	_update_pair()
	_show_zoom()

func _show_zoom() -> void:
	if not _access.is_empty(): return
	if book.marker.x < 0 and fan.marker.x < 0:
		_last_message = "先点选一处，再放大细看。"
		_update_pair()
		return
	zoom_reference.texture = reference_crop.texture
	zoom_object.texture = object_crop.texture
	zoom.show()

func _note(note: String) -> void:
	if not _paired(): return
	var result := session.fan_command("draft", item_id, FanEvidence.payload(_kind, book.marker, fan.marker, note))
	_last_message = result.message
	refresh()

func _clear() -> void:
	var result := session.fan_command("clear_draft", item_id, "all")
	_last_message = result.message
	if result.ok:
		book.set_marker(UNSELECTED)
		fan.set_marker(UNSELECTED)
		_kind = ""
	refresh()

func _review(kind: String) -> void:
	var pairs := FanAppraisalService.notes(session._day.state, item_id)
	if not pairs.has(kind):
		_last_message = "旧手记没有留下圈点，可自由看图；已经查过的细节不再收费。"
		_update_pair()
		return
	var pair: Dictionary = pairs[kind]
	_kind = kind
	book.set_marker(FanEvidence.unpack(pair.reference))
	fan.set_marker(FanEvidence.unpack(pair.object))
	_last_message = "%s手记：%s。复看不耗时。" % [FanEvidence.TITLES[kind], FanEvidence.NOTES[pair.note]]
	_update_pair()
	_link.queue_redraw()

func _open_decision() -> void:
	_choice = ""
	decision_error.text = ""
	refresh()
	decision.show()
	choice_buttons.sound.grab_focus()

func _choose(choice: String) -> void:
	_choice = choice
	refresh()

func _decide() -> void:
	var result := session.fan_command("commit", item_id, _choice)
	_last_message = result.message
	decision_error.text = "" if result.ok else result.message
	if result.ok: decision.hide()
	refresh()

func refresh() -> void:
	if _refreshing or stage == null or is_queued_for_deletion(): return
	_refreshing = true
	var state := session._day.state
	_access = FanConditionService.desk_reason(session._day, item_id)
	var item := FanAppraisalService.target(session._day, item_id)
	if item != null and _access.is_empty():
		var variant := String(item.selected_variant_id)
		if variant != _art_variant:
			fan.texture = load(ART + "fan-" + variant + ".png")
			fan.queue_redraw()
			_art_variant = variant
	book.visible = FanAppraisalService.data(state).get("manual", false)
	fan.visible = item != null and _access.is_empty()
	if not fan.visible:
		book.set_marker(UNSELECTED)
		fan.set_marker(UNSELECTED)
		zoom.hide()
		decision.hide()
		_kind = ""
	deadline.text = "铺中自有折扇 · 可免费翻阅图录"
	var visit := CustomerManager.new().active(state)
	if item != null and visit != null and visit.item == item and not InventoryManager.new().contains(state, item_id):
		deadline.text = "客人等到%s · 草稿可重选，确认落笔才计时" % TimeController.clock_text(session.definition.opening_minute, visit.expires_at)
		var customer := state.ghost_catalog.get_definition("customers", visit.customer_id) as CustomerDefinition
		if customer.guest_rule == "no_appraisal": deadline.text = "客人按着扇子：‘不许验货。’动手比对会惹他收物离开。"
	if not _access.is_empty(): deadline.text = _access
	clock_label.text = "第%d夜   %s" % [state.current_night_index, TimeController.clock_text(session.definition.opening_minute, state.game_minutes)]
	var row := FanAppraisalService.record(state, item_id)
	var pairs := FanAppraisalService.notes(state, item_id)
	var locked: bool = not String(row.get("verdict", "")).is_empty()
	for kind in record_buttons:
		var note: String = pairs.get(kind, {}).get("note", "")
		record_buttons[kind].text = ("笔锋" if kind == "brush" else "题款") + " · " + FanEvidence.NOTES.get(note, "未记") + ("" if locked or note.is_empty() else "（草稿）")
		record_buttons[kind].disabled = not pairs.has(kind) or not _access.is_empty()
	var draft_error := FanAppraisalService.draft_access(session._day, item_id)
	clear_all.disabled = not draft_error.is_empty() or pairs.is_empty()
	var verdict_error := FanAppraisalService.reason(session._day, "commit", item_id, "sound")
	stamp.disabled = not verdict_error.is_empty()
	stamp.tooltip_text = verdict_error if not verdict_error.is_empty() else "将两份手记合看，写下自鉴判断"
	var minutes := FanAppraisalService.commit_minutes(state, item_id)
	verdict.text = "笔锋：%s　题款：%s\n初步结论：%s\n%s\n%s" % [FanEvidence.NOTES.get(pairs.get("brush", {}).get("note", ""), "未记"), FanEvidence.NOTES.get(pairs.get("inscription", {}).get("note", ""), "未记"), FanAppraisalService.tentative(pairs), FanAppraisalService.standing_text(state), "本次落笔耗时10分钟。" if minutes > 0 else "此前检查已付时间，本次落笔不再扣时。"]
	for key in choice_buttons:
		var button: Button = choice_buttons[key]
		button.disabled = not verdict_error.is_empty()
		button.text = ("已选 · " if _choice == key else "判为") + FanAppraisalService.DISPLAY_LABELS[key]
	confirm_button.disabled = _choice.is_empty() or not verdict_error.is_empty()
	confirm_button.text = "先选择鉴定结论" if _choice.is_empty() else "确认落笔 · %d分钟" % minutes
	confirm_button.tooltip_text = "先选上方一种结论，再确认落笔" if _choice.is_empty() and verdict_error.is_empty() else verdict_error
	if not String(row.get("verdict", "")).is_empty():
		verdict.text = FanAppraisalService.claim_label(row.verdict) + "（" + FanAppraisalService.DISPLAY_LABELS[row.verdict] + "）"
		if item != null and item.expert_reviewed: verdict.text = GoodsExpertise.description(item, state.ghost_catalog.get_definition("items", item.definition_id))
		if _last_message.is_empty(): _last_message = verdict.text + " · 圈点可免费复看。"
	_update_pair()
	_link.queue_redraw()
	_refreshing = false
