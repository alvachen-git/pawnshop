class_name BangleDeskView
extends LuxuryAppraisalView

signal judgment_confirmed
const FIRE_DURATION := 3.0
var canvas: Control
var clock_note: Label
var finding: Label
var progress_note: Label
var selection_title: Label
var note_panel: Panel
var material_choice: OptionButton
var repair_choice: OptionButton
var seal_button: Button
var note_reason: Label

static func open_bangle(owner_view: Control, current: RunSession, id: String) -> BangleDeskView:
	var old := owner_view.get_tree().root.get_node_or_null("BangleDeskOverlay") as BangleDeskView
	if old != null: return old
	# Inventory/facility entry also pays through the existing transaction before opening the desk.
	if BangleAppraisal.row(current._day.state,id).is_empty():
		request_entry(owner_view,current,id)
		return null
	var view := BangleDeskView.new(); view.name = "BangleDeskOverlay"; view.session = current; view.item_id = id
	var parent: Node = owner_view
	while parent != null:
		if parent.has_method("_close_drawer"):
			view.judgment_confirmed.connect(Callable(parent,"_close_drawer")); break
		parent = parent.get_parent()
	owner_view.get_tree().root.add_child(view); owner_view.tree_exiting.connect(view.queue_free,CONNECT_ONE_SHOT)
	return view

static func request_entry(owner_view: Control, current: RunSession, id: String) -> void:
	if owner_view.get_tree().root.has_node("BangleEntry"): return
	var dialog := ConfirmationDialog.new(); dialog.name = "BangleEntry"; dialog.title = "器材鉴定"
	dialog.theme = CounterTheme.build(); dialog.ok_button_text = "开始查验 · 10分钟"; dialog.cancel_button_text = "返回"
	var why := BangleAppraisal.reason(current._day,"luxury_begin",id,"2")
	dialog.dialog_text = why if not why.is_empty() else "将金镯放上衡具，称重、看戳记与火试。\n首次查验耗10分钟，称重、火试与复看不耗时。"
	dialog.get_ok_button().disabled = not why.is_empty()
	owner_view.get_tree().root.add_child(dialog); dialog.popup_centered(Vector2i(620,230))
	dialog.confirmed.connect(func() -> void:
		var result := current.fan_command("luxury_begin",id,"2")
		if result.ok:
			dialog.queue_free(); open_bangle(owner_view,current,id)
		else:
			dialog.dialog_text = result.message; dialog.popup_centered(Vector2i(620,230)))
	dialog.canceled.connect(dialog.queue_free); owner_view.tree_exiting.connect(dialog.queue_free,CONNECT_ONE_SHOT)

var balance: BangleBalance
var whole: TextureRect
var before_image: TextureRect
var after_image: TextureRect
var grams_note: Label
var location_note: Label
var fire_button: Button
var fire_seconds := 0.0
var lamp:Polygon2D
var zoom_panel: Panel
var zoom_image: TextureRect

func _ready() -> void:
	layer = 90
	_root = Control.new(); add_child(_root); _root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shade := ColorRect.new(); shade.color = Color("110e0c"); _root.add_child(shade); shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	canvas = Control.new(); canvas.theme = CounterTheme.build(); canvas.size = Vector2(1600,900); _root.add_child(canvas)
	texture(load("res://assets/watch_desk/workbench.png"),Rect2(0,0,1600,900))
	for rect in [Rect2(40,160,470,505),Rect2(530,160,420,505),Rect2(970,160,590,505)]:
		var panel := Panel.new(); panel.position=rect.position; panel.size=rect.size; panel.add_theme_stylebox_override("panel",CounterTheme.painted_paper()); canvas.add_child(panel)
	label("老凤祥花雕金镯",Rect2(45,28,800,52),34)
	clock_note = label("",Rect2(45,90,1220,40),21)
	button("返回柜台",Rect2(1370,35,180,50),close_desk,"close")
	label("一 · 称重对款",Rect2(70,181,400,40),27,true)
	balance = BangleBalance.new(); balance.position=Vector2(68,244); balance.size=Vector2(412,272); canvas.add_child(balance)
	grams_note=label("",Rect2(70,538,407,80),24,true)
	label("图录 · 同款足色样品30—32克",Rect2(70,614,425,34),21,true)
	label("二 · 转看实物",Rect2(560,181,355,40),27,true)
	whole=texture(BangleArt.exterior(["intact","minor","major"].find(item().goods.precision.damage)),Rect2(552,270,376,310)); whole.material=BangleArt.cutout()
	whole.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	label("称重相符，仍须看戳记与局部。",Rect2(555,600,365,52),21,true)
	location_note=label("",Rect2(1000,182,525,40),27,true)
	before_image=texture(null,Rect2(995,268,255,255)); after_image=texture(null,Rect2(1270,268,255,255))
	label("火试前",Rect2(1080,232,130,35),20,true)
	selection_title=label("当前所见",Rect2(1330,232,185,35),20,true)
	finding=label("",Rect2(1000,545,520,108),22,true)
	for i in BangleAppraisal.DENOMINATIONS.size():
		var grams: int=BangleAppraisal.DENOMINATIONS[i]; var x:=45+i*92
		button("+%d克" % grams,Rect2(x,720,85,43),weight.bind(grams,1),"add_"+str(grams))
		button("−%d克" % grams,Rect2(x,772,85,43),weight.bind(grams,-1),"remove_"+str(grams))
	button("放上金镯",Rect2(45,671,215,42),func() -> void: act({"op":"place"}),"place")
	button("清空砝码",Rect2(275,671,225,42),func() -> void: act({"op":"clear"}),"clear")
	for i in BangleAppraisal.PARTS.size():
		var part: String=BangleAppraisal.PARTS[i]
		button(BangleAppraisal.LABELS[part],Rect2(540+i*101,678,96,44),select_part.bind(part),"part_"+part)
	button("向左转",Rect2(540,735,192,46),turn.bind(-1),"turn_left")
	button("向右转",Rect2(747,735,192,46),turn.bind(1),"turn_right")
	button("放大细看",Rect2(540,797,399,45),magnify,"view")
	fire_button=button("开始火试",Rect2(980,678,270,48),start_fire,"fire")
	button("收火冷却",Rect2(1270,678,270,48),stop_fire,"stop_fire")
	button("擦去烟污",Rect2(980,740,560,48),func() -> void: act({"op":"wipe"}),"wipe")
	button("查看指南",Rect2(980,807,270,54),func() -> void: BangleGuideView.open(canvas,session),"guide")
	button("记下判断",Rect2(1270,807,270,54),show_notes,"notes",true)
	progress_note=label("",Rect2(45,846,895,32),19)
	lamp=BangleArt.prop("lamp");lamp.position=Vector2(1495,520);lamp.scale=Vector2.ONE*.24;canvas.add_child(lamp);lamp.hide()
	build_notes(); build_zoom(); session.changed.connect(refresh); session.restored.connect(queue_free)
	_root.resized.connect(layout_canvas); layout_canvas(); refresh()

func item() -> ItemInstance:
	return LuxuryAppraisalService.target(session._day,item_id)

func data() -> Dictionary:
	return BangleAppraisal.row(session._day.state,item_id)

func act(payload: Dictionary) -> bool:
	var result:=session.fan_command("luxury_bangle",item_id,JSON.stringify(payload))
	_error="" if result.ok else result.message
	refresh(); return result.ok

func weight(grams: int, direction: int) -> void:
	act({"op":"weight","grams":grams,"direction":direction})

func select_part(part: String) -> void:
	act({"op":"select","part":part})

func turn(direction: int) -> void:
	act({"op":"turn","angle":posmod(int(data().angle)+direction,3)})

func start_fire() -> void:
	if act({"op":"fire_start"}): fire_seconds=0.0

func stop_fire() -> void:
	if act({"op":"fire_stop"}): fire_seconds=0.0

func magnify() -> void:
	if act({"op":"view"}): zoom_panel.show(); refresh()

func close_desk() -> void:
	if not data().active.is_empty() and not act({"op":"fire_stop"}): return
	queue_free()

func _process(delta: float) -> void:
	if canvas==null or item()==null or data().is_empty(): return
	if not data().active.is_empty():
		fire_seconds+=delta
		if fire_seconds>=FIRE_DURATION:
			fire_seconds=0.0
			if not act({"op":"fire_finish"}): return
		else:
			fire_button.text="火试中 · %.1f秒" % fire_seconds
			lamp.modulate=Color(1.0,1.0,.85+sin(fire_seconds*12.0)*.10)
			(after_image.material as ShaderMaterial).set_shader_parameter("heat",sin(fire_seconds*5.0)*.2+.3)

func refresh() -> void:
	if canvas==null: return
	if item()==null: queue_free(); return
	var d:=data(); var current:=item(); var active: bool=not d.active.is_empty()
	balance.weights=d.weights.duplicate(); balance.grams=BangleAppraisal.total(d); balance.placed=d.placed; balance.weight=int(current.goods.bangle_value.weight); balance.queue_redraw()
	grams_note.text="砝码合计 %d克\n" % BangleAppraisal.total(d)+("天平平衡" if d.placed and BangleAppraisal.total(d)==int(current.goods.bangle_value.weight) else "镯盘偏低" if d.placed and BangleAppraisal.total(d)<int(current.goods.bangle_value.weight) else "砝码盘偏低" if BangleAppraisal.total(d)>0 else "请放上金镯与砝码")
	(canvas.find_child("place",true,false) as Button).text="取下金镯" if d.placed else "放上金镯"
	location_note.text="三 · "+BangleAppraisal.LABELS[d.part]+" · "+["正看","向左转","向右转"][int(d.angle)]
	whole.rotation=deg_to_rad([0,7,-7][int(d.angle)]); whole.pivot_offset=whole.size/2
	lamp.visible=active
	var seen:=BangleAppraisal.visible_detail(current,d)
	var finished: bool=d.part in d.finished; var wiped: bool=d.part in d.wiped
	before_image.texture=BangleArt.detail(current,d,false)
	after_image.texture=BangleArt.detail(current,d,finished)
	before_image.material=BangleArt.surface(0.0,0.0,int(d.angle))
	after_image.material=BangleArt.surface(.78 if finished and not wiped else 0.0,0.0,int(d.angle))
	selection_title.text="擦拭后" if wiped else "冷却后" if finished else "当前所见"
	var description: String="转动金镯，放大看细节，再选一处火试。"
	if not seen: description="这一角度看不清交界，转到另一侧再放大。"
	elif finished and not wiped: description="表面有烟污，冷却后擦去，再与火试前比较。"
	elif d.part=="joint": description="接合处花纹有中断，一线焊色越过旧纹。" if current.goods.bangle_value.repair=="altered" else "接缝细直，两侧花纹衔接，可再与图录合看。"
	elif wiped: description={"fine":"擦拭后色泽连贯，仍需合看重量与戳记。","lower":"烟污已去，凹处仍留斑色；须和重量、戳记合看。","plated":"已有磨处可见薄层边缘，下方露出另一层底色。"}[current.goods.bangle_value.material]
	elif d.part=="stamp": description="留意框内笔画、收笔和排列，再对照指南。"
	finding.text=_error if not _error.is_empty() else description
	clock_note.text=TimeController.clock_text(session.definition.opening_minute,session._day.state.game_minutes)+" · "+TieredAppraisal.exterior_text(session._day.state,current)
	var visitor:=CustomerManager.new().active(session._day.state)
	if visitor!=null and visitor.item.instance_id==item_id: clock_note.text+=" · 客人等到"+TimeController.clock_text(session.definition.opening_minute,visitor.expires_at)
	progress_note.text=("已称得%d克 · " % d.measured if d.weighed else "尚未称定 · ")+"已火试%d处 · " % d.finished.size()+("手记已落笔" if TieredAppraisal.stage(session._day.state,item_id,2).committed else "可随时记下判断")
	fire_button.text="火试中" if active else "复看火试" if finished else "开始火试 · %d秒" % int(FIRE_DURATION)
	for child in canvas.get_children():
		if child is Button: child.disabled=active and child.name not in ["stop_fire","close"]
	fire_button.disabled=active or d.part=="stamp"
	(canvas.find_child("stop_fire",true,false) as Button).disabled=not active
	(canvas.find_child("wipe",true,false) as Button).disabled=active or not finished
	if note_panel.visible: refresh_notes()
	if zoom_panel.visible:
		zoom_image.texture=after_image.texture; zoom_image.material=after_image.material

func build_zoom() -> void:
	zoom_panel=Panel.new(); zoom_panel.position=Vector2(420,105); zoom_panel.size=Vector2(760,690)
	zoom_panel.add_theme_stylebox_override("panel",CounterTheme.painted_paper()); canvas.add_child(zoom_panel)
	zoom_image=texture(null,Rect2(0,0,560,540)); zoom_image.reparent(zoom_panel); zoom_image.position=Vector2(100,55)
	var back:=button("收起放大",Rect2(0,0,230,48),zoom_panel.hide,"close_zoom"); back.reparent(zoom_panel); back.position=Vector2(490,622)
	zoom_panel.hide()

func build_notes() -> void:
	note_panel = Panel.new(); note_panel.name = "bangle_notes"; note_panel.position = Vector2(325,190); note_panel.size = Vector2(950,500)
	note_panel.add_theme_stylebox_override("panel",CounterTheme.painted_paper()); canvas.add_child(note_panel)
	var title := Label.new(); title.text = "验金手记"; title.position = Vector2(40,28); title.add_theme_font_size_override("font_size",30); note_panel.add_child(title)
	for i in 2:
		var label_node := Label.new(); label_node.text = "金料判断" if i==0 else "修补情况"; label_node.position=Vector2(40,110+i*90); note_panel.add_child(label_node)
		var choice := OptionButton.new(); choice.position=Vector2(165,100+i*90); choice.size=Vector2(735,60); choice.add_item("暂难判断"); choice.set_item_metadata(0,"unsure")
		for key in BangleNegotiation.OPTIONS["material" if i==0 else "repair"]:
			choice.add_item(BangleNegotiation.OPTIONS["material" if i==0 else "repair"][key]); choice.set_item_metadata(choice.item_count-1,key)
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
		elif zoom_panel.visible: zoom_panel.hide()
		else: close_desk()

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
