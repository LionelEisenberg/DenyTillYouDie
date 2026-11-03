extends Node
## Holds the current run and today's patients. Saves at the start of each
## morning; a finished run deletes its save so Continue can't resume it.

const SAVE_PATH := "user://save.json"
const DEFAULT_NAME := "J. Doe"

var run: RunState
var claims_today: Array[Claim] = []
## Tests point this at a scratch file.
var save_path_override: String = ""


func new_run(player_name: String, seed_value: int = -1) -> void:
	var name_clean := player_name.strip_edges()
	if name_clean == "":
		name_clean = DEFAULT_NAME
	var run_seed := seed_value if seed_value >= 0 else randi()
	run = RunState.create(name_clean, run_seed)
	run.morning = {"paper": {}, "memo": NewsWriter.build_memo(run, {}), "letters": []}
	claims_today.clear()
	save_game()


## Generates today's patients. Call when the shift starts.
func begin_day() -> void:
	claims_today = ClaimGenerator.new(run.run_seed, run.player_name).generate_day(run.day)
	run.reset_today()


func decide(c: Claim, approve: bool, cited_rule: String) -> Dictionary:
	var result := ShiftLogic.apply_decision(run, c, approve, cited_rule)
	if c.is_player:
		# Day 7 has no night ledger, so its base pay is booked here.
		run.stats["earned"] += Economy.BASE_PAY
		run.ending = Endings.resolve_final(run, approve)
		delete_save()
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
		save_game()
	else:
		delete_save()
	return ending


## Writes a temp file, then swaps it in, so a crash mid-write can't eat the save.
## A write that fails never replaces the old save. On Windows the swap deletes
## the old file before moving the new one in, so a crash in between leaves only
## the temp file, which `_read_save` falls back to.
func save_game() -> void:
	var tmp := _tmp_path()
	if not _write_file(tmp, JSON.stringify(run.to_dict(), "\t")):
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


func _path() -> String:
	return save_path_override if save_path_override != "" else SAVE_PATH


func _tmp_path() -> String:
	return _path() + ".tmp"
