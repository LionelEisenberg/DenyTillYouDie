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
func save_game() -> void:
	var tmp := _path() + ".tmp"
	var file := FileAccess.open(tmp, FileAccess.WRITE)
	if file == null:
		push_warning("Could not save: %s" % error_string(FileAccess.get_open_error()))
		return
	file.store_string(JSON.stringify(run.to_dict(), "\t"))
	file.close()
	var err := DirAccess.rename_absolute(ProjectSettings.globalize_path(tmp), ProjectSettings.globalize_path(_path()))
	if err != OK:
		push_warning("Could not replace save: %s" % error_string(err))


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


func delete_save() -> void:
	if FileAccess.file_exists(_path()):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(_path()))


func _read_save() -> Dictionary:
	if not FileAccess.file_exists(_path()):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(_path()))
	if parsed is Dictionary:
		return parsed
	return {}


func _path() -> String:
	return save_path_override if save_path_override != "" else SAVE_PATH
