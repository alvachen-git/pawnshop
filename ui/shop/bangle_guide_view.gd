class_name BangleGuideView
extends CanvasLayer

var session: RunSession
var canvas: Control
var content: Control
var page := 0
var heading: Label
var status: Label
var study: Button

static func open(owner_view: Node, current: RunSession) -> BangleGuideView:
	var old := owner_view.get_tree().root.get_node_or_null("BangleGuide") as BangleGuideView
	if old != null: return old
	var view := BangleGuideView.new(); view.name = "BangleGuide"; view.session = current
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
	var known := ShopKnowledgeService.mastered(session._day.state,"luxury_metal")
	study.text = "已掌握金银器知识 · 免费复看" if known else "研习指南 · 准备1次 / 不收银元"
	var why := ShopKnowledgeService.reason(session._day,"luxury_metal")
	study.disabled = not why.is_empty(); study.tooltip_text = why
	status.text = "翻页不耗时。"+("金银器知识已掌握。" if known else why if not why.is_empty() else "研习后，可配合金银衡验具称重、看戳记与火试。")

func learn() -> void:
	var result := session.growth_command("learn_knowledge","luxury_metal")
	refresh_status()
	if not result.ok: status.text = result.message

func picture(index: int, variant: String, rect: Rect2) -> void:
	var image:=TextureRect.new(); image.texture=BangleArt.cell(index,variant)
	if index==0: image.texture=BangleArt.exterior()
	image.expand_mode=TextureRect.EXPAND_IGNORE_SIZE; image.position=rect.position; image.size=rect.size; content.add_child(image)

func pointer(points: Array[Vector2]) -> void:
	var line := Line2D.new(); line.width = 2; line.default_color = Color("713e20"); content.add_child(line)
	for point in points: line.add_point(point)
	var ring := Line2D.new(); ring.width = 2; ring.default_color = line.default_color; content.add_child(ring)
	for step in 33: ring.add_point(points[-1]+Vector2.from_angle(TAU*step/32.0)*9)

func render() -> void:
	for child in content.get_children(): content.remove_child(child); child.queue_free()
	heading.text="金镯鉴定指南 · %d / 3 · " % (page+1)+["称重对款","看戳与接缝","火试后看什么"][page]
	if page==0:
		picture(5,"base",Rect2(125,185,300,310)); picture(0,"base",Rect2(440,200,275,275))
		text(content,"加减砝码，等两盘平衡",Rect2(125,505,320,35),22)
		text(content,"本款参考：30—32克",Rect2(445,505,310,35),22)
		text(content,"先认清尺寸与结构",Rect2(790,173,335,45),28)
		text(content,"放上金镯，再加减砝码。两盘齐平时，把砝码总重记下来。",Rect2(790,235,335,120))
		text(content,"同样重量可能是不同金料。称重相符，仍须看戳记、接缝及火试后的变化。",Rect2(790,386,335,140))
	elif page==1:
		picture(1,"base",Rect2(125,205,270,270)); picture(3,"base",Rect2(420,205,270,270))
		text(content,"戳记：看框线与收笔",Rect2(125,490,300,40),22)
		text(content,"原有接缝：细直、花纹相接",Rect2(420,490,350,40),21)
		pointer([Vector2(260,490),Vector2(260,430),Vector2(260,350)])
		pointer([Vector2(557,490),Vector2(557,400),Vector2(552,330)])
		text(content,"先对照正规样式",Rect2(790,173,335,45),28)
		text(content,"戳记可被仿刻，不能单凭店号认金料。看笔画排列，再核重量。",Rect2(790,235,335,125))
		text(content,"正常接缝不等于修补。留意花纹中断、越过旧纹的焊线；转动后再放大。",Rect2(790,392,335,130))
	else:
		picture(2,"base",Rect2(125,210,270,270)); picture(2,"plated",Rect2(420,210,270,270))
		text(content,"参考：擦后表面连贯",Rect2(125,496,295,40),22)
		text(content,"可疑：薄层边缘与异色底料",Rect2(420,496,355,40),21)
		text(content,"收火、冷却、擦拭、比较",Rect2(778,173,365,45),26)
		text(content,"表面烟污先擦去。再看已有磨处的薄层边缘、残留斑色，以及接焊处与邻处的差别。",Rect2(790,235,335,150))
		text(content,"变黑不必然是假，不变色也不能保真。重量、戳记、局部痕迹须合看，不能据此断定精确成色。",Rect2(790,403,335,135),22)
	refresh_status()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"): get_viewport().set_input_as_handled(); queue_free()
