extends RefCounted
# Numeric, session-local diagnostics. No identity, payload or credential storage.
var frames := []
var rtts := []
var gaps := []
var apply_times := []
var sent_times := {}
var received_bytes := 0
var sent_bytes := 0
var received_states := 0
var sent_inputs := 0
var coalesced := 0
var queue_peak := 0
var last_state := 0
var began := 0
var last_frame := 0
var rates := {"down":0.0,"up":0.0,"states":0.0,"inputs":0.0}

func sample(values: Array, value: float, limit: int = 120) -> void:
	values.append(value)
	if values.size() > limit: values.pop_front()

func quantile(values: Array, percentile: float) -> float:
	if values.is_empty(): return 0
	var sorted := values.duplicate()
	sorted.sort()
	return float(sorted[mini(sorted.size() - 1, floori(sorted.size() * percentile))])

func frame(delta: float) -> void:
	# Wall time rather than the engine's smoothed/clamped simulation delta.
	var frame_now := Time.get_ticks_usec()
	if last_frame > 0: sample(frames, (frame_now - last_frame) / 1000.0)
	last_frame = frame_now
	var now := Time.get_ticks_msec()
	if began == 0: began = now
	if now - began >= 1000:
		var seconds := (now - began) / 1000.0
		rates = {"down":received_bytes / seconds,"up":sent_bytes / seconds,"states":received_states / seconds,"inputs":sent_inputs / seconds}
		received_bytes = 0; sent_bytes = 0; received_states = 0; sent_inputs = 0; began = now

func input_sent(sequence: int) -> void:
	sent_times[sequence] = Time.get_ticks_usec()
	sent_inputs += 1
	if sent_times.size() > 256: sent_times.erase(sent_times.keys()[0])

func acknowledge(sequence: int) -> void:
	if not sent_times.has(sequence): return
	sample(rtts, (Time.get_ticks_usec() - int(sent_times[sequence])) / 1000.0, 60)
	sent_times.erase(sequence)

func state_received() -> void:
	var now := Time.get_ticks_usec()
	if last_state > 0: sample(gaps, (now - last_state) / 1000.0, 60)
	last_state = now
	received_states += 1

func jitter() -> float:
	var differences := []
	for i in range(1, rtts.size()): differences.append(absf(float(rtts[i]) - float(rtts[i - 1])))
	return quantile(differences, 0.95)

func summary() -> Dictionary:
	var average := 0.0
	for value in frames: average += float(value) / frames.size()
	return {"fps":0.0 if frames.is_empty() else 1000.0 / maxf(0.01, average),"frame_p95":quantile(frames, 0.95),"rtt":quantile(rtts, 0.5),"rtt_p95":quantile(rtts, 0.95),"jitter":jitter(),"gap_p95":quantile(gaps, 0.95),"apply_p95":quantile(apply_times, 0.95),"rates":rates.duplicate(),"queue_peak":queue_peak,"coalesced":coalesced}
