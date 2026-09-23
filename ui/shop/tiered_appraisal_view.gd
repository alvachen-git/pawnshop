class_name TieredAppraisalView
extends LuxuryAppraisalView

var tier := 2
var focus_index := 0
var canvas: Control
var object_plate: FanDeskObject
var reference_plate: FanDeskObject
var observation: Label
var reference_text: Label
var choices: HBoxContainer
var identity: OptionButton
var condition: OptionButton
var seal: Button
var zoom_layer: Control
var zoom_object: TextureRect
var zoom_reference: TextureRect
var begin_buttons: Array[Button] = []
var detail_buttons: Array[Button] = []
var note_buttons: Array[Button] = []
var identity_keys: Array = []
var condition_keys: Array = []
var status_note: Label
var tool_note: Label

static func create(owner_view: Control, current: RunSession, id: String) -> TieredAppraisalView:
	var old := owner_view.get_tree().root.get_node_or_null("TieredAppraisalOverlay") as TieredAppraisalView
	if old != null: return old
	var view := TieredAppraisalView.new()
	view.name = "TieredAppraisalOverlay"; view.session = current; view.item_id = id
	owner_view.get_tree().root.add_child(view)
	owner_view.tree_exiting.connect(view.queue_free,CONNECT_ONE_SHOT)
	return view

func _ready() -> void:
	layer = 90
	_root = Control.new(); add_child(_root); _root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shade := ColorRect.new(); shade.color = Color("201a16"); _root.add_child(shade); shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	canvas = Control.new(); canvas.theme = CounterTheme.build(); canvas.size = Vector2(1600,900); _root.add_child(canvas)
	var paper := Panel.new(); paper.add_theme_stylebox_override("panel",CounterTheme.painted_paper()); canvas.add_child(paper); paper.position = Vector2(25,20); paper.size = Vector2(1550,860)
	_title = text_at("",Vector2(60,38),Vector2(980,42),28)
	tool_note = text_at("",Vector2(640,45),Vector2(690,32),18)
	make_button("返回柜台",Rect2(1350,35,180,48),queue_free,"close")
	status_note = text_at("",Vector2(60,85),Vector2(1460,40),21)
	for index in 3:
		var button := make_button("",Rect2(60+index*495,128,475,48),begin.bind(index),"begin_"+str(index))
		begin_buttons.append(button)
	text_at("实物",Vector2(160,184),Vector2(430,32),24)
	text_at("图录",Vector2(970,184),Vector2(430,32),24)
	object_plate = plate("object",Vector2(150,225))
	reference_plate = plate("reference",Vector2(950,225))
	make_button("放大对照",Rect2(700,370,200,50),show_zoom,"zoom")
	for index in 2:
		var button := make_button("",Rect2(60+index*745,640,720,48),select_detail.bind(index),"detail_"+str(index))
		button.toggle_mode = true; detail_buttons.append(button)
	observation = text_at("",Vector2(60,553),Vector2(720,78),22)
	reference_text = text_at("",Vector2(805,553),Vector2(720,78),22)
	var index := 0
	for key in TieredAppraisal.NOTES:
		var button := make_button(TieredAppraisal.NOTES[key],Rect2(60+index*240,701,220,48),save_pair.bind(key),"note_"+key)
		button.toggle_mode = true; note_buttons.append(button); index += 1
	identity = OptionButton.new(); condition = OptionButton.new()
	for button in [identity,condition]:
		button.allow_reselect = true
		canvas.add_child(button); button.size = Vector2(310,48); button.add_theme_font_size_override("font_size",22)
	identity.position = Vector2(805,701); condition.position = Vector2(1135,701)
	identity.item_selected.connect(select_verdict); condition.item_selected.connect(select_verdict)
	body = text_at("",Vector2(60,777),Vector2(1150,65),21)
	seal = make_button("确认落笔",Rect2(1280,786,240,50),commit,"seal")
	build_zoom()
	session.changed.connect(refresh); session.restored.connect(queue_free)
	_root.resized.connect(layout_canvas); layout_canvas(); refresh()

func layout_canvas() -> void:
	var scale_factor := minf(_root.size.x/1600.0,_root.size.y/900.0)
	canvas.scale = Vector2.ONE*scale_factor
	canvas.position = (_root.size-Vector2(1600,900)*scale_factor)/2.0

func text_at(value: String, pos: Vector2, area: Vector2, font: int) -> Label:
	var label := Label.new(); label.text = value; label.position = pos; label.size = area
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; label.add_theme_font_size_override("font_size",font)
	canvas.add_child(label); return label

func make_button(value: String, rect: Rect2, action: Callable, id: String) -> Button:
	var button := Button.new(); button.name = id; button.text = value; button.position = rect.position; button.size = rect.size
	button.add_theme_font_size_override("font_size",22); CounterTheme.style_paper_button(button)
	button.pressed.connect(action); canvas.add_child(button); return button

func plate(side: String, pos: Vector2) -> FanDeskObject:
	var object := FanDeskObject.new(); object.side = side; object.position = pos; object.size = Vector2(315,315)
	object.limits = Rect2(pos,object.size) # fixed plates, accurate normalized evidence coordinates
	object.selected.connect(point_selected); object.detail_requested.connect(func(_side: String, _point: Vector2) -> void: show_zoom())
	canvas.add_child(object); return object

func begin(index: int) -> void:
	_error = ""
	if index == 0: send("luxury_exterior",""); return
	tier = index+1; focus_index = 0
	send("luxury_begin",str(tier))

func select_detail(index: int) -> void:
	focus_index = index; _error = ""; refresh()

func point_selected(side: String, point: Vector2) -> void:
	var row := TieredAppraisal.stage(session._day.state,item_id,tier)
	if row.get("committed",false): refresh(); return
	send("luxury_mark",JSON.stringify({"tier":tier,"index":focus_index,"side":side,"point":[point.x,point.y]}))

func update_note_buttons() -> void:
	var row := TieredAppraisal.stage(session._day.state,item_id,tier)
	for button in note_buttons: button.disabled = row.is_empty() or row.get("committed",false) or object_plate.marker.x < 0 or reference_plate.marker.x < 0

func save_pair(note: String) -> void:
	var payload := {"tier":tier,"index":focus_index,"note":note,"object":[object_plate.marker.x,object_plate.marker.y],"reference":[reference_plate.marker.x,reference_plate.marker.y]}
	send("luxury_pair",JSON.stringify(payload))

func select_verdict(_index: int) -> void:
	send("luxury_select",JSON.stringify({"tier":tier,"identity":identity_keys[identity.selected],"condition":condition_keys[condition.selected]}))

func commit() -> void:
	send("luxury_seal",str(tier))

func send(command: String, detail: String) -> void:
	var result := session.fan_command(command,item_id,detail)
	_error = "" if result.ok else result.message
	refresh()

func refresh() -> void:
	if canvas == null: return
	var item := LuxuryAppraisalService.target(session._day,item_id)
	if item == null: queue_free(); return
	var state := session._day.state
	var definition := session._counter.catalog.get_definition("items",item.definition_id) as ItemDefinition
	var spec := TieredAppraisal.config(state,item)
	var book := LuxuryAppraisalService.info(state,item)
	var row := TieredAppraisal.stage(state,item_id,tier)
	var record := TieredAppraisal.record(state,item_id)
	var used: Array[String] = ["放大镜","灯"]
	if not String(spec.kit).is_empty(): used.append(TieredAppraisal.KITS[spec.kit].name)
	if tier == 3: used.append(TieredAppraisal.KITS[spec.deep_kit].name)
	tool_note.text = "器材："+"、".join(used) if not row.is_empty() else ""
	_title.text = definition.display_name+" · "+("器材鉴定" if tier == 2 else "深入查验")
	var visitor := CustomerManager.new().active(state)
	status_note.text = TimeController.clock_text(session.definition.opening_minute,state.game_minutes)+" · "+TieredAppraisal.exterior_text(state,item)
	if visitor != null and visitor.item == item: status_note.text += " · 客人最迟留到"+TimeController.clock_text(session.definition.opening_minute,visitor.expires_at)
	for index in 3:
		var command := "luxury_exterior" if index == 0 else "luxury_begin"
		var detail := "" if index == 0 else str(index+1)
		var why := TieredAppraisal.reason(session._day,command,item_id,detail)
		var cost := (0 if record.get("exterior",false) else 5) if index == 0 else TieredAppraisal.minutes(state,item_id,index+1)
		begin_buttons[index].text = ["检查外观","器材鉴定","深入查验"][index]+(" · %d分钟" % cost if cost > 0 else " · 免费复看")
		begin_buttons[index].disabled = not why.is_empty(); begin_buttons[index].tooltip_text = why
	object_plate.texture = TieredArt.plate(state,item,tier)
	reference_plate.texture = TieredArt.plate(state,item,tier,true)
	object_plate.mouse_filter = Control.MOUSE_FILTER_STOP if not row.is_empty() else Control.MOUSE_FILTER_IGNORE
	reference_plate.mouse_filter = object_plate.mouse_filter
	if row.is_empty():
		object_plate.texture = TieredArt.cell(spec.atlas,["intact","minor","major"].find(item.goods.precision.damage) if record.get("exterior",false) else 0,0)
		observation.text = "使用器材后，查验细节会摊在案上。"
		reference_text.text = TieredAppraisal.missing(session._day,item,tier)
	else:
		observation.text = "所见 · "+String(TieredAppraisal.observations(state,item,tier)[focus_index])
		reference_text.text = "图录 · "+String((spec.deep_references if tier == 3 else book.references)[focus_index])
	for index in 2:
		detail_buttons[index].text = ("一 · " if index == 0 else "二 · ")+String((spec.deep_checks if tier == 3 else book.checks)[index])
		detail_buttons[index].set_pressed_no_signal(index == focus_index)
	var pair: Dictionary = row.get("pairs",{}).get(str(focus_index),{})
	var marks: Dictionary = row.get("marks",{}).get(str(focus_index),{})
	for object in [object_plate,reference_plate]:
		var p: Array = marks.get(object.side,pair.get(object.side,[-1,-1])); object.set_marker(Vector2(p[0],p[1])); object.queue_redraw()
	for index in note_buttons.size(): note_buttons[index].set_pressed_no_signal(pair.get("note","") == TieredAppraisal.NOTES.keys()[index])
	update_note_buttons()
	identity.clear(); condition.clear()
	var ids := TieredAppraisal.identities(state,item); var conditions := TieredAppraisal.conditions()
	identity_keys = ids.keys(); condition_keys = conditions.keys()
	for key in ids: identity.add_item("身份 · "+ids[key])
	for key in conditions: condition.add_item("修配 · "+conditions[key])
	identity.select(identity_keys.find(row.get("identity","unsure")) if not String(row.get("identity","")).is_empty() else identity_keys.find("unsure"))
	condition.select(condition_keys.find(row.get("condition","unsure")) if not String(row.get("condition","")).is_empty() else condition_keys.find("unsure"))
	identity.disabled = row.is_empty() or row.get("committed",false); condition.disabled = identity.disabled
	var reason := TieredAppraisal.reason(session._day,"luxury_seal",item_id,str(tier))
	seal.disabled = not reason.is_empty()
	body.text = _error if not _error.is_empty() else "这份自鉴已落笔。可复看，或用新证据深入查验。" if row.get("committed",false) else reason if not reason.is_empty() else "确认后，这一级的判断不能改写。"
	if row.get("committed",false) and tier == 3 and _error.is_empty(): body.text = "这份自鉴已落笔，复看不耗时。举证谈价请回柜台。"
	if _error.is_empty() and not row.is_empty() and row.get("pairs",{}).is_empty(): body.text = "点击实物与图录的对应细节，再记下看法。右键或滚轮可放大。"

func build_zoom() -> void:
	zoom_layer = Control.new(); canvas.add_child(zoom_layer); zoom_layer.size = Vector2(1600,900)
	var panel := Panel.new(); panel.add_theme_stylebox_override("panel",CounterTheme.painted_paper()); zoom_layer.add_child(panel); panel.position = Vector2(80,80); panel.size = Vector2(1440,730)
	for index in 2:
		var texture := TextureRect.new(); texture.position = Vector2(120+index*710,150); texture.size = Vector2(650,570)
		texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED; zoom_layer.add_child(texture)
		if index == 0: zoom_object = texture
		else: zoom_reference = texture
	var close := Button.new(); close.text = "收起放大 · Esc"; close.position = Vector2(1240,90); close.size = Vector2(240,48); close.pressed.connect(zoom_layer.hide); zoom_layer.add_child(close)
	zoom_layer.hide()

func show_zoom() -> void:
	if TieredAppraisal.stage(session._day.state,item_id,tier).is_empty(): return
	zoom_object.texture = crop(object_plate.texture,object_plate.marker)
	zoom_reference.texture = crop(reference_plate.texture,reference_plate.marker)
	zoom_layer.show()

func crop(texture: Texture2D, point: Vector2) -> Texture2D:
	if texture == null or point.x < 0: return texture
	var result := AtlasTexture.new(); result.atlas = texture
	var size := texture.get_size(); var region_size := size*0.55
	result.region = Rect2((point*size-region_size/2).clamp(Vector2.ZERO,size-region_size),region_size)
	return result

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		if zoom_layer.visible: zoom_layer.hide()
		else: queue_free()
