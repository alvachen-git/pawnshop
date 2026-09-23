extends SceneTree

var failures := 0
var assertions := 0

func check(ok: bool, description: String) -> void:
	assertions += 1
	if not ok:
		failures += 1
		push_error(description)

# Inspect the rendered PCM, not just the schedule supplied to the synthesizer.
func attacks(wav: AudioStreamWAV) -> Array[float]:
	var result: Array[float] = []
	var last_loud := -1.0
	var pcm := wav.data
	for frame in pcm.size()/2:
		if abs(pcm.decode_s16(frame*2)) < 300: continue
		var time := float(frame)/wav.mix_rate
		if time-last_loud > .08: result.append(time)
		last_loud = time
	return result

func _initialize() -> void:
	var rendered := {}
	var folder := "res://docs/qa/watch-v34/audio/"
	DirAccess.make_dir_recursive_absolute(folder)
	for operation in ["stable","positional","stopping"]:
		var wav := WatchSound.stream(WatchEconomy.sample_ticks(operation,"vertical",.4))
		check(wav.get_length() == 8,"eight seconds including silence: "+operation)
		check(wav.save_to_wav(folder+operation+".wav") == OK,"export actual sample "+operation)
		var heard := attacks(wav)
		rendered[operation] = heard
		print(operation+" PCM attacks: "+str(heard))
		check(heard.size() > 10,"audible clicks present: "+operation)
		check(wav.data == WatchSound.stream(WatchEconomy.sample_ticks(operation,"vertical",.4)).data,"deterministic playback: "+operation)
	var normal: Array = rendered.stable
	var positional: Array = rendered.positional
	var stopping: Array = rendered.stopping
	check(normal.size() == 39,"normal has all 39 beats")
	check(normal.back() > 7.7,"normal continues to end")
	for i in range(1,normal.size()): check(abs(normal[i]-normal[i-1]-.2) < .005,"normal interval is uniform")
	var gaps: Array = []
	for i in range(1,positional.size()):
		if positional[i]-positional[i-1] > .6: gaps.append([positional[i-1],positional[i]])
	check(gaps.size() == 2,"positional has two audible pauses followed by resumption")
	check(positional.back() > 7.7,"positional resumes through ending")
	check(stopping.back() > 3 and stopping.back() < 4,"stopping becomes silent around halfway")
	check(normal.slice(0,10) == positional.slice(0,10) and normal.slice(0,10) == stopping.slice(0,10),"openings really are the same")
	check(WatchSound.stream(WatchEconomy.sample_ticks("positional","flat",.4)).data == WatchSound.stream(WatchEconomy.sample_ticks("stable","flat",.4)).data,"positional fault is continuous when flat")
	print("Measured positional pauses (last beat / next beat): "+str(gaps))
	print("WATCH GUIDE AUDIO: %d assertions, %d failures" % [assertions,failures])
	quit(0 if failures == 0 else 1)
