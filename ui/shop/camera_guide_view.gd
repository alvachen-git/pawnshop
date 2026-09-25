class_name CameraGuideView
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

static func open(owner_view: Node, current: RunSession) -> CameraGuideView:
	var old := owner_view.get_tree().root.get_node_or_null("CameraGuide") as CameraGuideView
	if old != null: return old
	var view := CameraGuideView.new(); view.name = "CameraGuide"; view.session = current
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
	page = posmod(page+direction,3); render()

func refresh_status() -> void:
	var known := ShopKnowledgeService.mastered(session._day.state,"luxury_textile")
	study.text = "已掌握相机知识 · 免费复看" if known else "研习指南 · 准备1次 / 不收银元"
	var why := ShopKnowledgeService.reason(session._day,"luxury_textile")
	study.disabled = not why.is_empty(); study.tooltip_text = why
	status.text = "翻页不耗时。"+("相机知识已掌握。" if known else why if not why.is_empty() else "研习后，可对照镜片、机械与铭文，分别判断身份和状态。")

func learn() -> void:
	var result := session.growth_command("learn_knowledge","luxury_textile")
	refresh_status()
	if not result.ok: status.text = result.message

func picture(group_name: String, rect: Rect2) -> void:
	var img:=TextureRect.new();img.texture=CameraArt.reference_image(group_name)
	img.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;img.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	img.position=rect.position;img.size=rect.size;content.add_child(img)

func pointer(start:Vector2,end:Vector2) -> void:
	var line:=Line2D.new();line.width=2;line.default_color=Color("713e20");content.add_child(line)
	line.add_point(start);line.add_point(end)
	var dir:=(start-end).normalized();line.add_point(end+dir.rotated(.5)*14);line.add_point(end);line.add_point(end+dir.rotated(-.5)*14)

func render() -> void:
	for child in content.get_children():content.remove_child(child);child.queue_free()
	heading.text="洋相机鉴定指南 · %d / 3 · " % (page+1)+["核铭文与镜座","透光看镜片","试光圈与快门"][page]
	var group_name: String=["identity","lens","aperture"][page]
	picture(group_name,Rect2(130,155,440,365))
	text(content,CameraArt.HINTS[group_name],Rect2(620,170,515,145),26)
	var extra: String=["① 字母排列与字形
② 镜座、转接件与螺钉

铭文可仿刻；装配不协调还需结合其他细节。", "① 移灯后仍遮住内部的雾层
② 随斜光显出的细线划痕

玻璃反光与外部灰尘，不能直接当作镜内故障。", "① 光圈随开度收放，留意油迹和迟滞
② 先过片上弦，再试较慢、较快挡

快门未上弦时不动作，不能据此判坏。原装机也可能有故障；不装胶卷，不生成照片。"][page]
	text(content,extra,Rect2(620,325,515,224),23)
	pointer(Vector2(170,530),Vector2(300,250))
	pointer(Vector2(480,530),Vector2(455,385))
	refresh_status()

func _input(event:InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):get_viewport().set_input_as_handled();queue_free()
