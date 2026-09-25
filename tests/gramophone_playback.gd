extends SceneTree

var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
 checks += 1
 if not ok: failures += 1; push_error(message)
func run() -> void:
 var p := GramophonePlayer.new(); root.add_child(p); p.set_process(false)
 var settings := {"wound":true,"record":"reference","speed":"nominal"}
 var facts := {"motor":"steady","sound":"clear","record_worn":true}
 p.listen(facts,settings)
 p._process(15.0)
 check(p.playing,"Normal playback must not appear to fail when a demonstration ends")
 p.player.finished.emit()
 check(p.playing and p.player.playing,"Normal record loops until the player lifts the needle")
 var reference: PackedByteArray = (p.player.stream as AudioStreamWAV).data
 settings.record="customer"; p.listen(facts,settings)
 check((p.player.stream as AudioStreamWAV).data != reference,"Worn customer record sounds different from reference")
 settings.record="reference"; facts.motor="stopping"; p.listen(facts,settings);p._process(6.0)
 check(not p.playing,"Wound stopping mechanism must actually halt")
 facts.motor="steady";settings.wound=false;p.listen(facts,settings);p._process(4.0)
 check(not p.playing,"Unwound machine runs down even when mechanically sound")
 settings.wound=true;facts.motor="wavering";p.listen(facts,settings);p._process(15.0)
 check(p.playing,"Wavering is distinct from stopping")
 check(absf(GramophonePlayer.rate_at(.2,true,"wavering","nominal")-GramophonePlayer.rate_at(.8,true,"wavering","nominal"))>.1,"Wavering produces an audible pitch change")
 p.stop();check(not p.playing and not p.player.playing,"Lift needle stops sound and motion")
 var hashes := {}
 for sound in ["clear","rasping","muffled"]:
  for suffix in ["","_worn"]:
   var path: String = "res://assets/gramophone_desk/audio/"+sound+suffix+".wav"
   var digest := FileAccess.get_sha256(path)
   check(not hashes.has(digest),"Every teaching sample must differ")
   hashes[digest]=true
   var stream := load(path) as AudioStreamWAV
   check(stream != null and stream.get_length()>10,"Recorded sample imports and has a usable duration")
 p.queue_free();await process_frame
 print("GRAMOPHONE PLAYBACK: %d checks, %d failures" % [checks,failures]);quit(1 if failures else 0)
