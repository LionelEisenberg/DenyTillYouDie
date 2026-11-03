# Deny 'til You Die MVP Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A playable 7-day *Papers, Please*-style insurance-denial campaign in Godot 4.7, from title screen to one of five endings.

**Architecture:** Pure game rules live in static/`RefCounted` GDScript classes under `game/core/` and are tested headless. One `GameState` autoload holds the run. Screens are script classes built in code, swapped by an enum state machine in `main.tscn`.

**Tech Stack:** Godot 4.7.2 (`C:\Program Files (x86)\Godot\Godot_v4.7.2-stable_win64_console.exe`), GDScript with static types, Compatibility renderer, MatchupPro pixel font. No addons.

**Spec:** [2026-11-03-deny-til-you-die-mvp-design.md](../specs/2026-11-03-deny-til-you-die-mvp-design.md)

## Global Constraints

- New project at `game/`; never modify `deny-'til-you-die/` (the old project).
- `game/.gitignore` ignores `.godot/`. Commit `.uid` and `.import` sidecars Godot generates.
- `project.godot`: `config/name="Deny 'til You Die"`, `config/use_custom_user_dir=true`, `config/custom_user_dir_name="DenyTilYouDieMVP"`, base 1920×1080, stretch `canvas_items`, aspect `keep`, window override 1600×900, renderer `gl_compatibility`, default texture filter nearest.
- All text uses MatchupPro at 16, 24, 32 or 48 px (multiples of 8 render crisp), antialiasing off.
- Static typing everywhere (`var x: int`, typed arrays, typed returns).
- Fictional names only. No real people, companies or events.
- Tone: deadpan corporate voice. No character says denial is wrong.
- Headless test command (from repo root): `"/c/Program Files (x86)/Godot/Godot_v4.7.2-stable_win64_console.exe" --headless --path game --script res://tests/run_tests.gd`. Prints `ALL TESTS PASSED` and exits 0, or lists failures and exits 1.
- Run `--headless --path game --import` once after adding new `class_name` scripts or assets.

## Review Focus

1. **Brute-force citing.** Clicking every rule/field pair must cost $2 per miss, and a valid citation must stay valid if the player keeps clicking. Test: `test_compliance_fee_per_miss` (Task 4), `test_citation_persists_until_stamp` (Task 9).
2. **Double stamping or stamping with no patient.** A second stamp or a stamp before NEXT! does nothing. Test: `test_stamp_ignored_without_active_claim` (Task 9).
3. **Money going negative mid-shift.** Fines can push today's pay below zero; only the night ledger decides eviction, using savings + net pay − rent. Test: `test_eviction_uses_net_after_fines` (Task 5).
4. **Discontent outside 0–100.** Approvals at 0% must clamp at 0; values above 100 trigger scapegoating at the night check and after the final claim. Test: `test_discontent_clamps_at_zero`, `test_final_claim_scapegoats_over_100` (Tasks 4, 6).
5. **Continue after a game over.** A save must not resume a finished run. Test: `test_save_cleared_on_ending` (Task 7).

---

## File structure

```
game/
  project.godot, .gitignore, icon.svg
  assets/fonts/MatchupPro.ttf            copied from the old project
  autoload/game_state.gd                 GameState: run, today's claims, save/load
  autoload/sfx.gd                        Sfx: synthesized sounds
  core/date_util.gd                      DateUtil: day-number dates, MM/DD/YYYY
  core/claim.gd                          Claim: one patient's paperwork
  core/rule_checker.gd                   RuleChecker: violations, citations
  core/claim_generator.gd                ClaimGenerator: seeded days of claims
  core/economy.gd                        Economy: every tunable number
  core/run_state.gd                      RunState: serializable run data
  core/shift_logic.gd                    ShiftLogic: applying a decision
  core/night_logic.gd                    NightLogic: appeals, deaths, ledger, family, events
  core/news_writer.gd                    NewsWriter: paper, memo, letters
  core/endings.gd                        Endings: resolution and ending pages
  content/rules.gd                       Rules: R-01..R-07 definitions
  content/medical.gd                     Medical: procedures, diagnoses, providers, plans, filler history
  content/names.gd                       Names: first/last name pools
  content/lines.gd                       Lines: patient arrival and reaction lines
  content/news_pool.gd                   NewsPool: headlines, flavor items, obituary templates, agreement text
  content/scripted.gd                    Scripted: the six moral cases and the player's claim
  ui/palette.gd, ui/ui_theme.gd          Palette constants; Theme + label helpers
  ui/portrait_view.gd                    PortraitView: procedural faces
  ui/field_row.gd, ui/document_view.gd   clickable fields; draggable paper documents
  ui/rulebook_view.gd                    RulebookView: tabbed rulebook
  ui/cite_overlay.gd, ui/stamp_mark.gd, ui/floating_text.gd, ui/discontent_meter.gd
  screens/main.tscn, screens/main.gd     flow state machine
  screens/screen_base.gd                 ScreenBase: `signal done(payload: Dictionary)`
  screens/title_screen.gd, agreement_screen.gd, newspaper_screen.gd, memo_screen.gd,
  screens/desk_screen.gd, ledger_screen.gd, ending_screen.gd
  tests/run_tests.gd                     runner; discovers tests/test_*.gd
  tests/test_*.gd                        one file per core class
  tests/balance_sim.gd                   strategy simulation
  tests/screenshot_tour.gd               renders every screen to PNG (windowed run)
```

---

### Task 1: Project scaffold and test runner

**Files:** Create `game/project.godot`, `game/.gitignore`, `game/icon.svg`, `game/assets/fonts/MatchupPro.ttf`, `game/screens/main.tscn`, `game/screens/main.gd` (stub), `game/tests/run_tests.gd`, `game/tests/test_smoke.gd`.

**Interfaces — Produces:** test files are `extends RefCounted`, every `func test_*() -> void` is run; assertions through `var t: TestContext` injected as a member before each test: `t.eq(actual, expected, msg)`, `t.ok(cond, msg)`, `t.near(a: float, b: float, eps: float, msg)`.

- [ ] Write `test_smoke.gd::test_truth` asserting `t.ok(true)`; run the runner; expect `1 passed` and `ALL TESTS PASSED`.
- [ ] Run headless boot `--headless --path game --quit-after 30`; expect no errors.
- [ ] Commit `chore: scaffold Godot 4.7 project for the MVP`.

### Task 2: Dates, content tables and rules

**Files:** `core/date_util.gd`, `content/rules.gd`, `content/medical.gd`, `content/names.gd`, `tests/test_content.gd`, `tests/test_date_util.gd`.

**Interfaces — Produces:**
- `DateUtil.from_ymd(y: int, m: int, d: int) -> int` (days since 1970-01-01), `DateUtil.fmt(days: int) -> String` (`"03/02/2026"`), `DateUtil.fmt_month_year(days: int) -> String` (`"11/2025"`), `DateUtil.weekday(days: int) -> String` (`"Monday"`), `DateUtil.game_date(day: int) -> int` (day 1 = 03/02/2026).
- `Rules.ALL: Array[Dictionary]` with keys `id, title, short, text, day`; `Rules.unlocked(day: int) -> PackedStringArray`; `Rules.get_rule(id: String) -> Dictionary`. Ids `R-01`..`R-07`, days 1..7, titles: Coverage lapsed, Out-of-network provider, Clerical mismatch, No prior authorization, Pre-existing condition, Excluded service, Algorithmic determination (DenyBot™).
- `Medical.PROCEDURES: Dictionary` id → `{label, cost, pa, excluded}`; `Medical.DIAGNOSES: Array[Dictionary]` with `{id, label, condition, priority, procs: Array, excluded_addons: Array, pa_addons: Array, child_ok: bool, adult_ok: bool, chronic: bool}`; `Medical.PROVIDERS_IN`, `Medical.PROVIDERS_OUT: PackedStringArray` (8 and 6, with near-miss names such as "Riverside General Hospital" in, "Riverside Medical Center" out); `Medical.PLANS`; `Medical.FILLER_HISTORY: Array[Dictionary]` `{label, condition}`; `Medical.pa_labels() -> PackedStringArray`; `Medical.excluded_labels() -> PackedStringArray`.
- `Names.FIRST`, `Names.LAST: PackedStringArray` (≥ 60 each, diverse).

- [ ] Tests: `test_game_date_day_one` (`fmt(game_date(1)) == "03/02/2026"`, `weekday == "Monday"`), `test_day_seven_is_sunday`, `test_every_diagnosis_procedure_exists`, `test_each_priority_has_diagnoses_for_adults_and_children`, `test_chronic_diagnoses_exist_for_pre_existing` (≥ 6), `test_pa_and_excluded_procedures_exist` (≥ 5 each), `test_providers_disjoint`, `test_rules_one_per_day`. Run: fail.
- [ ] Implement; run: pass. Commit `feat: content tables, rules and date utilities`.

### Task 3: Claim, rule checker and generator

**Files:** `core/claim.gd`, `core/rule_checker.gd`, `core/claim_generator.gd`, `content/scripted.gd`, `tests/test_rule_checker.gd`, `tests/test_generator.gd`.

**Interfaces — Produces:**
- `Claim` (`RefCounted`): `enum Priority { ROUTINE, URGENT, CRITICAL }`; fields `claim_no, day, scripted_id, is_player, portrait_seed, age, name, dob, member_id, provider, date_of_service, diagnosis, condition, treatment, amount, priority, prior_auth, card_name, card_dob, card_member_id, plan, member_since, coverage_through, bill_lines: Array[Dictionary] ({id,label,cost,pa,excluded}), history: Array[Dictionary] ({date,label,condition}), arrival_line, parent_speaks, sticky_note, exempt_from_citation`; `is_child() -> bool` (age < 16); `shows_bill() -> bool` (day ≥ 4); `shows_history() -> bool` (day ≥ 5); `summary() -> Dictionary` (name, age, diagnosis, priority, scripted_id, child) for news.
- Evidence keys: `claim.claim_no|name|dob|member_id|provider|date_of_service|diagnosis|treatment|amount|priority|prior_auth`, `card.name|dob|member_id|plan|member_since|coverage_through`, `bill.provider|date_of_service|total|line.N`, `history.name|dob|entry.N`, and `denybot`.
- `RuleChecker.violations(c: Claim, day: int) -> Array[Dictionary]` (`{rule: String, evidence: PackedStringArray}`, unlocked rules only, never R-07); `RuleChecker.has_valid_reason(c, day) -> bool`; `RuleChecker.check_citation(c, rule_id: String, evidence_key: String, day: int) -> bool` (R-07 valid only with key `denybot` on day ≥ 7).
- `ClaimGenerator.new(run_seed: int, player_name: String)`; `generate_day(day: int) -> Array[Claim]` (deterministic; counts `[5,6,7,7,8,8,7]`, day 7 also appends the player's claim last); `const VIOLATION_TARGET := [0.40, 0.50, 0.55, 0.60, 0.60, 0.65, 0.65]`; the new rule of the day gets ~45% of injected violations.
- `Scripted.CASES: Dictionary` id → case data (walt d1, lily d2, dale d3, eleanor d4, priya d5, marcus d6) with `day, slot, name, age, diagnosis_id, violation, line, sticky_note, exempt_from_citation`; `Scripted.player_claim_data(player_name) -> Dictionary`.

- [ ] Tests (rule checker; build claims by hand): `test_r01_lapsed_detected` / `_clean`, `test_r02_out_of_network`, `test_r03_name_typo`, `test_r03_member_id`, `test_r03_dob`, `test_r04_missing_prior_auth` (only when a billed line has `pa`), `test_r05_pre_existing_before_member_since` (entry after enrollment is clean), `test_r06_excluded_line`, `test_rules_locked_before_their_day`, `test_citation_needs_matching_evidence`, `test_denybot_only_day_seven`.
- [ ] Tests (generator): `test_deterministic_by_seed`, `test_patient_counts_per_day`, `test_violation_share_near_target` (2,000 claims/day: within ±0.08), `test_clean_claims_have_no_violations_any_rule` (check with day-7 rules), `test_bill_totals_match_amount`, `test_dob_matches_age`, `test_scripted_case_in_slot_and_valid`, `test_player_claim_last_on_day_seven` (has R-02 and R-05, name = player name, amount ≥ 50,000).
- [ ] Run: fail. Implement. Run: pass. Commit `feat: claims, rule checker and seeded generator`.

### Task 4: Economy, run state and decisions

**Files:** `core/economy.gd`, `core/run_state.gd`, `core/shift_logic.gd`, `tests/test_shift_logic.gd`.

**Interfaces — Produces:**
- `Economy` constants (spec values): `BASE_PAY=30, COMMISSION=[15,25,40], BLIND_COMMISSION=[7,12,20], APPROVAL_COST=[5,10,15], DISCONTENT_DENY=[2,4,7], DISCONTENT_APPROVE=[1,2,3], CHILD_MULT=1.5, DENYBOT_MULT=2.0, PROTEST_EXTRA=1, COMPLIANCE_FEE=2, FREE_WARNINGS=2, CITATION_FINE=10, LEGAL_FEE=20, APPEAL_CHANCE=0.5, APPEAL_DISCONTENT=2, RENT=30, FOOD=15, HEAT=10, MEDICINE=25, START_SAVINGS=50, START_DISCONTENT=10, NIGHT_DECAY=2, DEATH_CHANCE=[0.0,0.10,0.40], DEATH_DISCONTENT=4, THRESHOLDS=[30,55,80], PROMOTION_RATE=0.6, BOSS_PENALTY=40`.
- `RunState`: `player_name, run_seed, day, savings, discontent: float, family: Array[Dictionary] ({id, name, role, hungry, cold, sick, sick_nights, alive}), stats: Dictionary (processed, denied, approved, cited, blind, deaths, earned, fines), events_fired: Array, effects: Dictionary (protest, audit, compassion), scripted_outcomes: Dictionary, today: Dictionary (commissions, deductions, fines, fees, warnings, decisions: Array), morning: Dictionary (paper, memo, letters), ending: String`; `static func create(name: String, run_seed: int) -> RunState`; `to_dict() -> Dictionary`; `static func from_dict(d: Dictionary) -> RunState`; `reset_today() -> void`.
- `ShiftLogic.apply_decision(run: RunState, c: Claim, approve: bool, cited_rule: String) -> Dictionary` returning `{pay: int, discontent: float, citation: bool, warning: int, fine: int}` and appending a decision record (`summary()` + `approved, cited_rule, blind, valid_reason`) to `run.today.decisions`; `ShiftLogic.compliance_fee(run: RunState) -> int`.

- [ ] Tests: `test_cited_denial_pays_commission_by_priority`, `test_blind_denial_pays_half`, `test_approval_costs_by_priority`, `test_child_denial_discontent_x1_5`, `test_denybot_doubles_discontent`, `test_protest_adds_one_per_denial`, `test_compassion_day_free_approvals_double_relief`, `test_missed_denial_two_warnings_then_fine`, `test_exempt_claim_never_cited` (Eleanor), `test_compliance_fee_per_miss`, `test_discontent_clamps_at_zero`, `test_run_state_round_trip`.
- [ ] Run: fail. Implement. Run: pass. Commit `feat: economy, run state and decision outcomes`.

### Task 5: Night: appeals, deaths, ledger, family, events

**Files:** `core/night_logic.gd`, `tests/test_night_logic.gd`.

**Interfaces — Produces:**
- `NightLogic.close_shift(run: RunState, rng: RandomNumberGenerator) -> Dictionary`: rolls appeals (blind denials without a valid reason: 50%, or 100% under audit) and deaths for today's denials (scripted cases: Walt and Marcus always die if denied; others by `DEATH_CHANCE`), applies scripted pre-ledger events (night 3: Riley sick, with a denied-claim note), and returns the ledger `{income: Array[{label, amount}], net: int, available: int, bills: Array[{id, label, amount, mandatory, default_on}], family: Array, notes: PackedStringArray, overturned: Array, deaths: Array, evicted: bool}`.
- `NightLogic.apply_ledger(run: RunState, paid: Dictionary) -> String` (`paid` = `{food: bool, heat: bool, medicine: Dictionary}`): sets savings, resolves family, applies death and appeal discontent and nightly decay, fires thresholds (sets tomorrow's `effects`), checks endings, stores tomorrow's `morning` via `NewsWriter`, advances `day`. Returns an ending id or `""`.

- [ ] Tests: `test_appeal_only_for_blind_without_reason`, `test_audit_overturns_all_blind_without_reason`, `test_walt_dies_if_denied`, `test_riley_sick_on_night_three`, `test_unpaid_food_two_nights_makes_sick`, `test_untreated_sick_two_nights_dies`, `test_medicine_cures`, `test_eviction_uses_net_after_fines`, `test_threshold_fires_once_and_sets_effect`, `test_scapegoated_at_100_after_night`, `test_nightly_decay`.
- [ ] Run: fail. Implement (with `NewsWriter` stubbed to return `{}` until Task 6). Run: pass. Commit `feat: night resolution and household ledger`.

### Task 6: Newspaper, memos, letters and endings

**Files:** `core/news_writer.gd`, `core/endings.gd`, `content/news_pool.gd`, `content/lines.gd`, `tests/test_news_and_endings.gd`.

**Interfaces — Produces:**
- `NewsWriter.build_paper(run: RunState, yesterday: Dictionary, rng: RandomNumberGenerator) -> Dictionary` → `{date: String, lead: {headline, sub}, items: Array[{headline, body}], stock: {symbol: "BMH", change: float}}`; `build_memo(run, yesterday) -> Dictionary` → `{date, to, from, subject, paragraphs: PackedStringArray}`; `build_letters(run, yesterday) -> Array[Dictionary]` (`{from, paragraphs}`). Lead priority: event > scripted outcome > discontent band.
- `Endings` ids `scapegoated, evicted, fired, employee_of_the_month, promoted`; `Endings.resolve_final(run: RunState, approved_own: bool) -> String` (scapegoated if discontent ≥ 100, else fired if approved, else promoted if denial rate ≥ 0.6, else employee_of_the_month); `Endings.denial_rate(run) -> float` (excludes the player's claim); `Endings.build(run, id) -> Dictionary` → `{title, paper: {headline, sub}, epilogue: PackedStringArray, stats: Array}`.
- `Lines.arrival(priority: int, parent: bool, rng) -> String`, `Lines.reaction(priority: int, approved: bool, rng) -> String`. `NewsPool` holds the text pools and `AGREEMENT: PackedStringArray`.

- [ ] Tests: `test_event_leads_paper`, `test_obituary_for_each_death`, `test_lily_denied_story`, `test_stock_rises_with_denials`, `test_memo_announces_new_rule`, `test_memo_reports_fines_and_appeals`, `test_walt_letter_after_denial`, `test_final_approve_is_fired`, `test_final_deny_high_rate_promoted`, `test_final_deny_low_rate_employee_of_month`, `test_final_claim_scapegoats_over_100`.
- [ ] Run: fail. Implement. Run: pass. Commit `feat: newspaper, memos, letters and endings`.

### Task 7: GameState autoload and save/load

**Files:** `autoload/game_state.gd`, register in `project.godot`, `tests/test_game_state.gd`.

**Interfaces — Produces:** `GameState.run: RunState`, `GameState.claims_today: Array[Claim]`, `new_run(player_name: String) -> void` (random seed, builds day-1 memo, saves), `begin_day() -> void`, `decide(c: Claim, approve: bool, cited_rule: String) -> Dictionary` (also sets `run.ending` for the player's claim), `compliance_fee() -> int`, `close_shift() -> Dictionary`, `apply_ledger(paid: Dictionary) -> String`, `save_game() -> void`, `load_game() -> bool`, `has_save() -> bool`, `delete_save() -> void`. `SAVE_PATH := "user://save.json"`. Tests use `GameState.save_path_override`.

- [ ] Tests: `test_new_run_creates_day_one_memo`, `test_save_load_resumes_morning`, `test_reload_replays_same_claims`, `test_save_cleared_on_ending`.
- [ ] Run: fail. Implement. Run: pass. Commit `feat: GameState autoload with save and load`.

### Task 8: Balance simulation and tuning

**Files:** `tests/balance_sim.gd`; adjust constants in `core/economy.gd` only.

- [ ] Strategies over 200 seeds: `approve_all`, `deny_all_blind`, `cite_or_approve`, `cite_or_blind_routine`, `cite_or_blind_all`. Print per strategy: mean final savings, mean final discontent, ending distribution, mean day of game over.
- [ ] Tune until: `cite_or_approve` reaches day 7 in ≥ 90% of runs with final discontent 55–85%; `deny_all_blind` is scapegoated with mean game-over day 3.5–5; `approve_all` is evicted with mean game-over day 3.5–5.5; at least one strategy can reach `promoted`.
- [ ] Re-run all tests (constants feed tests through `Economy`, so they still pass). Commit `balance: tune economy from strategy simulation`.

### Task 9: UI foundation, documents, portraits and the desk

**Files:** `ui/*`, `screens/screen_base.gd`, `screens/main.gd`, `screens/title_screen.gd`, `screens/agreement_screen.gd`, `screens/desk_screen.gd`, `tests/test_desk_flow.gd`.

**Interfaces — Produces:**
- `Palette` color constants; `UiTheme.build() -> Theme`, `UiTheme.font() -> FontFile`, `UiTheme.label(text: String, size: int, color: Color) -> Label`, `UiTheme.paper_box(color: Color) -> StyleBoxFlat`.
- `PortraitView` (`Control`): `enum Expression { NEUTRAL, WORRIED, RELIEVED, DEVASTATED, ANGRY }`, `show_patient(seed: int, age: int, sick: bool) -> void`, `set_expression(e: Expression) -> void`, `clear() -> void`.
- `DocumentView` (`PanelContainer`): `signal evidence_clicked(key: String, row: Control)`, `setup(title: String, rows: Array[Dictionary], width: int) -> void` (row: `{label, value, key}` or `{heading}`), `set_inspect(on: bool) -> void`, `find_row(key: String) -> Control`. Draggable; raises to front on press.
- `RulebookView`: `signal rule_clicked(rule_id: String, row: Control)`, `signal denybot_pressed`, `setup(day: int) -> void`, `set_inspect(on: bool)`, `find_rule_row(rule_id) -> Control`.
- `DeskScreen` test hooks: `call_next_patient() -> void`, `try_cite(rule_id: String, evidence_key: String) -> bool`, `stamp(approve: bool) -> void`, `active_claim() -> Claim`, `end_shift_ready() -> bool`.

- [ ] Tests (`test_desk_flow.gd`, desk instanced headless with a fixed run): `test_stamp_ignored_without_active_claim`, `test_valid_citation_then_deny_records_cited`, `test_invalid_citation_charges_fee`, `test_citation_persists_until_stamp`, `test_day_ends_after_last_patient`.
- [ ] Run: fail. Implement UI. Run: pass.
- [ ] Screenshot tour (windowed): title, agreement, desk mid-citation on day 6 (all documents). Check legibility at 1920×1080; fix overlaps. Commit `feat: desk, documents, portraits and title flow`.

### Task 10: Morning, night and ending screens, sound, full flow

**Files:** `screens/newspaper_screen.gd`, `memo_screen.gd`, `ledger_screen.gd`, `ending_screen.gd`, `autoload/sfx.gd`, `tests/test_full_flow.gd`, `tests/screenshot_tour.gd`, `game/README.md`.

- [ ] Test `test_autopilot_reaches_an_ending`: drives `Main` through all seven days headless with the `cite_or_approve` strategy using the desk hooks; asserts an ending screen is shown and no errors were pushed.
- [ ] Implement screens and `Sfx` (`play(name: String)` for `stamp, paper, bell, buzz, click, cash`). Run: pass.
- [ ] Screenshot tour of paper, memo, letter, ledger, every ending. Fix layout. Commit `feat: morning, night and ending screens with sound`.
- [ ] Write `game/README.md` (how to open and play in Godot 4.7, controls, run tests). Commit `docs: how to play the MVP`.

### Task 11: Review and polish

- [ ] Whole-branch code review by a fresh reviewer; fix confirmed findings; re-run tests and the screenshot tour. Commit `fix: review findings`.
