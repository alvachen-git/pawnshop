extends "res://tests/camera_appraisal.gd"

func run() -> void:
	if not setup():quit(1);return
	var s:=unit_visit("customer_wealthy_factory",CameraEconomy.ITEM,"flawed","sell")
	var item:ItemInstance=s._day.state.visits[0].item
	var counts:={"legacy":0,"letter_swap":0,"extra_letter":0,"city_swap":0}
	for seed_value in 1000:
		s._day.state.run_seed=seed_value;item.goods.erase("camera_value")
		CameraEconomy.attach(s._day.state,item)
		var facts:Dictionary=item.goods.camera_value.duplicate(true)
		counts[facts.engraving]+=1
		var key:=item.instance_id+"/camera43/"
		var l:=VarietyService.rng(seed_value,key+"lens").randi_range(0,99)
		var m:=VarietyService.rng(seed_value,key+"mechanism").randi_range(0,99)
		check(facts.lens==("clear" if l<70 else "haze" if l<90 else "scratched") and facts.mechanism==("smooth" if m<70 else "sticky" if m<90 else "stuck"),"engraving does not disturb old random keys")
		item.goods.erase("camera_value");CameraEconomy.attach(s._day.state,item)
		check(item.goods.camera_value==facts,"same seed same engraving and facts")
	for variant in counts:
		check(counts[variant]>180 and counts[variant]<320,"all four variants generated "+variant)
		item.goods.camera_value.engraving=variant
		var snapshot:=RunSnapshot.copy(s._day.state)
		check(snapshot.visits[0].item.goods.camera_value.engraving==variant,"variant survives snapshot")
		var copy:Dictionary=item.goods.camera_value.duplicate(true)
		check(CameraArt.detail(copy,"identity")!=null,"variant texture available")
		check(copy==item.goods.camera_value,"view is read only")
		var value:=CameraEconomy.valuation(copy.identity,copy.lens,copy.mechanism,item.goods.precision.damage)
		check(copy.actual==value,"engraving never changes value")
	item.goods.camera_value.erase("engraving")
	var legacy:=item.goods.duplicate(true);CameraEconomy.attach(s._day.state,item)
	check(item.goods==legacy and CameraArt.detail(item.goods.camera_value,"identity") is AtlasTexture,"existing camera retains legacy image without migration")
	for scenario in ["imitation-legacy","imitation-letters","imitation-extra","imitation-city"]:
		CameraPreview.apply(s,scenario)
		check(item.goods.camera_value.identity=="imitation","preview routes to imitation")
		check(item.goods.camera_value.engraving==CameraEconomy.ENGRAVINGS[["imitation-legacy","imitation-letters","imitation-extra","imitation-city"].find(scenario)],"preview selects requested spelling")
	var shutter:=CameraShutter.new();root.add_child(shutter);shutter.set_process(false)
	for condition in ["smooth","sticky","stuck"]:
		for setting in ["slow","fast"]:
			shutter.play_test(condition,setting,false);shutter._process(2.0)
			check(shutter.played_events.is_empty(),"unwound cannot sound like working shutter")
			shutter.play_test(condition,setting,true)
			check(shutter.played_events==["release"],"mechanical latch at press")
			shutter._process(shutter.opening_time()-.01)
			check(shutter.played_events==["release"],"no curtain sound before movement")
			shutter._process(.02)
			check(shutter.played_events==["release","jam" if condition=="stuck" else "travel"],"movement synced to visible curtain")
			shutter._process(2.0)
			check((not "catch" in shutter.played_events) if condition=="stuck" else shutter.played_events==["release","travel","catch"],"jam has no successful close sound")
	for event in CameraShutter.SOUNDS:
		var clip:=CameraShutter.SOUNDS[event] as AudioStreamWAV
		check(clip!=null and clip.mix_rate==48000 and clip.get_length()>.05,"PCM mechanical clip loaded "+event)
	check(CameraShutter.SOUNDS.fast.data!=CameraShutter.SOUNDS.slow.data,"different recorded exposures for fast and slow")
	check(CameraShutter.SOUNDS.jam.get_length()<CameraShutter.SOUNDS.fast.get_length(),"jam omits full recorded exposure")
	check(CameraShutter.SOUNDS.sticky_slow.get_length()>CameraShutter.SOUNDS.slow.get_length()+.79,"delayed recording matches delayed curtain")
	shutter.audio_player.stop();shutter.queue_free()
	await process_frame
	await create_timer(.15).timeout
	print("CAMERA FEEDBACK: %d passes, %d failures" % [passes,failures]);quit(0 if failures==0 else 1)
