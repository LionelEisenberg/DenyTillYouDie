extends RefCounted

var t: TestContext
var gs: Node


## A GameState whose writes can be made to fail partway, like a full disk.
class FailingSave extends "res://autoload/game_state.gd":
	var fail_writes := false

	func _write_file(path: String, text: String) -> bool:
		if not fail_writes:
			return super(path, text)
		var file := FileAccess.open(path, FileAccess.WRITE)
		file.store_string(text.left(40))
		file.close()
		return false


func _write(path: String, text: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()


func before_each() -> void:
	gs = (Engine.get_main_loop() as SceneTree).root.get_node("GameState")
	gs.save_path_override = TestContext.save_path()
	gs.delete_save()
	gs.delete_retry()
	gs.clear_record()


func after_each() -> void:
	gs.delete_save()
	gs.delete_retry()
	gs.clear_record()
	gs.save_path_override = ""
	gs.run = null


func _fingerprint(claims: Array) -> String:
	var parts: PackedStringArray = []
	for c: Claim in claims:
		parts.append("%s|%s|%d" % [c.claim_no, c.name, c.amount])
	return ",".join(parts)


func _pay_everything() -> Dictionary:
	var medicine := {}
	for m: Dictionary in gs.run.family:
		medicine[m["id"]] = true
	return {"food": true, "heat": true, "medicine": medicine}


func test_new_run_creates_day_one_memo() -> void:
	gs.new_run("Pat Doe", 42)
	t.eq(gs.run.day, 1)
	t.eq(gs.run.player_name, "Pat Doe")
	t.ok(String(gs.run.morning["memo"]["subject"]).contains("R-01"), "day-one memo")
	t.ok(gs.has_save(), "saved on hire")


func test_blank_name_defaults() -> void:
	gs.new_run("   ", 42)
	t.eq(gs.run.player_name, "J. Doe")


func test_save_load_resumes_morning() -> void:
	gs.new_run("Pat Doe", 42)
	gs.begin_day()
	for c: Claim in gs.claims_today:
		gs.decide(c, false, "")
	gs.close_shift()
	t.eq(gs.apply_ledger(_pay_everything()), "")
	var savings: int = gs.run.savings
	gs.run = null
	t.ok(gs.load_game(), "loads")
	t.eq(gs.run.day, 2)
	t.eq(gs.run.savings, savings)
	t.ok((gs.run.morning["paper"] as Dictionary).has("lead"), "paper waiting")


func test_reload_replays_same_claims() -> void:
	gs.new_run("Pat Doe", 42)
	gs.begin_day()
	var first := _fingerprint(gs.claims_today)
	gs.load_game()
	gs.begin_day()
	t.eq(_fingerprint(gs.claims_today), first)


func test_save_cleared_on_ending() -> void:
	gs.new_run("Pat Doe", 42)
	gs.run.savings = -500
	gs.begin_day()
	gs.close_shift()
	t.eq(gs.apply_ledger(_pay_everything()), Endings.EVICTED)
	t.ok(not gs.has_save(), "no continue after a game over")


func test_own_claim_ends_the_run() -> void:
	gs.new_run("Pat Doe", 42)
	gs.run.day = 7
	gs.begin_day()
	var mine: Claim = gs.claims_today[gs.claims_today.size() - 1]
	var earned_before: int = gs.run.stats["earned"]
	var result: Dictionary = gs.decide(mine, true, "")
	t.eq(gs.run.ending, Endings.FIRED)
	t.ok(not gs.has_save())
	t.eq(gs.run.stats["earned"], earned_before + int(result["pay"]) + Economy.BASE_PAY, "day-7 base pay counts")


func test_saving_twice_replaces_the_file() -> void:
	gs.new_run("Pat Doe", 42)
	gs.run.savings = 777
	gs.save_game()
	gs.run = null
	t.ok(gs.load_game())
	t.eq(gs.run.savings, 777, "second save replaced the first")
	t.ok(not FileAccess.file_exists(TestContext.save_path() + ".tmp"), "no temp file left behind")


func test_temp_file_alone_is_loadable() -> void:
	gs.new_run("Pat Doe", 42)
	gs.run.savings = 321
	gs.save_game()
	var path := TestContext.save_path()
	# What a crash leaves on Windows between deleting the old save and moving the new one in.
	DirAccess.rename_absolute(ProjectSettings.globalize_path(path), ProjectSettings.globalize_path(path + ".tmp"))
	t.ok(not FileAccess.file_exists(path), "only the temp file is left")
	gs.run = null
	t.ok(gs.has_save(), "Continue is offered")
	t.eq(gs.saved_day(), 1)
	t.ok(gs.load_game(), "loads from the temp file")
	if gs.run != null:
		t.eq(gs.run.savings, 321)


func test_torn_save_falls_back_to_the_temp_file() -> void:
	gs.new_run("Pat Doe", 42)
	gs.run.savings = 321
	var path := TestContext.save_path()
	_write(path + ".tmp", JSON.stringify(gs.run.to_dict()))
	_write(path, "{\"version\": 1, \"player_na")
	gs.run = null
	t.ok(gs.load_game(), "the unreadable save is skipped")
	if gs.run != null:
		t.eq(gs.run.savings, 321)


func test_stale_temp_file_does_not_shadow_the_save() -> void:
	gs.new_run("Pat Doe", 42)
	gs.run.savings = 777
	gs.save_game()
	var stale: Dictionary = gs.run.to_dict()
	stale["savings"] = 111
	_write(TestContext.save_path() + ".tmp", JSON.stringify(stale))
	gs.run = null
	t.ok(gs.load_game())
	t.eq(gs.run.savings, 777, "the real save wins")


func test_delete_save_removes_the_temp_file_too() -> void:
	gs.new_run("Pat Doe", 42)
	var path := TestContext.save_path()
	_write(path + ".tmp", JSON.stringify(gs.run.to_dict()))
	gs.delete_save()
	t.ok(not FileAccess.file_exists(path), "save removed")
	t.ok(not FileAccess.file_exists(path + ".tmp"), "temp file removed")
	t.ok(not gs.has_save(), "a finished run can't be continued from the temp file")


## Plays today's claims citing every valid reason, then pays every bill.
func _play_day() -> String:
	gs.begin_day()
	for c: Claim in gs.claims_today:
		var violations := RuleChecker.violations(c, gs.run.day)
		gs.decide(c, violations.is_empty(), "" if violations.is_empty() else violations[0]["rule"])
	gs.close_shift()
	return gs.apply_ledger(_pay_everything())


## Plays today and loses the house tonight.
func _evict_tonight() -> void:
	gs.begin_day()
	for c: Claim in gs.claims_today:
		gs.decide(c, true, "")
	gs.run.savings = -500
	gs.close_shift()
	t.eq(gs.apply_ledger(_pay_everything()), Endings.EVICTED, "evicted on night %d" % gs.run.day)


func test_an_eviction_on_night_3_retries_day_3() -> void:
	gs.new_run("Pat Doe", 42)
	t.eq(_play_day(), "")
	t.eq(_play_day(), "")
	t.eq(gs.run.day, 3)
	gs.begin_day()
	var day_three := _fingerprint(gs.claims_today)
	var savings: int = gs.run.savings
	_evict_tonight()
	t.ok(not gs.has_save(), "no Continue after a game over")
	t.eq(gs.retry_day(), 3, "the morning of the night that was lost")
	gs.run = null
	t.ok(gs.load_retry(3), "restores Wednesday morning")
	t.eq(gs.run.day, 3)
	t.eq(gs.run.ending, "")
	t.eq(gs.run.savings, savings, "as it stood that morning")
	gs.begin_day()
	t.eq(_fingerprint(gs.claims_today), day_three, "the same seeded patients")
	t.ok(gs.has_save(), "writes a normal save")
	t.eq(gs.saved_day(), 3, "so Continue resumes it")
	t.ok(not gs.load_retry(5), "a morning that never came can't be loaded")


func test_an_earlier_morning_on_file_loads_too() -> void:
	gs.new_run("Pat Doe", 42)
	t.eq(_play_day(), "")
	_evict_tonight()
	t.eq(gs.retry_day(), 2)
	t.ok(gs.load_retry(1), "Monday is on file as well")
	t.eq(gs.run.day, 1)
	t.eq(gs.mornings.keys(), ["1"], "mornings after the one loaded are dropped")


func test_mornings_go_into_the_save_and_come_back_with_continue() -> void:
	gs.new_run("Pat Doe", 42)
	t.eq(_play_day(), "")
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(TestContext.save_path()))
	var mornings: Dictionary = data["mornings"]
	var days := mornings.keys()
	days.sort()
	t.eq(days, ["1", "2"], "a snapshot per morning")
	t.eq(int(mornings["1"]["day"]), 1)
	t.ok(not (mornings["2"] as Dictionary).has("mornings"), "a snapshot holds no snapshots")
	gs.run = null
	gs.mornings = {}
	t.ok(gs.load_game())
	t.eq(gs.mornings.size(), 2, "Continue brings the mornings back")
	_evict_tonight()
	t.eq(gs.retry_day(), 2)


func test_a_save_from_before_snapshots_still_retries() -> void:
	gs.new_run("Pat Doe", 42)
	t.eq(_play_day(), "")
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(TestContext.save_path()))
	data.erase("mornings")
	_write(TestContext.save_path(), JSON.stringify(data))
	gs.run = null
	gs.mornings = {}
	t.ok(gs.load_game())
	t.ok(gs.mornings.has("2"), "the loaded morning is itself on file")
	_evict_tonight()
	t.eq(gs.retry_day(), 2)


func test_morning_snapshots_are_copies() -> void:
	gs.new_run("Pat Doe", 42)
	gs.run.savings = 999
	gs.run.family[0]["sick"] = true
	t.eq(int(gs.mornings["1"]["savings"]), Economy.START_SAVINGS, "later changes don't reach the morning on file")
	t.eq(gs.mornings["1"]["family"][0]["sick"], false)


func test_new_run_clears_the_retry() -> void:
	gs.new_run("Pat Doe", 42)
	_evict_tonight()
	t.eq(gs.retry_day(), 1)
	t.eq(gs.retry_path(), TestContext.save_path().get_basename() + "_retry.json", "beside the save")
	t.ok(FileAccess.file_exists(gs.retry_path()))
	gs.new_run("Pat Doe", 43)
	t.eq(gs.retry_day(), 0, "a new week has nothing to retry")
	t.ok(not FileAccess.file_exists(gs.retry_path()))


func test_the_record_counts_each_ending_once() -> void:
	t.eq(gs.record_path(), TestContext.save_path().get_basename() + "_record.cfg", "beside the save")
	t.eq(gs.outcomes_on_file(), 0)
	for i in 2:
		gs.new_run("Pat Doe", 42 + i)
		_evict_tonight()
	t.eq(gs.outcomes_on_file(), 1, "two evictions are one outcome")
	gs.new_run("Pat Doe", 42)
	t.eq(gs.outcomes_on_file(), 1, "a new week keeps the record")
	gs.run.day = 7
	gs.begin_day()
	gs.decide(gs.claims_today[gs.claims_today.size() - 1], true, "")
	t.eq(gs.run.ending, Endings.FIRED)
	t.eq(gs.outcomes_on_file(), 2, "a second outcome")
	t.eq(gs.retry_day(), 7, "a day-7 ending retries Sunday morning")
	gs.record_ending("not_an_ending")
	t.eq(gs.outcomes_on_file(), 2, "only real endings count")


func test_resetting_the_override_clears_its_scratch_files() -> void:
	gs.new_run("Pat Doe", 42)
	_evict_tonight()
	var retry: String = gs.retry_path()
	var record: String = gs.record_path()
	t.ok(FileAccess.file_exists(retry) and FileAccess.file_exists(record), "the ending wrote both files")
	gs.save_path_override = ""
	t.ok(not FileAccess.file_exists(retry), "the scratch retry file is gone")
	t.ok(not FileAccess.file_exists(record), "and the scratch record")
	t.eq(gs.record_path(), "user://save_record.cfg", "the real record sits beside the real save")
	gs.save_path_override = TestContext.save_path()


func test_switching_away_from_a_real_save_keeps_its_files() -> void:
	# Not a scratch path: say, a second profile. Named per process all the same.
	var profile := "user://profile_%d.json" % OS.get_process_id()
	var retry := profile.get_basename() + "_retry.json"
	var record := profile.get_basename() + "_record.cfg"
	_write(retry, "{}")
	_write(record, "[endings]\nevicted=true\n")
	gs.save_path_override = profile
	t.eq(gs.outcomes_on_file(), 1, "that profile's record")
	gs.save_path_override = TestContext.save_path()
	t.ok(FileAccess.file_exists(retry), "moving off it leaves its retry file alone")
	t.ok(FileAccess.file_exists(record), "and never wipes its record")
	t.ok(gs.is_scratch_path(TestContext.save_path()), "a test's own path is scratch")
	t.ok(not gs.is_scratch_path(profile) and not gs.is_scratch_path("user://save.json"), "a player's is not")
	for path in [retry, record]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func test_failed_write_keeps_the_old_save() -> void:
	var path := TestContext.save_path()
	var failing := FailingSave.new()
	failing.save_path_override = path
	failing.new_run("Pat Doe", 42)
	failing.run.savings = 777
	failing.fail_writes = true
	failing.save_game()
	t.ok(not FileAccess.file_exists(path + ".tmp"), "the half-written temp file is removed")
	failing.run = null
	t.ok(failing.load_game(), "the old save still loads")
	if failing.run != null:
		t.eq(failing.run.savings, Economy.START_SAVINGS, "the old save was kept")
	failing.free()
