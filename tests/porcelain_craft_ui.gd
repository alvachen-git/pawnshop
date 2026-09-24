extends SceneTree
var failures := 0
var checks := 0
func _initialize() -> void:
    call_deferred("_run")
func check(ok:bool,why:String) -> void:
    checks+=1
    if not ok: failures+=1;push_error(why)
func _run() -> void:
    root.size=Vector2i(1500,1400);root.content_scale_size=root.size
    var canvas:=Control.new();root.add_child(canvas);canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    var bg:=ColorRect.new();bg.color=Color("#d9caa8");bg.size=Vector2(1500,1400);canvas.add_child(bg)
    var label:=Label.new();label.position=Vector2(15,0);label.add_theme_font_size_override("font_size",17);label.modulate=Color.BLACK;canvas.add_child(label)
    for col in 3:
        var heading:=Label.new();heading.text=["粗工","常品","精工"][col];heading.position=Vector2(col*495+20,20);heading.size=Vector2(465,28)
        heading.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;heading.add_theme_font_size_override("font_size",25);heading.modulate=Color.BLACK;canvas.add_child(heading)
    var cards:Array[TextureRect]=[]
    for row in 4:
        for col in 3:
            var card:=TextureRect.new();card.position=Vector2(20+col*495,50+row*334);card.size=Vector2(465,314)
            card.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;card.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
            canvas.add_child(card);cards.append(card)
    for era in PorcelainArt.ERAS:
        for sample in 2:
            for hidden in [false,true]:
                var identity:String=era+"_"+str(sample+1)+("_hidden" if hidden else "_ordinary")
                label.text=identity
                for col in 3:
                    var quality:String=PorcelainArt.CRAFTS[col]
                    var facts:={"era":era,"craft":quality,"sample":sample,"hidden":hidden,"actual":999}
                    var frozen:=facts.duplicate(true)
                    for angle in 4:
                        var tex:=PorcelainArt.cell(era,quality,sample,hidden,"body",angle)
                        check(tex.atlas.resource_path.contains("/craft/"),identity+" body uses craft")
                        check(Rect2(Vector2.ZERO,tex.atlas.get_size()).encloses(tex.region),identity+" body bounds")
                        for other in range(col):
                            var previous:=PorcelainArt.cell(era,PorcelainArt.CRAFTS[other],sample,hidden,"body",angle)
                            check(tex.region!=previous.region,identity+" all rotations differ by craft")
                    for row in 4:
                        var group:String=["body","painting","foot","counter"][row]
                        var tex:AtlasTexture=PorcelainArt.counter(facts) if row==3 else PorcelainArt.from_facts(facts,group,0)
                        check(tex.atlas.resource_path.contains("/craft/"),identity+" complete route "+group)
                        check(Rect2(Vector2.ZERO,tex.atlas.get_size()).encloses(tex.region),identity+" region bounds "+group)
                        check(tex.region.size.x>90 and tex.region.size.y>100,identity+" viable detail resolution")
                        cards[row*3+col].texture=tex
                        for other in range(col):
                            var previous:AtlasTexture=cards[row*3+other].texture
                            check(tex.region!=previous.region,identity+" no shared grade image "+group)
                    check(facts==frozen,identity+" rendering leaves fixed facts untouched")
                await process_frame;await process_frame;await RenderingServer.frame_post_draw
                var folder:="res://docs/qa/porcelain-v41/craft/"
                DirAccess.make_dir_recursive_absolute(folder)
                check(root.get_texture().get_image().save_png(folder+identity+".png")==OK,"save "+identity)
    print("PORCELAIN CRAFT: %d checks, %d failures" % [checks,failures]);quit(0 if failures==0 else 1)
