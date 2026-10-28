extends SceneTree
## Vygeneruje všechny zvuky do WAV souborů a vypíše jejich parametry (délka, špička, RMS, NaN, smyčka).
## Spuštění: godot --headless --path . -s scripts/tools/audio_dump.gd -- cesta/k/výstupu


func _init() -> void:
	var out_dir: String = "/tmp/td_audio"
	var ua: PackedStringArray = OS.get_cmdline_user_args()
	if ua.size() > 0:
		out_dir = ua[0]
	DirAccess.make_dir_recursive_absolute(out_dir)
	var report: Dictionary = {}
	var t0: int = Time.get_ticks_msec()
	for n in Synth.SFX_NAMES:
		var w: AudioStreamWAV = Synth.make_sfx(str(n))
		report[str(n)] = _info(w)
		w.save_to_wav("%s/%s.wav" % [out_dir, str(n)])
	var t1: int = Time.get_ticks_msec()
	for k in ["wind", "water"]:
		var wa: AudioStreamWAV = Synth.make_ambient(k)
		report["amb_" + k] = _info(wa)
		wa.save_to_wav("%s/amb_%s.wav" % [out_dir, k])
	var t2: int = Time.get_ticks_msec()
	var mt: Dictionary = {}
	for k2 in ["calm", "battle"]:
		var s0: int = Time.get_ticks_msec()
		var wm: AudioStreamWAV = Synth.render_music_sync(k2)
		mt[k2] = Time.get_ticks_msec() - s0
		report["music_" + k2] = _info(wm)
		wm.save_to_wav("%s/music_%s.wav" % [out_dir, k2])
	report["_timing_ms"] = {"sfx": t1 - t0, "ambient": t2 - t1, "music": mt}
	print("AUDIO_JSON " + JSON.stringify(report))
	quit(0)


func _info(w: AudioStreamWAV) -> Dictionary:
	var d: PackedByteArray = w.data
	var n: int = d.size() / 2
	var peak: float = 0.0
	var sq: float = 0.0
	var bad: int = 0
	var zero_run: int = 0
	var max_zero: int = 0
	for i in range(n):
		var v: float = float(d.decode_s16(i * 2)) / 32768.0
		if is_nan(v) or is_inf(v):
			bad += 1
			continue
		peak = maxf(peak, absf(v))
		sq += v * v
		if absi(d.decode_s16(i * 2)) < 4:
			zero_run += 1
			max_zero = maxi(max_zero, zero_run)
		else:
			zero_run = 0
	var first: float = float(d.decode_s16(0)) / 32768.0
	var last: float = float(d.decode_s16((n - 1) * 2)) / 32768.0
	return {
		"sec": snappedf(float(n) / float(w.mix_rate), 0.01), "rate": w.mix_rate, "peak": snappedf(peak, 0.001),
		"rms": snappedf(sqrt(sq / float(maxi(n, 1))), 0.0001), "bad": bad, "silent_run_ms": int(1000.0 * float(max_zero) / float(w.mix_rate)),
		"first": snappedf(first, 0.0001), "last": snappedf(last, 0.0001), "loop": w.loop_mode != AudioStreamWAV.LOOP_DISABLED,
	}
