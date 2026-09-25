class_name LuxuryAppraisalView
extends CanvasLayer

var session: RunSession
var item_id := ""
var body: Label
var actions: VBoxContainer
var status: Label
var tabs: Array[Button] = []
var step := 0
var _root: Control
var _title: Label
var _footer: HBoxContainer
var _error := ""

static func open(owner_view: Control, current: RunSession, id: String) -> LuxuryAppraisalView:
	if CameraEconomy.handles(current._day.state,LuxuryAppraisalService.target(current._day,id)): return CameraDeskView.open_camera(owner_view,current,id)
	if PorcelainEconomy.handles(current._day.state,LuxuryAppraisalService.target(current._day,id)): return PorcelainDeskView.open_porcelain(owner_view,current,id)
	if BangleEconomy.handles(current._day.state,LuxuryAppraisalService.target(current._day,id)): return BangleDeskView.open_bangle(owner_view,current,id)
	if PearlEconomy.handles(current._day.state,LuxuryAppraisalService.target(current._day,id)): return PearlDeskView.open_pearl(owner_view,current,id)
	if WatchAppraisal.handles(current._day.state,LuxuryAppraisalService.target(current._day,id)): return WatchDeskView.create(owner_view,current,id)
	if TieredAppraisal.enabled(current.definition): return TieredAppraisalView.create(owner_view,current,id)
	var existing := owner_view.get_tree().root.get_node_or_null("LuxuryAppraisalOverlay") as LuxuryAppraisalView
	if existing != null: return existing
	var view := LuxuryAppraisalView.new()
	view.name = "LuxuryAppraisalOverlay"
	view.session = current; view.item_id = id
	if LuxuryAppraisalService.record(current._day.state,id).get("committed",false): view.step = 2
	owner_view.get_tree().root.add_child(view)
	owner_view.tree_exiting.connect(view.queue_free,CONNECT_ONE_SHOT)
	return view

func _ready() -> void:
	layer = 90
	_root = Control.new(); _root.theme = CounterTheme.build(); add_child(_root)
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shade := ColorRect.new(); shade.color = Color("201a16")
	_root.add_child(shade); shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel",CounterTheme.painted_paper())
	_root.add_child(panel); panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.offset_left = 36; panel.offset_top = 28; panel.offset_right = -36; panel.offset_bottom = -28
	var margin := MarginContainer.new()
	for edge in ["left","right","top","bottom"]: margin.add_theme_constant_override("margin_"+edge,24)
	panel.add_child(margin)
	var column := VBoxContainer.new(); column.add_theme_constant_override("separation",18); margin.add_child(column)
	var header := HBoxContainer.new(); column.add_child(header)
	_title = _label(header,"",28); _title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var close := _button(header,"返回柜台",queue_free)
	close.name = "CloseLuxuryStudy"
	status = _label(column,"",18)
	var navigation := HBoxContainer.new(); navigation.add_theme_constant_override("separation",12); column.add_child(navigation)
	for index in 3:
		var tab := _button(navigation,"",select_step.bind(index)); tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tab.name = "Step" + str(index); tab.toggle_mode = true; tabs.append(tab)
	column.add_child(HSeparator.new())
	var split := HBoxContainer.new(); split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.add_theme_constant_override("separation",40); column.add_child(split)
	for index in 2:
		var scroll := ScrollContainer.new(); scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		scroll.size_flags_stretch_ratio = 1.35 if index == 0 else 1.0
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED; split.add_child(scroll)
		if index == 0:
			body = _label(scroll,"",22); body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		else:
			actions = VBoxContainer.new(); actions.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			actions.add_theme_constant_override("separation",12); scroll.add_child(actions)
	column.add_child(HSeparator.new())
	_footer = HBoxContainer.new(); _footer.add_theme_constant_override("separation",16); column.add_child(_footer)
	session.changed.connect(refresh); session.restored.connect(queue_free)
	refresh(); close.grab_focus()

func select_step(index: int) -> void:
	step = index; _error = ""; refresh()

func refresh() -> void:
	var item := LuxuryAppraisalService.target(session._day,item_id)
	if item == null:
		body.text = "这件货已不在眼前。"; _clear(actions); _clear(_footer); return
	var definition := session._counter.catalog.get_definition("items",item.definition_id) as ItemDefinition
	var book := LuxuryAppraisalService.info(session._day.state,item)
	var record := LuxuryAppraisalService.record(session._day.state,item_id)
	var committed: bool = record.get("committed",false)
	var known := ShopKnowledgeService.mastered(session._day.state,book.topic)
	_title.text = definition.display_name + " · 鉴定"
	status.text = "%s · 已查%d/2处" % [TimeController.clock_text(session.definition.opening_minute,session._day.state.game_minutes),record.get("checks",[]).size()]
	for index in 3:
		tabs[index].text = ("一 · " if index == 0 else "二 · ") + String(book.checks[index]) if index < 2 else "三 · 记录判断"
		tabs[index].set_pressed_no_signal(step == index)
	_clear(actions); _clear(_footer)
	if step < 2:
		var checked: bool = str(step) in record.get("checks",[])
		body.text = "实物\n\n" + (String(book.observations[item.selected_variant_id][step]) if checked else "尚未细查。")
		if checked and known: body.text += "\n\n图录\n\n" + String(book.references[step])
		_action("luxury_check",str(step),"复看 · 不耗时" if checked else "细查 · 10分钟")
		if checked and known:
			_label(actions,"与图录比较",22)
			for choice in LuxuryAppraisalService.MATCHES:
				var labels := {"sound":"与原样相符","mended":"有修配痕迹","flawed":"有仿制疑点"}
				if item.definition_id == "item_luxury_album": labels.mended = "有临摹痕迹"
				if item.definition_id == "item_luxury_gold_bangle": labels.mended = "与低成色旧款相符"
				_action("luxury_match","%d/%s" % [step,choice],labels[choice],record.get("matches",{}).get(str(step),"") == choice)
		elif not known: _label(actions,"先到知识柜学习" + String(ShopKnowledgeService.TOPICS[book.topic].name) + "，再对照图录。",18)
		if committed: _label(actions,"已落笔，可复看。",18)
	else:
		body.text = "查验记录"
		for index in 2:
			body.text += "\n\n" + String(book.checks[index]) + "\n"
			body.text += String(book.observations[item.selected_variant_id][index]) if str(index) in record.get("checks",[]) else "尚未细查。"
		if committed:
			_label(actions,"已落笔",24)
			_label(actions,"身份 · " + LuxuryAppraisalService.IDENTITIES[record.identity],22)
			_label(actions,"品相 · " + LuxuryAppraisalService.CONDITIONS[record.condition],22)
		else:
			_label(actions,"身份",22)
			for choice in LuxuryAppraisalService.identity_choices(session._day.state,item):
				_action("luxury_identity",choice,LuxuryAppraisalService.IDENTITIES[choice],record.get("identity","") == choice)
			_label(actions,"品相",22)
			for choice in LuxuryAppraisalService.CONDITIONS:
				_action("luxury_condition",choice,LuxuryAppraisalService.CONDITIONS[choice],record.get("condition","") == choice)
	var note := _label(_footer,_error,17); note.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if step < 2: _button(_footer,"下一处" if step == 0 else "记录判断",select_step.bind(step+1))
	elif not committed:
		var reason := LuxuryAppraisalService.reason(session._day,"luxury_commit",item_id)
		note.text = _error if not _error.is_empty() else ("确认后不能改写。" if reason.is_empty() else reason)
		var commit := _button(_footer,"确认落笔",_act.bind("luxury_commit",""))
		commit.name = "luxury_commit_"; commit.disabled = not reason.is_empty()
	else: _button(_footer,"返回柜台",queue_free)

func _action(command: String, detail: String, text: String, chosen := false) -> void:
	var reason := LuxuryAppraisalService.reason(session._day,command,item_id,detail)
	var button := _button(actions,text,_act.bind(command,detail))
	button.name = command + "_" + detail.replace("/","_")
	button.disabled = not reason.is_empty(); button.tooltip_text = reason
	button.toggle_mode = command != "luxury_check"; button.set_pressed_no_signal(chosen)
	if command == "luxury_check" and not reason.is_empty(): _label(actions,reason,18)

func _act(command: String, detail: String) -> void:
	var result := session.fan_command(command,item_id,detail)
	_error = "" if result.ok else result.message
	refresh()

func _button(parent: Node, text: String, action: Callable) -> Button:
	var button := Button.new(); button.text = text; button.custom_minimum_size = Vector2(160,48)
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	CounterTheme.style_paper_button(button)
	button.add_theme_font_size_override("font_size",20)
	button.pressed.connect(action); parent.add_child(button)
	return button

func _label(parent: Node, text: String, size: int) -> Label:
	var label := Label.new(); label.text = text; label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size",size); parent.add_child(label)
	return label

func _clear(parent: Node) -> void:
	for child in parent.get_children(): parent.remove_child(child); child.queue_free()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled(); queue_free()
