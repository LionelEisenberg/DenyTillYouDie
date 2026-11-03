extends Node
## Sound effects synthesized at startup (no audio files): a stamp thud, paper
## shuffle, desk bell, buzzer, click, ding and cash-register blip.

const RATE := 22050
const VOICES := 8

var muted: bool = false
var _streams: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []
var _next := 0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.seed = 7
	_streams = {
		"stamp": _make(0.22, _stamp),
		"paper": _make(0.28, _paper),
		"bell": _make(0.9, _bell),
		"buzz": _make(0.25, _buzz),
		"click": _make(0.05, _click),
		"ding": _make(0.5, _ding),
		"cash": _make(0.22, _cash),
	}
	for i in VOICES:
		var p := AudioStreamPlayer.new()
		p.volume_db = -8.0
		add_child(p)
		_players.append(p)


func play(sound_name: String) -> void:
	if muted or not _streams.has(sound_name):
		return
	var p := _players[_next]
	_next = (_next + 1) % _players.size()
	p.stream = _streams[sound_name]
	p.pitch_scale = _rng.randf_range(0.95, 1.05)
	p.play()


func _make(seconds: float, voice: Callable) -> AudioStreamWAV:
	var frames := int(seconds * RATE)
	var data := PackedByteArray()
	data.resize(frames * 2)
	var noise := RandomNumberGenerator.new()
	noise.seed = 11
	var state := {"lp": 0.0}
	for i in frames:
		var t := float(i) / RATE
		var sample: float = clampf(voice.call(t, seconds, noise, state), -1.0, 1.0)
		data.encode_s16(i * 2, int(sample * 32000.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.stereo = false
	wav.data = data
	return wav


func _stamp(t: float, _len: float, noise: RandomNumberGenerator, state: Dictionary) -> float:
	var env := exp(-t * 28.0)
	var thump := sin(TAU * 70.0 * t) * exp(-t * 18.0)
	state["lp"] = lerpf(state["lp"], noise.randf_range(-1.0, 1.0), 0.15)
	return (thump * 0.9 + state["lp"] * 0.8) * env * 1.4


func _paper(t: float, length: float, noise: RandomNumberGenerator, state: Dictionary) -> float:
	var env := sin(PI * t / length) * (0.6 + 0.4 * sin(TAU * 18.0 * t))
	state["lp"] = lerpf(state["lp"], noise.randf_range(-1.0, 1.0), 0.5)
	return (noise.randf_range(-1.0, 1.0) - state["lp"]) * env * 0.35


func _bell(t: float, _len: float, _noise: RandomNumberGenerator, _state: Dictionary) -> float:
	var env := exp(-t * 4.5)
	return (sin(TAU * 1320.0 * t) * 0.5 + sin(TAU * 1980.0 * t) * 0.25 + sin(TAU * 2640.0 * t) * 0.12) * env * 0.6


func _buzz(t: float, length: float, _noise: RandomNumberGenerator, _state: Dictionary) -> float:
	var square := 1.0 if fmod(t * 110.0, 1.0) < 0.5 else -1.0
	return square * 0.25 * (1.0 - t / length)


func _click(t: float, _len: float, noise: RandomNumberGenerator, _state: Dictionary) -> float:
	return noise.randf_range(-1.0, 1.0) * exp(-t * 200.0) * 0.6


func _ding(t: float, _len: float, _noise: RandomNumberGenerator, _state: Dictionary) -> float:
	return (sin(TAU * 880.0 * t) + 0.4 * sin(TAU * 1760.0 * t)) * exp(-t * 7.0) * 0.4


func _cash(t: float, _len: float, _noise: RandomNumberGenerator, _state: Dictionary) -> float:
	var freq := 1568.0 if t < 0.08 else 2093.0
	return sin(TAU * freq * t) * exp(-fmod(t, 0.08) * 30.0) * 0.35
