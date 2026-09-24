class_name PorcelainDeskView
extends LuxuryAppraisalView

signal judgment_confirmed
var canvas: Control
var clock_note: Label
var finding: Label
var progress_note: Label
var selection_title: Label
var note_panel: Panel
var era_choice: OptionButton
var craft_choice: OptionButton
var seal_button: Button
var note_reason: Label

static func open_porcelain(owner_view: Control, current: RunSession, id: String) -> PorcelainDeskView:
	var old := owner_view.get_tree().root.get_node_or_null("PorcelainDeskOverlay") as PorcelainDeskView
	if old != null: return old
	# Inventory/facility entry also pays through the existing transaction before opening the desk.
	if PorcelainAppraisal.row(current._day.state,id).is_empty():
		request_entry(owner_view,current,id)
		return null
	var view := PorcelainDeskView.new(); view.name = "PorcelainDeskOverlay"; view.session = current; view.item_id = id
	var parent: Node = owner_view
	while parent != null:
		if parent.has_method("_close_drawer"):
			view.judgment_confirmed.connect(Callable(parent,"_close_drawer")); break
		parent = parent.get_parent()
	owner_view.get_tree().root.add_child(view); owner_view.tree_exiting.connect(view.queue_free,CONNECT_ONE_SHOT)
	return view

static func request_entry(owner_view: Control, current: RunSession, id: String) -> void:
	if owner_view.get_tree().root.has_node("PorcelainEntry"): return
	var dialog := ConfirmationDialog.new(); dialog.name = "PorcelainEntry"; dialog.title = "器材鉴定"
	dialog.theme = CounterTheme.build(); dialog.ok_button_text = "开始查验 · 10分钟"; dialog.cancel_button_text = "返回"
	var why := PorcelainAppraisal.reason(current._day,"luxury_begin",id,"2")
	dialog.dialog_text = why if not why.is_empty() else "将青花瓶放在案上，转看整器、绘纹与底足。\n首次查验耗10分钟，转看、比对与复看不耗时。"
	dialog.get_ok_button().disabled = not why.is_empty()
	owner_view.get_tree().root.add_child(dialog); dialog.popup_centered(Vector2i(620,230))
	dialog.confirmed.connect(func() -> void:
		var result := current.fan_command("luxury_begin",id,"2")
		if result.ok:
			dialog.queue_free(); open_porcelain(owner_view,current,id)
		else:
			dialog.dialog_text = result.message; dialog.popup_centered(Vector2i(620,230)))
	dialog.canceled.connect(dialog.queue_free); owner_view.tree_exiting.connect(dialog.queue_free,CONNECT_ONE_SHOT)

var object_image: TextureRect
var reference_image: TextureRect
var object_frame: Control
var reference_frame: Control
var reference_title: Label
var reference_hint: Label
var reference_choice: OptionButton

func _ready() -> void:
	layer = 90
	_root = Control.new(); add_child(_root); _root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shade := ColorRect.new(); shade.color=Color("110e0c");_root.add_child(shade);shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	canvas=Control.new();canvas.theme=CounterTheme.build();canvas.size=Vector2(1600,900);_root.add_child(canvas)
	texture(load("res://assets/watch_desk/workbench.png"),Rect2(0,0,1600,900))
	label("青花玉壶春瓶",Rect2(48,24,800,54),36)
	clock_note=label("",Rect2(48,88,1230,36),21)
	button("返回柜台",Rect2(1370,30,180,52),close_desk,"close")
	for rect in [Rect2(40,150,735,510),Rect2(795,150,765,510)]:
		var paper:=Panel.new();paper.position=rect.position;paper.size=rect.size;paper.add_theme_stylebox_override("panel",CounterTheme.painted_paper());canvas.add_child(paper)
	selection_title=label("",Rect2(72,169,650,40),27,true)
	object_frame=Control.new();object_frame.position=Vector2(92,216);object_frame.size=Vector2(630,385);object_frame.clip_contents=true;canvas.add_child(object_frame)
	object_image=texture(null,Rect2(0,0,630,385));object_image.reparent(object_frame);object_image.position=Vector2.ZERO;object_image.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	reference_title=label("图录",Rect2(830,169,140,38),27,true)
	reference_choice=OptionButton.new();reference_choice.position=Vector2(970,166);reference_choice.size=Vector2(320,44);canvas.add_child(reference_choice)
	for age in PorcelainEconomy.BASE:
		reference_choice.add_item(PorcelainNegotiation.OPTIONS.era[age]+" · 参考");reference_choice.set_item_metadata(reference_choice.item_count-1,age)
	reference_choice.item_selected.connect(func(_index:int)->void:act({"op":"reference","era":reference_choice.get_selected_metadata()}))
	button("换例图",Rect2(1310,166,205,44),func()->void:act({"op":"sample","sample":1-int(data().sample)}),"sample")
	reference_frame=Control.new();reference_frame.position=Vector2(860,222);reference_frame.size=Vector2(630,330);reference_frame.clip_contents=true;canvas.add_child(reference_frame)
	reference_image=texture(null,Rect2(0,0,630,330));reference_image.reparent(reference_frame);reference_image.position=Vector2.ZERO;reference_image.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	reference_hint=label("",Rect2(835,564,685,82),22,true)
	finding=label("",Rect2(74,605,650,44),21,true)
	for i in 3:
		var group:String=PorcelainAppraisal.GROUPS[i]
		button(PorcelainAppraisal.LABELS[group],Rect2(45+i*241,686,229,49),func()->void:act({"op":"group","group":group}),"group_"+group)
	button("向左转",Rect2(45,752,174,49),turn.bind(-1),"left")
	button("向右转",Rect2(230,752,174,49),turn.bind(1),"right")
	button("翻看底部",Rect2(415,752,174,49),flip,"flip")
	button("放大",Rect2(600,752,163,49),func()->void:act({"op":"zoom","zoom":not data().zoom}),"zoom")
	button("查看图录",Rect2(810,708,350,70),func()->void:PorcelainGuideView.open(canvas,session),"guide")
	button("记下判断",Rect2(1190,708,350,70),show_notes,"notes",true)
	progress_note=label("",Rect2(48,838,1450,36),21)
	build_notes();session.changed.connect(refresh);session.restored.connect(queue_free)
	_root.resized.connect(layout_canvas);layout_canvas();refresh()

func item() -> ItemInstance:
	return LuxuryAppraisalService.target(session._day,item_id)

func data() -> Dictionary:
	return PorcelainAppraisal.row(session._day.state,item_id)

func act(payload: Dictionary) -> bool:
	var result:=session.fan_command("luxury_porcelain",item_id,JSON.stringify(payload))
	_error="" if result.ok else result.message
	refresh();return result.ok

func turn(direction:int) -> void:
	act({"op":"turn","angle":posmod(int(data().angle)+direction,4)})

func flip() -> void:
	act({"op":"group","group":"body" if data().group=="foot" else "foot"})

func close_desk() -> void:
	queue_free()

func refresh() -> void:
	if canvas==null:return
	if item()==null:queue_free();return
	var d:=data();var current:=item()
	object_image.texture=PorcelainArt.from_facts(current.goods.porcelain_value,d.group,int(d.angle))
	object_image.material=PorcelainArt.surface("front",current.goods.precision.damage,d.group=="body",object_image.texture)
	reference_image.texture=PorcelainArt.cell(d.reference,"standard",int(d.sample),false,d.group,int(d.angle))
	reference_image.material=PorcelainArt.surface("front","intact",false,reference_image.texture)
	for pair in [[object_image,object_frame],[reference_image,reference_frame]]:
		var img:TextureRect=pair[0];var frame:Control=pair[1];var factor:=1.65 if d.zoom else 1.0
		img.size=frame.size*factor;img.position=(frame.size-img.size)/2
	selection_title.text="实物 · "+PorcelainAppraisal.LABELS[d.group]+" · "+["正面","右侧","背面","左侧"][int(d.angle)]
	reference_title.text="图录 · 例"+str(int(d.sample)+1)
	reference_hint.text=PorcelainArt.HINTS[d.reference][d.group]
	for i in reference_choice.item_count:
		if reference_choice.get_item_metadata(i)==d.reference:reference_choice.select(i)
	finding.text=_error if not _error.is_empty() else "转看不同部位，与图录合看；不凭一处定年代。"
	clock_note.text=TimeController.clock_text(session.definition.opening_minute,session._day.state.game_minutes)+" · "+TieredAppraisal.exterior_text(session._day.state,current)
	var visitor:=CustomerManager.new().active(session._day.state)
	if visitor!=null and visitor.item.instance_id==item_id:clock_note.text+=" · 客人等到"+TimeController.clock_text(session.definition.opening_minute,visitor.expires_at)
	progress_note.text="已查看 "+"、".join(d.viewed.map(func(g:String)->String:return PorcelainAppraisal.LABELS[g]))+" · 转看与比对不耗时 · "+("手记已落笔" if TieredAppraisal.stage(session._day.state,item_id,2).committed else "可随时记下判断")
	(canvas.find_child("zoom",true,false) as Button).set_pressed_no_signal(d.zoom)
	(canvas.find_child("zoom",true,false) as Button).text="缩回" if d.zoom else "放大"
	(canvas.find_child("flip",true,false) as Button).text="放回整器" if d.group=="foot" else "翻看底部"
	for group in PorcelainAppraisal.GROUPS:
		var b:=canvas.find_child("group_"+group,true,false) as Button;b.text=PorcelainAppraisal.LABELS[group]+(" · 当前" if d.group==group else "")
	if note_panel.visible:refresh_notes()

func build_notes() -> void:
	note_panel = Panel.new(); note_panel.name = "porcelain_notes"; note_panel.position = Vector2(325,190); note_panel.size = Vector2(950,500)
	note_panel.add_theme_stylebox_override("panel",CounterTheme.painted_paper()); canvas.add_child(note_panel)
	var title := Label.new(); title.text = "验瓷手记"; title.position = Vector2(40,28); title.add_theme_font_size_override("font_size",30); note_panel.add_child(title)
	for i in 2:
		var label_node := Label.new(); label_node.text = "年代判断" if i==0 else "工艺判断"; label_node.position=Vector2(40,110+i*90); note_panel.add_child(label_node)
		var choice := OptionButton.new(); choice.position=Vector2(165,100+i*90); choice.size=Vector2(735,60); choice.add_item("暂难判断"); choice.set_item_metadata(0,"unsure")
		for key in PorcelainNegotiation.OPTIONS["era" if i==0 else "craft"]:
			choice.add_item(PorcelainNegotiation.OPTIONS["era" if i==0 else "craft"][key]); choice.set_item_metadata(choice.item_count-1,key)
		note_panel.add_child(choice); choice.item_selected.connect(save_draft)
		if i==0: era_choice=choice
		else: craft_choice=choice
	note_reason=Label.new(); note_reason.position=Vector2(40,292); note_reason.size=Vector2(855,90); note_reason.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; note_reason.add_theme_font_size_override("font_size",22); note_panel.add_child(note_reason)
	seal_button=button("确认落笔",Rect2(0,0,260,60),seal,"seal",true); seal_button.reparent(note_panel); seal_button.position=Vector2(630,403)
	var back:=button("继续查验",Rect2(0,0,235,60),note_panel.hide,"close_notes"); back.reparent(note_panel); back.position=Vector2(40,403)
	note_panel.hide()

func show_notes() -> void:
	note_panel.show(); refresh_notes()

func refresh_notes() -> void:
	var d:=data(); var sealed: bool=TieredAppraisal.stage(session._day.state,item_id,2).get("committed",false)
	for pair in [[era_choice,"era"],[craft_choice,"craft"]]:
		var choice: OptionButton=pair[0]; choice.disabled=sealed
		for i in choice.item_count:
			if choice.get_item_metadata(i)==d.get(pair[1],"unsure"): choice.select(i)
	seal_button.disabled=sealed or d.is_empty()
	note_reason.text=_error if not _error.is_empty() else "手记已落笔，可复看。" if sealed else "未查完也能落笔，拿不准的保留暂难判断。\n这里只记自己的看法；回柜台可另选说法谈价。"

func save_draft(_index: int) -> void:
	act({"op":"draft","era":era_choice.get_selected_metadata(),"craft":craft_choice.get_selected_metadata()})

func seal() -> void:
	if act({"op":"seal"}): judgment_confirmed.emit(); queue_free()

func _input(event:InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		if note_panel.visible:note_panel.hide()
		else:close_desk()

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
	result.toggle_mode = key_name == "zoom"
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
