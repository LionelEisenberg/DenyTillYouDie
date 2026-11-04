extends Node
## The building you work in, rendered in code: office room tone, the waiting
## room through the glass, the protest outside, the kitchen, the night, and the
## hold music on the title. Registered as the autoload "Ambience" (after Sfx).
##
## It follows the screens by class name as they enter the tree, so no screen
## has to know it exists. Beds render lazily on a worker thread as seamless
## loops. Nothing is rendered or played under the headless display server, but
## the scene and the waiting count are still tracked (tests read them, and can
## turn playback on with enable_playback() and hand it short streams).

## The hold music ducked for its chime; the title prints a line meanwhile.
signal hold_chime

const SfxLib := preload("res://autoload/sfx.gd")
const Filter := SfxLib.Filter

const RATE := 11025
const MUSIC_RATE := 8000
## Seconds rendered past each loop's end and folded back into its start.
const XFADE := 0.5
const HOLD_SECONDS := 24.0
const FADE := 1.2
## The picture cut to black with the desk still up (the day-7 cut): so does the room.
const CUT := 0.05
const DRAIN := 4.0
const POLL := 0.5
## The murmur is at full level with this many people waiting.
const FULL_ROOM := 8.0
## The memo is read in the same office, a little away from the window.
const MEMO_GAIN := 0.398 ## -8 dB
const CHIME_EVERY := 30.0
const DUCK_DB := -6.0
const DUCK_TIME := 0.3

## The scene each screen class plays. Unknown screens leave the scene alone.
const SCENES := {
	"TitleScreen": "hold", "AgreementScreen": "hold",
	"MemoScreen": "memo", "DeskScreen": "desk",
	"NewspaperScreen": "kitchen", "LedgerScreen": "night",
	"EndingScreen": "silence", "DayCardScreen": "silence",
}
## Each looping layer and the bed it plays.
const LAYERS := {
	"hum": "office_hum", "hvac": "office_hvac",
	"murmur_a": "murmur_a", "murmur_b": "murmur_b", "protest": "protest",
	"house": "house", "rain": "rain", "music": "hold_music",
}
## Render order once the current scene's beds are queued (one-shots included).
const PREWARM: PackedStringArray = [
	"hold_music", "hold_chime", "office_hum", "office_hvac", "murmur_a", "murmur_b",
	"phone", "drawer", "cough", "house", "rain", "protest",
]

## The current scene: hold, memo, desk, kitchen, night or silence.
var scene_id: String = "silence"
## People still to come at the desk (never counting the player).
var waiting: int = 0
## The desk asked for quiet (the day-7 climax): everything drains to the hum.
var quiet: bool = false
var protest: bool = false

## Players exist and are mixed every frame.
var _audio := false
## Beds render on worker threads (off when a test hands over its own streams).
var _render := false
var _desk: WeakRef
var _targets: Dictionary = {}
var _gains: Dictionary = {}
var _rates: Dictionary = {}
var _players: Dictionary = {}
var _shot_player: AudioStreamPlayer
var _chime_player: AudioStreamPlayer
var _streams: Dictionary = {}
var _queue: PackedStringArray = []
var _task := -1
var _task_bed := ""
var _result: Dictionary = {}
var _result_lock := Mutex.new()
var _poll_left := POLL
var _shot_left := 30.0
var _hold_clock := 0.0
var _music_duck := 1.0
var _music_duck_t := -1.0
var _duck_left := 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rng.seed = 4471
	SfxLib.ensure_buses()
	var sfx := get_node_or_null("/root/Sfx")
	if sfx != null and sfx.has_signal("played"):
		sfx.connect("played", _on_sfx_played)
	get_tree().node_added.connect(_on_node_added)
	for layer: String in LAYERS:
		_targets[layer] = 0.0
		_gains[layer] = 0.0
		_rates[layer] = 1.0 / FADE
	if DisplayServer.get_name() != "headless":
		enable_playback(true)


## Makes the players and mixes them every frame. The game calls it with
## `render` at startup when there is a display; tests call it headless without,
## and hand over short streams with set_stream() instead of rendering beds.
func enable_playback(render: bool = false) -> void:
	_render = _render or render
	if _audio:
		return
	_audio = true
	for layer: String in LAYERS:
		var p := AudioStreamPlayer.new()
		p.bus = "Music" if layer == "music" else "Ambience"
		p.volume_db = -80.0
		add_child(p)
		_players[layer] = p
	_shot_player = AudioStreamPlayer.new()
	_shot_player.bus = "Ambience"
	add_child(_shot_player)
	_chime_player = AudioStreamPlayer.new()
	_chime_player.bus = "Music"
	add_child(_chime_player)
	_queue_beds()


## Hands over a rendered bed or one-shot (by its render_bed() name), as the
## worker does when it finishes one.
func set_stream(bed: String, stream: AudioStream) -> void:
	_streams[bed] = stream


func _exit_tree() -> void:
	if _task != -1:
		WorkerThreadPool.wait_for_task_completion(_task)
		_task = -1
	SfxLib.hush(get_children().filter(func(n: Node) -> bool: return n is AudioStreamPlayer))


func _process(delta: float) -> void:
	_poll_left -= delta
	if _poll_left <= 0.0:
		_poll_left = POLL
		poll()
	if not _audio:
		return
	if _render:
		_collect_render()
		_start_render()
	_mix_layers(delta)
	_run_duck(delta)
	_run_hold_chime(delta)
	_run_one_shots(delta)


## The scene a screen class plays, or "" for a screen this doesn't know.
static func scene_for(screen_class: String) -> String:
	return String(SCENES.get(screen_class, ""))


## People still to come at `desk`: claims after the current index that are not
## the player's own. Reads the desk's claims and index with get().
static func waiting_for(desk: Object) -> int:
	if desk == null or not is_instance_valid(desk):
		return 0
	var claims: Variant = desk.get("claims")
	var index: Variant = desk.get("index")
	if not (claims is Array) or not (index is int):
		return 0
	var count := 0
	var list: Array = claims
	for i in range(maxi(int(index) + 1, 0), list.size()):
		var c: Object = list[i]
		if c != null and not bool(c.get("is_player")):
			count += 1
	return count


## The level a layer is heading for (0 to 1), from the scene, the waiting room,
## the protest and the desk's quiet.
func target_gain(layer: String) -> float:
	return float(_targets.get(layer, 0.0))


## Beds rendered so far (always empty headless).
func rendered_beds() -> PackedStringArray:
	return PackedStringArray(_streams.keys())


## Switches to a scene over `fade` seconds. `screen` is the desk, when the
## scene is the desk.
func set_scene(id: String, screen: Node = null, fade: float = FADE) -> void:
	var was := scene_id
	scene_id = id
	_desk = weakref(screen) if id == "desk" and screen != null else null
	quiet = false
	protest = false
	if id == "hold" and was != "hold":
		_hold_clock = 0.0
		_gains["music"] = 0.0
		if _audio and _players["music"].playing:
			_players["music"].stop()
	if id == "desk":
		# The desk's _ready hasn't run yet when it enters the tree.
		poll.call_deferred()
		if screen != null:
			screen.tree_exited.connect(_on_desk_left.bind(weakref(screen)), CONNECT_ONE_SHOT)
	_update_targets(fade)


## Reads the desk: who is still waiting, whether it wants quiet, whether there
## is a protest outside. Called every POLL seconds while a desk is up.
func poll() -> void:
	if _desk == null:
		return
	var desk: Object = _desk.get_ref()
	if desk == null or not is_instance_valid(desk):
		_cut_to_silence()
		return
	waiting = waiting_for(desk)
	var asked: Variant = desk.get("ambience_quiet")
	quiet = asked is bool and asked
	protest = _protest_today()
	_update_targets(DRAIN if quiet else FADE)


func _on_node_added(node: Node) -> void:
	if not (node is ScreenBase) or node.get_script() == null:
		return
	var id := scene_for(String((node.get_script() as Script).get_global_name()))
	if id != "":
		set_scene(id, node)


## The desk left the tree. Normally the next screen arrived first (main adds it
## in the frame it frees the desk) and set its own scene; if nothing did (the
## day-7 cut to black), the room cuts with the picture.
func _on_desk_left(which: WeakRef) -> void:
	if _desk != null and _desk.get_ref() == which.get_ref():
		_cut_to_silence()


func _cut_to_silence() -> void:
	_desk = null
	if scene_id == "desk":
		set_scene("silence", null, CUT)


func _on_sfx_played(sound_name: String) -> void:
	match sound_name:
		"stamp", "stamp_heavy":
			_duck_left = DUCK_TIME
		"handset":
			# Hanging up cuts the hold music dead; the next screen brings its own room.
			_cut_music()


func _cut_music() -> void:
	_gains["music"] = 0.0
	_targets["music"] = 0.0
	_music_duck_t = -1.0
	_music_duck = 1.0
	if scene_id == "hold":
		scene_id = "silence"
		_update_targets(FADE)
	if _audio:
		_players["music"].stop()
		_chime_player.stop()


func _protest_today() -> bool:
	var gs := get_node_or_null("/root/GameState")
	if gs == null or gs.get("run") == null:
		return false
	var effects: Variant = gs.get("run").get("effects")
	return effects is Dictionary and bool(effects.get("protest", false))


func _update_targets(fade: float) -> void:
	for layer: String in LAYERS:
		_targets[layer] = 0.0
		_rates[layer] = 1.0 / fade
	match scene_id:
		"hold":
			_targets["music"] = 1.0
		"memo":
			_targets["hum"] = MEMO_GAIN
			_targets["hvac"] = MEMO_GAIN
		"desk":
			_targets["hum"] = 1.0
			if not quiet:
				var room := clampf(waiting / FULL_ROOM, 0.0, 1.0)
				_targets["hvac"] = 1.0
				_targets["murmur_a"] = room
				_targets["murmur_b"] = room
				_targets["protest"] = 1.0 if protest else 0.0
		"kitchen":
			_targets["house"] = 1.0
		"night":
			_targets["house"] = 1.0
			_targets["rain"] = 1.0
	if _audio:
		_queue_beds()


# --- playback ---------------------------------------------------------------------

func _mix_layers(delta: float) -> void:
	for layer: String in LAYERS:
		var p: AudioStreamPlayer = _players[layer]
		var target: float = _targets[layer]
		var bed: String = LAYERS[layer]
		if target > 0.0 and p.stream == null and _streams.has(bed):
			p.stream = _streams[bed]
		if p.stream == null:
			# Still rendering: the fade waits for the bed, so it always rises
			# from silence instead of popping in at whatever level it reached.
			_gains[layer] = 0.0
			continue
		var g := move_toward(float(_gains[layer]), target, delta * float(_rates[layer]))
		_gains[layer] = g
		var level := g * (_music_duck if layer == "music" else 1.0)
		p.volume_db = linear_to_db(level) if level > 0.0005 else -80.0
		if g > 0.0 and not p.playing:
			p.play()
		elif g <= 0.0 and target <= 0.0 and p.playing:
			p.stop()


func _run_duck(delta: float) -> void:
	var bus := AudioServer.get_bus_index("Ambience")
	if bus == -1:
		return
	_duck_left = maxf(_duck_left - delta, 0.0)
	# Full duck for the first half, then back up over the second.
	AudioServer.set_bus_volume_db(bus, DUCK_DB * clampf(_duck_left / (DUCK_TIME * 0.5), 0.0, 1.0))


## About every 30 s of hold music: duck it, play the chime, tell the title.
func _run_hold_chime(delta: float) -> void:
	if _music_duck_t >= 0.0:
		_music_duck_t += delta
		var t := _music_duck_t
		_music_duck = lerpf(1.0, 0.25, clampf(t / 0.3, 0.0, 1.0))
		if t > 2.5:
			_music_duck = lerpf(0.25, 1.0, clampf((t - 2.5) / 0.5, 0.0, 1.0))
		if t >= 3.0:
			_music_duck_t = -1.0
			_music_duck = 1.0
	if scene_id != "hold" or not _players["music"].playing:
		return
	_hold_clock += delta
	if _hold_clock < CHIME_EVERY:
		return
	_hold_clock = _rng.randf_range(-2.0, 2.0)
	_music_duck_t = 0.0
	if _streams.has("hold_chime"):
		_chime_player.stream = _streams["hold_chime"]
		_chime_player.play()
	hold_chime.emit()


## A phone two offices over, a filing drawer, a cough in the waiting room.
func _run_one_shots(delta: float) -> void:
	if scene_id != "desk" or quiet:
		return
	_shot_left -= delta
	if _shot_left > 0.0:
		return
	_shot_left = _rng.randf_range(20.0, 60.0)
	var pool: Array[String] = ["phone", "drawer"]
	if waiting > 0:
		pool.append("cough")
	var shot := pool[_rng.randi() % pool.size()]
	if _streams.has(shot):
		_shot_player.stream = _streams[shot]
		_shot_player.play()


# --- rendering ------------------------------------------------------------------

func _queue_beds() -> void:
	var needed: PackedStringArray = []
	for layer: String in LAYERS:
		if float(_targets[layer]) > 0.0:
			needed.append(LAYERS[layer])
	if scene_id == "desk":
		needed.append_array(PackedStringArray(["phone", "drawer", "cough"]))
	elif scene_id == "hold":
		needed.append("hold_chime")
	var order := needed.duplicate()
	order.append_array(PREWARM)
	_queue.clear()
	for bed in order:
		if not _streams.has(bed) and bed != _task_bed and not _queue.has(bed):
			_queue.append(bed)


func _start_render() -> void:
	if _task != -1 or _queue.is_empty():
		return
	_task_bed = _queue[0]
	_queue.remove_at(0)
	_task = WorkerThreadPool.add_task(_render_task.bind(_task_bed), false, "Ambience " + _task_bed)


## Worker thread: renders one bed into _result.
func _render_task(bed: String) -> void:
	var r := render_bed(bed)
	_result_lock.lock()
	_result = r
	_result_lock.unlock()


func _collect_render() -> void:
	if _task == -1 or not WorkerThreadPool.is_task_completed(_task):
		return
	WorkerThreadPool.wait_for_task_completion(_task)
	_task = -1
	_result_lock.lock()
	var r := _result
	_result = {}
	_result_lock.unlock()
	if not r.is_empty():
		_streams[_task_bed] = SfxLib.make_wav(r["pcm"], r["rate"], r["loop"])
	_task_bed = ""


## Renders a bed: {pcm, rate, loop} where loop is the loop length in frames (0
## for one-shots). Pure: safe on any thread, and callable from tests.
static func render_bed(bed: String) -> Dictionary:
	var samples := PackedFloat32Array()
	var rate := RATE
	var loop := 0
	match bed:
		"office_hum":
			samples = fold_loop(_office_hum(8.0), frames(8.0), false)
		"office_hvac":
			samples = fold_loop(_office_hvac(8.0), frames(8.0), true)
		"murmur_a":
			samples = fold_loop(_murmur(6.0, 61), frames(6.0), true)
		"murmur_b":
			samples = fold_loop(_murmur(7.3, 73), frames(7.3), true)
		"protest":
			samples = fold_loop(_protest(4.0), frames(4.0), true)
		"house":
			samples = fold_loop(_house(4.0), frames(4.0), false)
		"rain":
			samples = fold_loop(_rain(4.0), frames(4.0), true)
		"hold_music":
			rate = MUSIC_RATE
			samples = _hold_music()
		"phone":
			samples = _phone()
		"drawer":
			samples = _drawer()
		"cough":
			samples = _cough()
		"hold_chime":
			rate = MUSIC_RATE
			samples = _hold_chime()
		_:
			return {}
	if LAYERS.values().has(bed):
		loop = samples.size()
	return {"pcm": SfxLib.pcm16(samples), "rate": rate, "loop": loop}


## The hold music as a looping stream: 24 s at 8 kHz. Synchronous (tests call it).
static func build_hold_music() -> AudioStreamWAV:
	var r := render_bed("hold_music")
	return SfxLib.make_wav(r["pcm"], r["rate"], r["loop"])


static func frames(seconds: float, rate: int = RATE) -> int:
	return int(round(seconds * rate))


## Folds what was rendered past `loop_frames` back over the start, so the loop
## has no seam: an equal-power crossfade for noise (`power`), linear for
## periodic sound that lines up with itself.
static func fold_loop(raw: PackedFloat32Array, loop_frames: int, power: bool) -> PackedFloat32Array:
	var x := raw.size() - loop_frames
	var out := raw.slice(0, loop_frames)
	for i in x:
		var u := float(i) / x
		var head := sqrt(u) if power else u
		var tail := sqrt(1.0 - u) if power else 1.0 - u
		out[i] = out[i] * head + raw[loop_frames + i] * tail
	return out


# --- beds (11025 Hz, rendered XFADE past the loop) ------------------------------------

## Fluorescent tubes: a buzzy 120 Hz with a slow waver, about -32 dB.
static func _office_hum(seconds: float) -> PackedFloat32Array:
	var rng := _seeded("office_hum")
	var n := frames(seconds + XFADE)
	var sizzle := SfxLib.biquad(SfxLib.white(n, rng), Filter.HIGH, 2500.0, 0.7, RATE)
	var b := SfxLib.zeros(n)
	for i in n:
		var t := float(i) / RATE
		var waver := 1.0 + 0.18 * sin(TAU * 0.125 * t) + 0.08 * sin(TAU * 0.375 * t + 1.3)
		var w := TAU * 120.0 * t
		var hum := sin(w) + 0.45 * sin(2.0 * w + 0.3) + 0.3 * sin(3.0 * w + 1.1) + 0.12 * sin(4.0 * w) + 0.06 * sin(5.0 * w)
		var gate := pow(0.5 + 0.5 * sin(w), 4.0)
		b[i] = hum * waver + sizzle[i] * gate * 0.25
	return SfxLib.normalize_rms(b, db_to_linear(-32.0))


## Air through the ducts: a low rumble, a breathy middle and a little hiss, about -28 dB.
static func _office_hvac(seconds: float) -> PackedFloat32Array:
	var rng := _seeded("office_hvac")
	var n := frames(seconds + XFADE)
	var noise := SfxLib.white(n, rng)
	var b := SfxLib.biquad(noise, Filter.LOW, 200.0, 0.7, RATE)
	SfxLib.mix(b, SfxLib.biquad(noise, Filter.BAND, 600.0, 0.7, RATE), 0.5, 0.0, RATE)
	SfxLib.mix(b, SfxLib.biquad(noise, Filter.HIGH, 2000.0, 0.7, RATE), 0.08, 0.0, RATE)
	for i in n:
		b[i] *= 1.0 + 0.1 * sin(TAU * 0.25 * float(i) / RATE)
	return SfxLib.normalize_rms(b, db_to_linear(-28.0))


## A waiting room behind glass: five voices of breath and vowel formants in
## phrases of 3-6 syllables a second, low-passed near 600 Hz and smeared by the
## room until no word survives. About -22 dB.
static func _murmur(seconds: float, seed_value: int) -> PackedFloat32Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var n := frames(seconds + XFADE)
	var room := SfxLib.zeros(n)
	for v in 5:
		_murmur_voice(room, rng)
	var b := SfxLib.biquad(SfxLib.biquad(room, Filter.LOW, 600.0, 0.7, RATE), Filter.LOW, 600.0, 0.7, RATE)
	var smeared := b.duplicate()
	for echo: Vector2 in [Vector2(0.035, 0.3), Vector2(0.073, 0.2)]:
		SfxLib.mix(smeared, b, echo.y, echo.x, RATE)
	return SfxLib.normalize_rms(smeared, db_to_linear(-22.0))


static func _murmur_voice(out: PackedFloat32Array, rng: RandomNumberGenerator) -> void:
	var vowels: Array[Vector2] = [Vector2(650, 1080), Vector2(480, 1720), Vector2(520, 880), Vector2(360, 900), Vector2(600, 1300)]
	var n := out.size()
	var f0 := rng.randf_range(95.0, 230.0)
	var voice_gain := rng.randf_range(0.55, 1.0)
	var formant_scale := 1.0 + (f0 - 95.0) / 400.0
	var phase := 0.0
	var s := PackedFloat64Array([0, 0, 0, 0, 0, 0, 0, 0]) ## two biquad states
	var i := int(rng.randf_range(0.0, 1.5) * RATE)
	while i < n:
		var phrase_end := i + int(rng.randf_range(1.0, 2.6) * RATE)
		while i < phrase_end and i < n:
			var syllable := int(RATE / rng.randf_range(3.0, 6.0))
			var vowel := vowels[rng.randi() % vowels.size()] * formant_scale
			var c1 := SfxLib.coefficients(Filter.BAND, vowel.x, 4.0, RATE)
			var c2 := SfxLib.coefficients(Filter.BAND, vowel.y, 6.0, RATE)
			var amp := rng.randf_range(0.5, 1.0) * voice_gain
			var pitch := f0 * rng.randf_range(0.9, 1.15)
			for k in syllable:
				if i >= n:
					break
				var u := float(k) / syllable
				var env := 4.0 * u * (1.0 - u)
				phase = fmod(phase + pitch / RATE, 1.0)
				var x := (2.0 * phase - 1.0) * 0.55 + rng.randf_range(-1.0, 1.0) * 0.45
				var y1 := c1[0] * x + c1[1] * s[0] + c1[2] * s[1] - c1[3] * s[2] - c1[4] * s[3]
				s[1] = s[0]
				s[0] = x
				s[3] = s[2]
				s[2] = y1
				var y2 := c2[0] * x + c2[1] * s[4] + c2[2] * s[5] - c2[3] * s[6] - c2[4] * s[7]
				s[5] = s[4]
				s[4] = x
				s[7] = s[6]
				s[6] = y2
				out[i] += (y1 + 0.5 * y2) * env * env * amp
				i += 1
		i += int(rng.randf_range(0.4, 1.5) * RATE)


## Outside, through the building: a crowd's two-beat chant every 2 s over a
## soft drum on the beat, all muffled. No words. About -27 dB.
static func _protest(seconds: float) -> PackedFloat32Array:
	var rng := _seeded("protest")
	var n := frames(seconds + XFADE)
	var b := SfxLib.zeros(n)
	var bed := SfxLib.biquad(SfxLib.white(n, rng), Filter.LOW, 300.0, 0.7, RATE)
	SfxLib.mix(b, SfxLib.normalized(bed), 0.15, 0.0, RATE)
	for voice in 10:
		var f0 := rng.randf_range(110.0, 260.0)
		for cycle in range(0, int(ceil((seconds + XFADE) / 2.0))):
			for syllable: Vector4 in [Vector4(0.0, 0.22, 500, 1700), Vector4(0.5, 0.4, 560, 900)]:
				var at := cycle * 2.0 + syllable.x + rng.randf_range(-0.04, 0.04)
				var pitch := f0 * (1.06 if syllable.x > 0.0 else 1.0)
				var shout := _shout(syllable.y, pitch, syllable.z, syllable.w, rng)
				SfxLib.mix(b, shout, rng.randf_range(0.5, 1.0), maxf(at, 0.0), RATE)
	var beat := 0.0
	while beat < seconds + XFADE:
		var accent := 1.0 if fmod(beat, 2.0) < 0.75 else 0.5
		SfxLib.mix(b, SfxLib.chirp(0.3, 80.0, 50.0, 14.0, RATE), 1.6 * accent, beat, RATE)
		SfxLib.mix(b, SfxLib.burst(0.2, 30.0, rng, Filter.LOW, 200.0, 0.7, 0.0, RATE), 0.8 * accent, beat, RATE)
		beat += 0.5
	b = SfxLib.biquad(SfxLib.biquad(b, Filter.LOW, 450.0, 0.7, RATE), Filter.LOW, 450.0, 0.7, RATE)
	return SfxLib.normalize_rms(b, db_to_linear(-27.0))


## One voice of the chant: a shouted vowel, mostly voiced.
static func _shout(seconds: float, pitch: float, f1: float, f2: float, rng: RandomNumberGenerator) -> PackedFloat32Array:
	var n := frames(seconds)
	var src := SfxLib.zeros(n)
	var phase := 0.0
	for i in n:
		phase = fmod(phase + pitch / RATE, 1.0)
		var t := float(i) / RATE
		var env := smoothstep(0.0, 0.02, t) * (1.0 - smoothstep(seconds - 0.06, seconds, t))
		src[i] = ((2.0 * phase - 1.0) * 0.7 + rng.randf_range(-1.0, 1.0) * 0.3) * env
	var out := SfxLib.biquad(src, Filter.BAND, f1, 3.0, RATE)
	return SfxLib.mix(out, SfxLib.biquad(src, Filter.BAND, f2, 5.0, RATE), 0.6, 0.0, RATE)


## A kitchen at night: the wall clock (tick, tock) and the refrigerator.
static func _house(seconds: float) -> PackedFloat32Array:
	var rng := _seeded("house")
	var n := frames(seconds + XFADE)
	var fridge := SfxLib.zeros(n)
	var air := SfxLib.biquad(SfxLib.white(n, rng), Filter.LOW, 400.0, 0.7, RATE)
	for i in n:
		var t := float(i) / RATE
		var w := TAU * 58.0 * t
		var v := 0.6 * sin(w) + 0.3 * sin(2.0 * w) + 0.15 * sin(3.0 * w) + 0.04 * sin(TAU * 410.0 * t)
		fridge[i] = v * (1.0 + 0.05 * sin(TAU * 0.25 * t)) + air[i] * 0.3
	SfxLib.normalize_rms(fridge, db_to_linear(-36.0))
	var tick := 0.0
	var k := 0
	while tick < seconds + XFADE:
		var clock := SfxLib.zeros(frames(0.05))
		var f := 3100.0 if k % 2 == 0 else 2500.0
		SfxLib.mix(clock, SfxLib.ring(0.05, f, 600.0, RATE), 0.6, 0.0, RATE)
		SfxLib.mix(clock, SfxLib.ring(0.05, f * 0.55, 300.0, RATE), 0.4, 0.0, RATE)
		SfxLib.mix(clock, SfxLib.ring(0.05, 600.0, 80.0, RATE), 0.15, 0.0, RATE)
		SfxLib.mix(clock, SfxLib.burst(0.004, 2000.0, rng, Filter.HIGH, 3000.0, 0.7, 0.0, RATE), 0.3, 0.0, RATE)
		SfxLib.mix(fridge, SfxLib.normalized(clock), db_to_linear(-26.0), tick, RATE)
		tick += 1.0
		k += 1
	return fridge


## Light rain on the window: a soft wash and scattered drops, about -31 dB.
static func _rain(seconds: float) -> PackedFloat32Array:
	var rng := _seeded("rain")
	var n := frames(seconds + XFADE)
	var noise := SfxLib.white(n, rng)
	var b := SfxLib.biquad(noise, Filter.BAND, 2500.0, 0.5, RATE)
	SfxLib.mix(b, SfxLib.biquad(noise, Filter.LOW, 600.0, 0.7, RATE), 0.8, 0.0, RATE)
	for drop in int(40 * (seconds + XFADE)):
		var at := rng.randf_range(0.0, seconds + XFADE - 0.02)
		SfxLib.mix(b, SfxLib.ring(0.012, rng.randf_range(2000.0, 5000.0), 800.0, RATE), rng.randf_range(0.1, 0.4), at, RATE)
	return SfxLib.normalize_rms(b, db_to_linear(-31.0))


# --- one-shots ---------------------------------------------------------------------

## A desk phone two offices over: a double trill, muffled, with a little room.
static func _phone() -> PackedFloat32Array:
	var n := frames(1.6)
	var b := SfxLib.zeros(n)
	for start: float in [0.0, 0.45]:
		for i in frames(0.32):
			var t := float(i) / RATE
			var f := 1000.0 if fmod(t * 16.0, 1.0) < 0.5 else 1300.0
			var env := smoothstep(0.0, 0.01, t) * (1.0 - smoothstep(0.3, 0.32, t))
			var j := frames(start) + i
			b[j] += (sin(TAU * f * t) + 0.3 * sin(TAU * 3.0 * f * t)) * env
	b = SfxLib.biquad(b, Filter.LOW, 1800.0, 0.7, RATE)
	var room := b.duplicate()
	for echo: Vector2 in [Vector2(0.025, 0.35), Vector2(0.06, 0.2), Vector2(0.11, 0.1)]:
		SfxLib.mix(room, b, echo.y, echo.x, RATE)
	return SfxLib.finish(room, db_to_linear(-24.0), RATE)


## A filing drawer rolled shut somewhere behind you.
static func _drawer() -> PackedFloat32Array:
	var rng := _seeded("drawer")
	var b := SfxLib.zeros(frames(1.1))
	var slide := SfxLib.biquad(SfxLib.white(frames(0.6), rng), Filter.LOW, 700.0, 0.7, RATE)
	SfxLib.mix(b, SfxLib.window(SfxLib.normalized(slide), 0.7), 0.6, 0.0, RATE)
	for k in 30:
		SfxLib.mix(b, SfxLib.ring(0.02, 2400.0, 400.0, RATE), 0.15, rng.randf_range(0.02, 0.58), RATE)
	SfxLib.mix(b, SfxLib.ring(0.4, 110.0, 35.0, RATE), 0.8, 0.62, RATE)
	SfxLib.mix(b, SfxLib.ring(0.3, 840.0, 45.0, RATE), 0.4, 0.62, RATE)
	SfxLib.mix(b, SfxLib.ring(0.2, 2050.0, 70.0, RATE), 0.2, 0.62, RATE)
	SfxLib.mix(b, SfxLib.burst(0.1, 100.0, rng, Filter.LOW, 2500.0, 0.7, 0.0, RATE), 0.4, 0.62, RATE)
	return SfxLib.finish(SfxLib.biquad(b, Filter.LOW, 2500.0, 0.7, RATE), db_to_linear(-23.0), RATE)


## Someone in the waiting room coughs twice, through the glass.
static func _cough() -> PackedFloat32Array:
	var rng := _seeded("cough")
	var b := SfxLib.zeros(frames(0.9))
	for hit: Vector2 in [Vector2(0.0, 1.0), Vector2(0.32, 0.7)]:
		var n := frames(0.25)
		var src := SfxLib.white(n, rng)
		var phase := 0.0
		for i in n:
			phase = fmod(phase + 160.0 / RATE, 1.0)
			src[i] = src[i] * 0.8 + (2.0 * phase - 1.0) * 0.3
		var c := SfxLib.biquad(src, Filter.BAND, 450.0, 2.0, RATE)
		SfxLib.mix(c, SfxLib.biquad(src, Filter.BAND, 1400.0, 3.0, RATE), 0.6, 0.0, RATE)
		SfxLib.mix(b, SfxLib.envelope(c, 0.008, 12.0, RATE), hit.y, hit.x, RATE)
	return SfxLib.finish(SfxLib.biquad(b, Filter.LOW, 1100.0, 0.7, RATE), db_to_linear(-26.0), RATE)


# --- hold music (8 kHz, telephone bandwidth) ---------------------------------------------

## The hold chime: two soft tones down the line.
static func _hold_chime() -> PackedFloat32Array:
	var dur := 1.4
	var b := SfxLib.zeros(frames(dur, MUSIC_RATE))
	for tone: Vector2 in [Vector2(932.3, 0.0), Vector2(698.5, 0.45)]:
		var note := SfxLib.zeros(frames(dur - tone.y, MUSIC_RATE))
		for i in note.size():
			var t := float(i) / MUSIC_RATE
			note[i] = sin(TAU * tone.x * t) + 0.2 * sin(TAU * 2.0 * tone.x * t)
		SfxLib.mix(b, SfxLib.envelope(note, 0.006, 3.0, MUSIC_RATE), 1.0, tone.y, MUSIC_RATE)
	return SfxLib.finish(_phone_line(b), 0.4, MUSIC_RATE)


## An original 24 s loop at 96 BPM: I-vi-IV-V twice on an FM electric piano with
## soft bass and shaker, then the tonic rings out for the last 4 s (24 s is not
## a whole number of bars at 96 BPM, so the loop breathes there). 0.3% tape
## wobble, faint line hiss, telephone bandwidth.
static func _hold_music() -> PackedFloat32Array:
	var rng := _seeded("hold_music")
	var beat := 60.0 / 96.0
	var bar := beat * 4.0
	var n := frames(HOLD_SECONDS + XFADE, MUSIC_RATE)
	var b := SfxLib.zeros(n)
	var wobble := PackedFloat32Array()
	wobble.resize(n)
	for i in n:
		var t := float(i) / MUSIC_RATE
		wobble[i] = 1.0 + 0.003 * sin(TAU * 0.5 * t) + 0.001 * sin(TAU * 1.75 * t + 0.7)
	# C, Am, F, G voiced above the phone line's low cut, and their roots.
	var chords: Array = [[64, 67, 72], [64, 69, 72], [65, 69, 72], [62, 67, 71]]
	var roots: Array[int] = [48, 45, 41, 43]
	for bar_i in 8:
		var t0 := bar_i * bar
		var chord: Array = chords[bar_i % 4]
		var root := roots[bar_i % 4]
		for note: int in chord:
			_epiano(b, t0, beat * 1.5, _midi(note), 0.55, wobble, false)
			_epiano(b, t0 + beat * 1.5, beat * 2.5, _midi(note), 0.45, wobble, false)
		_bass(b, t0, beat * 2.0, _midi(root), wobble)
		_bass(b, t0 + beat * 2.0, beat, _midi(root), wobble)
		_bass(b, t0 + beat * 3.0, beat, _midi(root + 7), wobble)
		for e in 8:
			_shaker(b, t0 + e * beat * 0.5, 0.16 if e % 2 == 1 else 0.08, rng)
	var melody: Array[Vector2] = [
		Vector2(76, 1), Vector2(79, 1), Vector2(84, 1.5), Vector2(83, 0.5),
		Vector2(81, 2), Vector2(76, 1), Vector2(72, 1),
		Vector2(77, 1), Vector2(81, 1), Vector2(84, 1), Vector2(81, 1),
		Vector2(79, 3), Vector2(74, 1),
		Vector2(76, 1), Vector2(79, 1), Vector2(84, 1), Vector2(86, 1),
		Vector2(88, 1.5), Vector2(86, 0.5), Vector2(84, 1), Vector2(81, 1),
		Vector2(77, 1), Vector2(81, 1), Vector2(79, 1), Vector2(77, 1),
		Vector2(74, 1), Vector2(76, 1), Vector2(77, 1), Vector2(74, 1),
	]
	var at := 0.0
	for m in melody:
		_epiano(b, at, m.y * beat * 0.92, _midi(int(m.x)), 0.7, wobble, true)
		at += m.y * beat
	# The last 4 s: the tonic rings out under the melody's last note.
	var end := 8 * bar
	for note: int in [64, 67, 72]:
		_epiano(b, end, 3.4, _midi(note), 0.5, wobble, false)
	_epiano(b, end, 3.4, _midi(76), 0.65, wobble, true)
	_bass(b, end, 3.0, _midi(48), wobble)
	var hiss := SfxLib.biquad(SfxLib.white(n, rng), Filter.HIGH, 1000.0, 0.7, MUSIC_RATE)
	SfxLib.mix(b, hiss, 0.012, 0.0, MUSIC_RATE)
	b = SfxLib.normalized(_phone_line(b))
	for i in b.size():
		b[i] *= 0.45
	# The last chord spills over the loop point into the first bar.
	var loop := frames(HOLD_SECONDS, MUSIC_RATE)
	var out := b.slice(0, loop)
	var spill := b.size() - loop
	for i in spill:
		out[i] += b[loop + i] * (1.0 - float(i) / spill)
	return out


## One FM electric piano note (carrier and modulator at 1:1, the index falling
## fast for the bark), added into b.
static func _epiano(b: PackedFloat32Array, start: float, length: float, freq: float, vel: float, wobble: PackedFloat32Array, lead: bool) -> void:
	var i0 := frames(start, MUSIC_RATE)
	var hold := frames(length, MUSIC_RATE)
	var n := hold + frames(0.08, MUSIC_RATE)
	var amp := 1.0
	var amp_k := exp(-(1.4 + freq / 900.0) / MUSIC_RATE)
	var index := (1.2 if lead else 1.6) * clampf(700.0 / freq, 0.35, 1.0)
	var index_k := exp(-7.0 / MUSIC_RATE)
	var phase := 0.0
	for i in n:
		var j := i0 + i
		if j >= b.size():
			break
		phase += TAU * freq * wobble[j] / MUSIC_RATE
		var g := amp * minf(1.0, i / 24.0)
		if i > hold:
			g *= 1.0 - float(i - hold) / (n - hold)
		b[j] += sin(phase + (index + 0.2) * sin(phase)) * g * vel * 0.18
		amp *= amp_k
		index *= index_k


## A soft, slightly rounded-off bass note; the phone line keeps only its overtones.
static func _bass(b: PackedFloat32Array, start: float, length: float, freq: float, wobble: PackedFloat32Array) -> void:
	var i0 := frames(start, MUSIC_RATE)
	var hold := frames(length, MUSIC_RATE)
	var n := hold + frames(0.06, MUSIC_RATE)
	var amp := 1.0
	var amp_k := exp(-2.5 / MUSIC_RATE)
	var phase := 0.0
	for i in n:
		var j := i0 + i
		if j >= b.size():
			break
		phase += TAU * freq * wobble[j] / MUSIC_RATE
		var g := amp * minf(1.0, i / 40.0)
		if i > hold:
			g *= 1.0 - float(i - hold) / (n - hold)
		b[j] += tanh(1.8 * sin(phase)) * g * 0.22
		amp *= amp_k


static func _shaker(b: PackedFloat32Array, start: float, gain: float, rng: RandomNumberGenerator) -> void:
	var i0 := frames(start, MUSIC_RATE)
	var n := frames(0.07, MUSIC_RATE)
	var lp := 0.0
	var amp := 1.0
	var k := exp(-70.0 / MUSIC_RATE)
	for i in n:
		var j := i0 + i
		if j >= b.size():
			break
		var x := rng.randf_range(-1.0, 1.0)
		lp += 0.35 * (x - lp)
		b[j] += (x - lp) * amp * minf(1.0, i / 32.0) * gain
		amp *= k


## A telephone line: 300-3400 Hz and a touch of compression.
static func _phone_line(b: PackedFloat32Array) -> PackedFloat32Array:
	var line := SfxLib.biquad(b, Filter.HIGH, 300.0, 0.707, MUSIC_RATE)
	line = SfxLib.biquad(line, Filter.LOW, 3400.0, 0.707, MUSIC_RATE)
	return SfxLib.saturate(SfxLib.normalized(line), 1.3)


static func _midi(note: int) -> float:
	return 440.0 * pow(2.0, (note - 69) / 12.0)


static func _seeded(bed: String) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(["ambience", bed])
	return rng
