class_name DeskScreen
extends ScreenBase
## The shift. Patients come to the booth window one at a time; their paperwork
## lands on the desk. The player reads, optionally cites a violation (INSPECT,
## then a rule and the evidence), and stamps APPROVED or DENIED.
##
## Day 1 coaches the first two patients. Day 7 ends with the adjuster's own claim,
## staged without a word; its stamp sends {"cut": true} so the flow cuts to black.

const BOOTH_W := 560.0
const TOP_H := 64.0
const TRAY_H := 112.0
const HINT_H := 40.0
const DESK_SIZE := Vector2(1360, 1080 - 64 - 112 - 40)
## The booth window's glass, in screen coordinates.
const WINDOW_RECT := Rect2(74, 180, 412, 472)
## Where papers from _extra_documents() land, cascading down from here.
const EXTRA_DOCS_AT := Vector2(930, 520)
## The adjuster's number: on the badge, and once on the NOW SERVING board.
const PLAYER_TICKET := 4471
## How far off the window's left edge a patient starts walking in, in blocks: the
## widest figure's outline and soft shadow (two blocks right) start out of sight.
const WALK_FROM := 38
## What an uncited denial prints under DENIED.
const UNCITED_CODE := "REASON: NOT STATED"
const STAMP_SIZE := Vector2(280, 80)
## The stamp's round trip, under half a second: it flies to the paper, hovers,
## drops, the game freezes on impact, and it goes back to the tray.
const STAMP_FLY := 0.18
const STAMP_HOVER := 0.06
const STAMP_DROP := 0.05
const HITSTOP := 0.05
const STAMP_RETURN := 0.15
## How far the citation slip rises out of the desk's lower edge.
const SLIP_RISE := 240.0
## Room for the top bar's effects line (from x 720 to the DISCONTENT caption).
const EFFECTS_WIDTH := 420.0
## The effects line's short names, for a day when the full ones don't fit.
const EFFECT_SHORT := {
	"PROTEST OUTSIDE": "PROTEST",
	"AUDIT IN PROGRESS": "AUDIT",
	"COMPASSION DAY": "COMPASSION",
}

const DAY_HINTS: PackedStringArray = [
	"",
	"Compare the card's COVERAGE THROUGH with the claim's DATE OF SERVICE.",
	"New rule R-02: check the claim's PROVIDER against the NETWORK tab in your rulebook.",
	"New rule R-03: NAME, MEMBER ID and DATE OF BIRTH on the claim must match the card exactly.",
	"New: itemized bill. Procedures on the PRIOR AUTH tab need a PRIOR AUTH # on the claim.",
	"New: medical history. The claimed condition, under any name, before MEMBER SINCE is pre-existing.",
	"New: EXCLUSIONS tab. Any excluded line on the bill is grounds for denial.",
	"New: DenyBot. Rulebook > DENYBOT > RUN DENYBOT works on any claim.",
]
const WARNINGS_HINT := "You may approve two claims with grounds for denial each day before fines."

## The day-1 coach. Every hint fits the strip: 100 characters at most.
const COACH_CITE: PackedStringArray = [
	"TRAINING  Coverage ended %s, before service on %s. That breaks R-01. Press INSPECT.",
	"TRAINING  Click R-01 in your manual.",
	"TRAINING  Now click the date that breaks it: COVERAGE THROUGH or DATE OF SERVICE.",
	"TRAINING  Cited. Stamp DENY (R-01) for full commission.",
]
const COACH_APPROVE := "TRAINING  Covered through %s, after service on %s. Nothing to cite. Stamp APPROVE."
const COACH_MISS := "No violation there. (Training: fee waived.)"
const COACH_UNCITED := "TRAINING  That was an uncited denial: half commission, and legal may lose the appeal. Cite first."
const COACH_UNCITED_CLEAN := "TRAINING  Nothing broke a rule. An uncited denial pays half, and legal may lose the appeal."
const COACH_MISSED := "TRAINING  This claim broke R-01. Approving it earned a citation."
const COACH_DONE := "Training complete. Press NEXT!"

const DENYBOT_ANALYZING := "ANALYZING..."
const DENYBOT_VERDICT := "DETERMINATION: DENY\nREASON: PROPRIETARY\nCONFIDENCE: 99.7%"

var day: int = 1
var claims: Array[Claim] = []
var index: int = -1
var current: Claim
var stamped: bool = false
var cited_rule: String = ""
var inspect: bool = false
var stamps_today: int = 0
## Day 1 coaches the first two patients through a citation or an approval.
var training_enabled := true
## Read by the Ambience autoload (with get()): true once the day-7 claim's papers
## are down, when the room drains to the hum.
var ambience_quiet := false
## Today's denied claim amounts, the adjuster's own claim excluded.
var saved_today: int = 0

var _sel_rule: String = ""
var _sel_rule_row: FieldRow
var _sel_key: String = ""
var _sel_key_row: FieldRow
## The rule and evidence rows of the current citation, kept red until the stamp.
var _cited_rows: Array[FieldRow] = []
## Bumped by every citation and every new patient, so a DenyBot run still
## ANALYZING can tell that the desk moved on without it.
var _citation_serial: int = 0
## Bumped by every new patient, so stamp and arrival animations still running for
## the last one stop touching the desk.
var _patient_serial: int = 0
var _docs: Array[DocumentView] = []
## Day-7 papers built but not yet laid down, one at a time.
var _unplaced: Array[DocumentView] = []
var _claim_doc: DocumentView
## The impression the last stamp left on the claim form.
var _last_mark: StampMark
## The impression of a stamp still in the air.
var _pending_mark: StampMark
var _rng := RandomNumberGenerator.new()
var _ticket_start := 0
var _training_done := false
var _coach_feedback := ""
var _coach_complete := false
var _coach_step := ""
var _stamps_outside_training := 0
var _shift_ending := false
## Set by on_shown(), once Main's fade-in is over. Until then Enter and N do
## nothing: a key pressed during the fade must not call a patient unseen.
var _shown := false
var _climax_waiting := false
var _climax_skip := false
var _hitstop_active := false
var _walk_tween: Tween
var _walk_k := -1
var _shown_pay := 0
var _pay_tween: Tween
var _last_tick := 0
var _saved_shown := 0
var _saved_tween: Tween
# Typing into the speech bubble.
var _typing := false
var _type_wait := 0.0
var _type_cps := 45.0
var _type_dot := 0.6
var _type_voice := ""
var _type_until_blip := 2
var _type_rng := RandomNumberGenerator.new()

var _stage: Control
var _desk: Control
var _desk_underlay: Control
var _desk_frame: Panel
var _rulebook: RulebookView
var _overlay: CiteOverlay
var _coach: CoachPulse
var _booth: BoothView
var _board: ServingBoard
var _portrait: PortraitView
var _poster_label: Label
var _bubble_box: PanelContainer
var _bubble_tail: Control
var _bubble: Label
var _next_button: Button
var _inspect_button: Button
var _approve_button: Button
var _deny_button: Button
var _approve_tool: StampTool
var _deny_tool: StampTool
var _approve_price: Label
var _deny_price: Label
var _cite_label: Label
var _target_label: Label
var _warnings_label: Label
var _hint_label: Label
var _skip_training: Button
var _banner: Label
var _day_label: Label
var _patient_label: Label
var _pay_label: Label
var _meter: DiscontentMeter
var _meter_label: Label
var _effects_label: Label
var _badge_slot: Control
var _saved_label: Label
var _booth_shade: ColorRect
var _booth_lights: ColorRect


func _ready() -> void:
	GameState.begin_day()
	day = GameState.run.day
	claims = GameState.claims_today
	_rng.seed = hash([GameState.run.run_seed, day, "desk"])
	_ticket_start = ticket_start(GameState.run.run_seed, day)
	_build()
	_update_hud(true)
	_show_saved(false)
	_refresh_hint()


func _exit_tree() -> void:
	# A desk freed mid-hitstop must not leave the game frozen.
	if _hitstop_active:
		_hitstop_active = false
		Engine.time_scale = 1.0
	_free_unplaced()


func on_shown() -> void:
	super()
	_shown = true


## Papers and the impression built for the desk but never put on it (the desk
## went first).
func _free_unplaced() -> void:
	for doc in _unplaced:
		if is_instance_valid(doc) and not doc.is_inside_tree():
			doc.free()
	_unplaced.clear()
	if is_instance_valid(_pending_mark) and not _pending_mark.is_inside_tree():
		_pending_mark.free()
	_pending_mark = null


func _process(delta: float) -> void:
	if _typing:
		_type(delta)


# --- rules the desk shows --------------------------------------------------------

## The day's first ticket on the NOW SERVING board: 30 to 70, seeded by run and day.
static func ticket_start(run_seed: int, for_day: int) -> int:
	return 30 + posmod(hash([run_seed, for_day, "ticket"]), 41)


## What a stamp would pay and do to discontent, from the same Economy helpers
## ShiftLogic uses. Never previews fines or appeal fees. Returns {pay, discontent}.
static func stamp_preview(c: Claim, approve: bool, cited: String, effects: Dictionary, on_day: int) -> Dictionary:
	if approve:
		var compassion: bool = effects.get("compassion", false)
		return {"pay": -Economy.approval_cost(c.priority, compassion), "discontent": -Economy.approval_relief(c, compassion)}
	var denybot := cited == Rules.R07 and Rules.is_unlocked(Rules.R07, on_day)
	var valid := denybot
	if not valid and cited != "":
		for v in RuleChecker.violations(c, on_day):
			if v["rule"] == cited:
				valid = true
	return {"pay": Economy.commission(c.priority, valid), "discontent": Economy.denial_discontent(c, denybot, effects.get("protest", false))}


## The murmur through the glass: a child's voice only when the child speaks, and
## none at all for the adjuster's own claim.
static func voice_for(c: Claim) -> String:
	if c.is_player:
		return ""
	if c.parent_speaks:
		return "voice_mid"
	if c.is_child():
		return "voice_high"
	return "voice_low" if c.age >= 60 else "voice_mid"


## The OUT time on the punch card: 08:00 plus 70 minutes a patient.
static func clock_out(processed: int) -> String:
	var minutes := 8 * 60 + 70 * processed
	return "%02d:%02d" % [(minutes / 60) % 24, minutes % 60]


# --- test hooks and actions --------------------------------------------------

func active_claim() -> Claim:
	return current if current != null and not stamped else null


func end_shift_ready() -> bool:
	return index >= claims.size() - 1 and stamped


## Patients still in the waiting room: everyone after the one at the window, the
## adjuster's own claim excluded.
func waiting_count() -> int:
	var n := 0
	for i in range(index + 1, claims.size()):
		if not claims[i].is_player:
			n += 1
	return n


## The ticket of patient `i`; the adjuster's own claim is #4471.
func ticket_for(i: int) -> int:
	return PLAYER_TICKET if claims[i].is_player else _ticket_start + i


func call_next_patient() -> void:
	if (current != null and not stamped) or _shift_ending:
		return
	if index >= claims.size() - 1:
		_end_shift()
		return
	var first := index < 0
	index += 1
	current = claims[index]
	stamped = false
	cited_rule = ""
	_citation_serial += 1
	_patient_serial += 1
	_cited_rows.clear()
	_clear_selection()
	# Papers still on the desk (a citation slip and what it was about) go first.
	_dismiss_documents()
	_last_mark = null
	_coach_feedback = ""
	_coach_complete = false
	if index >= 2:
		_training_done = true
	_banner.visible = false
	_cite_label.text = ""
	_deny_button.text = "DENY"
	_deny_tool.tag = ""
	_set_next_enabled(false)
	# The stamps wake once the claim form is down (see _papers_down).
	_set_stamps_enabled(false)
	_rulebook.set_denybot_enabled(day >= 7)
	_rulebook.show_denybot_result("")
	_rulebook.clear_marks()
	_booth.set_waiting(waiting_count(), _motion())
	_booth.set_progress(_progress())
	if current.is_player:
		_arrive_player()
	else:
		_arrive(first)
	_update_prices()
	_update_hud(false)
	_refresh_hint()


## Cites `rule_id` with `evidence_key` as if the player clicked both. Returns
## whether the citation was valid.
func try_cite(rule_id: String, evidence_key: String) -> bool:
	if active_claim() == null:
		return false
	if rule_id == Rules.R07:
		return _run_denybot()
	return _evaluate(rule_id, _rulebook.find_rule_row(rule_id), evidence_key, _find_evidence_row(evidence_key))


func stamp(approve: bool) -> void:
	if active_claim() == null:
		return
	var c := current
	var serial := _patient_serial
	var training := _training_active()
	stamped = true
	stamps_today += 1
	_set_inspect(false)
	_set_stamps_enabled(false)
	_finish_typing()
	var citing := not approve and cited_rule != ""
	var code := "" if approve else UNCITED_CODE
	if citing:
		code = "%s  %s" % [cited_rule, String(Rules.get_rule(cited_rule)["title"]).to_upper()]
		if cited_rule == Rules.R07:
			code = "R-07  ALGORITHMIC DETERMINATION"
	# The decision is booked before anything moves, so a desk freed mid-flight
	# has still stamped.
	var result := GameState.decide(c, approve, cited_rule if citing else "")
	if not approve and not c.is_player:
		saved_today += c.amount
	var completes := false
	if training:
		_coach_feedback = _coach_verdict(c, approve, citing)
		if index >= 1:
			_training_done = true
			completes = true
	else:
		_stamps_outside_training += 1
	var mark := _make_mark(approve, code)
	if _motion() and _claim_doc != null:
		await _fly_stamp(approve, mark, result, citing)
		if serial != _patient_serial:
			return
	else:
		_impact(approve, mark, result, citing)
	if c.is_player:
		await _climax_hold(1.5)
		finish({"cut": true})
		return
	await _hold(1.5)
	if serial != _patient_serial:
		return
	# Papers that earned a citation stay until NEXT!, with the missed rule marked.
	if not result["citation"]:
		_dismiss_documents()
	_walk_out(approve, c)
	await _hold(0.5)
	if serial != _patient_serial:
		return
	_set_next_enabled(true)
	if completes:
		if _coach_feedback != "":
			_refresh_hint()
			await _hold(2.5)
			if serial != _patient_serial:
				return
			_coach_feedback = ""
		_coach_complete = true
		Sfx.play("ding")
	_refresh_hint()


## Ends the day-1 coaching at once (SKIP TRAINING).
func skip_training() -> void:
	_training_done = true
	_coach_feedback = ""
	_coach_complete = false
	_coach.clear()
	_refresh_hint()


# --- arrivals ------------------------------------------------------------------

## An ordinary patient: the board calls their number, they walk up to the glass,
## their papers slide onto the desk halfway through the walk, then they speak. The
## stamps wake when the claim form lands, so a stamp can't fly at a paper that
## isn't there yet; the line goes on typing.
func _arrive(first: bool) -> void:
	var c := current
	_portrait.modulate.a = 1.0
	_portrait.with_parent = c.is_child() and c.parent_speaks
	_portrait.show_patient(c.portrait_seed, c.age, c.is_player)
	_board.show_ticket(ticket_for(index), _animate())
	Sfx.play("bell")
	var lead := _open_shutter() if first else 0.0
	var walk := 0.9 if c.priority == Claim.Priority.CRITICAL or c.age >= 75 else 0.5
	if not _motion():
		walk = 0.0
	_walk_in(lead, walk)
	_spawn_documents(c, lead + walk / 2.0)
	_say(_arrival_line(c), lead + walk, 45.0, voice_for(c))


## The adjuster's own claim. No bell and no walk.
func _arrive_player() -> void:
	var c := current
	_stop_walk()
	_portrait.with_parent = false
	_portrait.fig_offset = Vector2i.ZERO
	_portrait.show_patient(c.portrait_seed, c.age, true)
	if not _animate():
		_board.show_ticket(PLAYER_TICKET, false)
		_dim_lights()
		_booth.set_sheen(0.12)
		_portrait.modulate.a = 1.0
		_spawn_documents(c)
		_say(_arrival_line(c))
		ambience_quiet = true
		return
	_portrait.modulate.a = 0.0
	_bubble.text = ""
	_stage_player(_patient_serial)


## Day 7's last patient, staged without a word: the board stops on 4471, the lights
## stutter and stay low, the adjuster's own face fades in behind a heavier glare,
## the papers land one at a time, and the bubble fills with three slow dots.
func _stage_player(serial: int) -> void:
	var c := current
	_board.show_ticket(PLAYER_TICKET, true, false)
	await _hold(0.4)
	if serial != _patient_serial:
		return
	await _stutter_lights()
	if serial != _patient_serial:
		return
	_booth.set_sheen(0.12)
	var fade := create_tween()
	fade.tween_property(_portrait, "modulate:a", 1.0, 2.5)
	await _hold(1.0)
	if serial != _patient_serial or stamped:
		return
	var layout := _document_layout(c)
	for entry: Array in layout:
		_unplaced.append(entry[0])
	for entry: Array in layout:
		if serial != _patient_serial or stamped:
			_free_unplaced()
			return
		var doc: DocumentView = entry[0]
		_unplaced.erase(doc)
		_add_document(doc)
		_slide_in(doc, entry[1], 0.0)
		Sfx.play("paper")
		await _hold(0.5)
	if serial != _patient_serial or stamped:
		return
	ambience_quiet = true
	if active_claim() != null:
		_set_stamps_enabled(true)
	_say(_arrival_line(c), 0.0, 45.0, "", 0.7)
	_refresh_hint()


## The booth lights flicker three times in half a second, then stay low.
func _stutter_lights() -> void:
	if _motion():
		Sfx.play("flicker")
		for i in 3:
			_booth_lights.color.a = 0.55
			await _hold(0.08)
			_booth_lights.color.a = 0.05
			await _hold(0.087)
	_dim_lights()


func _dim_lights() -> void:
	_booth_lights.color.a = 0.2
	_booth.set_lights(false)


## The first NEXT! of the day rattles the shutter up. Returns how long it takes.
func _open_shutter() -> float:
	if not _motion():
		_booth.set_shutter(0.0)
		return 0.0
	Sfx.play("shutter_up")
	create_tween().tween_method(_rattle_shutter, 1.0, 0.0, 0.6)
	return 0.6


## The shutter moves in small jerks, never smoothly.
func _rattle_shutter(f: float) -> void:
	_booth.set_shutter(snappedf(f, 1.0 / 30.0))


func _walk_in(delay: float, duration: float) -> void:
	_stop_walk()
	if duration <= 0.0:
		_portrait.fig_offset = Vector2i.ZERO
		return
	_portrait.fig_offset = Vector2i(-WALK_FROM, 0)
	_walk_k = -1
	_walk_tween = create_tween()
	if delay > 0.0:
		_walk_tween.tween_interval(delay)
	_walk_tween.tween_method(_walk_step.bind(-WALK_FROM, 0, 0), 0.0, 1.0, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


## The patient leaves: briskly when approved, at a normal pace when denied, and,
## after a moment and a sag, slowly when a critical or scripted claim is denied.
func _walk_out(approved: bool, c: Claim) -> void:
	if c.is_player:
		return
	_stop_walk()
	if not _motion() or _portrait.fig_offset.x != 0:
		# Instant, or stamped before they even reached the glass.
		_portrait.clear()
		_portrait.fig_offset = Vector2i.ZERO
		return
	var heavy := not approved and (c.priority == Claim.Priority.CRITICAL or c.scripted_id != "")
	var duration := 0.4 if approved else (1.2 if heavy else 0.6)
	_walk_k = -1
	_walk_tween = create_tween()
	if heavy:
		_walk_tween.tween_interval(0.8)
		_walk_tween.tween_callback(_set_fig.bind(Vector2i(0, 1)))
		_walk_tween.tween_interval(0.25)
	_walk_tween.tween_method(_walk_step.bind(0, WALK_FROM, 1 if heavy else 0), 0.0, 1.0, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_walk_tween.tween_callback(_portrait.clear)


## One frame of a walk, `p` from 0 to 1. The figure moves in two-block steps and
## bobs up a block on every other step; two footsteps sound on the way.
func _walk_step(p: float, from: int, to: int, sink: int) -> void:
	var steps := absi(to - from) / 2
	var k := clampi(roundi(p * steps), 0, steps)
	var bob := -1 if k % 2 == 1 and k < steps else 0
	_portrait.fig_offset = Vector2i(from + signi(to - from) * k * 2, sink + bob)
	if k != _walk_k:
		if k == steps / 3 or k == (2 * steps) / 3:
			Sfx.play("step")
		_walk_k = k


func _stop_walk() -> void:
	if _walk_tween:
		_walk_tween.kill()
		_walk_tween = null


func _set_fig(offset: Vector2i) -> void:
	_portrait.fig_offset = offset


# --- the stamp -------------------------------------------------------------------

## The impression for this stamp, placed on the claim form but not yet inked.
func _make_mark(approve: bool, code: String) -> StampMark:
	var mark := StampMark.create(approve, code)
	mark.ink_seed = _rng.randi()
	var paper := _claim_doc.size if _claim_doc != null else Vector2(500, 480)
	mark.position = Vector2(paper.x / 2.0 - mark.size.x / 2.0 + _rng.randf_range(-30, 30), paper.y - mark.size.y - 30 + _rng.randf_range(-20, 10))
	mark.rotation_degrees = _rng.randf_range(-9.0, 9.0)
	_pending_mark = mark
	return mark


## A copy of the stamp leaves the tray, flies to the claim form wherever it lies,
## hovers, drops, freezes the game for a beat on impact, and goes back. The day-7
## stamp travels at half speed and hangs in the air for half a second.
func _fly_stamp(approve: bool, mark: StampMark, result: Dictionary, citing: bool) -> void:
	var serial := _patient_serial
	var heavy := current.is_player
	var slow := 2.0 if heavy else 1.0
	var tool := _approve_tool if approve else _deny_tool
	var flier := tool.copy()
	var home := tool.global_position - _stage.global_position
	flier.position = home
	_stage.add_child(flier)
	tool.visible = false
	var center := _claim_doc.overlay.global_position + mark.position + mark.size / 2.0
	var target := center - _stage.global_position - flier.pad_center()
	var tween := create_tween()
	tween.tween_property(flier, "position", target - Vector2(0, 36), STAMP_FLY * slow).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_interval(0.5 if heavy else STAMP_HOVER)
	tween.tween_property(flier, "position", target, STAMP_DROP * slow).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await tween.finished
	if serial != _patient_serial:
		# The desk moved on mid-flight: the decision stands, the impression doesn't.
		_return_tool(flier, tool)
		if mark == _pending_mark:
			_pending_mark = null
		mark.free()
		return
	_impact(approve, mark, result, citing)
	await _hitstop()
	_shake(12.0 if heavy else 6.0)
	var back := create_tween()
	back.tween_property(flier, "position", home, STAMP_RETURN).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	back.tween_callback(_return_tool.bind(flier, tool))


func _return_tool(flier: StampTool, tool: StampTool) -> void:
	flier.queue_free()
	tool.visible = true


## The moment the rubber meets the paper: the impression at full ink, the thud,
## the pay and discontent pops, the slip if it earned one, and the patient's answer.
func _impact(approve: bool, mark: StampMark, result: Dictionary, citing: bool) -> void:
	var c := current
	_pending_mark = null
	if _claim_doc != null:
		_claim_doc.overlay.add_child(mark)
		_claim_doc.move_to_front()
		_last_mark = mark
	else:
		mark.free()
	Sfx.play("stamp_heavy" if c.is_player else "stamp")
	_show_feedback(result)
	if result["citation"] and not c.is_player:
		_print_citation(result)
	_react(approve, citing)
	_booth.set_processed(stamps_today)
	if not approve and not c.is_player:
		_show_saved(true)
	_update_hud(false)
	_refresh_hint()
	if c.is_player: # From here a click cuts the stillness short.
		_climax_skip = false
		_climax_waiting = _animate()


## Freezes the game for 50 ms on impact. A real-time timer brings time back even if
## this desk is gone by then (and _exit_tree does too).
func _hitstop() -> void:
	if Engine.get_meta("reduce_motion", false) or not is_inside_tree():
		return
	_hitstop_active = true
	Engine.time_scale = 0.0
	var timer := get_tree().create_timer(HITSTOP, true, false, true)
	timer.timeout.connect(Engine.set_time_scale.bind(1.0))
	await timer.timeout
	_hitstop_active = false


## Holds still after the week's last stamp; a click since the impact ends it early.
## Game time, so it stands still while the Esc menu pauses the game.
func _climax_hold(seconds: float) -> void:
	if not _animate():
		_climax_waiting = false
		return
	_climax_waiting = true
	var left := seconds
	while left > 0.0 and not _climax_skip:
		await get_tree().process_frame
		if not is_inside_tree():
			return
		if not get_tree().paused:
			left -= get_process_delta_time()
	_climax_waiting = false


## Waits `seconds` (not at all in fast mode) on a timer that stops while the game
## is paused, so nothing the desk has lined up (the next step of a stamp, END
## SHIFT's finish) happens behind the Esc menu.
func _hold(seconds: float) -> void:
	if not _animate():
		return
	await get_tree().create_timer(seconds, false).timeout


# --- citations ---------------------------------------------------------------

func _on_rule_clicked(rule_id: String, row: FieldRow) -> void:
	if not inspect or active_claim() == null:
		return
	if rule_id == Rules.R07:
		# DenyBot needs no evidence: citing R-07 just runs it.
		_set_inspect(false)
		_rulebook.show_page("DENYBOT")
		_on_denybot_pressed()
		return
	_unmark(_sel_rule_row)
	_sel_rule = rule_id
	_sel_rule_row = row
	row.set_mark(FieldRow.Mark.SELECTED)
	Sfx.play("click")
	if _sel_key != "":
		_try_selection()
	else:
		_refresh_hint()


func _on_evidence_clicked(key: String, row: FieldRow) -> void:
	if not inspect or active_claim() == null:
		return
	_unmark(_sel_key_row)
	_sel_key = key
	_sel_key_row = row
	row.set_mark(FieldRow.Mark.SELECTED)
	Sfx.play("click")
	if _sel_rule != "":
		_try_selection()
	else:
		_refresh_hint()


func _try_selection() -> void:
	if _sel_rule != "" and _sel_key != "":
		_evaluate(_sel_rule, _sel_rule_row, _sel_key, _sel_key_row)


func _evaluate(rule_id: String, rule_row: FieldRow, key: String, key_row: FieldRow) -> bool:
	if RuleChecker.check_citation(current, rule_id, key, day):
		_apply_citation(rule_id, rule_row, key_row)
		return true
	Sfx.play("buzz")
	var training := _training_active()
	var miss := COACH_MISS
	if not training:
		var fee := GameState.compliance_fee()
		var pop := "-%s" % UiTheme.money(fee)
		if _motion():
			FloatingText.fly(self, pop, Palette.RED, _feedback_spot(0), _pay_target(), 0.0, _land_pay)
		elif _animate(): # Reduce motion: it fades where it is; the readout changes now.
			FloatingText.spawn(self, pop, Palette.RED, _feedback_spot(0), 0.0, 0.0)
		miss = "No violation there. Compliance review fee: %s." % UiTheme.money(fee)
	for row: FieldRow in [rule_row, key_row]:
		if row and is_instance_valid(row):
			row.set_mark(FieldRow.Mark.INVALID)
	_update_hud(false)
	# The miss drops the whole selection. In training the coach's pulse goes back
	# to the step that needs doing now; its words return once the grey marks fade.
	_clear_selection_later(rule_row, key_row)
	if training:
		_refresh_hint(true)
	_hint_label.text = miss
	return false


func _apply_citation(rule_id: String, rule_row: FieldRow, key_row: FieldRow) -> void:
	_rulebook.clear_marks()
	if _claim_doc:
		for doc in _docs:
			doc.clear_marks()
	cited_rule = rule_id
	_citation_serial += 1
	# Forget the old citation first, so leaving inspect mode doesn't paint its rows red again.
	_cited_rows.clear()
	_set_inspect(false)
	for row: FieldRow in [rule_row, key_row]:
		if row:
			row.set_mark(FieldRow.Mark.VALID)
			_cited_rows.append(row)
	if rule_row and key_row:
		_overlay.link(rule_row, key_row)
	var title := String(Rules.get_rule(rule_id)["title"]).to_upper()
	_flash_banner("VIOLATION: %s (%s)" % [title, rule_id])
	_cite_label.text = "CITED: %s %s" % [rule_id, title]
	_deny_button.text = "DENY (%s)" % rule_id
	_deny_tool.tag = rule_id
	Sfx.play("ding")
	_sel_rule = ""
	_sel_key = ""
	_update_prices()
	_refresh_hint()


func _run_denybot() -> bool:
	if day < 7 or active_claim() == null:
		return false
	_rulebook.show_denybot_result(DENYBOT_VERDICT)
	_overlay.clear()
	cited_rule = Rules.R07
	_citation_serial += 1
	_cited_rows.clear()
	# DenyBot needs no evidence: drop inspect mode and any half-made selection,
	# or the next click on a paper would pair with a rule picked before.
	_set_inspect(false)
	_rulebook.clear_marks()
	for doc in _docs:
		doc.clear_marks()
	_flash_banner("DENYBOT: DENY (R-07)")
	_cite_label.text = "CITED: R-07 ALGORITHMIC DETERMINATION"
	_deny_button.text = "DENY (R-07)"
	_deny_tool.tag = Rules.R07
	Sfx.play("ding")
	_update_prices()
	_refresh_hint()
	return true


func _on_denybot_pressed() -> void:
	if active_claim() == null:
		return
	var serial := _citation_serial
	_rulebook.show_denybot_result(DENYBOT_ANALYZING)
	Sfx.play("click")
	await _hold(0.8)
	if active_claim() == null or serial != _citation_serial:
		# The player cited something by hand, stamped or moved on while DenyBot
		# thought it over. Their call stands; only the stale "ANALYZING..." goes.
		if _rulebook.denybot_text() == DENYBOT_ANALYZING:
			_rulebook.show_denybot_result("")
		return
	_run_denybot()


var _banner_tween: Tween


## Shows the red banner across the desk for a moment.
func _flash_banner(text: String) -> void:
	if _banner_tween:
		_banner_tween.kill()
	_banner.text = text
	_banner.visible = true
	_banner.modulate.a = 1.0
	if fast:
		return
	_banner_tween = create_tween()
	_banner_tween.tween_interval(1.4)
	_banner_tween.tween_property(_banner, "modulate:a", 0.0, 0.5)
	_banner_tween.tween_callback(func() -> void: _banner.visible = false)


func _clear_selection() -> void:
	for row: Variant in [_sel_rule_row, _sel_key_row]:
		_unmark(row)
	_sel_rule = ""
	_sel_key = ""
	_sel_rule_row = null
	_sel_key_row = null


## Drops the selection now and clears a missed citation's grey marks after a
## moment. Then a training miss gives the hint strip back to the coach.
func _clear_selection_later(rule_row: FieldRow, key_row: FieldRow) -> void:
	_sel_rule = ""
	_sel_key = ""
	_sel_rule_row = null
	_sel_key_row = null
	var serial := _patient_serial
	await _hold(0.6)
	for row: Variant in [rule_row, key_row]:
		# A row the player has already picked again keeps its live selection.
		if is_instance_valid(row) and row != _sel_rule_row and row != _sel_key_row:
			_unmark(row)
	if _animate() and serial == _patient_serial and _hint_label.text == COACH_MISS:
		_refresh_hint()


## Takes a selection or miss mark off `row`: back to red if the row belongs to
## the current citation, plain otherwise. Accepts null and freed rows.
func _unmark(row: Variant) -> void:
	if not is_instance_valid(row):
		return
	var field := row as FieldRow
	field.set_mark(FieldRow.Mark.VALID if _cited_rows.has(field) else FieldRow.Mark.NONE)


func _set_inspect(on: bool) -> void:
	inspect = on and active_claim() != null
	_rulebook.set_inspect(inspect)
	if inspect:
		# The rules to click live on the RULES page, not the reference tabs.
		_rulebook.show_page("RULES")
	for doc in _docs:
		doc.set_inspect(inspect)
	if not inspect:
		_clear_selection()
	_desk_frame.visible = inspect
	_booth_shade.color.a = 0.25 if inspect else 0.0
	_inspect_button.text = "INSPECTING (SPACE)" if inspect else "INSPECT (SPACE)"
	_refresh_hint()


func _find_evidence_row(key: String) -> FieldRow:
	for doc in _docs:
		var row := doc.find_row(key)
		if row:
			return row
	return null


# --- what patients say --------------------------------------------------------------

func _arrival_line(c: Claim) -> String:
	var event := EventLines.opening(c, GameState.run.effects)
	if event != "":
		return event
	if c.arrival_line != "":
		return c.arrival_line
	var rng := RandomNumberGenerator.new()
	rng.seed = c.line_seed
	return Lines.arrival(c.priority, c.parent_speaks, c.first_name(), rng)


## Everything the patient may say once the stamp lands, chosen in one place.
func _reaction_line(approve: bool, citing: bool) -> String:
	var rng := RandomNumberGenerator.new()
	rng.seed = current.line_seed + 1
	var line := Scripted.reaction("player" if current.is_player else current.scripted_id, approve)
	if line != "":
		return line
	line = current.reaction_approved if approve else current.reaction_denied
	if line == "":
		line = Lines.reaction(current.priority, approve, current.parent_speaks, rng)
	if citing and cited_rule != Rules.R07 and rng.randf() < 0.35:
		line = Lines.code_reaction(cited_rule, Rules.get_rule(cited_rule)["title"], rng)
	return line


func _react(approve: bool, citing: bool) -> void:
	var c := current
	var heavy := not approve and c.priority == Claim.Priority.CRITICAL
	_say(_reaction_line(approve, citing), 0.4 if heavy else 0.0, 25.0 if heavy else 45.0, voice_for(c), 0.7 if c.is_player else 0.6)
	if c.is_player:
		_portrait.set_expression(PortraitView.Mood.NEUTRAL)
	elif approve:
		_portrait.set_expression(PortraitView.Mood.RELIEVED)
	elif c.priority == Claim.Priority.ROUTINE:
		_portrait.set_expression(PortraitView.Mood.ANGRY)
	else:
		_portrait.set_expression(PortraitView.Mood.DEVASTATED)


## Types `text` into the bubble after `delay` seconds at `cps` characters a second,
## with a murmured `voice` blip every second or third letter. A run of dots types
## one dot every `dot` seconds, silently. Nothing waits on it, and a click on the
## bubble finishes the line. Instant in fast mode.
func _say(text: String, delay: float = 0.0, cps: float = 45.0, voice: String = "", dot: float = 0.6) -> void:
	_bubble.text = text
	if not _animate() or text == "":
		_finish_typing()
		return
	_bubble.visible_characters = 0
	_typing = true
	_type_cps = cps
	_type_voice = voice
	_type_dot = dot
	_type_rng.seed = hash(text)
	_type_until_blip = _type_rng.randi_range(2, 3)
	_type_wait = delay + _char_delay(0)


func _finish_typing() -> void:
	_typing = false
	_bubble.visible_characters = -1


func _type(delta: float) -> void:
	_type_wait -= delta
	var text := _bubble.text
	while _typing and _type_wait <= 0.0:
		var n := _bubble.visible_characters
		if n < 0 or n >= text.length():
			_finish_typing()
			return
		_bubble.visible_characters = n + 1
		if _type_voice != "" and _is_letter(text[n]):
			_type_until_blip -= 1
			if _type_until_blip <= 0:
				Sfx.play(_type_voice)
				_type_until_blip = _type_rng.randi_range(2, 3)
		if n + 1 >= text.length():
			_finish_typing()
			return
		_type_wait += _char_delay(n + 1)


## How long the bubble waits before showing character `i`.
func _char_delay(i: int) -> float:
	var text := _bubble.text
	if i < text.length() and text[i] == ".":
		var run := (i > 0 and text[i - 1] == ".") or (i + 1 < text.length() and text[i + 1] == ".")
		if run:
			return _type_dot
	return 1.0 / _type_cps


static func _is_letter(ch: String) -> bool:
	var code := ch.unicode_at(0)
	return (code >= 48 and code <= 57) or (code >= 65 and code <= 90) or (code >= 97 and code <= 122) or code > 127


func _on_bubble_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
		_finish_typing()
		_bubble_box.accept_event()


# --- documents -----------------------------------------------------------------

## Every paper the patient brings and where it lands: [[doc, position], ...]. The
## sticky note comes last, clear of the medical history.
func _document_layout(c: Claim) -> Array:
	_claim_doc = Paperwork.claim_form(c)
	var layout: Array = [[_claim_doc, Vector2(20, 16)], [Paperwork.member_card(c), Vector2(540, 16)]]
	if c.shows_bill():
		layout.append([Paperwork.itemized_bill(c), Vector2(540, 320)])
	if c.shows_history():
		layout.append([Paperwork.medical_history(c), Vector2(20, 470)])
	var at := EXTRA_DOCS_AT
	for doc in _extra_documents(c):
		layout.append([doc, at])
		at += Vector2(-30, 40)
	if c.sticky_note != "":
		layout.append([Paperwork.sticky_note(c.sticky_note), _sticky_spot(c)])
	return layout


## Papers a patient brings besides the forms: a scripted case's exhibit, if any.
func _extra_documents(c: Claim) -> Array[DocumentView]:
	var docs: Array[DocumentView] = []
	var exhibit := Paperwork.exhibit(c)
	if exhibit:
		docs.append(exhibit)
	return docs


## Where the sticky note goes: below the claim form, or, once the medical history
## takes that spot, under the manual at the desk's right.
func _sticky_spot(c: Claim) -> Vector2:
	if c.shows_history():
		return Vector2(990, 680)
	return Vector2(60, 480)


## Lays the patient's papers on the desk, sliding in from `delay` seconds on. The
## stamps wake when the claim form is down.
func _spawn_documents(c: Claim, delay: float = 0.0) -> void:
	var t := delay
	for entry: Array in _document_layout(c):
		var doc: DocumentView = entry[0]
		_add_document(doc)
		_slide_in(doc, entry[1], t, _papers_down.bind(_patient_serial) if doc == _claim_doc else Callable())
		t += 0.08
	_play_after("paper", delay)


## Puts `doc` at `target`, sliding in from the left after `delay` (at once without
## motion), then calls `landed`.
func _slide_in(doc: DocumentView, target: Vector2, delay: float, landed: Callable = Callable()) -> void:
	if not _motion():
		doc.position = target
		if landed.is_valid():
			landed.call()
		return
	doc.position = Vector2(-520, target.y + 40)
	var tween := doc.create_tween()
	if delay > 0.0:
		tween.tween_interval(delay)
	tween.tween_property(doc, "position", target, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if landed.is_valid():
		tween.tween_callback(landed)


## The claim form of patient `serial` has landed: the stamps can come down on it.
func _papers_down(serial: int) -> void:
	if serial == _patient_serial and active_claim() != null and not _shift_ending:
		_set_stamps_enabled(true)


func _add_document(doc: DocumentView) -> void:
	doc.drag_bounds = Rect2(Vector2.ZERO, DESK_SIZE)
	doc.evidence_clicked.connect(_on_evidence_clicked)
	doc.set_inspect(inspect)
	_desk.add_child(doc)
	_docs.append(doc)


## Slides every paper on the desk off to the left and frees it.
func _dismiss_documents() -> void:
	_overlay.clear()
	_banner.visible = false
	if _docs.is_empty():
		return
	for doc in _docs:
		doc.evidence_clicked.disconnect(_on_evidence_clicked)
		doc.set_inspect(false)
		if not _motion():
			doc.queue_free()
			continue
		var tween := doc.create_tween()
		tween.tween_property(doc, "position:x", -700.0, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_callback(doc.queue_free)
	_docs.clear()
	_claim_doc = null
	Sfx.play("paper")


## The pink slip for approving a claim with grounds, with the printer's chatter
## (in every mode; only the slip's jerks need motion). It names the missed rule
## and the facts, and the manual opens to the rule; both stay marked until NEXT!.
func _print_citation(result: Dictionary) -> void:
	Sfx.play("printer")
	var slip := Paperwork.citation_slip(int(result["warning"]), int(result["fine"]))
	var found := RuleChecker.violations(current, day)
	if not found.is_empty():
		var why := slip.add_text(CitationText.explain(current, found[0]), UiTheme.SIZE_BODY, Palette.INK)
		slip.body.move_child(why, 1)
		_show_missed(found[0])
	_add_document(slip)
	slip.rotation_degrees = -3.0
	_feed_slip(slip)


## Marks the rule an approval missed and its first piece of evidence, linked in red.
func _show_missed(v: Dictionary) -> void:
	_rulebook.show_page("RULES")
	var rule_row := _rulebook.find_rule_row(v["rule"])
	var evidence: PackedStringArray = v["evidence"]
	var key_row := _find_evidence_row(evidence[0]) if not evidence.is_empty() else null
	for row: FieldRow in [rule_row, key_row]:
		if row:
			row.set_mark(FieldRow.Mark.VALID)
	if rule_row and key_row:
		_overlay.link(rule_row, key_row)


## The slip comes out of the desk's lower edge in four jerks, in time with the
## printer, and rises far enough that all of it shows once it has been laid out.
func _feed_slip(slip: DocumentView) -> void:
	slip.position = Vector2(560, DESK_SIZE.y if _motion() else DESK_SIZE.y - SLIP_RISE)
	if not is_inside_tree():
		return
	for i in 2: # Its height is known once its labels have wrapped.
		await get_tree().process_frame
	if not is_instance_valid(slip) or slip.position.x != 560.0:
		return
	var top := DESK_SIZE.y - maxf(SLIP_RISE, slip.size.y + 16.0)
	if not _motion():
		slip.position.y = top
		return
	var tween := slip.create_tween()
	for i in 4:
		tween.tween_property(slip, "position:y", lerpf(DESK_SIZE.y, top, (i + 1) / 4.0), 0.05)
		tween.tween_interval(0.15)


func _play_after(sound: String, delay: float) -> void:
	if delay <= 0.0 or not _animate():
		Sfx.play(sound)
		return
	create_tween().tween_callback(Sfx.play.bind(sound)).set_delay(delay)


# --- end of the shift ----------------------------------------------------------------

func _end_shift() -> void:
	_shift_ending = true
	_set_next_enabled(false)
	_dismiss_documents()
	_rulebook.clear_marks()
	_coach.clear()
	_say("")
	_refresh_hint()
	if not _animate():
		finish({})
		return
	_close_the_window()


## END SHIFT: two chimes, the shutter comes down, and the time clock punches the
## card out at 08:00 plus 70 minutes a patient. Cosmetic; nothing reads it.
func _close_the_window() -> void:
	Sfx.play("chime")
	await _hold(0.35)
	Sfx.play("chime")
	await _hold(0.3)
	if _motion():
		Sfx.play("shutter_down")
		var down := create_tween()
		down.tween_method(_rattle_shutter, _booth.shutter, 1.0, 0.6)
		await down.finished
	else:
		_booth.set_shutter(1.0)
	var out := UiTheme.label("OUT   %s" % clock_out(stamps_today), UiTheme.SIZE_TITLE, Palette.RED)
	var card := _time_card(out)
	_desk.add_child(card)
	var rest := DESK_SIZE.y - 210.0
	card.position = Vector2(DESK_SIZE.x - 420, DESK_SIZE.y + 10 if _motion() else rest)
	_tween_property(card, "position:y", rest, 0.3)
	await _hold(0.5)
	out.modulate.a = 1.0
	Sfx.play("chunk")
	await _hold(1.0)
	finish({})


## The punch card for END SHIFT; `out` stays blank until the clock stamps it.
func _time_card(out: Label) -> Control:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", UiTheme.paper_box(Palette.PAPER_ALT, Palette.PAPER_SHADE, 16))
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.custom_minimum_size = Vector2(340, 0)
	card.rotation_degrees = -3.0
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 4)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(column)
	column.add_child(UiTheme.label("BENEVOLENCE MUTUAL  -  TIME CARD", UiTheme.SIZE_SMALL, Palette.INK_FADED))
	column.add_child(UiTheme.label("ADJUSTER #%d  -  DESK 11" % PLAYER_TICKET, UiTheme.SIZE_SMALL, Palette.INK_FADED))
	column.add_child(UiTheme.rect(Palette.PAPER_SHADE, Vector2(0, 2)))
	column.add_child(UiTheme.label("IN    08:00", UiTheme.SIZE_TITLE, Palette.RED_DARK))
	out.modulate.a = 0.0
	column.add_child(out)
	return card


# --- layout ------------------------------------------------------------------

func _build() -> void:
	add_child(_bg(Rect2(0, 0, 1920, 1080), Palette.BG_DARK))
	_stage = Control.new()
	_stage.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_stage)
	_build_booth()
	_build_desk()
	_build_tray()
	# The coach's highlights go over the desk, the hint strip and the tray.
	_coach = CoachPulse.new()
	_coach.position = Vector2(BOOTH_W, TOP_H)
	_coach.size = Vector2(1920 - BOOTH_W, 1080 - TOP_H)
	_stage.add_child(_coach)
	_build_top_bar()
	_bind_buttons()


func _build_top_bar() -> void:
	add_child(_bg(Rect2(0, 0, 1920, TOP_H), Palette.BG_DARK))
	add_child(_bg(Rect2(0, TOP_H - 2, 1920, 2), Palette.WALL_LIGHT))
	var date := DateUtil.game_date(day)
	_day_label = _place_label("DAY %d  -  %s %s" % [day, DateUtil.weekday(date).to_upper(), DateUtil.fmt(date)], Vector2(24, 16), UiTheme.SIZE_BODY, Palette.TEXT_LIGHT)
	_patient_label = _place_label("", Vector2(560, 16), UiTheme.SIZE_BODY, Palette.TEXT_LIGHT)
	_effects_label = _place_label("", Vector2(720, 16), UiTheme.SIZE_BODY, Palette.AMBER)
	_effects_label.mouse_filter = Control.MOUSE_FILTER_PASS
	_place_label("DISCONTENT", Vector2(1150, 20), UiTheme.SIZE_SMALL, Palette.TEXT_DIM)
	_meter = DiscontentMeter.new()
	_meter.position = Vector2(1270, 18)
	add_child(_meter)
	_meter_label = _place_label("", Vector2(1584, 16), UiTheme.SIZE_BODY, Palette.TEXT_LIGHT)
	_pay_label = _place_label("", Vector2(1680, 16), UiTheme.SIZE_BODY, Palette.TEXT_LIGHT)


func _build_booth() -> void:
	var run := GameState.run
	_stage.add_child(_bg(Rect2(0, TOP_H, BOOTH_W, 1080 - TOP_H), Palette.WALL))
	_stage.add_child(_bg(Rect2(0, TOP_H + 20, BOOTH_W, 6), Palette.WALL_LIGHT))
	# The slogan poster on the left of the wall, the NOW SERVING board on the right.
	var poster := PanelContainer.new()
	poster.add_theme_stylebox_override("panel", UiTheme.flat_box(Palette.PAPER_ALT, Palette.INK_FADED, 2, 14, 6))
	poster.mouse_filter = Control.MOUSE_FILTER_IGNORE
	poster.position = Vector2(24, TOP_H + 34)
	var usual := NewsPool.SLOGANS[(day - 1) % NewsPool.SLOGANS.size()]
	_poster_label = UiTheme.label(EventLines.poster(run.effects, run.discontent, usual), UiTheme.SIZE_SMALL, Palette.INK)
	poster.add_child(_poster_label)
	_stage.add_child(poster)
	_board = ServingBoard.new()
	_board.position = Vector2(BOOTH_W - 24 - ServingBoard.BOARD_SIZE.x, TOP_H + 6)
	_stage.add_child(_board)
	# The window frame, and the waiting room behind the glass.
	_stage.add_child(_bg(Rect2(54, TOP_H + 96, 452, 512), Palette.DESK_DARK))
	_booth = BoothView.new()
	_booth.position = WINDOW_RECT.position
	_stage.add_child(_booth)
	_booth.setup(_silhouette_kinds(), hash([run.run_seed, day, "booth"]))
	_booth.set_event(run.effects)
	_booth.set_waiting(waiting_count())
	_booth.set_progress(0.0)
	_booth.set_shutter(1.0)
	_portrait = _booth.portrait
	_portrait.idle_motion = true
	_portrait.clear()
	# The speech bubble, with a tail pointing up at the window. Click it to finish a line.
	_bubble_box = PanelContainer.new()
	_bubble_box.add_theme_stylebox_override("panel", UiTheme.flat_box(Palette.PAPER, Palette.INK, 2, 16, 12))
	_bubble_box.position = Vector2(40, TOP_H + 630)
	_bubble_box.custom_minimum_size = Vector2(480, 150)
	_bubble_box.mouse_filter = Control.MOUSE_FILTER_STOP
	_bubble_box.gui_input.connect(_on_bubble_input)
	_bubble = UiTheme.para("", 440, UiTheme.SIZE_BODY, Palette.INK)
	_bubble_box.add_child(_bubble)
	_stage.add_child(_bubble_box)
	_bubble_tail = Control.new()
	_bubble_tail.position = Vector2(256, TOP_H + 630 - 18)
	_bubble_tail.size = Vector2(28, 20)
	_bubble_tail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bubble_tail.draw.connect(_draw_bubble_tail)
	_stage.add_child(_bubble_tail)
	_next_button = UiTheme.button("NEXT! (ENTER)", UiTheme.SIZE_BIG, 480)
	_next_button.position = Vector2(40, TOP_H + 800)
	_next_button.custom_minimum_size = Vector2(480, 88)
	_stage.add_child(_next_button)
	# The bottom strip: today's badge, and what the plan saved.
	_stage.add_child(_bg(Rect2(0, 1080 - TRAY_H, BOOTH_W, TRAY_H), Palette.DESK_DARK))
	_badge_slot = Control.new()
	_badge_slot.position = Vector2(16, 976)
	_badge_slot.size = Vector2(280, 96)
	_badge_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.add_child(_badge_slot)
	_badge_slot.add_child(IdBadge.create_mini(GameState.run.player_name))
	var saved := VBoxContainer.new()
	saved.position = Vector2(300, 986)
	saved.custom_minimum_size = Vector2(BOOTH_W - 300 - 20, 0)
	saved.add_theme_constant_override("separation", 2)
	saved.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var caption := UiTheme.label("SAVED FOR THE PLAN TODAY", UiTheme.SIZE_SMALL, Palette.TEXT_DIM)
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	saved.add_child(caption)
	_saved_label = UiTheme.label("", UiTheme.SIZE_TITLE, Palette.TEXT_LIGHT)
	_saved_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	saved.add_child(_saved_label)
	_stage.add_child(saved)
	# Shades over the whole booth column: the day-7 lights, and inspect mode's dimming.
	_booth_lights = _bg(Rect2(0, TOP_H, BOOTH_W, 1080 - TOP_H), Color(0, 0, 0, 0))
	_stage.add_child(_booth_lights)
	_booth_shade = _bg(Rect2(0, TOP_H, BOOTH_W, 1080 - TOP_H), Color(0, 0, 0, 0))
	_stage.add_child(_booth_shade)


func _draw_bubble_tail() -> void:
	var tail := _bubble_tail
	tail.draw_colored_polygon(PackedVector2Array([Vector2(1, 20), Vector2(27, 20), Vector2(9, 0)]), Palette.PAPER)
	tail.draw_line(Vector2(1, 19), Vector2(9, 0), Palette.INK, 2.0)
	tail.draw_line(Vector2(9, 0), Vector2(27, 19), Palette.INK, 2.0)


func _build_desk() -> void:
	_stage.add_child(_bg(Rect2(BOOTH_W, TOP_H, 1920 - BOOTH_W, 1080 - TOP_H), Palette.DESK))
	for i in 6:
		_stage.add_child(_bg(Rect2(BOOTH_W, TOP_H + 150 + i * 150, 1920 - BOOTH_W, 2), Palette.DESK_DARK))
	_desk = Control.new()
	_desk.position = Vector2(BOOTH_W, TOP_H)
	_desk.size = DESK_SIZE
	_desk.clip_contents = true
	_desk.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.add_child(_desk)
	# Under every paper: room for things that live on the desk.
	_desk_underlay = Control.new()
	_desk_underlay.size = DESK_SIZE
	_desk_underlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_desk.add_child(_desk_underlay)
	_desk_underlay.add_child(DeskProps.create(GameState.run))
	_rulebook = RulebookView.new()
	_rulebook.setup(day)
	_rulebook.drag_bounds = Rect2(Vector2.ZERO, DESK_SIZE)
	_rulebook.position = Vector2(DESK_SIZE.x - RulebookView.WIDTH - 12, 12)
	_rulebook.rule_clicked.connect(_on_rule_clicked)
	_rulebook.denybot_pressed.connect(_on_denybot_pressed)
	_desk.add_child(_rulebook)
	# The red citation link covers exactly the desk and clips to it, so a paper
	# dragged half off the desk can't draw it over the booth or the top bar.
	_overlay = CiteOverlay.new()
	_overlay.position = _desk.position
	_overlay.size = DESK_SIZE
	_stage.add_child(_overlay)
	_desk_frame = Panel.new()
	var frame_box := UiTheme.flat_box(Color(0, 0, 0, 0), Palette.HIGHLIGHT, 4, 0, 0)
	frame_box.draw_center = false
	_desk_frame.add_theme_stylebox_override("panel", frame_box)
	_desk_frame.position = _desk.position
	_desk_frame.size = DESK_SIZE
	_desk_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_desk_frame.visible = false
	_stage.add_child(_desk_frame)
	var banner_box := CenterContainer.new()
	banner_box.position = Vector2(BOOTH_W, TOP_H + 8)
	banner_box.size = Vector2(DESK_SIZE.x, 48)
	banner_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_banner = UiTheme.label("", UiTheme.SIZE_TITLE, Palette.TEXT_LIGHT)
	_banner.add_theme_stylebox_override("normal", UiTheme.flat_box(Palette.RED_DARK, Palette.RED, 2, 16, 6))
	_banner.visible = false
	banner_box.add_child(_banner)
	_stage.add_child(banner_box)
	var strip_y := TOP_H + DESK_SIZE.y
	_stage.add_child(_bg(Rect2(BOOTH_W, strip_y, DESK_SIZE.x, HINT_H), Color(0, 0, 0, 0.35)))
	_hint_label = _place_label_on(_stage, "", Vector2(BOOTH_W + 20, strip_y + 8), UiTheme.SIZE_BODY, Palette.TEXT_LIGHT)
	# SKIP TRAINING: plain text at the strip's right end, on day 1 only.
	_skip_training = UiTheme.button("SKIP TRAINING", UiTheme.SIZE_SMALL)
	var bare := StyleBoxEmpty.new()
	for state: String in ["normal", "hover", "pressed", "disabled", "focus"]:
		_skip_training.add_theme_stylebox_override(state, bare)
	_skip_training.add_theme_color_override("font_color", Palette.TEXT_DIM)
	_skip_training.add_theme_color_override("font_hover_color", Palette.TEXT_LIGHT)
	_skip_training.add_theme_color_override("font_pressed_color", Palette.TEXT_LIGHT)
	_skip_training.custom_minimum_size = Vector2(120, 32)
	_skip_training.position = Vector2(1920 - 120 - 12, strip_y + 4)
	_skip_training.set_meta("silent", true)
	_skip_training.visible = false
	_stage.add_child(_skip_training)


func _build_tray() -> void:
	var y := 1080.0 - TRAY_H
	_stage.add_child(_bg(Rect2(BOOTH_W, y, 1920 - BOOTH_W, TRAY_H), Palette.DESK_DARK))
	_inspect_button = UiTheme.button("INSPECT (SPACE)", UiTheme.SIZE_BODY, 280)
	_inspect_button.position = Vector2(BOOTH_W + 20, y + 20)
	_inspect_button.custom_minimum_size = Vector2(280, 72)
	_stage.add_child(_inspect_button)
	_cite_label = _place_label_on(_stage, "", Vector2(BOOTH_W + 320, y + 24), UiTheme.SIZE_BODY, Palette.HIGHLIGHT)
	# The info line: today's denial target (when there is one) and the warnings left.
	var info := HBoxContainer.new()
	info.position = Vector2(BOOTH_W + 320, y + 64)
	info.add_theme_constant_override("separation", 28)
	info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_target_label = UiTheme.label("", UiTheme.SIZE_SMALL, Palette.TEXT_DIM)
	_target_label.visible = false
	info.add_child(_target_label)
	_warnings_label = UiTheme.label("", UiTheme.SIZE_SMALL, Palette.TEXT_DIM)
	info.add_child(_warnings_label)
	_stage.add_child(info)
	_approve_button = _stamp_button(true)
	_approve_button.position = Vector2(1920 - 600, y + 16)
	_stage.add_child(_approve_button)
	_deny_button = _stamp_button(false)
	_deny_button.position = Vector2(1920 - 300, y + 16)
	_stage.add_child(_deny_button)
	_set_stamps_enabled(false)


## A stamp in the tray: a real Button (it takes the clicks and keeps its text for
## tests) drawn as nothing but the rubber stamp inside it and a price line.
func _stamp_button(approved: bool) -> Button:
	var b := UiTheme.button("APPROVE" if approved else "DENY", UiTheme.SIZE_TITLE, STAMP_SIZE.x)
	b.custom_minimum_size = STAMP_SIZE
	var clear := StyleBoxEmpty.new()
	for state: String in ["normal", "hover", "pressed", "disabled", "focus"]:
		b.add_theme_stylebox_override(state, clear)
	for color_name: String in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color", "font_disabled_color"]:
		b.add_theme_color_override(color_name, Color(0, 0, 0, 0))
	b.set_meta("silent", true)
	var tool := StampTool.create(approved)
	b.add_child(tool)
	var price := UiTheme.label("", UiTheme.SIZE_SMALL, Palette.TEXT_LIGHT)
	price.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	price.position = Vector2(0, StampTool.TOOL_SIZE.y)
	price.size = Vector2(STAMP_SIZE.x, 16)
	b.add_child(price)
	if approved:
		_approve_tool = tool
		_approve_price = price
	else:
		_deny_tool = tool
		_deny_price = price
	return b


func _bind_buttons() -> void:
	# Mouse-driven desk: no keyboard focus, or Space (ui_accept) would press a
	# focused stamp instead of toggling inspect.
	for b: Button in [_next_button, _inspect_button, _approve_button, _deny_button, _skip_training]:
		b.focus_mode = Control.FOCUS_NONE
	_next_button.pressed.connect(call_next_patient)
	_inspect_button.pressed.connect(func() -> void: _set_inspect(not inspect))
	_approve_button.pressed.connect(stamp.bind(true))
	_deny_button.pressed.connect(stamp.bind(false))
	_skip_training.pressed.connect(skip_training)


func _silhouette_kinds() -> Array[int]:
	var kinds: Array[int] = []
	for c in claims:
		if c.is_player:
			continue
		if c.is_child():
			kinds.append(BoothView.Shape.CHILD)
		elif posmod(hash([c.portrait_seed, "shape"]), 2) == 0:
			kinds.append(BoothView.Shape.HAT)
		else:
			kinds.append(BoothView.Shape.LONG_HAIR)
	return kinds


## How far through the day's patients the window is: 0 first, 1 last.
func _progress() -> float:
	if current != null and current.is_player:
		return 1.0
	var total := 0
	for c in claims:
		if not c.is_player:
			total += 1
	return clampf(float(index) / maxf(1.0, float(total - 1)), 0.0, 1.0)


# --- input ---------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("inspect_toggle"):
		_set_inspect(not inspect)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("cancel_inspect") and inspect:
		_set_inspect(false)
		get_viewport().set_input_as_handled()
	elif _is_next_key(event) and _shown and not _next_button.disabled:
		call_next_patient()
		get_viewport().set_input_as_handled()


func _input(event: InputEvent) -> void:
	# After the week's last stamp, any click or Enter ends the stillness.
	if not _climax_waiting:
		return
	var mb := event as InputEventMouseButton
	if (mb and mb.pressed) or _is_next_key(event):
		_climax_skip = true


## Enter, keypad Enter or N: the keys that press NEXT! and END SHIFT.
static func _is_next_key(event: InputEvent) -> bool:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return false
	return key.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_N] or key.physical_keycode in [KEY_ENTER, KEY_KP_ENTER]


# --- HUD -----------------------------------------------------------------------

## Refreshes the top bar and the tray's info line. The pay and the meter move when
## their pops land (see _show_feedback); `set_readouts` sets them right away, as
## do fast mode and reduce motion (where no pop flies).
func _update_hud(set_readouts: bool) -> void:
	var run := GameState.run
	_patient_label.text = "PATIENT %d OF %d" % [maxi(index + 1, 1), claims.size()] if index >= 0 else "%d PATIENTS TODAY" % claims.size()
	if set_readouts or not _motion():
		_set_pay(GameState.pay_so_far())
		_land_discontent(false)
	_update_effects()
	_update_info()
	if run.effects.get("compassion", false):
		_approve_button.text = "APPROVE (FREE)"
		_approve_tool.tag = "FREE"


## Pops for what the stamp paid and what it did to the public. They fly into the
## TODAY readout and the meter, which then count to their new values. With reduce
## motion they fade where they appear and the readouts change at once.
func _show_feedback(result: Dictionary) -> void:
	var pay: int = result["pay"]
	var d: float = result["discontent"]
	if pay > 0:
		Sfx.play("cash")
	var pay_text := UiTheme.signed_money(pay)
	var pay_color := Palette.GREEN if pay >= 0 else Palette.RED
	var moved := absf(d) >= 0.05
	var d_text := "%s%s%% discontent" % ["+" if d > 0 else "-", _fmt_points(absf(d))]
	var d_color := Palette.RED if d > 0 else Palette.GREEN
	if not _motion():
		if _animate():
			FloatingText.spawn(self, pay_text, pay_color, _feedback_spot(0), 0.0, 0.0)
			if moved:
				FloatingText.spawn(self, d_text, d_color, _feedback_spot(1), 0.15, 0.0)
		_set_pay(GameState.pay_so_far())
		_land_discontent(false)
		return
	FloatingText.fly(self, pay_text, pay_color, _feedback_spot(0), _pay_target(), 0.0, _land_pay)
	if moved:
		FloatingText.fly(self, d_text, d_color, _feedback_spot(1), _meter_target(), 0.15, _land_discontent.bind(true))
	else:
		_land_discontent(true)


func _land_pay() -> void:
	_count_pay_to(GameState.pay_so_far())


func _land_discontent(animate: bool = true) -> void:
	var run := GameState.run
	_meter.set_value(run.discontent, animate and _animate())
	_meter_label.text = "%d%%" % roundi(run.discontent)
	_update_effects()


func _set_pay(value: int) -> void:
	if _pay_tween:
		_pay_tween.kill()
		_pay_tween = null
	_show_pay(value)
	_pay_label.add_theme_color_override("font_color", Palette.TEXT_LIGHT)


func _show_pay(value: int) -> void:
	_shown_pay = value
	_pay_label.text = "TODAY %s" % UiTheme.money(value)


## The TODAY readout counts to `value` in dollar steps (0.6 s at most), flashing
## green for money in and red for money out.
func _count_pay_to(value: int) -> void:
	var delta := value - _shown_pay
	if delta == 0 or not _animate():
		_set_pay(value)
		return
	if _pay_tween:
		_pay_tween.kill()
	var flash := Palette.GREEN if delta > 0 else Palette.RED
	_pay_label.add_theme_color_override("font_color", flash.lightened(0.35))
	_pay_tween = create_tween()
	_pay_tween.tween_method(_tick_pay, float(_shown_pay), float(value), minf(0.6, absi(delta) * 0.05))
	_pay_tween.tween_interval(0.2)
	_pay_tween.tween_callback(_pay_label.add_theme_color_override.bind("font_color", Palette.TEXT_LIGHT))


func _tick_pay(v: float) -> void:
	var n := roundi(v)
	if n == _shown_pay:
		return
	_show_pay(n)
	var now := Time.get_ticks_msec()
	if now - _last_tick >= 35:
		_last_tick = now
		Sfx.play("tick")


## The plan's savings in the booth strip, counting up over half a second.
func _show_saved(animate: bool) -> void:
	if _saved_tween:
		_saved_tween.kill()
		_saved_tween = null
	if not animate or not _animate():
		_set_saved_shown(saved_today)
		return
	_saved_tween = create_tween()
	_saved_tween.tween_method(_set_saved_shown, float(_saved_shown), float(saved_today), 0.5)


func _set_saved_shown(v: float) -> void:
	_saved_shown = roundi(v)
	_saved_label.text = Fmt.money(_saved_shown)


## The top bar's effects line: today's events, and the board's warning near 100%.
## Its tooltip says what each one does. When the line runs long it drops to small
## type, and if that still doesn't fit it uses short names (the tooltip keeps the
## full ones), large if they fit, so it never reaches the DISCONTENT caption.
func _update_effects() -> void:
	var run := GameState.run
	var names: PackedStringArray = []
	var tips: PackedStringArray = []
	if run.effects.get("protest", false):
		names.append("PROTEST OUTSIDE")
		tips.append("PROTEST OUTSIDE: every denial today adds %s%% more discontent." % _fmt_points(Economy.PROTEST_EXTRA))
	if run.effects.get("audit", false):
		names.append("AUDIT IN PROGRESS")
		tips.append("AUDIT IN PROGRESS: uncited denials of claims with no valid grounds are overturned.")
	if run.effects.get("compassion", false):
		names.append("COMPASSION DAY")
		tips.append("COMPASSION DAY: approvals cost nothing and calm the public more. No citations.")
	if run.discontent >= 90.0:
		var review := "BOARD REVIEW AT %d%%" % roundi(Economy.SCAPEGOAT_AT)
		names.append(review)
		tips.append("%s: at full discontent the Company lets the adjuster go." % review)
	var short: PackedStringArray = []
	for n in names:
		short.append(String(EFFECT_SHORT.get(n, n.trim_prefix("BOARD "))))
	var full := "  ".join(names)
	var brief := "  ".join(short)
	var text := brief
	var font_size := UiTheme.SIZE_SMALL
	for option: Array in [[full, UiTheme.SIZE_BODY], [full, UiTheme.SIZE_SMALL], [brief, UiTheme.SIZE_BODY]]:
		if _text_width(option[0], option[1]) <= EFFECTS_WIDTH:
			text = option[0]
			font_size = option[1]
			break
	_effects_label.text = text
	_effects_label.tooltip_text = "\n".join(tips)
	_effects_label.add_theme_font_size_override("font_size", font_size)
	_effects_label.position.y = 16.0 if font_size == UiTheme.SIZE_BODY else 22.0


static func _text_width(text: String, font_size: int) -> float:
	return UiTheme.font().get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x


## The tray's info line: the denial target over the claims processed so far, and
## how many citations are still free today.
func _update_info() -> void:
	var run := GameState.run
	var target := int(run.today.get("target_pct", 0))
	_target_label.visible = target > 0
	if target > 0:
		var processed := 0
		var denied := 0
		for rec: Dictionary in run.today.get("decisions", []):
			if rec.get("is_player", false):
				continue
			processed += 1
			if not rec.get("approved", false):
				denied += 1
		_target_label.text = "TARGET %d%%: %d OF %d DENIED" % [target, denied, processed]
		var met := processed > 0 and denied * 100 >= target * processed
		_target_label.add_theme_color_override("font_color", Palette.AMBER if met else Palette.TEXT_DIM)
	if run.effects.get("compassion", false):
		_warnings_label.text = "NO CITATIONS TODAY"
	else:
		var left := Economy.FREE_WARNINGS - int(run.today.get("warnings", 0))
		_warnings_label.text = "WARNINGS LEFT TODAY: %d" % left if left > 0 else "NEXT CITATION: -%s" % Fmt.money(Economy.CITATION_FINE)


## The price lines on the stamps: what each would pay and do to discontent now.
func _update_prices() -> void:
	if active_claim() == null:
		_approve_price.text = ""
		_deny_price.text = ""
		return
	var effects := GameState.run.effects
	var a := stamp_preview(current, true, "", effects, day)
	_approve_price.text = "PAY %s   DISCONTENT %s" % [_pay_text(a["pay"]), _pct_text(a["discontent"])]
	var d := stamp_preview(current, false, cited_rule, effects, day)
	_deny_price.text = "PAY %s%s   DISCONTENT %s" % [_pay_text(d["pay"]), "" if cited_rule != "" else " UNCITED", _pct_text(d["discontent"])]


func _set_stamps_enabled(on: bool) -> void:
	_approve_button.disabled = not on
	_deny_button.disabled = not on
	var color := Palette.TEXT_LIGHT if on else Palette.TEXT_DIM.darkened(0.3)
	for price: Label in [_approve_price, _deny_price]:
		price.add_theme_color_override("font_color", color)


func _set_next_enabled(on: bool) -> void:
	_next_button.disabled = not on
	if on:
		_next_button.text = "END SHIFT (ENTER)" if index >= claims.size() - 1 else "NEXT! (ENTER)"


# --- hints and the day-1 coach ---------------------------------------------------

## Sets the hint strip and the coach's pulse for the desk as it stands. A new
## coaching step clicks, unless `quiet`.
func _refresh_hint(quiet: bool = false) -> void:
	var text := ""
	var targets: Array[Control] = []
	var coach := ""
	if current == null:
		text = "Press NEXT! to call the first patient."
	elif stamped:
		# Nothing while the papers clear (NEXT! stays disabled for a moment, and
		# stamp() refreshes this once it's live again), except the coach's verdict.
		if _coach_feedback != "":
			text = _coach_feedback
		elif not _next_button.disabled and not current.is_player and not _shift_ending:
			if _coach_complete:
				text = COACH_DONE
			else:
				text = "That's everyone. Press END SHIFT." if index >= claims.size() - 1 else "Press NEXT! for the next patient."
	elif _training_active():
		coach = _coach_hint(targets)
		text = coach
	elif inspect:
		text = "INSPECTING: click a rule in the rulebook, then the field that breaks it. Esc to stop."
	elif cited_rule != "":
		text = "Reason cited. Stamp DENY to deny with %s, or APPROVE anyway." % cited_rule
	elif current.is_player:
		text = ""
	elif stamps_today == 0 and DAY_HINTS[day] != "":
		text = DAY_HINTS[day]
	elif day == 1 and _stamps_outside_training == 1:
		text = WARNINGS_HINT
	elif day == 1 and stamps_today < 3:
		text = "Found a problem? INSPECT, click the rule, then the date that breaks it. Or just stamp."
	else:
		text = "Drag papers to read them. INSPECT (Space) to cite a reason, then stamp."
	_hint_label.text = text
	_coach.set_targets(targets)
	if coach != _coach_step:
		_coach_step = coach
		if coach != "" and not quiet:
			Sfx.play("click")
	_skip_training.visible = _training_pending()


## Day-1 training still to come or under way.
func _training_pending() -> bool:
	return day == 1 and training_enabled and not _training_done and index <= 1


## Whether the coach is on for the patient at the window: one of the first two,
## not a scripted case, not yet stamped.
func _training_active() -> bool:
	return _training_pending() and index >= 0 and current != null and not stamped and current.scripted_id == "" and not current.is_player


## The coach's line for the patient at the window; fills `targets` with what to pulse.
## It follows the claim: a lapsed card gets the cite path, anything else approval.
func _coach_hint(targets: Array[Control]) -> String:
	var c := current
	var through := DateUtil.fmt(c.coverage_through)
	var service := DateUtil.fmt(c.date_of_service)
	if not _coach_cites(c):
		targets.append_array(_date_rows())
		targets.append(_approve_button)
		return COACH_APPROVE % [through, service]
	if cited_rule != "":
		targets.append(_deny_button)
		return COACH_CITE[3]
	if inspect and _sel_rule == Rules.R01:
		targets.append_array(_date_rows())
		return COACH_CITE[2]
	if inspect:
		var row := _rulebook.find_rule_row(Rules.R01)
		if row:
			targets.append(row)
		return COACH_CITE[1]
	targets.append_array(_date_rows())
	targets.append(_inspect_button)
	return COACH_CITE[0] % [through, service]


## What the coach says once a training claim is stamped ("" for the right call).
static func _coach_verdict(c: Claim, approve: bool, citing: bool) -> String:
	if _coach_cites(c):
		if approve:
			return COACH_MISSED
		return "" if citing else COACH_UNCITED
	return "" if approve else COACH_UNCITED_CLEAN


static func _coach_cites(c: Claim) -> bool:
	for v in RuleChecker.violations(c, 1):
		if v["rule"] == Rules.R01:
			return true
	return false


func _date_rows() -> Array[Control]:
	var rows: Array[Control] = []
	for key: String in ["card.coverage_through", "claim.date_of_service"]:
		var row := _find_evidence_row(key)
		if row:
			rows.append(row)
	return rows


# --- helpers ---------------------------------------------------------------------

## Whether anything animates at all: never in fast mode or outside the tree.
func _animate() -> bool:
	return not fast and is_inside_tree()


## Whether things move: walks, slides, flights, shakes. Off with reduce motion.
func _motion() -> bool:
	return _animate() and not Engine.get_meta("reduce_motion", false)


func _shake(amount: float = 6.0) -> void:
	if not _motion():
		return
	var tween := create_tween()
	for i in 4:
		tween.tween_property(_stage, "position", Vector2(_rng.randf_range(-amount, amount), _rng.randf_range(-amount, amount) * 0.66), 0.03)
	tween.tween_property(_stage, "position", Vector2.ZERO, 0.04)


func _tween_property(target: Object, property: String, value: Variant, duration: float, delay: float = 0.0) -> void:
	if not _motion():
		target.set_indexed(property, value)
		return
	var tween := create_tween()
	if delay > 0.0:
		tween.tween_interval(delay)
	tween.tween_property(target, property, value, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _bg(r: Rect2, color: Color) -> ColorRect:
	var c := UiTheme.rect(color)
	c.position = r.position
	c.size = r.size
	return c


func _place_label(text: String, at: Vector2, size: int, color: Color) -> Label:
	var l := UiTheme.label(text, size, color)
	l.position = at
	add_child(l)
	return l


func _place_label_on(parent: Control, text: String, at: Vector2, size: int, color: Color) -> Label:
	var l := UiTheme.label(text, size, color)
	l.position = at
	parent.add_child(l)
	return l


## Where pay (0) and discontent (1) feedback pops up: just above the stamps,
## where the player's eyes already are.
func _feedback_spot(which: int) -> Vector2:
	return Vector2(1920 - 600 + which * 300, 1080 - TRAY_H - HINT_H - 56)


## Where the pay pop lands: on the TODAY readout.
func _pay_target() -> Vector2:
	return _pay_label.position + Vector2(20, -4)


## Where the discontent pop lands: on the meter.
func _meter_target() -> Vector2:
	return _meter.position + Vector2(_meter.size.x / 2.0 - 60, -6)


func _fmt_points(v: float) -> String:
	return str(int(v)) if is_equal_approx(v, roundf(v)) else "%.1f" % v


func _pay_text(amount: int) -> String:
	return Fmt.money(amount) if amount == 0 else Fmt.signed_money(amount)


func _pct_text(points: float) -> String:
	return "%s%s%%" % ["+" if points > 0 else "-", _fmt_points(absf(points))]
