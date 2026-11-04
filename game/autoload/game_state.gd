extends Node
## Holds the current run and today's patients. Saves at the start of each
## morning, along with a snapshot of every morning so far. A finished run
## deletes its save, so Continue can't resume it, but leaves a retry file for
## replaying the morning that was lost, and files the outcome on record.

const SAVE_PATH := "user://save.json"
const DEFAULT_NAME := "J. Doe"
const RECORD_SECTION := "endings"
## Scratch save paths (tests and the screenshot tour) start with one of these.
const SCRATCH_PREFIXES: PackedStringArray = ["user://test_", "user://tour_"]

var run: RunState
var claims_today: Array[Claim] = []
## FOR TESTS AND TOOLS ONLY: the game itself never sets this. Points the save
## at a scratch file; the retry and record files sit beside it.
##
## Moving the override off a scratch path (one starting with SCRATCH_PREFIXES)
## deletes that path's retry and record files, so a test that reaches an ending
## leaves nothing behind once it resets the override. Any other path is left
## alone: switching away from a real save must never wipe a player's record.
var save_path_override: String = "":
	set(value):
		if value != save_path_override and is_scratch_path(save_path_override):
			_remove(save_path_override.get_basename() + "_retry.json")
			_remove(save_path_override.get_basename() + "_record.cfg")
		save_path_override = value
## This run's mornings: str(day) -> run.to_dict() as it stood that morning.
var mornings: Dictionary = {}


func new_run(player_name: String, seed_value: int = -1) -> void:
	var name_clean := player_name.strip_edges()
	if name_clean == "":
		name_clean = DEFAULT_NAME
	var run_seed := seed_value if seed_value >= 0 else randi()
	run = RunState.create(name_clean, run_seed)
	run.morning = {"paper": {}, "memo": NewsWriter.build_memo(run, {}), "letters": []}
	claims_today.clear()
	mornings = {}
	delete_retry()
	_snapshot_morning()
	save_game()


## Generates today's patients. Call when the shift starts. On day 7 a favor
## owed comes due as a sticky note on the player's own claim.
func begin_day() -> void:
	# Nothing changes between the morning save and the shift, so a morning that
	# was never saved (a run moved straight to a day) is on file from here.
	if not mornings.has(str(run.day)):
		_snapshot_morning()
	claims_today = ClaimGenerator.new(run.run_seed, run.player_name).generate_day(run.day)
	run.reset_today()
	if run.day == 7:
		var note := Endings.favor_note(run)
		for c in claims_today:
			if c.is_player and note != "":
				c.sticky_note = note


func decide(c: Claim, approve: bool, cited_rule: String) -> Dictionary:
	var result := ShiftLogic.apply_decision(run, c, approve, cited_rule)
	if c.is_player:
		# Day 7 has no night ledger, so its base pay is booked here.
		run.stats["earned"] += Economy.BASE_PAY
		run.ending = Endings.resolve_final(run, approve)
		_end_run()
	return result


func compliance_fee() -> int:
	return ShiftLogic.compliance_fee(run)


func pay_so_far() -> int:
	return ShiftLogic.pay_so_far(run)


func close_shift() -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([run.run_seed, run.day, "night"])
	return NightLogic.close_shift(run, rng)


func apply_ledger(paid: Dictionary) -> String:
	var ending := NightLogic.apply_ledger(run, paid)
	if ending == "":
		_snapshot_morning()
		save_game()
	else:
		_end_run()
	return ending


## Writes a temp file, then swaps it in, so a crash mid-write can't eat the save.
## A write that fails never replaces the old save. On Windows the swap deletes
## the old file before moving the new one in, so a crash in between leaves only
## the temp file, which `_read_save` falls back to.
func save_game() -> void:
	var tmp := _tmp_path()
	var data := run.to_dict()
	data["mornings"] = mornings
	if not _write_file(tmp, JSON.stringify(data, "\t")):
		_remove(tmp)
		return
	var err := DirAccess.rename_absolute(ProjectSettings.globalize_path(tmp), ProjectSettings.globalize_path(_path()))
	if err != OK:
		push_warning("Could not replace save: %s" % error_string(err))


## Writes `text` to `path`. False if the file could not be opened or written.
func _write_file(path: String, text: String) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_warning("Could not save: %s" % error_string(FileAccess.get_open_error()))
		return false
	var stored := file.store_string(text)
	var err := file.get_error()
	file.close()
	if not stored or err != OK:
		push_warning("Could not save: %s" % error_string(err if err != OK else ERR_FILE_CANT_WRITE))
		return false
	return true


func load_game() -> bool:
	var data := _read_save()
	if data.is_empty():
		return false
	run = RunState.from_dict(data)
	mornings = _mornings_from(data.get("mornings", {}))
	# A save is itself a morning, including one written before snapshots existed.
	if not mornings.has(str(run.day)):
		_snapshot_morning()
	claims_today.clear()
	return true


func has_save() -> bool:
	var data := _read_save()
	return not data.is_empty() and str(data.get("ending", "")) == ""


## The morning a Continue would resume, or 0 without a save.
func saved_day() -> int:
	return int(_read_save().get("day", 0))


## Removes the save and any temp file, so a finished run can't be continued.
func delete_save() -> void:
	_remove(_path())
	_remove(_tmp_path())


# --- retry and the record -----------------------------------------------------

## Where a finished run keeps its mornings: beside the save, per save path.
func retry_path() -> String:
	return _path().get_basename() + "_retry.json"


## Which endings this player has reached, across runs: beside the save.
func record_path() -> String:
	return _path().get_basename() + "_record.cfg"


## The morning a retry replays: the day whose shift or night was lost (day 7
## for the day-7 endings). 0 when there is nothing to retry.
func retry_day() -> int:
	var data := _read_json(retry_path())
	var day := int(data.get("day", 0))
	if day <= 0 or not _mornings_from(data.get("mornings", {})).has(str(day)):
		return 0
	return day


## Restores the morning of `day` from the retry file and saves it, so Continue
## resumes it too. The same seeded patients come back. False if that morning
## isn't on file.
func load_retry(day: int) -> bool:
	var saved := _mornings_from(_read_json(retry_path()).get("mornings", {}))
	if not saved.has(str(day)):
		return false
	run = RunState.from_dict(saved[str(day)])
	mornings = {}
	for key: String in saved:
		if int(key) <= day:
			mornings[key] = saved[key]
	claims_today.clear()
	save_game()
	return true


func delete_retry() -> void:
	_remove(retry_path())


## Files `id` as reached. Each ending counts once, however often it comes.
func record_ending(id: String) -> void:
	if id == "":
		return
	var record := _load_record()
	if record.has_section_key(RECORD_SECTION, id):
		return
	record.set_value(RECORD_SECTION, id, true)
	var err := record.save(record_path())
	if err != OK:
		push_warning("Could not file the outcome: %s" % error_string(err))


## How many of Endings.ALL are on file.
func outcomes_on_file() -> int:
	var record := _load_record()
	var count := 0
	for id in Endings.ALL:
		if record.has_section_key(RECORD_SECTION, id):
			count += 1
	return count


func clear_record() -> void:
	_remove(record_path())


## The run is over: file the outcome, keep the mornings for a retry, then remove
## the save so Continue can't resume a finished run.
func _end_run() -> void:
	record_ending(run.ending)
	var retry := {"ending": run.ending, "day": run.day, "mornings": mornings}
	if not _write_file(retry_path(), JSON.stringify(retry, "\t")):
		_remove(retry_path())
	delete_save()


## Keeps a copy of the run as it stands this morning.
func _snapshot_morning() -> void:
	mornings[str(run.day)] = run.to_dict().duplicate(true)


func _load_record() -> ConfigFile:
	var record := ConfigFile.new()
	if FileAccess.file_exists(record_path()):
		record.load(record_path())
	return record


## Morning snapshots read back from JSON, keyed "1".."7"; anything else dropped.
static func _mornings_from(raw: Variant) -> Dictionary:
	var out := {}
	if not (raw is Dictionary):
		return out
	for key: Variant in raw:
		var snapshot: Variant = (raw as Dictionary)[key]
		var day := int(str(key))
		if day >= 1 and day <= 7 and snapshot is Dictionary and not (snapshot as Dictionary).is_empty():
			out[str(day)] = (snapshot as Dictionary).duplicate(true)
	return out


## The saved run, or {} if there is none. Falls back to the temp file when the
## main file is missing or unreadable (a crash during the swap in `save_game`).
func _read_save() -> Dictionary:
	var data := _read_json(_path())
	if data.is_empty():
		data = _read_json(_tmp_path())
	return data


static func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	# A JSON instance reports a torn file quietly; JSON.parse_string logs an error.
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK:
		return {}
	var parsed: Variant = json.data
	if parsed is Dictionary:
		return parsed
	return {}


static func _remove(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


## Whether `path` is a scratch save (a test's or the tour's), whose files may be
## cleaned up without asking.
static func is_scratch_path(path: String) -> bool:
	for prefix in SCRATCH_PREFIXES:
		if path.begins_with(prefix):
			return true
	return false


func _path() -> String:
	return save_path_override if save_path_override != "" else SAVE_PATH


func _tmp_path() -> String:
	return _path() + ".tmp"
