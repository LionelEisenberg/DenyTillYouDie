extends Node
## Sound effects synthesized in code (no audio files), rendered on a worker
## thread at startup. play() of an unknown name, or of a sound still rendering,
## is a silent no-op, so other code may call any name in NAMES at any time.
## The static DSP helpers at the bottom are thread-safe; Ambience uses them too.

## Emitted by play() for every known sound name, even while muted or rendering.
signal played(sound_name: String)
## Emitted once, when every sound has been rendered.
signal rendered

enum Filter { NONE, LOW, HIGH, BAND }

const RATE := 22050
const VOICES := 16
const BUSES: PackedStringArray = ["SFX", "Ambience", "Music"]
## Every sound other code may play, in render order: the opening minute first.
const NAMES: PackedStringArray = [
	"stamp", "clack", "typewriter", "pen_scratch", "handset", "card_tick", "paper",
	"click", "bell", "buzz", "ding", "cash", "paper_pick", "paper_drop", "page",
	"step", "voice_low", "voice_mid", "voice_high", "chime", "relay", "tick",
	"switch_on", "switch_off", "chunk", "printer", "flicker", "breaker",
	"stamp_heavy", "thwap", "rumble", "shutter_up", "shutter_down", "lamp_click",
	"ratchet", "tone_low",
]
## Sounds rendered in several takes; play() picks one at random.
const TAKES := {
	"clack": 2, "typewriter": 4, "paper_pick": 2, "step": 3,
	"voice_low": 4, "voice_mid": 4, "voice_high": 4,
}

## Silences this player only. Settings mutes the Master bus instead.
var muted: bool = false
var _streams: Dictionary = {} ## name -> Array of AudioStreamWAV takes
var _players: Array[AudioStreamPlayer] = []
var _next := 0
var _rng := RandomNumberGenerator.new()
var _task := -1
var _ready_all := false
## Rendered sounds handed over by the worker: [name, Array[PackedByteArray]].
var _inbox: Array = []
var _inbox_lock := Mutex.new()


func _ready() -> void:
	# Menu clicks must still sound while the Esc menu pauses the tree.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rng.seed = 7
	ensure_buses()
	for i in VOICES:
		var p := AudioStreamPlayer.new()
		p.volume_db = -8.0
		p.bus = "SFX"
		add_child(p)
		_players.append(p)
	# One sound per group element, spread over the pool's threads.
	_task = WorkerThreadPool.add_group_task(_render_one, NAMES.size(), -1, true, "Sfx")


func _process(_delta: float) -> void:
	_collect()
	if _task != -1 and WorkerThreadPool.is_group_task_completed(_task):
		WorkerThreadPool.wait_for_group_task_completion(_task)
		_task = -1
		_collect()
		_ready_all = true
		set_process(false)
		rendered.emit()


func _exit_tree() -> void:
	if _task != -1:
		WorkerThreadPool.wait_for_group_task_completion(_task)
		_task = -1
	hush(_players)


## Stops `players` and, if any of them ever played, gives the audio thread a
## moment to let go of their playbacks, so quitting mid-sound (the QUIT
## button's own clack) leaks nothing. Only for shutdown: it blocks briefly.
static func hush(players: Array) -> void:
	var used := false
	for p: AudioStreamPlayer in players:
		used = used or p.stream != null
		p.stop()
	if used:
		OS.delay_msec(80)


func play(sound_name: String) -> void:
	if not NAMES.has(sound_name):
		return
	played.emit(sound_name)
	var takes: Array = _streams.get(sound_name, [])
	if muted or takes.is_empty():
		return
	var p := _players[_next]
	_next = (_next + 1) % _players.size()
	p.stream = takes[_rng.randi() % takes.size()]
	p.pitch_scale = _rng.randf_range(0.95, 1.05)
	p.play()


## True once every sound has been rendered.
func is_ready() -> bool:
	return _ready_all


func sound_names() -> PackedStringArray:
	return NAMES


## The first take of a rendered sound, or null.
func get_stream(sound_name: String) -> AudioStreamWAV:
	var takes: Array = _streams.get(sound_name, [])
	return takes[0] if not takes.is_empty() else null


## Adds the SFX, Ambience and Music buses (each sending to Master) if missing.
static func ensure_buses() -> void:
	for bus_name in BUSES:
		if AudioServer.get_bus_index(bus_name) != -1:
			continue
		var idx := AudioServer.bus_count
		AudioServer.add_bus(idx)
		AudioServer.set_bus_name(idx, bus_name)
		AudioServer.set_bus_send(idx, "Master")


# --- rendering (worker thread) -------------------------------------------------

## Renders NAMES[index], every take, and hands it to the main thread.
func _render_one(index: int) -> void:
	var sound_name := NAMES[index]
	var takes: Array[PackedByteArray] = []
	for take in int(TAKES.get(sound_name, 1)):
		takes.append(pcm16(render(sound_name, take)))
	_inbox_lock.lock()
	_inbox.append([sound_name, takes])
	_inbox_lock.unlock()


## Wraps what the worker has finished so far (main thread).
func _collect() -> void:
	_inbox_lock.lock()
	var batch := _inbox
	_inbox = []
	_inbox_lock.unlock()
	for entry: Array in batch:
		var wavs: Array[AudioStreamWAV] = []
		for pcm: PackedByteArray in entry[1]:
			wavs.append(make_wav(pcm, RATE))
		_streams[entry[0]] = wavs


## One take of a sound as samples at RATE. Pure: safe on any thread.
static func render(sound_name: String, take: int = 0) -> PackedFloat32Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([sound_name, take])
	match sound_name:
		"stamp": return _legacy_stamp()
		"paper": return _legacy_paper()
		"bell": return _legacy_bell()
		"buzz": return _legacy_buzz()
		"click": return _legacy_click()
		"ding": return _legacy_ding()
		"cash": return _legacy_cash()
		"clack": return _clack(rng, take)
		"typewriter": return _typewriter(rng, take)
		"pen_scratch": return _pen_scratch(rng)
		"handset": return _handset(rng)
		"card_tick": return _card_tick(rng)
		"paper_pick": return _paper_pick(rng, take)
		"paper_drop": return _paper_drop(rng)
		"page": return _page(rng)
		"step": return _step(rng, take)
		"voice_low": return _voice(rng, take, 0)
		"voice_mid": return _voice(rng, take, 1)
		"voice_high": return _voice(rng, take, 2)
		"chime": return _chime()
		"relay": return _relay(rng)
		"tick": return _tick(rng)
		"switch_on": return _switch(rng, true)
		"switch_off": return _switch(rng, false)
		"chunk": return _chunk(rng)
		"printer": return _printer(rng)
		"flicker": return _flicker(rng)
		"breaker": return _breaker(rng)
		"stamp_heavy": return _stamp_heavy(rng)
		"thwap": return _thwap(rng)
		"rumble": return _rumble(rng)
		"shutter_up": return _shutter(rng, true)
		"shutter_down": return _shutter(rng, false)
		"lamp_click": return _lamp_click(rng)
		"ratchet": return _ratchet(rng)
		"tone_low": return _tone_low()
	return PackedFloat32Array()


# --- the original seven (same formulas, same output) ---------------------------

static func _legacy_stamp() -> PackedFloat32Array:
	var noise := _legacy_noise()
	var b := zeros(int(0.22 * RATE))
	var lp := 0.0
	for i in b.size():
		var t := float(i) / RATE
		var thump := sin(TAU * 70.0 * t) * exp(-t * 18.0)
		lp = lerpf(lp, noise.randf_range(-1.0, 1.0), 0.15)
		b[i] = clampf((thump * 0.9 + lp * 0.8) * exp(-t * 28.0) * 1.4, -1.0, 1.0)
	return b


static func _legacy_paper() -> PackedFloat32Array:
	var noise := _legacy_noise()
	var length := 0.28
	var b := zeros(int(length * RATE))
	var lp := 0.0
	for i in b.size():
		var t := float(i) / RATE
		var env := sin(PI * t / length) * (0.6 + 0.4 * sin(TAU * 18.0 * t))
		lp = lerpf(lp, noise.randf_range(-1.0, 1.0), 0.5)
		b[i] = clampf((noise.randf_range(-1.0, 1.0) - lp) * env * 0.35, -1.0, 1.0)
	return b


static func _legacy_bell() -> PackedFloat32Array:
	var b := zeros(int(0.9 * RATE))
	for i in b.size():
		var t := float(i) / RATE
		var v := sin(TAU * 1320.0 * t) * 0.5 + sin(TAU * 1980.0 * t) * 0.25 + sin(TAU * 2640.0 * t) * 0.12
		b[i] = clampf(v * exp(-t * 4.5) * 0.6, -1.0, 1.0)
	return b


static func _legacy_buzz() -> PackedFloat32Array:
	var length := 0.25
	var b := zeros(int(length * RATE))
	for i in b.size():
		var t := float(i) / RATE
		var square := 1.0 if fmod(t * 110.0, 1.0) < 0.5 else -1.0
		b[i] = square * 0.25 * (1.0 - t / length)
	return b


static func _legacy_click() -> PackedFloat32Array:
	var noise := _legacy_noise()
	var b := zeros(int(0.05 * RATE))
	for i in b.size():
		b[i] = noise.randf_range(-1.0, 1.0) * exp(-float(i) / RATE * 200.0) * 0.6
	return b


static func _legacy_ding() -> PackedFloat32Array:
	var b := zeros(int(0.5 * RATE))
	for i in b.size():
		var t := float(i) / RATE
		b[i] = (sin(TAU * 880.0 * t) + 0.4 * sin(TAU * 1760.0 * t)) * exp(-t * 7.0) * 0.4
	return b


static func _legacy_cash() -> PackedFloat32Array:
	var b := zeros(int(0.22 * RATE))
	for i in b.size():
		var t := float(i) / RATE
		var freq := 1568.0 if t < 0.08 else 2093.0
		b[i] = sin(TAU * freq * t) * exp(-fmod(t, 0.08) * 30.0) * 0.35
	return b


static func _legacy_noise() -> RandomNumberGenerator:
	var noise := RandomNumberGenerator.new()
	noise.seed = 11
	return noise


# --- desk and paper ----------------------------------------------------------------

## A button press: a dry plastic key, quiet enough to hear on every click.
static func _clack(rng: RandomNumberGenerator, take: int) -> PackedFloat32Array:
	var b := zeros(frames(0.06))
	mix(b, burst(0.01, 900.0, rng, Filter.HIGH, 2500.0), 0.5)
	mix(b, ring(0.06, 1350.0 + 90.0 * take, 140.0), 0.35)
	mix(b, ring(0.06, 245.0, 90.0), 0.4)
	return finish(b, 0.22)


## Picking up a sheet: a quick rustle with a couple of crinkles.
static func _paper_pick(rng: RandomNumberGenerator, take: int) -> PackedFloat32Array:
	var dur := 0.16
	var b := zeros(frames(dur))
	var rustle := biquad(white(frames(dur), rng), Filter.BAND, 3600.0 + 400.0 * take, 0.8)
	mix(b, envelope(rustle, 0.006, 32.0), 1.0)
	for k in 3:
		mix(b, burst(0.02, 260.0, rng, Filter.HIGH, 4000.0), 0.6 - 0.15 * k, 0.012 + 0.03 * k + rng.randf_range(0.0, 0.01))
	return finish(b, 0.2)


## Setting a sheet down: a puff of air, then a soft tap on the desk.
static func _paper_drop(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var b := zeros(frames(0.24))
	var air := biquad(white(frames(0.08), rng), Filter.LOW, 1400.0, 0.7)
	mix(b, window(air, 1.0), 0.5)
	mix(b, burst(0.12, 55.0, rng, Filter.LOW, 520.0), 1.0, 0.07)
	mix(b, ring(0.12, 105.0, 45.0), 0.5, 0.07)
	mix(b, burst(0.17, 22.0, rng, Filter.HIGH, 3000.0), 0.14, 0.07)
	return finish(b, 0.25)


## A plastic member card tapping the desk.
static func _card_tick(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var b := zeros(frames(0.06))
	mix(b, burst(0.01, 1500.0, rng, Filter.HIGH, 3000.0), 0.6)
	mix(b, ring(0.06, 2400.0, 220.0), 0.5)
	mix(b, ring(0.06, 4750.0, 300.0), 0.25)
	return finish(b, 0.25)


## Turning a page of the manual: a swish that rises in pitch, then the flap.
static func _page(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var b := zeros(frames(0.32))
	var swish := biquad_sweep(white(frames(0.24), rng), Filter.BAND, 1200.0, 3600.0, 1.1)
	mix(b, window(swish, 1.5), 1.0)
	mix(b, burst(0.06, 110.0, rng, Filter.LOW, 900.0), 0.55, 0.22)
	return finish(b, 0.2)


## A typewriter key: the typebar's crack, a metallic ring and the carriage thunk.
static func _typewriter(rng: RandomNumberGenerator, take: int) -> PackedFloat32Array:
	var f := 3100.0 * (1.0 + 0.04 * (take - 1.5))
	var b := zeros(frames(0.09))
	mix(b, burst(0.006, 1200.0, rng, Filter.HIGH, 3000.0), 0.7)
	mix(b, ring(0.09, f, 140.0), 0.4)
	mix(b, ring(0.09, f * 1.68, 180.0), 0.25)
	mix(b, ring(0.09, 170.0 + 10.0 * take, 60.0), 0.5)
	mix(b, burst(0.04, 80.0, rng, Filter.LOW, 600.0), 0.3)
	return finish(b, 0.28)


## A ballpoint signature: six quick strokes of scratchy paper grain.
static func _pen_scratch(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var n := frames(0.5)
	var grain := biquad(white(n, rng), Filter.BAND, 3800.0, 1.2)
	var fiber := normalized(biquad(white(n, rng), Filter.LOW, 60.0, 0.7))
	var hiss := biquad(white(n, rng), Filter.HIGH, 6000.0, 0.7)
	var strokes: Array[Vector2] = [
		Vector2(0.0, 0.07), Vector2(0.08, 0.09), Vector2(0.18, 0.06),
		Vector2(0.25, 0.10), Vector2(0.36, 0.05), Vector2(0.42, 0.07),
	]
	var env := zeros(n)
	for s in strokes:
		var gain := rng.randf_range(0.6, 1.0)
		var i0 := int(s.x * RATE)
		var len_i := int(s.y * RATE)
		for k in len_i:
			if i0 + k >= n:
				break
			var u := float(k) / len_i
			env[i0 + k] += pow(4.0 * u * (1.0 - u), 0.8) * gain
	var b := zeros(n)
	for i in n:
		b[i] = (grain[i] * (0.6 + 0.4 * fiber[i]) + hiss[i] * 0.2) * env[i]
	return finish(b, 0.13)


## A telephone handset set down hard: the knock, a rattle, the hook switch.
static func _handset(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var b := zeros(frames(0.4))
	for hit: Vector3 in [Vector3(0.0, 1.0, 1.0), Vector3(0.035, 0.4, 1.07)]:
		mix(b, ring(0.2, 520.0 * hit.z, 60.0), 0.6 * hit.y, hit.x)
		mix(b, ring(0.15, 1350.0 * hit.z, 90.0), 0.35 * hit.y, hit.x)
		mix(b, burst(0.08, 100.0, rng, Filter.LOW, 1800.0), 0.6 * hit.y, hit.x)
	mix(b, burst(0.01, 1500.0, rng, Filter.HIGH, 3000.0), 0.4, 0.075)
	mix(b, ring(0.05, 3200.0, 350.0), 0.3, 0.075)
	return finish(b, 0.4)


## A footstep on the tile floor beyond the glass: heel, then toe, muffled.
static func _step(rng: RandomNumberGenerator, take: int) -> PackedFloat32Array:
	var b := zeros(frames(0.17))
	mix(b, burst(0.1, 70.0, rng, Filter.LOW, 700.0), 1.0)
	mix(b, ring(0.1, 85.0 + 7.0 * take, 45.0), 0.8)
	mix(b, burst(0.08, 90.0, rng, Filter.LOW, 900.0), 0.45, 0.045 + 0.01 * take)
	return finish(biquad(b, Filter.LOW, 1100.0, 0.7), 0.22)


## A 60 ms breathy syllable heard through the glass: noise and a little voice
## through two vowel formants, low-passed. Never a word. register 0 low, 1 mid, 2 high.
static func _voice(rng: RandomNumberGenerator, take: int, register: int) -> PackedFloat32Array:
	var vowels: Array[Vector2] = [Vector2(650, 1080), Vector2(480, 1720), Vector2(520, 880), Vector2(360, 900)]
	var formant_scale: float = [1.0, 1.17, 1.35][register]
	var f0: float = [110.0, 185.0, 285.0][register]
	var n := frames(0.06)
	var src := zeros(n)
	var phase := 0.0
	for i in n:
		phase = fmod(phase + f0 * (1.0 - 0.06 * i / n) / RATE, 1.0)
		src[i] = rng.randf_range(-1.0, 1.0) * 0.8 + (2.0 * phase - 1.0) * 0.35
	var v := vowels[take % vowels.size()] * formant_scale
	var formants := biquad(src, Filter.BAND, v.x, 5.0)
	mix(formants, biquad(src, Filter.BAND, v.y, 7.0), 0.6)
	var glass := biquad(biquad(formants, Filter.LOW, 1100.0, 0.7), Filter.LOW, 1100.0, 0.7)
	return finish(window(glass, 1.3), 0.1)


# --- booth, board and building ------------------------------------------------------

## The two-tone PA chime over the ceiling speaker.
static func _chime() -> PackedFloat32Array:
	var dur := 1.5
	var b := zeros(frames(dur))
	for tone: Vector2 in [Vector2(659.25, 0.0), Vector2(523.25, 0.42)]:
		var note := zeros(frames(dur - tone.y))
		for i in note.size():
			var t := float(i) / RATE
			note[i] = sin(TAU * tone.x * t) + 0.25 * sin(TAU * 2.0 * tone.x * t) + 0.08 * sin(TAU * 3.0 * tone.x * t)
		mix(b, envelope(note, 0.005, 3.2), 1.0, tone.y)
	b = biquad(biquad(b, Filter.HIGH, 350.0, 0.7), Filter.LOW, 3800.0, 0.7)
	return finish(saturate(b, 1.5), 0.3)


## A relay clicking in the NOW SERVING board.
static func _relay(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var b := zeros(frames(0.035))
	mix(b, burst(0.005, 2500.0, rng, Filter.HIGH, 3000.0), 0.6)
	mix(b, ring(0.035, 3500.0, 500.0), 0.5)
	mix(b, ring(0.035, 900.0, 300.0), 0.4)
	return finish(b, 0.18)


## A counter wheel ticking over a dollar.
static func _tick(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var b := zeros(frames(0.03))
	mix(b, burst(0.005, 2000.0, rng, Filter.HIGH, 3000.0), 0.5)
	mix(b, ring(0.03, 1900.0, 350.0), 0.5)
	return finish(b, 0.15)


## A wall switch: on snaps bright, off lands lower.
static func _switch(rng: RandomNumberGenerator, on: bool) -> PackedFloat32Array:
	var hi := 2900.0 if on else 2250.0
	var second := 0.012 if on else 0.009
	var b := zeros(frames(0.08))
	mix(b, burst(0.008, 2000.0, rng, Filter.HIGH, 3500.0), 0.6 if on else 0.35)
	mix(b, ring(0.05, hi, 260.0), 0.5 if on else 0.3)
	mix(b, burst(0.008, 2200.0, rng, Filter.HIGH, 3500.0), 0.25 if on else 0.6, second)
	mix(b, ring(0.04, hi * (1.17 if on else 0.85), 400.0), 0.2 if on else 0.45, second)
	mix(b, ring(0.05, 185.0, 120.0), 0.2)
	return finish(b, 0.3)


## The time clock punching a card: a heavy thud and a metal clank.
static func _chunk(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var dur := 0.32
	var b := zeros(frames(dur))
	mix(b, chirp(dur, 95.0, 55.0, 22.0), 1.0)
	for partial: Vector3 in [Vector3(560, 28, 0.5), Vector3(1460, 40, 0.35), Vector3(2350, 55, 0.25)]:
		mix(b, ring(dur, partial.x, partial.y), partial.z, 0.004)
	mix(b, burst(0.03, 300.0, rng, Filter.LOW, 3000.0), 0.6)
	return finish(b, 0.5)


## The citation printer: four chopped square-wave lines, each followed by the
## paper jerking forward (0.0, 0.2, 0.4 and 0.6 s).
static func _printer(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var b := zeros(frames(0.8))
	var pitches: Array[float] = [520.0, 560.0, 500.0, 540.0]
	for k in 4:
		var at := 0.2 * k
		var n := frames(0.11)
		var head := zeros(n)
		var pins := biquad(white(n, rng), Filter.BAND, 3000.0, 1.0)
		for i in n:
			var t := float(i) / RATE
			var gate := 1.0 if fmod(t * 70.0, 1.0) < 0.6 else 0.0
			head[i] = (1.0 if fmod(t * pitches[k], 1.0) < 0.5 else -1.0) * gate
			pins[i] *= gate
		mix(b, biquad(head, Filter.LOW, 2600.0, 0.7), 0.35, at)
		mix(b, pins, 0.25, at)
		mix(b, ring(0.06, 300.0, 80.0), 0.5, at + 0.13)
		mix(b, burst(0.05, 150.0, rng, Filter.LOW, 1200.0), 0.4, at + 0.13)
	return finish(b, 0.22)


## Fluorescent tubes stuttering: three dropouts, buzzing and clicking at each edge.
static func _flicker(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var dur := 0.55
	var n := frames(dur)
	var spans: Array[Vector2] = [Vector2(0.0, 0.05), Vector2(0.16, 0.22), Vector2(0.33, 0.38), Vector2(0.47, 0.55)]
	var buzz := biquad(saw(dur, 120.0, 12), Filter.LOW, 2500.0, 0.7)
	var ramp := int(0.003 * RATE)
	for i in n:
		var t := float(i) / RATE
		var g := 0.0
		for s in spans:
			if t >= s.x and t < s.y:
				var into := mini(i - int(s.x * RATE), int(s.y * RATE) - i)
				g = minf(1.0, float(into) / ramp)
		buzz[i] *= g
	var b := zeros(n)
	mix(b, buzz, 0.6)
	for s in spans:
		for edge: float in [s.x, s.y]:
			if edge < dur - 0.02:
				mix(b, burst(0.02, 800.0, rng, Filter.HIGH, 2000.0), 0.5, edge)
				mix(b, ring(0.02, 2200.0, 300.0), 0.25, edge)
	return finish(b, 0.3)


## A breaker tripping: a clunk, a crackle, and the hum dying away.
static func _breaker(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var dur := 0.5
	var b := zeros(frames(dur))
	mix(b, ring(dur, 75.0, 25.0), 1.0)
	mix(b, ring(dur, 720.0, 45.0), 0.35)
	mix(b, ring(dur, 1900.0, 70.0), 0.2)
	mix(b, burst(0.1, 120.0, rng, Filter.LOW, 2500.0), 0.5)
	var hum := zeros(frames(0.45))
	var phase := 0.0
	for i in hum.size():
		var u := float(i) / hum.size()
		phase += lerpf(120.0, 100.0, u) / RATE
		var v := 0.0
		for k in range(1, 7):
			v += sin(TAU * k * phase) / k
		hum[i] = v * exp(-8.0 * float(i) / RATE)
	mix(b, hum, 0.25, 0.02)
	for k in 5:
		mix(b, burst(0.006, 1500.0, rng, Filter.HIGH, 2500.0), rng.randf_range(0.1, 0.25), rng.randf_range(0.02, 0.15))
	return finish(b, 0.45)


## The last stamp of the week: lower and longer than the usual one.
static func _stamp_heavy(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var dur := 0.5
	var b := zeros(frames(dur))
	mix(b, chirp(dur, 58.0, 44.0, 9.0), 1.0)
	mix(b, burst(0.3, 25.0, rng, Filter.LOW, 300.0), 0.7)
	mix(b, burst(0.06, 90.0, rng, Filter.LOW, 2000.0), 0.5)
	mix(b, ring(0.2, 160.0, 30.0), 0.4)
	return finish(b, 0.7)


## A folded newspaper landing on the kitchen table.
static func _thwap(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var b := zeros(frames(0.36))
	mix(b, burst(0.06, 90.0, rng, Filter.LOW, 6000.0, 0.7, 0.001), 1.0)
	mix(b, burst(0.2, 25.0, rng, Filter.LOW, 350.0), 0.8)
	mix(b, burst(0.3, 12.0, rng, Filter.HIGH, 2500.0), 0.25, 0.02)
	return finish(b, 0.45)


## A low swell from the street, for discontent crossing a line.
static func _rumble(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var dur := 1.3
	var n := frames(dur)
	var b := biquad(biquad(white(n, rng), Filter.LOW, 140.0, 0.7), Filter.LOW, 140.0, 0.7)
	b = normalized(b)
	mix(b, ring(dur, 42.0, 0.0), 0.4)
	for i in n:
		var t := float(i) / RATE
		var env := smoothstep(0.0, 0.3, t)
		if t > 0.5:
			env *= exp(-3.0 * (t - 0.5))
		b[i] *= env
	return finish(b, 0.45)


## The booth shutter rattling up (or down): slat after slat, then the stop.
static func _shutter(rng: RandomNumberGenerator, up: bool) -> PackedFloat32Array:
	var dur := 0.75
	var n := frames(dur)
	var b := zeros(n)
	var end := 0.64
	var t := 0.02
	while t < end:
		var u := t / end
		var j := lerpf(0.95, 1.08, u) if up else lerpf(1.06, 0.94, u)
		var g := 0.5 + 0.5 * rng.randf()
		mix(b, ring(0.03, 900.0 * j, 120.0), 0.5 * g, t)
		mix(b, ring(0.03, 2300.0 * j, 160.0), 0.3 * g, t)
		mix(b, ring(0.02, 3700.0 * j, 220.0), 0.15 * g, t)
		mix(b, burst(0.01, 400.0, rng, Filter.LOW, 4000.0), 0.4 * g, t)
		t += (lerpf(0.040, 0.028, u) if up else lerpf(0.028, 0.040, u)) * rng.randf_range(0.85, 1.15)
	var roll := biquad(white(frames(end), rng), Filter.LOW, 220.0, 0.7)
	mix(b, window(normalized(roll), 1.0), 0.3)
	if up:
		mix(b, ring(0.09, 140.0, 40.0), 0.6, 0.66)
		mix(b, ring(0.09, 600.0, 60.0), 0.35, 0.66)
	else:
		mix(b, ring(0.09, 90.0, 30.0), 1.0, 0.66)
		mix(b, burst(0.09, 60.0, rng, Filter.LOW, 900.0), 0.7, 0.66)
		mix(b, ring(0.09, 450.0, 50.0), 0.4, 0.66)
	return finish(b, 0.35)


## The desk lamp's switch at night.
static func _lamp_click(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var b := zeros(frames(0.08))
	mix(b, burst(0.006, 1800.0, rng, Filter.HIGH, 3500.0), 0.6)
	mix(b, ring(0.04, 3800.0, 400.0), 0.4)
	mix(b, ring(0.03, 2600.0, 500.0), 0.25, 0.03)
	mix(b, burst(0.005, 2500.0, rng, Filter.HIGH, 3500.0), 0.2, 0.03)
	mix(b, ring(0.05, 220.0, 150.0), 0.2)
	return finish(b, 0.3)


## An adding machine printing a line: three ratchet clicks and the carriage.
static func _ratchet(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var b := zeros(frames(0.16))
	for k in 3:
		mix(b, ring(0.03, 2600.0, 380.0), 0.5, 0.028 * k)
		mix(b, burst(0.006, 1500.0, rng, Filter.HIGH, 3000.0), 0.5, 0.028 * k)
	mix(b, ring(0.07, 380.0, 70.0), 0.7, 0.085)
	mix(b, burst(0.04, 120.0, rng, Filter.LOW, 1500.0), 0.5, 0.085)
	mix(b, ring(0.05, 1100.0, 90.0), 0.25, 0.085)
	return finish(b, 0.3)


## A low, muted tone for bad news on the ledger.
static func _tone_low() -> PackedFloat32Array:
	var b := zeros(frames(0.6))
	for i in b.size():
		var t := float(i) / RATE
		b[i] = sin(TAU * 196.0 * t) + 0.3 * sin(TAU * 392.0 * t) + 0.08 * sin(TAU * 588.0 * t)
	return finish(envelope(b, 0.025, 4.0), 0.22)


# --- DSP helpers (static and thread-safe) ---------------------------------------------

static func frames(seconds: float, rate: int = RATE) -> int:
	return maxi(1, int(seconds * rate))


## n samples of silence.
static func zeros(n: int) -> PackedFloat32Array:
	var b := PackedFloat32Array()
	b.resize(maxi(n, 1))
	b.fill(0.0)
	return b


static func white(n: int, rng: RandomNumberGenerator) -> PackedFloat32Array:
	var b := PackedFloat32Array()
	b.resize(n)
	for i in n:
		b[i] = rng.randf_range(-1.0, 1.0)
	return b


## Adds src * gain into dst, starting `at` seconds in. Changes dst and returns it.
static func mix(dst: PackedFloat32Array, src: PackedFloat32Array, gain: float = 1.0, at: float = 0.0, rate: int = RATE) -> PackedFloat32Array:
	var o := int(at * rate)
	for i in mini(src.size(), dst.size() - o):
		dst[o + i] += src[i] * gain
	return dst


## A struck resonance: a sine at `freq` decaying by `decay` per second.
static func ring(seconds: float, freq: float, decay: float, rate: int = RATE) -> PackedFloat32Array:
	var b := zeros(frames(seconds, rate))
	var w := TAU * freq / rate
	var k := exp(-decay / rate)
	var a := 1.0
	for i in b.size():
		b[i] = sin(w * i) * a
		a *= k
	return b


## A sine gliding exponentially from f0 to f1 while it decays: a thud.
static func chirp(seconds: float, f0: float, f1: float, decay: float, rate: int = RATE) -> PackedFloat32Array:
	var b := zeros(frames(seconds, rate))
	var phase := 0.0
	var k := exp(-decay / rate)
	var a := 1.0
	for i in b.size():
		phase += f0 * pow(f1 / f0, float(i) / b.size()) / rate
		b[i] = sin(TAU * phase) * a
		a *= k
	return b


## A band-limited sawtooth: `harmonics` partials of `freq`, steady.
static func saw(seconds: float, freq: float, harmonics: int, rate: int = RATE) -> PackedFloat32Array:
	var b := zeros(frames(seconds, rate))
	for i in b.size():
		var w := TAU * freq * i / rate
		var v := 0.0
		for k in range(1, harmonics + 1):
			v += sin(w * k) / k
		b[i] = v
	return b


## White noise, optionally filtered, with an attack and an exponential decay.
static func burst(seconds: float, decay: float, rng: RandomNumberGenerator, kind: Filter = Filter.NONE, freq: float = 1000.0, q: float = 0.7, attack: float = 0.0, rate: int = RATE) -> PackedFloat32Array:
	var b := white(frames(seconds, rate), rng)
	if kind != Filter.NONE:
		b = biquad(b, kind, freq, q, rate)
	return envelope(b, attack, decay, rate)


## Multiplies buf by a linear attack, then an exponential decay. Changes and returns it.
static func envelope(buf: PackedFloat32Array, attack: float, decay: float, rate: int = RATE) -> PackedFloat32Array:
	var na := int(attack * rate)
	var k := exp(-decay / rate)
	var a := 1.0
	for i in buf.size():
		if i < na:
			buf[i] *= float(i) / na
		else:
			buf[i] *= a
			a *= k
	return buf


## Multiplies buf by a sine window raised to `power`. Changes and returns it.
static func window(buf: PackedFloat32Array, power: float) -> PackedFloat32Array:
	for i in buf.size():
		buf[i] *= pow(sin(PI * float(i) / buf.size()), power)
	return buf


## A soft clip (tanh), keeping the level. Changes and returns buf.
static func saturate(buf: PackedFloat32Array, drive: float) -> PackedFloat32Array:
	for i in buf.size():
		buf[i] = tanh(buf[i] * drive) / drive
	return buf


## Scales buf in place so its loudest sample is 1. Returns it.
static func normalized(buf: PackedFloat32Array) -> PackedFloat32Array:
	var top := 0.0
	for v in buf:
		top = maxf(top, absf(v))
	if top > 0.0:
		for i in buf.size():
			buf[i] /= top
	return buf


## Scales buf so its RMS is `target`, never letting a peak pass 0.95. Returns it.
static func normalize_rms(buf: PackedFloat32Array, target: float) -> PackedFloat32Array:
	var sum := 0.0
	var top := 0.0
	for v in buf:
		sum += v * v
		top = maxf(top, absf(v))
	if sum <= 0.0:
		return buf
	var g := minf(target / sqrt(sum / buf.size()), 0.95 / top)
	for i in buf.size():
		buf[i] *= g
	return buf


## Scales buf so its loudest sample is `peak`, with short fades at both ends so
## nothing clicks. Changes and returns it.
static func finish(buf: PackedFloat32Array, peak: float, rate: int = RATE) -> PackedFloat32Array:
	normalized(buf)
	var fade_in := maxi(1, int(0.0007 * rate))
	var fade_out := maxi(1, int(0.004 * rate))
	var n := buf.size()
	for i in n:
		var g := peak
		if i < fade_in:
			g *= float(i) / fade_in
		if n - 1 - i < fade_out:
			g *= float(n - 1 - i) / fade_out
		buf[i] *= g
	return buf


## A 12 dB/octave RBJ biquad over the whole buffer, into a new buffer.
static func biquad(src: PackedFloat32Array, kind: Filter, freq: float, q: float, rate: int = RATE) -> PackedFloat32Array:
	var c := coefficients(kind, freq, q, rate)
	var b0 := c[0]
	var b1 := c[1]
	var b2 := c[2]
	var a1 := c[3]
	var a2 := c[4]
	var out := PackedFloat32Array()
	out.resize(src.size())
	var x1 := 0.0
	var x2 := 0.0
	var y1 := 0.0
	var y2 := 0.0
	for i in src.size():
		var x := src[i]
		var y := b0 * x + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2
		x2 = x1
		x1 = x
		y2 = y1
		y1 = y
		out[i] = y
	return out


## biquad() with the frequency gliding exponentially from f0 to f1.
static func biquad_sweep(src: PackedFloat32Array, kind: Filter, f0: float, f1: float, q: float, rate: int = RATE) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(src.size())
	var x1 := 0.0
	var x2 := 0.0
	var y1 := 0.0
	var y2 := 0.0
	var c := PackedFloat64Array()
	for i in src.size():
		if i % 32 == 0:
			c = coefficients(kind, f0 * pow(f1 / f0, float(i) / src.size()), q, rate)
		var x := src[i]
		var y := c[0] * x + c[1] * x1 + c[2] * x2 - c[3] * y1 - c[4] * y2
		x2 = x1
		x1 = x
		y2 = y1
		y1 = y
		out[i] = y
	return out


## RBJ cookbook coefficients [b0, b1, b2, a1, a2], divided by a0. BAND has 0 dB peak gain.
static func coefficients(kind: Filter, freq: float, q: float, rate: int) -> PackedFloat64Array:
	var w := TAU * clampf(freq, 10.0, rate * 0.45) / rate
	var cw := cos(w)
	var alpha := sin(w) / (2.0 * q)
	var a0 := 1.0 + alpha
	var b0 := alpha
	var b1 := 0.0
	var b2 := -alpha
	if kind == Filter.LOW:
		b0 = (1.0 - cw) * 0.5
		b1 = 1.0 - cw
		b2 = b0
	elif kind == Filter.HIGH:
		b0 = (1.0 + cw) * 0.5
		b1 = -(1.0 + cw)
		b2 = b0
	return PackedFloat64Array([b0 / a0, b1 / a0, b2 / a0, -2.0 * cw / a0, (1.0 - alpha) / a0])


## Samples as 16-bit PCM, clamped.
static func pcm16(buf: PackedFloat32Array) -> PackedByteArray:
	var data := PackedByteArray()
	data.resize(buf.size() * 2)
	for i in buf.size():
		data.encode_s16(i * 2, int(clampf(buf[i], -1.0, 1.0) * 32000.0))
	return data


## A mono 16-bit stream; loop_frames > 0 loops the first loop_frames forever.
static func make_wav(pcm: PackedByteArray, rate: int, loop_frames: int = 0) -> AudioStreamWAV:
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.stereo = false
	wav.data = pcm
	if loop_frames > 0:
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		wav.loop_end = loop_frames
	return wav
