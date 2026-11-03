extends RefCounted

var t: TestContext
var gs: Node


func before_each() -> void:
	gs = (Engine.get_main_loop() as SceneTree).root.get_node("GameState")
	gs.save_path_override = "user://test_save.json"
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
	gs.decide(mine, true, "")
	t.eq(gs.run.ending, Endings.FIRED)
	t.ok(not gs.has_save())
