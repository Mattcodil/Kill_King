## fps_sfx.gd
## Synthesised placeholder sound effects (no audio assets needed).
## Streams are generated once and cached.

class_name FpsSfx
extends RefCounted

const RATE := 22050

static var _cache: Dictionary = {}

static func shot(kind: String) -> AudioStreamWAV:
	var key := "shot_" + kind
	if _cache.has(key):
		return _cache[key]
	# dur, decay, tone_hz, noise_smooth (lower = duller)
	var p: Array = [0.25, 28.0, 140.0, 0.6]
	match kind:
		"smg":     p = [0.16, 42.0, 190.0, 0.7]
		"shotgun": p = [0.50, 13.0, 75.0, 0.4]
		"g3":      p = [0.38, 20.0, 105.0, 0.5]
		"ak":      p = [0.30, 24.0, 125.0, 0.55]
		"deagle":  p = [0.45, 15.0, 90.0, 0.45]
	var s := _gunshot(float(p[0]), float(p[1]), float(p[2]), float(p[3]))
	_cache[key] = s
	return s

static func reload_click() -> AudioStreamWAV:
	if _cache.has("reload"):
		return _cache["reload"]
	var n := int(RATE * 0.8)
	var data := PackedFloat32Array()
	data.resize(n)
	for click_t: float in [0.12, 0.55]:
		var start := int(click_t * RATE)
		for i in range(int(RATE * 0.05)):
			if start + i >= n:
				break
			data[start + i] += (randf() * 2.0 - 1.0) * exp(-float(i) / (RATE * 0.008)) * 0.6
	var s := _to_stream(data)
	_cache["reload"] = s
	return s

static func empty_click() -> AudioStreamWAV:
	if _cache.has("empty"):
		return _cache["empty"]
	var n := int(RATE * 0.05)
	var data := PackedFloat32Array()
	data.resize(n)
	for i in range(n):
		data[i] = (randf() * 2.0 - 1.0) * exp(-float(i) / (RATE * 0.006)) * 0.4
	var s := _to_stream(data)
	_cache["empty"] = s
	return s

static func hit_marker() -> AudioStreamWAV:
	if _cache.has("hit"):
		return _cache["hit"]
	var n := int(RATE * 0.07)
	var data := PackedFloat32Array()
	data.resize(n)
	for i in range(n):
		var t := float(i) / RATE
		data[i] = sin(TAU * 1500.0 * t) * exp(-t * 55.0) * 0.5
	var s := _to_stream(data)
	_cache["hit"] = s
	return s

static func hurt() -> AudioStreamWAV:
	if _cache.has("hurt"):
		return _cache["hurt"]
	var n := int(RATE * 0.22)
	var data := PackedFloat32Array()
	data.resize(n)
	var y := 0.0
	for i in range(n):
		var t := float(i) / RATE
		y += 0.15 * ((randf() * 2.0 - 1.0) - y)
		data[i] = (sin(TAU * 70.0 * t) * 0.6 + y * 0.8) * exp(-t * 14.0)
	var s := _to_stream(data)
	_cache["hurt"] = s
	return s

static func _gunshot(dur: float, decay: float, tone_hz: float, smooth: float) -> AudioStreamWAV:
	var n := int(RATE * dur)
	var data := PackedFloat32Array()
	data.resize(n)
	var y := 0.0
	for i in range(n):
		var t := float(i) / RATE
		y += smooth * ((randf() * 2.0 - 1.0) - y)
		var crack := y * exp(-t * decay)
		var thump := sin(TAU * tone_hz * t) * exp(-t * decay * 0.6)
		data[i] = clampf(crack * 1.2 + thump * 0.7, -1.0, 1.0)
	return _to_stream(data)

static func _to_stream(samples: PackedFloat32Array) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i in range(samples.size()):
		bytes.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32767.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = bytes
	return w
