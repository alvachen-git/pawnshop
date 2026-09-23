class_name WatchSound
extends RefCounted

# Deterministic synthetic escapement clicks; intentionally not a branded recording.
# Two resonances and a very short noisy attack, no music or spoken answers.
static func stream(ticks: PackedFloat32Array) -> AudioStreamWAV:
	const RATE := 22050
	var samples := PackedFloat32Array(); samples.resize(int(WatchAppraisal.LENGTH*RATE))
	var rng := RandomNumberGenerator.new(); rng.seed = 5731
	for index in ticks.size():
		var start := int(ticks[index]*RATE)
		for j in 550:
			if start+j >= samples.size(): break
			var t := float(j)/RATE
			var hz := 3100.0 if index%2 == 0 else 2650.0
			var value := (sin(TAU*hz*t)*.52+sin(TAU*hz*1.63*t)*.18+rng.randf_range(-.3,.3))*exp(-t*235.0)
			samples[start+j] += value
	var bytes := PackedByteArray(); bytes.resize(samples.size()*2)
	for i in samples.size(): bytes.encode_s16(i*2,int(clampf(samples[i],-1,1)*24500))
	var result := AudioStreamWAV.new(); result.format = AudioStreamWAV.FORMAT_16_BITS
	result.mix_rate = RATE; result.stereo = false; result.data = bytes
	return result
