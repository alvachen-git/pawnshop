class_name PearlDeskView
extends LuxuryAppraisalView

signal judgment_confirmed
var canvas: Control
var clock_note: Label
var finding: Label
var progress_note: Label
var selection_title: Label
var comparison_title: Label
var pearl_image: TextureRect
var compare_image: TextureRect
var bead_buttons: Array[TextureButton] = []
var selection_ring: Line2D
var note_panel: Panel
var material_choice: OptionButton
var repair_choice: OptionButton
var seal_button: Button
var note_reason: Label
var controls: Array[Button] = []
var pin := -1
var hole_view := false
var zoomed := false
var dragging := false
var drag_start := 0.0

static func open_pearl(owner_view: Control, current: RunSession, id: String) -> PearlDeskView:
	var old := owner_view.get_tree().root.get_node_or_null("PearlDeskOverlay") as PearlDeskView
	if old != null: return old
	# Inventory/facility entry also pays through the existing transaction before opening the desk.
	if PearlAppraisal.row(current._day.state,id).is_empty():
		request_entry(owner_view,current,id)
		return null
	var view := PearlDeskView.new(); view.name = "PearlDeskOverlay"; view.session = current; view.item_id = id
	var parent: Node = owner_view
	while parent != null:
		if parent.has_method("_close_drawer"):
			view.judgment_confirmed.connect(Callable(parent,"_close_drawer")); break
		parent = parent.get_parent()
	owner_view.get_tree().root.add_child(view); owner_view.tree_exiting.connect(view.queue_free,CONNECT_ONE_SHOT)
	return view

static func request_entry(owner_view: Control, current: RunSession, id: String) -> void:
	if owner_view.get_tree().root.has_node("PearlEntry"): return
	var dialog := ConfirmationDialog.new(); dialog.name = "PearlEntry"; dialog.title = "器材鉴定"
	dialog.theme = CounterTheme.build(); dialog.ok_button_text = "开始查验 · 10分钟"; dialog.cancel_button_text = "返回"
	var why := PearlAppraisal.reason(current._day,"luxury_begin",id,"2")
	dialog.dialog_text = why if not why.is_empty() else "将珠串放上托具，用灯与放大镜逐粒查看。\n首次查验耗10分钟，转珠、比较与复看不耗时。"
	dialog.get_ok_button().disabled = not why.is_empty()
	owner_view.get_tree().root.add_child(dialog); dialog.popup_centered(Vector2i(620,230))
	dialog.confirmed.connect(func() -> void:
		var result := current.fan_command("luxury_begin",id,"2")
		if result.ok:
			dialog.queue_free(); open_pearl(owner_view,current,id)
		else:
			dialog.dialog_text = result.message; dialog.popup_centered(Vector2i(620,230)))
	dialog.canceled.connect(dialog.queue_free); owner_view.tree_exiting.connect(dialog.queue_free,CONNECT_ONE_SHOT)

func _ready() -> void:
	layer = 90
	_root = Control.new(); add_child(_root); _root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shade := ColorRect.new(); shade.color = Color("110e0c"); _root.add_child(shade); shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	canvas = Control.new(); canvas.theme = CounterTheme.build(); canvas.size = Vector2(1600,900); _root.add_child(canvas)
	texture(load("res://assets/watch_desk/workbench.png"),Rect2(0,0,1600,900))
	texture(load("res://assets/pearl_desk/velvet.png"),Rect2(800,172,750,493))
	label("灯下验珠",Rect2(45,32,620,50),34)
	clock_note = label("",Rect2(45,90,970,34),21)
	button("返回柜台",Rect2(1370,35,180,50),queue_free,"close")
	label("逐粒对照",Rect2(70,170,590,44),30,true)
	label("转珠看表层，再放大孔口。差异须连着看。",Rect2(70,222,655,50),22,true)
	selection_title = label("",Rect2(85,290,300,38),22,true)
	comparison_title = label("图录 · 正常珠",Rect2(420,290,310,38),22,true)
	pearl_image = texture(null,Rect2(105,320,260,260)); pearl_image.name = "SelectedPearl"
	compare_image = texture(null,Rect2(440,320,260,260)); compare_image.name = "ComparisonPearl"
	pearl_image.mouse_filter = Control.MOUSE_FILTER_STOP; pearl_image.gui_input.connect(drag_pearl)
	finding = label("",Rect2(80,605,635,63),21,true)
	progress_note = label("",Rect2(850,670,650,42),20)
	var strand := Line2D.new(); strand.width = 2; strand.default_color = Color("c9bea0"); canvas.add_child(strand)
	var damaged: String = item().goods.precision.damage
	for step in 129:
		var theta := PI+.16+(TAU-.32)*step/128.0 if damaged=="major" else TAU*step/128.0
		strand.add_point(Vector2(1175,410)+Vector2(sin(theta)*292,cos(theta)*185))
	var clasp := Line2D.new(); clasp.width = 5; clasp.default_color = Color("bca265"); canvas.add_child(clasp)
	for step in 33:
		var theta := (TAU*.7 if damaged=="major" else TAU)*step/32.0
		clasp.add_point(Vector2(1204,226)+Vector2(sin(theta)*(16 if damaged=="minor" else 12),cos(theta)*(3 if damaged=="minor" else 6)))
	for i in 32:
		var angle := PI+TAU*float(i)/32.0
		var bead := TextureButton.new(); bead.name = "Pearl_%02d" % i; bead.texture_normal = PearlArt.cell("fine",0)
		bead.ignore_texture_size = true; bead.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		var weight: int = item().goods.pearl_value.beads[i].weight
		var width := 32.0+weight*6.0
		bead.size = Vector2.ONE*width; bead.position = Vector2(1175,410)+Vector2(sin(angle)*292,cos(angle)*185)-bead.size/2
		bead.material = PearlArt.material(); bead.tooltip_text = "查看这颗珠子"
		bead.pressed.connect(select_bead.bind(i)); canvas.add_child(bead); bead_buttons.append(bead)
	selection_ring = Line2D.new(); selection_ring.width = 2; selection_ring.default_color = Color("eed295"); canvas.add_child(selection_ring)
	controls.append(button("向左转",Rect2(75,735,145,48),turn.bind(-1),"turn_left"))
	controls.append(button("向右转",Rect2(230,735,145,48),turn.bind(1),"turn_right"))
	controls.append(button("放大孔口",Rect2(390,735,170,48),show_hole,"hole"))
	controls.append(button("并排比较",Rect2(570,735,175,48),choose_pair,"compare"))
	controls.append(button("左侧光",Rect2(75,798,145,45),light.bind("left"),"light_left"))
	controls.append(button("正面光",Rect2(230,798,145,45),light.bind("front"),"light_front"))
	controls.append(button("右侧光",Rect2(390,798,170,45),light.bind("right"),"light_right"))
	controls.append(button("放大 / 还原",Rect2(570,798,175,45),toggle_zoom,"zoom"))
	button("查看指南",Rect2(850,735,290,60),func() -> void: PearlGuideView.open(canvas,session),"guide")
	controls.append(button("记下判断",Rect2(1190,735,310,60),show_notes,"notes",true))
	label("点选珠子 · 拖动转珠 · 复看不耗时",Rect2(925,815,570,35),20)
	build_notes(); session.changed.connect(refresh); session.restored.connect(queue_free)
	_root.resized.connect(layout_canvas); layout_canvas(); refresh()

func item() -> ItemInstance:
	return LuxuryAppraisalService.target(session._day,item_id)

func data() -> Dictionary:
	return PearlAppraisal.row(session._day.state,item_id)

func act(payload: Dictionary) -> bool:
	var result := session.fan_command("luxury_pearl",item_id,JSON.stringify(payload)); _error = "" if result.ok else result.message
	refresh(); return result.ok

func select_bead(index: int) -> void:
	var d := data()
	var angle := int(d.get("angles",{}).get(str(d.get("selected",0)),0))
	act({"op":"select","index":index,"angle":angle,"hole":hole_view})

func turn(direction: int) -> void:
	var d := data(); var i: int = d.get("selected",0)
	act({"op":"turn","index":i,"angle":posmod(int(d.get("angles",{}).get(str(i),0))+direction,3)})

func light(value: String) -> void:
	act({"op":"light","index":data().get("selected",0),"light":value})

func show_hole() -> void:
	if hole_view: hole_view = false; refresh(); return
	if act({"op":"hole","index":data().get("selected",0)}): hole_view = true; refresh()

func choose_pair() -> void:
	var index: int = data().get("selected",0)
	if pin < 0 or pin == index:
		pin = index; _error = "已留住这颗，再选另一颗后点并排比较。"; refresh(); return
	act({"op":"compare","index":index,"other":pin}); pin = -1

func toggle_zoom() -> void:
	zoomed = not zoomed; refresh()

func drag_pearl(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed: dragging = true; drag_start = event.position.x
		elif dragging:
			dragging = false
			if absf(event.position.x-drag_start)>20: turn(1 if event.position.x>drag_start else -1)
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT: toggle_zoom()

func refresh() -> void:
	if canvas == null: return
	var current := item()
	if current == null: queue_free(); return
	var d := data(); var paid := not d.is_empty(); var index: int = d.get("selected",0)
	var bead: Dictionary = current.goods.pearl_value.beads[index]; var angle: int = d.get("angles",{}).get(str(index),0)
	var hidden: bool = current.goods.precision.hidden
	var visible_hole := hole_view and (not hidden or angle == int(bead.hole_angle))
	pearl_image.texture = PearlArt.cell(bead.quality if paid else "fine",angle+int(bead.texture),visible_hole)
	pearl_image.material = PearlArt.material(d.get("light","front"),int(bead.tint))
	pearl_image.scale = Vector2.ONE*(1.15 if zoomed else 1.0); pearl_image.pivot_offset = pearl_image.size/2
	var other: int = d.get("compare",-1)
	var comparison: Dictionary = current.goods.pearl_value.beads[other] if other >= 0 else {"quality":"fine","texture":0,"tint":2}
	compare_image.texture = PearlArt.cell(comparison.quality,angle+int(comparison.texture),hole_view if other < 0 else hole_view and (not hidden or angle == int(comparison.hole_angle)))
	compare_image.material = PearlArt.material(d.get("light","front"),int(comparison.tint))
	selection_title.text = "实物 · 第%d颗" % (index+1); comparison_title.text = "实物 · 第%d颗" % (other+1) if other>=0 else "图录 · 正常珠"
	finding.text = _error if not _error.is_empty() else PearlAppraisal.observation(bead,angle,hole_view,hidden) if paid else TieredAppraisal.reason(session._day,"luxury_begin",item_id,"2")
	if not paid and finding.text.is_empty(): finding.text = "开始器材鉴定后，可以选珠、转珠与比较。"
	(canvas.find_child("hole",true,false) as Button).text = "返回表层" if hole_view else "放大孔口"
	for side in ["left","front","right"]:
		(canvas.find_child("light_"+side,true,false) as Button).set_pressed_no_signal(d.get("light","front")==side)
	(canvas.find_child("hole",true,false) as Button).set_pressed_no_signal(hole_view)
	(canvas.find_child("zoom",true,false) as Button).set_pressed_no_signal(zoomed)
	selection_ring.clear_points(); selection_ring.visible = paid
	var chosen := bead_buttons[index]
	for step in 49: selection_ring.add_point(chosen.position+chosen.size/2+Vector2.from_angle(TAU*step/48.0)*(chosen.size.x*.43+4))
	for b in controls: b.disabled = not paid
	for i in bead_buttons.size():
		bead_buttons[i].disabled = not paid
		bead_buttons[i].self_modulate = Color("ffe6ad") if i == index and paid else Color.WHITE
	clock_note.text = TimeController.clock_text(session.definition.opening_minute,session._day.state.game_minutes)+" · "+TieredAppraisal.exterior_text(session._day.state,current)
	var visitor := CustomerManager.new().active(session._day.state)
	if visitor != null and visitor.item.instance_id == item_id: clock_note.text += " · 客人等到"+TimeController.clock_text(session.definition.opening_minute,visitor.expires_at)
	progress_note.text = "已查看 %d 处孔口 · 比较 %d 组 · %s" % [d.get("holes",[]).size(),d.get("pairs",[]).size(),"手记已落笔" if TieredAppraisal.stage(session._day.state,item_id,2).get("committed",false) else "可随时记下判断"]
	if note_panel.visible: refresh_notes()

func build_notes() -> void:
	note_panel = Panel.new(); note_panel.name = "pearl_notes"; note_panel.position = Vector2(325,190); note_panel.size = Vector2(950,500)
	note_panel.add_theme_stylebox_override("panel",CounterTheme.painted_paper()); canvas.add_child(note_panel)
	var title := Label.new(); title.text = "验珠手记"; title.position = Vector2(40,28); title.add_theme_font_size_override("font_size",30); note_panel.add_child(title)
	for i in 2:
		var label_node := Label.new(); label_node.text = "仿珠情况" if i==0 else "真珠品质"; label_node.position=Vector2(40,110+i*90); note_panel.add_child(label_node)
		var choice := OptionButton.new(); choice.position=Vector2(165,100+i*90); choice.size=Vector2(735,60); choice.add_item("暂难判断"); choice.set_item_metadata(0,"unsure")
		for key in PearlNegotiation.OPTIONS["material" if i==0 else "repair"]:
			choice.add_item(PearlNegotiation.OPTIONS["material" if i==0 else "repair"][key]); choice.set_item_metadata(choice.item_count-1,key)
		note_panel.add_child(choice); choice.item_selected.connect(save_draft)
		if i==0: material_choice=choice
		else: repair_choice=choice
	note_reason=Label.new(); note_reason.position=Vector2(40,292); note_reason.size=Vector2(855,90); note_reason.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; note_reason.add_theme_font_size_override("font_size",22); note_panel.add_child(note_reason)
	seal_button=button("确认落笔",Rect2(0,0,260,60),seal,"seal",true); seal_button.reparent(note_panel); seal_button.position=Vector2(630,403)
	var back:=button("继续查验",Rect2(0,0,235,60),note_panel.hide,"close_notes"); back.reparent(note_panel); back.position=Vector2(40,403)
	note_panel.hide()

func show_notes() -> void:
	note_panel.show(); refresh_notes()

func refresh_notes() -> void:
	var d:=data(); var sealed: bool=TieredAppraisal.stage(session._day.state,item_id,2).get("committed",false)
	for pair in [[material_choice,"material"],[repair_choice,"repair"]]:
		var choice: OptionButton=pair[0]; choice.disabled=sealed
		for i in choice.item_count:
			if choice.get_item_metadata(i)==d.get(pair[1],"unsure"): choice.select(i)
	seal_button.disabled=sealed or d.is_empty()
	note_reason.text=_error if not _error.is_empty() else "手记已落笔，可复看。" if sealed else "未查完也能落笔，拿不准的保留暂难判断。\n这里只记自己的看法；回柜台可另选说法谈价。"

func save_draft(_index: int) -> void:
	act({"op":"draft","material":material_choice.get_selected_metadata(),"repair":repair_choice.get_selected_metadata()})

func seal() -> void:
	if act({"op":"seal"}): judgment_confirmed.emit(); queue_free()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		if note_panel.visible: note_panel.hide()
		else: queue_free()

func layout_canvas() -> void:
	var factor := minf(_root.size.x/1600.0,_root.size.y/900.0)
	canvas.scale = Vector2.ONE*factor; canvas.position = (_root.size-Vector2(1600,900)*factor)/2

func label(value: String, rect: Rect2, font: int, ink := false) -> Label:
	var result := Label.new(); result.text = value; result.position = rect.position; result.size = rect.size
	result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	result.add_theme_color_override("font_color",Color("392919") if ink else Color("f1ddb2"))
	result.add_theme_font_override("font",CounterTheme.display_font()); result.add_theme_font_size_override("font_size",font)
	if not ink:
		result.add_theme_color_override("font_shadow_color",Color("160d07")); result.add_theme_constant_override("shadow_offset_x",1); result.add_theme_constant_override("shadow_offset_y",2)
	canvas.add_child(result); return result

func texture(value: Texture2D, rect: Rect2) -> TextureRect:
	var result := TextureRect.new(); result.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	result.texture = value; result.position = rect.position; result.size = rect.size
	result.stretch_mode = TextureRect.STRETCH_SCALE; result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(result); return result

func button(value: String, rect: Rect2, action: Callable, key_name: String, primary := false) -> Button:
	var result := Button.new(); result.name = key_name; result.text = value; result.position = rect.position; result.size = rect.size
	result.toggle_mode = key_name in ["light_left","light_front","light_right","hole","zoom"]
	result.add_theme_font_override("font",CounterTheme.display_font()); result.add_theme_font_size_override("font_size",24 if primary else 22)
	for state in ["normal","hover","pressed","disabled"]:
		var style := StyleBoxTexture.new(); style.texture = WatchArt.plaque(primary)
		style.modulate_color = Color.WHITE
		if state == "hover": style.modulate_color = style.modulate_color.lightened(.2)
		if state == "pressed" and result.toggle_mode: style.modulate_color = Color("e7bb75")
		if state == "disabled": style.modulate_color = Color("655f55")
		for side in [SIDE_LEFT,SIDE_TOP,SIDE_RIGHT,SIDE_BOTTOM]:
			style.set_texture_margin(side,0); style.set_content_margin(side,5)
		style.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
		result.add_theme_stylebox_override(state,style)
		result.add_theme_color_override("font_color" if state == "normal" else "font_"+state+"_color",Color("f4e0b9") if state != "disabled" else Color("aca18b"))
	result.pressed.connect(action); canvas.add_child(result); return result

