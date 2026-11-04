extends RefCounted
## The sound library (Sfx) and the building around it (Ambience), headless.

const AMBIENCE := preload("res://autoload/ambience.gd")
const SFX := preload("res://autoload/sfx.gd")
## The names other screens may call, old and new. Unknown names are no-ops.
const CONTRACT: PackedStringArray = [
	"stamp", "paper", "bell", "buzz", "click", "ding", "cash",
	"paper_pick", "paper_drop", "card_tick", "page", "switch_on", "switch_off",
	"chunk", "clack", "printer", "step", "chime", "relay", "flicker", "breaker",
	"stamp_heavy", "thwap", "typewriter", "pen_scratch", "handset",
	"voice_low", "voice_mid", "voice_high", "tick", "rumble",
	"shutter_up", "shutter_down", "lamp_click", "ratchet", "tone_low",
]
const LOOPED_BEDS := {
	"office_hum": 8.0, "office_hvac": 8.0, "murmur_a": 6.0, "murmur_b": 7.3,
	"protest": 4.0, "house": 4.0, "rain": 4.0,
}

var t: TestContext
var tree: SceneTree
var gs: Node
var sfx: Node
var amb: Node
var _screens: Array[Node] = []
## Short silent streams handed to a playing Ambience in place of its beds.
var _stubs: Dictionary = {}


## Records every message and error logged while it is attached.
class Capture extends Logger:
	var lines: PackedStringArray = []
	var _lock := Mutex.new()

	func _log_message(message: String, _error: bool) -> void:
		_lock.lock()
		lines.append(message)
		_lock.unlock()

	func _log_error(_function: String, _file: String, _line: int, code: String, rationale: String, _editor_notify: bool, _error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
		_lock.lock()
		lines.append(rationale if rationale != "" else code)
		_lock.unlock()


func before_each() -> void:
	tree = Engine.get_main_loop() as SceneTree
	gs = tree.root.get_node("GameState")
	sfx = tree.root.get_node("Sfx")
	gs.save_path_override = TestContext.save_path()
	gs.new_run("Pat Doe", 3)


func after_each() -> void:
	for s in _screens:
		if is_instance_valid(s):
			s.queue_free()
	_screens.clear()
	if amb != null and is_instance_valid(amb):
		amb.queue_free()
	amb = null
	_stubs.clear()
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Ambience"), 0.0)
	await tree.process_frame
	gs.delete_save()
	gs.save_path_override = ""


func _add_ambience() -> Node:
	amb = AMBIENCE.new()
	tree.root.add_child(amb)
	return amb


## An Ambience that plays headless, one step at a time: its players are made
## and mixed, the engine no longer processes it (the test calls _step), and
## each bed and one-shot is a short silent stub instead of a render.
func _playing_ambience(with_streams: bool = true) -> Node:
	_add_ambience()
	amb.set_process(false)
	amb.enable_playback()
	if with_streams:
		for bed: String in AMBIENCE.LAYERS.values():
			amb.set_stream(bed, _stub(bed, true))
		for shot in ["phone", "drawer", "cough", "hold_chime"]:
			amb.set_stream(shot, _stub(shot, false))
	return amb


func _stub(sound_name: String, loop: bool) -> AudioStreamWAV:
	var pcm := PackedByteArray()
	pcm.resize(2756 * 2)
	var wav: AudioStreamWAV = SFX.make_wav(pcm, 11025, 2756 if loop else 0)
	_stubs[sound_name] = wav
	return wav


## Advances the playing Ambience by `seconds` of game time, `dt` at a time.
func _step(seconds: float, dt: float = 0.05) -> void:
	var left := seconds
	while left > 0.00001:
		var d := minf(dt, left)
		amb._process(d)
		left -= d


func _gain(layer: String) -> float:
	return float(amb._gains[layer])


func _player(layer: String) -> AudioStreamPlayer:
	return amb._players[layer]


func _fake_desk(waiting_count: int) -> Node:
	var script := GDScript.new()
	script.source_code = "extends Node\nvar claims: Array = []\nvar index: int = -1\nvar ambience_quiet: bool = false\n"
	script.reload()
	var fake: Node = script.new()
	var claims: Array = []
	for i in waiting_count:
		claims.append(Claim.new())
	fake.set("claims", claims)
	tree.root.add_child(fake)
	_screens.append(fake)
	return fake


func _open(screen: ScreenBase) -> ScreenBase:
	screen.fast = true
	screen.theme = UiTheme.build()
	tree.root.add_child(screen)
	_screens.append(screen)
	await tree.process_frame
	return screen


func _close(screen: Node) -> void:
	_screens.erase(screen)
	screen.queue_free()
	await tree.process_frame


func _waited_for_sfx() -> int:
	var frames := 0
	while not sfx.is_ready() and frames < 120:
		await tree.process_frame
		frames += 1
	return frames


# --- Sfx --------------------------------------------------------------------------

func test_every_contract_sound_is_rendered_within_120_frames() -> void:
	var frames: int = await _waited_for_sfx()
	t.ok(sfx.is_ready(), "rendered after %d frames" % frames)
	for sound_name in CONTRACT:
		var stream: AudioStreamWAV = sfx.get_stream(sound_name)
		t.ok(stream != null and stream.get_length() > 0.0, "%s has a stream with length" % sound_name)
		t.ok(sfx.sound_names().has(sound_name), "%s is in the library" % sound_name)


## play() ignores names it doesn't know, so a typo is silence. Every sound name
## the code plays (directly, through a bind, or as a ledger line's sound) must
## be one the library renders. A literal followed by "]" is a dictionary key.
func test_every_sound_the_code_plays_exists() -> void:
	var literal := RegEx.create_from_string("\"([a-z_0-9]+)\"(?!\\])")
	var checked := 0
	for dir in ["res://screens/", "res://ui/", "res://autoload/", "res://core/"]:
		for file_name in DirAccess.get_files_at(dir):
			if not file_name.ends_with(".gd") or file_name == "sfx.gd":
				continue
			for line in FileAccess.get_file_as_string(dir + file_name).split("\n"):
				if not (line.contains("Sfx.play") or line.contains("LINE_TIME, \"") or line.contains("[\"sound\"] =")):
					continue
				for m in literal.search_all(line):
					checked += 1
					t.ok(SFX.NAMES.has(m.get_string(1)), "%s plays unknown sound \"%s\"" % [file_name, m.get_string(1)])
	t.ok(checked >= 30, "checked %d sound names" % checked)
	for age in [8, 40, 70]:
		var c := Claim.new()
		c.age = age
		t.ok(SFX.NAMES.has(DeskScreen.voice_for(c)), "a %d-year-old's voice %s" % [age, DeskScreen.voice_for(c)])


func test_unknown_sound_is_a_silent_no_op() -> void:
	var heard: Array[String] = []
	var listen := func(n: String) -> void: heard.append(n)
	sfx.played.connect(listen)
	var capture := Capture.new()
	OS.add_logger(capture)
	sfx.play("no_such_sound")
	sfx.play("")
	OS.remove_logger(capture)
	sfx.played.disconnect(listen)
	t.eq(capture.lines.size(), 0, "nothing logged: %s" % ", ".join(capture.lines))
	t.eq(heard.size(), 0, "and nothing announced")


func test_played_fires_for_each_play() -> void:
	await _waited_for_sfx()
	var heard: Array[String] = []
	var listen := func(n: String) -> void: heard.append(n)
	sfx.played.connect(listen)
	sfx.play("clack")
	sfx.play("stamp_heavy")
	sfx.played.disconnect(listen)
	t.eq(heard, ["clack", "stamp_heavy"] as Array[String])


func test_played_fires_even_while_muted() -> void:
	var heard: Array[String] = []
	var listen := func(n: String) -> void: heard.append(n)
	sfx.played.connect(listen)
	sfx.muted = true
	sfx.play("handset")
	sfx.muted = false
	sfx.played.disconnect(listen)
	t.eq(heard, ["handset"] as Array[String], "listeners such as Ambience still hear it")


func test_buses_exist_and_send_to_master() -> void:
	for bus_name in ["SFX", "Ambience", "Music"]:
		var idx := AudioServer.get_bus_index(bus_name)
		t.ok(idx > 0, "%s bus exists" % bus_name)
		t.eq(String(AudioServer.get_bus_send(idx)), "Master", "%s sends to Master" % bus_name)
	var players := sfx.get_children().filter(func(n: Node) -> bool: return n is AudioStreamPlayer)
	t.ok(players.size() >= 8, "a pool of players")
	for p: AudioStreamPlayer in players:
		t.eq(String(p.bus), "SFX")


func test_ensure_buses_never_duplicates() -> void:
	var before := AudioServer.bus_count
	SFX.ensure_buses()
	SFX.ensure_buses()
	t.eq(AudioServer.bus_count, before)


func test_sounds_stay_quiet_and_voices_sit_near_minus_20_db() -> void:
	for sound_name in CONTRACT:
		var peak := 0.0
		for v in SFX.render(sound_name, 0):
			peak = maxf(peak, absf(v))
		t.ok(peak <= 1.0, "%s never clips (%.2f)" % [sound_name, peak])
	for voice in ["voice_low", "voice_mid", "voice_high"]:
		var samples := SFX.render(voice, 1)
		var peak := 0.0
		for v in samples:
			peak = maxf(peak, absf(v))
		t.near(linear_to_db(peak), -20.0, 1.5, "%s peak level" % voice)
		t.near(samples.size() / float(SFX.RATE), 0.06, 0.002, "%s is a 60 ms blip" % voice)


## The desk times the pink slip's four jerks to this: a printed line every
## 0.2 s, each followed by a short hush and then the paper feed.
func test_printer_prints_four_lines_0_2_s_apart() -> void:
	var samples := SFX.render("printer")
	t.near(samples.size() / float(SFX.RATE), 0.8, 0.01, "0.8 s")
	for k in 4:
		var line := _window_rms(samples, 0.2 * k + 0.02, 0.2 * k + 0.10)
		var hush := _window_rms(samples, 0.2 * k + 0.113, 0.2 * k + 0.128)
		var feed := _window_rms(samples, 0.2 * k + 0.13, 0.2 * k + 0.16)
		t.ok(line > 4.0 * hush, "line %d stands out from the hush after it (%.3f vs %.3f)" % [k + 1, line, hush])
		t.ok(feed > 4.0 * hush, "then the paper jerks forward (%.3f vs %.3f)" % [feed, hush])


func _window_rms(samples: PackedFloat32Array, from: float, to: float) -> float:
	var sum := 0.0
	var i0 := int(from * SFX.RATE)
	var i1 := int(to * SFX.RATE)
	for i in range(i0, i1):
		sum += samples[i] * samples[i]
	return sqrt(sum / maxi(i1 - i0, 1))


# --- Ambience -----------------------------------------------------------------------

func test_ambience_follows_each_screen_by_class_name() -> void:
	_add_ambience()
	await tree.process_frame
	t.eq(amb.scene_id, "silence", "starts silent")
	var cases: Array = [
		[TitleScreen.new(), "hold"],
		[AgreementScreen.new(), "hold"],
		[MemoScreen.new(), "memo"],
		[NewspaperScreen.new(), "kitchen"],
	]
	for pair: Array in cases:
		var screen: ScreenBase = await _open(pair[0])
		t.eq(amb.scene_id, pair[1], "%s plays %s" % [screen.get_script().get_global_name(), pair[1]])
		await _close(screen)
	var desk: ScreenBase = await _open(DeskScreen.new())
	t.eq(amb.scene_id, "desk", "the desk")
	await tree.process_frame
	t.ok(amb.target_gain("hum") > 0.0 and amb.target_gain("hvac") > 0.0, "room tone at the desk")
	t.ok(amb.target_gain("murmur_a") > 0.0, "people waiting behind the glass")
	t.eq(amb.target_gain("music"), 0.0, "no music on shift")
	await _close(desk)
	var ledger: ScreenBase = await _open(LedgerScreen.new())
	t.eq(amb.scene_id, "night")
	t.ok(amb.target_gain("rain") > 0.0 and amb.target_gain("house") > 0.0, "clock, fridge and rain")
	t.eq(amb.target_gain("hum"), 0.0, "the office is gone")
	await _close(ledger)
	gs.run.ending = Endings.FIRED
	await _open(EndingScreen.new())
	t.eq(amb.scene_id, "silence", "the ending is silent")


func test_scene_names_cover_every_screen() -> void:
	var expected := {
		"TitleScreen": "hold", "AgreementScreen": "hold", "MemoScreen": "memo",
		"DeskScreen": "desk", "NewspaperScreen": "kitchen", "LedgerScreen": "night",
		"EndingScreen": "silence", "DayCardScreen": "silence",
	}
	for screen_class: String in expected:
		t.eq(AMBIENCE.scene_for(screen_class), expected[screen_class], screen_class)
	t.eq(AMBIENCE.scene_for("SomeFutureScreen"), "", "unknown screens leave the scene alone")


func test_memo_is_the_office_eight_db_down() -> void:
	_add_ambience()
	amb.set_scene("memo")
	t.near(linear_to_db(amb.target_gain("hum")), -8.0, 0.1)
	t.eq(amb.target_gain("murmur_a"), 0.0, "nobody waiting at the memo")


func test_waiting_never_counts_the_player_on_day_seven() -> void:
	_add_ambience()
	gs.run.day = 7
	var desk: DeskScreen = await _open(DeskScreen.new())
	await tree.process_frame
	var total := desk.claims.size()
	t.ok(desk.claims[total - 1].is_player, "the player's claim comes last")
	t.eq(AMBIENCE.waiting_for(desk), total - 1, "everyone but the player is waiting")
	t.eq(amb.waiting, total - 1, "Ambience read the desk when it opened")
	while desk.index < total - 2:
		desk.call_next_patient()
		await desk.stamp(true)
	t.ok(desk.claims[desk.index + 1].is_player, "the next claim is the player's")
	amb.poll()
	t.eq(amb.waiting, 0, "an empty waiting room when the player is next")
	t.eq(amb.target_gain("murmur_a"), 0.0, "and no murmur")
	desk.call_next_patient()
	amb.poll()
	t.eq(amb.waiting, 0, "still empty with the player at the window")


func test_waiting_falls_by_one_per_patient() -> void:
	_add_ambience()
	var desk: DeskScreen = await _open(DeskScreen.new())
	await tree.process_frame
	var total := desk.claims.size()
	t.eq(amb.waiting, total, "day 1: everyone is waiting before NEXT!")
	desk.call_next_patient()
	amb.poll()
	t.eq(amb.waiting, total - 1)
	t.near(amb.target_gain("murmur_a"), (total - 1) / 8.0, 0.001, "murmur scales with the room, full at 8")


func test_protest_joins_the_desk_only_on_protest_days() -> void:
	_add_ambience()
	var desk: ScreenBase = await _open(DeskScreen.new())
	await tree.process_frame
	t.eq(amb.target_gain("protest"), 0.0, "no protest")
	await _close(desk)
	gs.run.effects["protest"] = true
	await _open(DeskScreen.new())
	await tree.process_frame
	t.eq(amb.target_gain("protest"), 1.0, "the chant outside")


func test_a_quiet_desk_drains_to_the_hum() -> void:
	_add_ambience()
	var fake_script := GDScript.new()
	fake_script.source_code = "extends Node\nvar claims: Array = []\nvar index: int = -1\nvar ambience_quiet: bool = false\n"
	fake_script.reload()
	var fake: Node = fake_script.new()
	tree.root.add_child(fake)
	_screens.append(fake)
	var c := Claim.new()
	fake.set("claims", [c, Claim.new()])
	amb.set_scene("desk", fake)
	amb.poll()
	t.eq(amb.waiting, 2)
	t.ok(amb.target_gain("murmur_a") > 0.0, "murmur while not quiet")
	fake.set("ambience_quiet", true)
	amb.poll()
	t.ok(amb.quiet, "the desk asked for quiet")
	t.eq(amb.target_gain("hum"), 1.0, "the hum stays")
	for layer in ["hvac", "murmur_a", "murmur_b", "protest"]:
		t.eq(amb.target_gain(layer), 0.0, "%s drains" % layer)


func test_hanging_up_cuts_the_hold_music() -> void:
	_add_ambience()
	amb.set_scene("hold")
	t.eq(amb.target_gain("music"), 1.0)
	sfx.play("handset")
	t.eq(amb.target_gain("music"), 0.0, "the handset cuts the music")
	t.eq(amb.scene_id, "silence", "silence until the next screen")


func test_ambience_renders_nothing_headless() -> void:
	_add_ambience()
	amb.set_scene("desk")
	for i in 5:
		await tree.process_frame
	t.eq(amb.rendered_beds().size(), 0, "no beds rendered")
	t.eq(amb.get_children().filter(func(n: Node) -> bool: return n is AudioStreamPlayer).size(), 0, "no players at all")


# --- Ambience playback (players forced on headless, stub streams) -------------------

func test_layers_crossfade_over_1_2_s() -> void:
	_playing_ambience()
	amb.set_scene("desk")
	_step(0.6)
	t.near(_gain("hum"), 0.5, 0.01, "halfway up after half the fade")
	t.ok(_player("hum").playing, "the hum plays")
	t.near(_player("hum").volume_db, linear_to_db(0.5), 0.1, "at the faded level")
	t.ok(not _player("house").playing, "nothing from the house")
	_step(0.6)
	t.near(_gain("hum"), 1.0, 0.001, "full after 1.2 s")
	t.near(_gain("hvac"), 1.0, 0.001, "the ducts too")
	amb.set_scene("night")
	_step(0.6)
	t.near(_gain("hum"), 0.5, 0.01, "the office fades out")
	t.near(_gain("house"), 0.5, 0.01, "as the house fades in")
	_step(0.65)
	t.eq(_gain("hum"), 0.0, "gone after 1.2 s")
	t.ok(not _player("hum").playing, "and its player stops")
	t.ok(_player("house").playing and _player("rain").playing, "clock, fridge and rain")


func test_a_bed_that_renders_late_still_fades_in_from_silence() -> void:
	_playing_ambience(false)
	amb.set_scene("desk")
	_step(2.0)
	t.eq(_gain("hum"), 0.0, "no fade runs ahead of a bed that is still rendering")
	t.ok(not _player("hum").playing)
	amb.set_stream("office_hum", _stub("office_hum", true))
	_step(0.12)
	t.near(_gain("hum"), 0.1, 0.002, "it rises from silence once it arrives")
	t.ok(_player("hum").playing)
	t.ok(_player("hum").volume_db < -19.0, "quietly (%.1f dB), no pop" % _player("hum").volume_db)


func test_a_stamp_ducks_the_room_6_db_for_0_3_s() -> void:
	_playing_ambience()
	amb.set_scene("desk")
	var bus := AudioServer.get_bus_index("Ambience")
	_step(0.1)
	t.eq(AudioServer.get_bus_volume_db(bus), 0.0, "no duck before a stamp")
	sfx.play("stamp")
	_step(0.05)
	t.near(AudioServer.get_bus_volume_db(bus), -6.0, 0.01, "6 dB down at once")
	_step(0.1)
	t.near(AudioServer.get_bus_volume_db(bus), -6.0, 0.01, "held for 0.15 s")
	_step(0.075)
	t.near(AudioServer.get_bus_volume_db(bus), -3.0, 0.05, "on its way back up")
	_step(0.075)
	t.near(AudioServer.get_bus_volume_db(bus), 0.0, 0.01, "back after 0.3 s")
	sfx.play("stamp_heavy")
	_step(0.05)
	t.near(AudioServer.get_bus_volume_db(bus), -6.0, 0.01, "the heavy stamp ducks it too")
	_step(0.3)
	sfx.play("clack")
	_step(0.05)
	t.eq(AudioServer.get_bus_volume_db(bus), 0.0, "other sounds leave the room alone")


func test_the_hold_music_chimes_about_every_30_s() -> void:
	_playing_ambience()
	var clock: Array[float] = [0.0]
	var chimes: Array[float] = []
	amb.hold_chime.connect(func() -> void: chimes.append(clock[0]))
	var tick := func(seconds: float) -> void:
		var left := seconds
		while left > 0.00001:
			amb._process(0.1)
			clock[0] += 0.1
			left -= 0.1
	amb.set_scene("hold")
	var music := _player("music")
	while chimes.is_empty() and clock[0] < 40.0:
		tick.call(0.1)
	t.ok(music.playing, "the hold music plays")
	t.eq(chimes.size(), 1, "one chime")
	t.near(chimes[0] if not chimes.is_empty() else -1.0, 30.0, 0.15, "after 30 s of music")
	t.eq(amb._chime_player.stream, _stubs["hold_chime"], "the two-tone chime plays")
	tick.call(0.5)
	t.near(music.volume_db, linear_to_db(0.25), 0.1, "the music ducks under it")
	tick.call(3.0)
	t.near(music.volume_db, 0.0, 0.01, "then comes back up")
	while chimes.size() < 2 and clock[0] < 80.0:
		tick.call(0.1)
	var gap := chimes[1] - chimes[0] if chimes.size() > 1 else -1.0
	t.ok(gap >= 27.9 and gap <= 32.1, "and again about 30 s later (%.1f s)" % gap)


func test_hanging_up_stops_the_hold_music_dead() -> void:
	_playing_ambience()
	amb.set_scene("hold")
	_step(1.5)
	t.ok(_player("music").playing and _gain("music") == 1.0, "the music is up")
	sfx.play("handset")
	t.ok(not _player("music").playing, "the handset stops it at once, no fade")
	t.eq(_gain("music"), 0.0)
	_step(1.0)
	t.ok(not _player("music").playing, "and it stays off")


func test_one_shots_come_every_20_to_60_s_and_never_cough_to_an_empty_room() -> void:
	_playing_ambience()
	var desk := _fake_desk(0)
	amb.set_scene("desk", desk)
	amb.poll()
	t.eq(amb.waiting, 0, "nobody waiting")
	var heard := _one_shots(40)
	t.ok(not heard.has("cough"), "no cough with nobody there")
	t.ok(heard.has("phone") and heard.has("drawer"), "a phone, a drawer: %s" % ", ".join(heard))
	desk.set("claims", [Claim.new(), Claim.new(), Claim.new()])
	amb.poll()
	t.eq(amb.waiting, 3)
	heard = _one_shots(40)
	t.ok(heard.has("cough"), "people waiting cough")
	desk.set("ambience_quiet", true)
	amb.poll()
	amb._shot_player.stream = null
	_step(120.0, 1.0)
	t.ok(amb._shot_player.stream == null, "nothing while the desk wants quiet")
	amb.set_scene("memo")
	_step(120.0, 1.0)
	t.ok(amb._shot_player.stream == null, "nor away from the desk")


## Plays `count` one-shots, stepping exactly to each, and names them.
func _one_shots(count: int) -> Array[String]:
	var names: Array[String] = []
	for i in count:
		var wait: float = amb._shot_left
		amb._shot_player.stream = null
		amb._process(wait + 0.001)
		var shot: Variant = _stubs.find_key(amb._shot_player.stream)
		names.append(String(shot) if shot != null else "nothing")
		var next: float = amb._shot_left
		if next < 20.0 or next > 60.0:
			t.ok(false, "the next one comes 20 to 60 s later, not %.1f" % next)
	return names


func test_the_room_cuts_with_the_picture_when_the_desk_goes_alone() -> void:
	_playing_ambience()
	var desk: ScreenBase = await _open(DeskScreen.new())
	_step(1.5)
	t.eq(_gain("hum"), 1.0, "the office hums")
	# The day-7 cut: the desk is freed and nothing follows it for a while.
	await _close(desk)
	t.eq(amb.scene_id, "silence", "the scene cuts with the desk")
	_step(0.03)
	t.ok(_gain("hum") > 0.0 and _gain("hum") < 0.5, "a 0.05 s fade, not a click (%.2f)" % _gain("hum"))
	_step(0.03)
	t.eq(_gain("hum"), 0.0, "the hum is gone")
	t.ok(not _player("hum").playing)


func test_the_next_screen_takes_over_the_room_with_a_crossfade() -> void:
	_playing_ambience()
	var desk: ScreenBase = await _open(DeskScreen.new())
	_step(1.5)
	# main.gd frees the desk and adds the next screen in the same frame.
	_screens.erase(desk)
	desk.queue_free()
	await _open(LedgerScreen.new())
	t.eq(amb.scene_id, "night", "the ledger's night, no cut")
	_step(0.6)
	t.near(_gain("hum"), 0.5, 0.01, "the office fades over the usual 1.2 s")
	t.near(_gain("house"), 0.5, 0.01, "as the house comes in")


func test_hold_music_is_a_24_second_loop_at_8_khz() -> void:
	var wav: AudioStreamWAV = AMBIENCE.build_hold_music()
	t.near(wav.get_length(), 24.0, 0.1, "24 s")
	t.eq(wav.mix_rate, 8000, "telephone rate")
	t.eq(wav.loop_mode, AudioStreamWAV.LOOP_FORWARD, "loops")
	t.eq(wav.loop_end, 192000, "the whole 24 s")
	t.ok(_rms(wav.data) > db_to_linear(-40.0), "not silent")


func test_every_bed_loops_without_a_click() -> void:
	for bed: String in LOOPED_BEDS:
		var r: Dictionary = AMBIENCE.render_bed(bed)
		var pcm: PackedByteArray = r["pcm"]
		var n := pcm.size() / 2
		t.eq(r["rate"], 11025, "%s at 11025 Hz" % bed)
		t.eq(r["loop"], n, "%s loops over the whole stream" % bed)
		t.near(n / 11025.0, LOOPED_BEDS[bed], 0.001, "%s length" % bed)
		# The jump from the last sample back to the first is no bigger than the
		# bed's own sample-to-sample movement.
		var sum := 0.0
		for i in range(1, n):
			var d := float(pcm.decode_s16(i * 2) - pcm.decode_s16((i - 1) * 2))
			sum += d * d
		var typical := sqrt(sum / (n - 1))
		var seam := absf(float(pcm.decode_s16(0) - pcm.decode_s16((n - 1) * 2)))
		t.ok(seam <= 4.0 * typical + 8.0, "%s seam %d vs typical %.0f" % [bed, seam, typical])
	for shot in ["phone", "drawer", "cough", "hold_chime"]:
		var r: Dictionary = AMBIENCE.render_bed(shot)
		t.eq(r["loop"], 0, "%s plays once" % shot)
		t.ok((r["pcm"] as PackedByteArray).size() > 0, "%s rendered" % shot)


func test_beds_sit_at_their_levels() -> void:
	var levels := {"office_hum": -32.0, "office_hvac": -28.0, "murmur_a": -22.0, "protest": -27.0}
	for bed: String in levels:
		var r: Dictionary = AMBIENCE.render_bed(bed)
		t.near(linear_to_db(_rms(r["pcm"])), levels[bed], 1.0, "%s RMS" % bed)


func _rms(pcm: PackedByteArray) -> float:
	var sum := 0.0
	var n := pcm.size() / 2
	for i in n:
		var v := pcm.decode_s16(i * 2) / 32000.0
		sum += v * v
	return sqrt(sum / maxi(n, 1))
