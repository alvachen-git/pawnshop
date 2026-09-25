extends "res://tests/watch_negotiation_ui.gd"

func _run() -> void:
	create_timer(180).timeout.connect(func()->void:push_error("PORCELAIN REFINED TIMEOUT");quit(1))
	root.size=Vector2i(1600,900);root.content_scale_size=root.size
	_main=load("res://scenes/start.tscn").instantiate();_main.get_node("Bootstrap").save_path="user://tests/porcelain-refined/auto.json";root.add_child(_main)
	_session=_main.get_node("Bootstrap").session
	await _frames();await _click_button(_main.title_menu.buttons[0])
	var screen:=_main.get_node("CounterScreen") as CounterScreen
	for era in PorcelainArt.ERAS:
		for sample in 2:
			for hidden in [false,true]:
				for quality in PorcelainArt.CRAFTS:
					for group in PorcelainAppraisal.GROUPS:
						var tex:=PorcelainArt.cell(era,quality,sample,hidden,group)
						_check(tex.atlas.resource_path.contains("/craft/"),"no craft fallback for "+era+quality+group)
						_check(Rect2(Vector2.ZERO,tex.atlas.get_size()).encloses(tex.region),"whole region in source")
				PrecisionPreview.apply(_session,2,"porcelain_vase","sound","intact",hidden,"antique")
				PorcelainPreview.apply(_session,{"--precision-era":era,"--precision-sample":str(sample+1),"--precision-difficulty":"hidden" if hidden else "ordinary"})
				_session.restored.emit();_session.changed.emit();await _frames()
				screen._close_drawer();screen._close_menu();screen._counter_view.dismiss_contexts();await _frames()
				var actual:AtlasTexture=screen._counter_view._item_image.texture
				var front:=PorcelainArt.cell(era,"standard",sample,hidden,"body",0)
				_check(actual.atlas!=front.atlas and actual.atlas.resource_path.contains("/craft/counter/"),"counter has dedicated painted perspective; inspection unchanged")
				await capture("refined_"+era+"_"+str(sample+1)+("_hidden" if hidden else "_ordinary"))
	print("PORCELAIN REFINED: %d assertions, %d failures" % [_assertions,_failures]);quit(0 if _failures==0 else 1)

func capture(label:String) -> void:
	await _frames();await RenderingServer.frame_post_draw
	var folder:="res://docs/qa/porcelain-v41/refined/";DirAccess.make_dir_recursive_absolute(folder)
	_check(root.get_texture().get_image().save_png(folder+label+".png")==OK,"capture "+label)
