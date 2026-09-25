class_name PorcelainGuideView
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

static func open(owner_view: Node, current: RunSession) -> PorcelainGuideView:
	var old := owner_view.get_tree().root.get_node_or_null("PorcelainGuide") as PorcelainGuideView
	if old != null: return old
	var view := PorcelainGuideView.new(); view.name = "PorcelainGuide"; view.session = current
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
	page = posmod(page+direction,5); render()

func refresh_status() -> void:
	var known := ShopKnowledgeService.mastered(session._day.state,"luxury_porcelain")
	study.text = "已掌握瓷器知识 · 免费复看" if known else "研习指南 · 1行动点 / 不收银元"
	var why := ShopKnowledgeService.reason(session._day,"luxury_porcelain")
	study.disabled = not why.is_empty(); study.tooltip_text = why
	status.text = "翻页不耗时。"+("瓷器知识已掌握。" if known else why if not why.is_empty() else "研习后，可对照整器、绘纹与底足，分别判断年代与工艺。")

func learn() -> void:
	var result := session.growth_command("learn_knowledge","luxury_porcelain")
	refresh_status()
	if not result.ok: status.text = result.message

func picture(age:String,craft:String,sample:int,hidden:bool,part:String,rect:Rect2) -> void:
	var img:=TextureRect.new();img.texture=PorcelainArt.cell(age,craft,sample,hidden,part)
	img.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;img.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	img.position=rect.position;img.size=rect.size;content.add_child(img)

func pointer(start:Vector2,end:Vector2) -> void:
	var line:=Line2D.new();line.width=2;line.default_color=Color("713e20");content.add_child(line)
	line.add_point(start);line.add_point(end)
	var dir:=(start-end).normalized();line.add_point(end+dir.rotated(.5)*14);line.add_point(end);line.add_point(end+dir.rotated(-.5)*14)

func render() -> void:
	for child in content.get_children():content.remove_child(child);child.queue_free()
	heading.text="青花断代图录 · %d / 5 · " % (page+1)+(["元","明","清","民国"][page] if page<4 else "工艺对照")
	if page<4:
		var age:String=PorcelainArt.ERAS[page]
		for i in 3:
			var part:String=PorcelainAppraisal.GROUPS[i]
			button(content,PorcelainAppraisal.LABELS[part]+(" · 当前" if part==group else ""),Rect2(120+i*170,124,157,39),func()->void:group=part;render(),"guide_"+part)
		button(content,"换一套样本",Rect2(645,124,170,39),func()->void:specimen=1-specimen;render(),"sample")
		picture(age,"standard",specimen,false,group,Rect2(135,184,365,317))
		picture(age,"standard",specimen,true,group,Rect2(495,184,365,317))
		text(content,"参考样本 · 例%d" % (specimen+1),Rect2(150,508,335,35),21)
		text(content,"磨耗后的同类样本" if age=="yuan" else "同代仿古样本",Rect2(527,508,320,35),21)
		text(content,PorcelainArt.HINTS[age][group],Rect2(885,190,265,185),23)
		text(content,"本页仅示范图中样本。旧款可被沿用；须把器形、绘纹、足底合看。",Rect2(885,388,265,147),21)
		var endpoint:=Vector2(330,335) if group=="painting" else Vector2(420,383) if group=="foot" else Vector2(330,389)
		pointer(Vector2(200,493),endpoint)
		pointer(Vector2(600,493),endpoint+Vector2(360,0))
	else:
		for i in 3:
			var part: String = PorcelainAppraisal.GROUPS[i]
			button(content,PorcelainAppraisal.LABELS[part]+(" · 当前" if part==craft_group else ""),Rect2(125+i*175,122,164,39),func()->void:craft_group=part;render(),"craft_"+part)
		for i in 3:
			picture("ming",PorcelainArt.CRAFTS[i],0,false,craft_group,Rect2(125+i*344,172,300,250))
			var captions: Array = ["粗工 · 填色越界，边线不齐","常品 · 轮廓规整，内纹简洁","精工 · 收笔利落，细线分明"]
			if craft_group=="foot": captions=["粗工 · 修足不齐，釉边起伏","常品 · 修整平顺，可见刀痕","精工 · 足边匀整，收釉细致"]
			if craft_group=="body": captions=["粗工 · 花叶歪斜，纹带参差","常品 · 布局规整，细部简洁","精工 · 线条舒展，细部有层次"]
			text(content,captions[i],Rect2(125+i*344,436,310,72),22)
		text(content,"看笔线、填色与收边，不凭模糊、旧色判粗工。年代与工艺分开，磕口另看。",Rect2(125,514,1000,42),22)
	refresh_status()

func _input(event:InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):get_viewport().set_input_as_handled();queue_free()
