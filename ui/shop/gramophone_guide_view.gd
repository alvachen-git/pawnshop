class_name GramophoneGuideView
extends CanvasLayer

var session: RunSession
var canvas: Control
var content: Control
var page := 0
var group := "body"
var specimen := 0
var craft_group := "painting"
var heading: Label
var status: Label
var study: Button
var sample_player: GramophonePlayer

static func open(owner_view: Node, current: RunSession) -> GramophoneGuideView:
	var old := owner_view.get_tree().root.get_node_or_null("GramophoneGuide") as GramophoneGuideView
	if old != null: return old
	var view := GramophoneGuideView.new(); view.name = "GramophoneGuide"; view.session = current
	owner_view.get_tree().root.add_child(view)
	owner_view.tree_exiting.connect(view.queue_free,CONNECT_ONE_SHOT)
	return view

func _ready() -> void:
	layer = 95
	var root_control := Control.new(); add_child(root_control); root_control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shade := ColorRect.new(); shade.color = Color("17120eea"); root_control.add_child(shade); shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	canvas = Control.new(); canvas.size = Vector2(1280,720); canvas.theme = CounterTheme.build(); root_control.add_child(canvas)
	var paper := Panel.new(); paper.position = Vector2(70,35); paper.size = Vector2(1140,650); paper.add_theme_stylebox_override("panel",CounterTheme.painted_paper()); canvas.add_child(paper)
	heading = text(canvas,"",Rect2(110,62,900,48),32)
	button(canvas,"收起 · Esc",Rect2(1010,61,155,44),queue_free,"close_guide")
	content = Control.new(); canvas.add_child(content)
	status = text(canvas,"",Rect2(115,562,1040,46),20)
	button(canvas,"上一页",Rect2(115,620,150,44),turn.bind(-1),"previous")
	button(canvas,"下一页",Rect2(280,620,150,44),turn.bind(1),"next")
	study = button(canvas,"",Rect2(640,620,510,44),learn,"study")

	sample_player=GramophonePlayer.new();sample_player.visible=false;add_child(sample_player)
	session.changed.connect(refresh_status); session.restored.connect(queue_free)
	root_control.resized.connect(func() -> void:
		var scale_factor := minf(root_control.size.x/1280.0,root_control.size.y/720.0)
		canvas.scale = Vector2.ONE*scale_factor; canvas.position = (root_control.size-Vector2(1280,720)*scale_factor)/2)
	root_control.resized.emit(); render()

func text(parent: Node, value: String, rect: Rect2, font := 23) -> Label:
	var label := Label.new(); label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.text = value; label.add_theme_font_size_override("font_size",font); label.add_theme_color_override("font_color",Color("382919")); parent.add_child(label)
	label.position = rect.position; label.size = rect.size
	return label

func button(parent: Node, value: String, rect: Rect2, action: Callable, id: String) -> Button:
	var b := Button.new(); b.name = id; b.text = value; b.position = rect.position; b.size = rect.size
	b.add_theme_font_size_override("font_size",22); CounterTheme.style_paper_button(b); b.pressed.connect(action); parent.add_child(b); return b

func turn(direction: int) -> void:
	page = posmod(page+direction,3); render()

func refresh_status() -> void:
	var known := ShopKnowledgeService.mastered(session._day.state,"luxury_watch")
	study.text = "已掌握钟表与留声机知识 · 免费复看" if known else "研习指南 · 1行动点 / 不收银元"
	var why := ShopKnowledgeService.reason(session._day,"luxury_watch")
	study.disabled = not why.is_empty(); study.tooltip_text = why
	status.text = "翻页不耗时。"+("钟表与留声机知识已掌握。" if known else why if not why.is_empty() else "与名表指南共用知识；研习一次即可对照留声机部件与运转。")

func learn() -> void:
	var result := session.growth_command("learn_knowledge","luxury_watch")
	refresh_status()
	if not result.ok: status.text = result.message

func picture(group_name: String, rect: Rect2) -> void:
	var img:=TextureRect.new();img.texture=GramophoneArt.reference_image(group_name)
	img.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;img.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	img.position=rect.position;img.size=rect.size;content.add_child(img)

func pointer(start:Vector2,end:Vector2) -> void:
	var line:=Line2D.new();line.width=2;line.default_color=Color("713e20");content.add_child(line)
	line.add_point(start);line.add_point(end)
	var dir:=(start-end).normalized();line.add_point(end+dir.rotated(.5)*14);line.add_point(end);line.add_point(end+dir.rotated(-.5)*14)

func render() -> void:
	sample_player.stop()
	for child in content.get_children():content.remove_child(child);child.queue_free()
	heading.text="留声机鉴定指南 · %d / 3 · " % (page+1)+["核对部件","上弦与调速","换片听发声"][page]
	var group_name: String=["identity","playback","soundbox"][page]
	picture(group_name,Rect2(130,155,440,340))
	text(content,GramophoneArt.HINTS[group_name],Rect2(620,155,515,135),25)
	var extra: String=["核对字母次序和固定方式。装配不协调、另加转接件时，应再查唱头。声音正常，也不能单凭这一点认原装。", "慢挡音低，快挡音高，这是调速的结果。回到参考挡后，乐句应稳定。上弦后仍忽快忽慢或停转，再怀疑动力问题。正常可连续试听，点停止抬针。", "正常老唱片也有轻微沙沙声。只在客人唱片上有明显爆豆声，先考虑唱片磨损。换对照片仍破音或闷弱，再检查唱头、振膜和密封圈。别凭一阵杂音断定机器好坏。"][page]
	text(content,extra,Rect2(620,300,515,210),23)
	if page==0:
		pointer(Vector2(170,530),Vector2(300,260));pointer(Vector2(480,530),Vector2(455,400))
	else:
		var samples: Array=["steady","wavering","stopping"] if page==1 else ["clear","rasping","muffled"]
		var labels: Array=["听平稳","听忽快忽慢","听停转"] if page==1 else ["听清楚","听破音","听闷弱"]
		for i in 3:
			var key: String=samples[i]
			button(content,labels[i],Rect2(130+i*145,511,137,42),func() -> void:
				sample_player.listen({"motor":key if page==1 else "steady","sound":key if page==2 else "clear","record_worn":false},{"wound":true,"record":"reference","speed":"nominal"}),"sample_"+str(i))
		button(content,"停止",Rect2(590,511,120,42),sample_player.stop,"stop_sample")
		if page==2:
			button(content,"听旧片杂音",Rect2(730,511,190,42),func() -> void:
				sample_player.listen({"motor":"steady","sound":"clear","record_worn":true},{"wound":true,"record":"customer","speed":"nominal"}),"worn_sample")
	refresh_status()

func _input(event:InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):get_viewport().set_input_as_handled();queue_free()
