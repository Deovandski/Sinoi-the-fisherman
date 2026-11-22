class_name Blip
extends RefCounted
## Placeholder sound effects made in code (a metronome tick, a hit, a miss),
## so the rhythm modes have audio before real sounds exist.

const RATE := 22050

const SOUNDS := {
	"tick": [1320.0, 0.04, 0.30, true],
	"tock": [880.0, 0.06, 0.35, true],
	"hit": [1760.0, 0.05, 0.22, false],
	"miss": [180.0, 0.12, 0.30, true],
	"catch": [1040.0, 0.25, 0.25, false],
}


static func build_all() -> Dictionary:
	var out := {}
	for sound in SOUNDS:
		var s: Array = SOUNDS[sound]
		out[sound] = make(s[0], s[1], s[2], s[3])
	return out


## A short tone that fades out. `square` gives a chiptune edge.
static func make(freq: float, length: float, volume: float, square: bool) -> AudioStreamWAV:
	var count := int(RATE * length)
	var data := PackedByteArray()
	data.resize(count * 2)
	for i in count:
		var t := float(i) / RATE
		var wave := sin(TAU * freq * t)
		if square:
			wave = signf(wave) * 0.6
		var fade := 1.0 - float(i) / count
		var attack := minf(1.0, float(i) / 40.0)
		data.encode_s16(i * 2, int(clampf(wave * fade * fade * attack * volume, -1.0, 1.0) * 32767.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = RATE
	stream.stereo = false
	stream.data = data
	return stream
