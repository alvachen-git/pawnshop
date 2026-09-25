class_name CameraDeskView
extends LuxuryAppraisalView

signal judgment_confirmed
var canvas: Control
var clock_note: Label
var finding: Label
var progress_note: Label
var selection_title: Label
var note_panel: Panel
var choices: Dictionary = {}
var shutter: CameraShutter
var control_rows: Dictionary = {}
var aperture_tween: Tween
var seal_button: Button
var note_reason: Label

static func open_camera(owner_view: Control, current: RunSession, id: String) -> CameraDeskView:
	var old := owner_view.get_tree().root.get_node_or_null("CameraDeskOverlay") as CameraDeskView
	if old != null: return old
	# Inventory/facility entry also pays through the existing transaction before opening the desk.
	if CameraAppraisal.row(current._day.state,id).is_empty():
		request_entry(owner_view,current,id)
		return null
	var view := CameraDeskView.new(); view.name = "CameraDeskOverlay"; view.session = current; view.item_id = id
	var parent: Node = owner_view
	while parent != null:
		if parent.has_method("_close_drawer"):
			view.judgment_confirmed.connect(Callable(parent,"_close_drawer")); break
		parent = parent.get_parent()
	owner_view.get_tree().root.add_child(view); owner_view.tree_exiting.connect(view.queue_free,CONNECT_ONE_SHOT)
	return view

static func request_entry(owner_view: Control, current: RunSession, id: String) -> void:
	if owner_view.get_tree().root.has_node("CameraEntry"): return
	var dialog := ConfirmationDialog.new(); dialog.name = "CameraEntry"; dialog.title = "器材鉴定"
	dialog.theme = CounterTheme.build(); dialog.ok_button_text = "开始查验 · 10分钟"; dialog.cancel_button_text = "返回"
	var why := CameraAppraisal.reason(current._day,"luxury_begin",id,"2")
	dialog.dialog_text = why if not why.is_empty() else "将相机放在案上，查镜片、调光圈，过片后试快门。\n首次查验耗10分钟，操作、比对与复看不耗时。"
	dialog.get_ok_button().disabled = not why.is_empty()
	owner_view.get_tree().root.add_child(dialog); dialog.popup_centered(Vector2i(620,230))
	dialog.confirmed.connect(func() -> void:
		var result := current.fan_command("luxury_begin",id,"2")
		if result.ok:
			dialog.queue_free(); open_camera(owner_view,current,id)
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
	label("德国徕卡Ⅰ型相机",Rect2(48,24,800,54),36)
	clock_note=label("",Rect2(48,88,1230,36),21)
	button("返回柜台",Rect2(1370,30,180,52),close_desk,"close")
	for rect in [Rect2(40,150,735,510),Rect2(795,150,765,510)]:
		var paper:=Panel.new();paper.position=rect.position;paper.size=rect.size;paper.add_theme_stylebox_override("panel",CounterTheme.painted_paper());canvas.add_child(paper)
	selection_title=label("",Rect2(72,169,650,40),27,true)
	object_frame=Control.new();object_frame.position=Vector2(92,216);object_frame.size=Vector2(630,385);object_frame.clip_contents=true;canvas.add_child(object_frame)
	object_image=texture(null,Rect2(0,0,630,385));object_image.reparent(object_frame);object_image.position=Vector2.ZERO;object_image.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	reference_title=label("图录",Rect2(830,169,140,38),27,true)
	reference_frame=Control.new();reference_frame.position=Vector2(860,222);reference_frame.size=Vector2(630,330);reference_frame.clip_contents=true;canvas.add_child(reference_frame)
	reference_image=texture(null,Rect2(0,0,630,330));reference_image.reparent(reference_frame);reference_image.position=Vector2.ZERO;reference_image.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	reference_hint=label("",Rect2(835,564,685,82),22,true)
	finding=label("",Rect2(74,605,650,44),21,true)
	for i in 4:
		var group: String=CameraAppraisal.GROUPS[i]
		button(CameraAppraisal.LABELS[group],Rect2(45+i*188,681,180,47),func()->void:act({"op":"group","group":group}),"group_"+group)
	button("放大",Rect2(44,806,180,48),func()->void:act({"op":"zoom","zoom":not data().zoom}),"zoom")
	for group in CameraAppraisal.GROUPS:
		var row_control:=Control.new();canvas.add_child(row_control);control_rows[group]=row_control
		var entries: Array=[]
		if group=="identity":entries=[["对照字母","zoom",true]]
		if group=="lens":entries=[["左侧光","light","left"],["正面光","light","front"],["右侧光","light","right"]]
		if group=="aperture":entries=[["开大光圈","aperture","open"],["中等开度","aperture","middle"],["收小光圈","aperture","narrow"]]
		if group=="shutter":entries=[["过片上弦","wind",""],["较慢挡","speed","slow"],["较快挡","speed","fast"],["按快门","shutter",""]]
		for i in entries.size():
			var entry: Array=entries[i];var key: String=entry[1]
			var payload: Dictionary={"op":key}
			if key in ["speed","aperture"]:payload["value"]=entry[2]
			if key=="light":payload.light=entry[2]
			if key=="zoom":payload.zoom=entry[2]
			var b:=button(entry[0],Rect2(45+i*188,744,180,49),func()->void:operate(payload),group+"_"+str(i))
			b.reparent(row_control)
	shutter=CameraShutter.new();shutter.position=Vector2(110,270);shutter.size=Vector2(590,255);canvas.add_child(shutter)
	button("查看图录",Rect2(810,742,350,62),func()->void:CameraGuideView.open(canvas,session),"guide")
	button("记下判断",Rect2(1190,742,350,62),show_notes,"notes",true)
	progress_note=label("",Rect2(245,815,1290,50),21)
	build_notes();session.changed.connect(refresh);session.restored.connect(queue_free)
	_root.resized.connect(layout_canvas);layout_canvas();refresh()

func item() -> ItemInstance:
	return LuxuryAppraisalService.target(session._day,item_id)

func data() -> Dictionary:
	return CameraAppraisal.row(session._day.state,item_id)

func act(payload: Dictionary) -> bool:
	var result:=session.fan_command("luxury_camera",item_id,JSON.stringify(payload))
	_error="" if result.ok else result.message
	refresh();return result.ok

func operate(payload: Dictionary) -> void:
	var previous_texture:=object_image.texture
	if not act(payload):return
	if payload.op=="shutter":shutter.play_test(CameraEconomy.operation(item(),"shutter"),data().speed,data().last_wound)
	if payload.op=="aperture" and CameraEconomy.operation(item(),"aperture")=="sticky":
		object_image.texture=previous_texture
		if aperture_tween!=null:aperture_tween.kill()
		aperture_tween=create_tween();aperture_tween.tween_interval(.9);aperture_tween.tween_callback(refresh)

func close_desk() -> void:
	queue_free()

func refresh() -> void:
	if canvas==null:return
	if item()==null:queue_free();return
	var d:=data();var current:=item()
	object_image.texture=CameraArt.detail(current.goods.camera_value,d.group,d.aperture)
	object_image.material=CameraArt.light_material(d.light) if d.group=="lens" else null
	reference_image.texture=CameraArt.reference_image(d.group,d.aperture)
	for pair in [[object_image,object_frame],[reference_image,reference_frame]]:
		var img: TextureRect=pair[0];var frame: Control=pair[1];var factor:=1.55 if d.zoom else 1.0
		img.size=frame.size*factor;img.position=(frame.size-img.size)/2
	selection_title.text="实物 · "+CameraAppraisal.LABELS[d.group]
	reference_title.text="原装样本"
	reference_hint.text=CameraArt.HINTS[d.group]
	finding.text=("已过片上弦" if d.wound else "未上弦")+" · "+("较慢挡" if d.speed=="slow" else "较快挡") if d.group=="shutter" else "按图录的观察点逐处比较。"
	if not _error.is_empty():finding.text=_error
	clock_note.text=TimeController.clock_text(session.definition.opening_minute,session._day.state.game_minutes)+" · "+TieredAppraisal.exterior_text(session._day.state,current)
	var visitor:=CustomerManager.new().active(session._day.state)
	if visitor!=null and visitor.item.instance_id==item_id:clock_note.text+=" · 客人等到"+TimeController.clock_text(session.definition.opening_minute,visitor.expires_at)
	progress_note.text="操作与复看不耗时 · "+("手记已落笔" if TieredAppraisal.stage(session._day.state,item_id,2).committed else "可随时记下判断")
	(canvas.find_child("zoom",true,false) as Button).text="缩回" if d.zoom else "放大"
	shutter.visible=d.group=="shutter";object_frame.visible=d.group!="shutter"
	for group in CameraAppraisal.GROUPS:
		var b:=canvas.find_child("group_"+group,true,false) as Button;b.set_pressed_no_signal(d.group==group)
		control_rows[group].visible=d.group==group
	for i in 3:
		(canvas.find_child("lens_"+str(i),true,false) as Button).set_pressed_no_signal(d.light==["left","front","right"][i])
		(canvas.find_child("aperture_"+str(i),true,false) as Button).set_pressed_no_signal(d.aperture==["open","middle","narrow"][i])
	(canvas.find_child("shutter_1",true,false) as Button).set_pressed_no_signal(d.speed=="slow")
	(canvas.find_child("shutter_2",true,false) as Button).set_pressed_no_signal(d.speed=="fast")
	if note_panel.visible:refresh_notes()

func build_notes() -> void:
	note_panel = Panel.new(); note_panel.name = "camera_notes"; note_panel.position = Vector2(325,160); note_panel.size = Vector2(950,580)
	note_panel.add_theme_stylebox_override("panel",CounterTheme.painted_paper()); canvas.add_child(note_panel)
	var title := Label.new(); title.text = "验机手记"; title.position = Vector2(40,28); title.add_theme_font_size_override("font_size",30); note_panel.add_child(title)
	for i in 3:
		var label_node := Label.new(); label_node.text = CameraNegotiation.LABELS[["identity","lens","mechanism"][i]]; label_node.position=Vector2(40,110+i*90); note_panel.add_child(label_node)
		var choice := OptionButton.new(); choice.position=Vector2(165,100+i*90); choice.size=Vector2(735,60); choice.add_item("暂难判断"); choice.set_item_metadata(0,"unsure")
		for key in CameraNegotiation.OPTIONS[["identity","lens","mechanism"][i]]:
			choice.add_item(CameraNegotiation.OPTIONS[["identity","lens","mechanism"][i]][key]); choice.set_item_metadata(choice.item_count-1,key)
		note_panel.add_child(choice); choice.item_selected.connect(save_draft)
		choices[["identity","lens","mechanism"][i]]=choice
	note_reason=Label.new(); note_reason.position=Vector2(40,385); note_reason.size=Vector2(855,90); note_reason.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; note_reason.add_theme_font_size_override("font_size",22); note_panel.add_child(note_reason)
	seal_button=button("确认落笔",Rect2(0,0,260,60),seal,"seal",true); seal_button.reparent(note_panel); seal_button.position=Vector2(630,493)
	var back:=button("继续查验",Rect2(0,0,235,60),note_panel.hide,"close_notes"); back.reparent(note_panel); back.position=Vector2(40,493)
	note_panel.hide()

func show_notes() -> void:
	note_panel.show(); refresh_notes()

func refresh_notes() -> void:
	var d:=data(); var sealed: bool=TieredAppraisal.stage(session._day.state,item_id,2).get("committed",false)
	for part in choices:
		var choice: OptionButton=choices[part]; choice.disabled=sealed
		for i in choice.item_count:
			if choice.get_item_metadata(i)==d.get(part,"unsure"): choice.select(i)
	seal_button.disabled=sealed or d.is_empty()
	note_reason.text=_error if not _error.is_empty() else "手记已落笔，可复看。" if sealed else "未查完也能落笔，拿不准的保留暂难判断。\n这里只记自己的看法；回柜台可另选说法谈价。"

func save_draft(_index: int) -> void:
	var payload: Dictionary={"op":"draft"}
	for part in choices:payload[part]=choices[part].get_selected_metadata()
	act(payload)

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
	result.toggle_mode = key_name == "zoom" or key_name.begins_with("group_") or key_name.begins_with("lens_") or key_name.begins_with("aperture_") or key_name in ["shutter_1","shutter_2"]
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
