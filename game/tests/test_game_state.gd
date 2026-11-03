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


func after_each() -> void:
	gs.delete_save()
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
