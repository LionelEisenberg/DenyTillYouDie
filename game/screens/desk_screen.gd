class_name DeskScreen
extends ScreenBase
## The shift. Patients come to the booth window one at a time; their paperwork
## lands on the desk. The player reads, optionally cites a violation (INSPECT,
## then a rule and the evidence), and stamps APPROVED or DENIED.

const BOOTH_W := 560.0
const TOP_H := 64.0
const TRAY_H := 112.0
const HINT_H := 40.0
const DESK_SIZE := Vector2(1360, 1080 - 64 - 112 - 40)

const DAY_HINTS: PackedStringArray = [
	"",
	"Compare the card's COVERAGE THROUGH with the claim's DATE OF SERVICE.",
	"New rule R-02: check the claim's PROVIDER against the NETWORK tab in your rulebook.",
	"New rule R-03: NAME, MEMBER ID and DATE OF BIRTH on the claim must match the card exactly.",
	"New: itemized bill. Procedures on the PRIOR AUTH tab need a PRIOR AUTH # on the claim.",
	"New: medical history. The claimed condition on record before MEMBER SINCE is pre-existing.",
	"New: EXCLUSIONS tab. Any excluded line on the bill is grounds for denial.",
	"New: DenyBot. Rulebook > DENYBOT > RUN DENYBOT works on any claim.",
]

var day: int = 1
var claims: Array[Claim] = []
var index: int = -1
var current: Claim
var stamped: bool = false
var cited_rule: String = ""
var inspect: bool = false
var stamps_today: int = 0

var _sel_rule: String = ""
var _sel_rule_row: FieldRow
var _sel_key: String = ""
var _sel_key_row: FieldRow
var _docs: Array[DocumentView] = []
var _claim_doc: DocumentView
var _rng := RandomNumberGenerator.new()

var _stage: Control
var _desk: Control
var _desk_frame: Panel
var _rulebook: RulebookView
var _overlay: CiteOverlay
var _portrait: PortraitView
var _bubble: Label
var _next_button: Button
var _inspect_button: Button
var _approve_button: Button
var _deny_button: Button
var _cite_label: Label
var _hint_label: Label
var _banner: Label
var _day_label: Label
var _patient_label: Label
var _pay_label: Label
var _meter: DiscontentMeter
var _meter_label: Label
var _effects_label: Label


func _ready() -> void:
	GameState.begin_day()
	day = GameState.run.day
	claims = GameState.claims_today
	_rng.seed = hash([GameState.run.run_seed, day, "desk"])
	_build()
	_update_hud(false)
	_refresh_hint()


# --- test hooks and actions --------------------------------------------------

func active_claim() -> Claim:
	return current if current != null and not stamped else null


func end_shift_ready() -> bool:
	return index >= claims.size() - 1 and stamped


func call_next_patient() -> void:
	if current != null and not stamped:
		return
	if index >= claims.size() - 1:
		finish({})
		return
	index += 1
	current = claims[index]
	stamped = false
	cited_rule = ""
	_clear_selection()
	_overlay.clear()
	_banner.visible = false
	_cite_label.text = ""
	_deny_button.text = "DENY"
	_next_button.disabled = true
	_approve_button.disabled = false
	_deny_button.disabled = false
	_rulebook.set_denybot_enabled(day >= 7)
	_rulebook.show_denybot_result("")
	_rulebook.clear_marks()
	_portrait.show_patient(current.portrait_seed, current.age, current.is_player)
	_portrait.modulate.a = 0.0
	_bubble.text = _arrival_line(current)
	_spawn_documents(current)
	_tween_property(_portrait, "modulate:a", 1.0, 0.3)
	Sfx.play("bell")
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
	stamped = true
	stamps_today += 1
	_set_inspect(false)
	_approve_button.disabled = true
	_deny_button.disabled = true
	var citing := not approve and cited_rule != ""
	var code := ""
	if citing:
		code = "%s  %s" % [cited_rule, String(Rules.get_rule(cited_rule)["title"]).to_upper()]
		if cited_rule == Rules.R07:
			code = "R-07  ALGORITHMIC DETERMINATION"
	_place_stamp(approve, code)
	var result := GameState.decide(current, approve, cited_rule if citing else "")
	_show_feedback(result)
	if result["citation"]:
		_print_citation(result)
	_react(approve, citing)
	_update_hud(true)
	_refresh_hint()
	await wait(1.5)
	_dismiss_documents()
	if current.is_player:
		await wait(1.2)
		finish({})
		return
	await wait(0.5)
	_next_button.text = "END SHIFT" if index >= claims.size() - 1 else "NEXT!"
	_next_button.disabled = false
	_refresh_hint()


# --- citations ---------------------------------------------------------------

func _on_rule_clicked(rule_id: String, row: FieldRow) -> void:
	if not inspect or active_claim() == null:
		return
	if _sel_rule_row and is_instance_valid(_sel_rule_row):
		_sel_rule_row.set_mark(FieldRow.Mark.NONE)
	_sel_rule = rule_id
	_sel_rule_row = row
	row.set_mark(FieldRow.Mark.SELECTED)
	Sfx.play("click")
	_try_selection()


func _on_evidence_clicked(key: String, row: FieldRow) -> void:
	if not inspect or active_claim() == null:
		return
	if _sel_key_row and is_instance_valid(_sel_key_row):
		_sel_key_row.set_mark(FieldRow.Mark.NONE)
	_sel_key = key
	_sel_key_row = row
	row.set_mark(FieldRow.Mark.SELECTED)
	Sfx.play("click")
	_try_selection()


func _try_selection() -> void:
	if _sel_rule != "" and _sel_key != "":
		_evaluate(_sel_rule, _sel_rule_row, _sel_key, _sel_key_row)


func _evaluate(rule_id: String, rule_row: FieldRow, key: String, key_row: FieldRow) -> bool:
	if RuleChecker.check_citation(current, rule_id, key, day):
		_apply_citation(rule_id, rule_row, key_row)
		return true
	var fee := GameState.compliance_fee()
	Sfx.play("buzz")
	FloatingText.spawn(self, "-%s" % UiTheme.money(fee), Palette.RED, Vector2(_pay_label.position.x, TOP_H + 8))
	_hint_label.text = "No violation there. Compliance review fee: %s." % UiTheme.money(fee)
	for row: FieldRow in [rule_row, key_row]:
		if row and is_instance_valid(row):
			row.set_mark(FieldRow.Mark.INVALID)
	_update_hud(false)
	_clear_selection_later(rule_row, key_row)
	return false


func _apply_citation(rule_id: String, rule_row: FieldRow, key_row: FieldRow) -> void:
	_rulebook.clear_marks()
	if _claim_doc:
		for doc in _docs:
			doc.clear_marks()
	cited_rule = rule_id
	_set_inspect(false)
	if rule_row:
		rule_row.set_mark(FieldRow.Mark.VALID)
	if key_row:
		key_row.set_mark(FieldRow.Mark.VALID)
	if rule_row and key_row:
		_overlay.link(rule_row, key_row)
	var title := String(Rules.get_rule(rule_id)["title"]).to_upper()
	_flash_banner("VIOLATION: %s (%s)" % [title, rule_id])
	_cite_label.text = "CITED: %s %s" % [rule_id, title]
	_deny_button.text = "DENY (%s)" % rule_id
	Sfx.play("ding")
	_sel_rule = ""
	_sel_key = ""
	_refresh_hint()


func _run_denybot() -> bool:
	if day < 7 or active_claim() == null:
		return false
	_rulebook.show_denybot_result("DETERMINATION: DENY\nREASON: PROPRIETARY\nCONFIDENCE: 99.7%")
	_overlay.clear()
	_rulebook.clear_marks()
	for doc in _docs:
		doc.clear_marks()
	cited_rule = Rules.R07
	_flash_banner("DENYBOT: DENY (R-07)")
	_cite_label.text = "CITED: R-07 ALGORITHMIC DETERMINATION"
	_deny_button.text = "DENY (R-07)"
	Sfx.play("ding")
	_refresh_hint()
	return true


func _on_denybot_pressed() -> void:
	if active_claim() == null:
		return
	_rulebook.show_denybot_result("ANALYZING...")
	Sfx.play("click")
	await wait(0.8)
	if active_claim() != null:
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
	for row in [_sel_rule_row, _sel_key_row]:
		if row and is_instance_valid(row):
			(row as FieldRow).set_mark(FieldRow.Mark.NONE)
	_sel_rule = ""
	_sel_key = ""
	_sel_rule_row = null
	_sel_key_row = null


func _clear_selection_later(rule_row: FieldRow, key_row: FieldRow) -> void:
	_sel_rule = ""
	_sel_key = ""
	_sel_rule_row = null
	_sel_key_row = null
	await wait(0.6)
	for row: FieldRow in [rule_row, key_row]:
		if row and is_instance_valid(row) and cited_rule == "":
			row.set_mark(FieldRow.Mark.NONE)


func _set_inspect(on: bool) -> void:
	inspect = on and active_claim() != null
	_rulebook.set_inspect(inspect)
	for doc in _docs:
		doc.set_inspect(inspect)
	if not inspect:
		_clear_selection()
	_desk_frame.visible = inspect
	_inspect_button.text = "INSPECTING (SPACE)" if inspect else "INSPECT (SPACE)"
	_refresh_hint()


func _find_evidence_row(key: String) -> FieldRow:
	for doc in _docs:
		var row := doc.find_row(key)
		if row:
			return row
	return null


# --- patients and documents --------------------------------------------------

func _arrival_line(c: Claim) -> String:
	if c.arrival_line != "":
		return c.arrival_line
	var rng := RandomNumberGenerator.new()
	rng.seed = c.line_seed
	return Lines.arrival(c.priority, c.parent_speaks, c.first_name(), rng)


func _react(approve: bool, citing: bool) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = current.line_seed + 1
	var line := Scripted.reaction("player" if current.is_player else current.scripted_id, approve)
	if line == "":
		line = Lines.reaction(current.priority, approve, current.parent_speaks, rng)
		if citing and cited_rule != Rules.R07 and rng.randf() < 0.35:
			line = Lines.code_reaction(cited_rule, Rules.get_rule(cited_rule)["title"], rng)
	_bubble.text = line
	if current.is_player:
		_portrait.set_expression(PortraitView.Mood.NEUTRAL)
	elif approve:
		_portrait.set_expression(PortraitView.Mood.RELIEVED)
	elif current.priority == Claim.Priority.ROUTINE:
		_portrait.set_expression(PortraitView.Mood.ANGRY)
	else:
		_portrait.set_expression(PortraitView.Mood.DEVASTATED)


func _spawn_documents(c: Claim) -> void:
	for doc in _docs:
		doc.queue_free()
	_docs.clear()
	_claim_doc = Paperwork.claim_form(c)
	var layout: Array = [[_claim_doc, Vector2(20, 16)], [Paperwork.member_card(c), Vector2(540, 16)]]
	if c.shows_bill():
		layout.append([Paperwork.itemized_bill(c), Vector2(540, 320)])
	if c.shows_history():
		layout.append([Paperwork.medical_history(c), Vector2(20, 470)])
	var delay := 0.0
	for entry in layout:
		var doc: DocumentView = entry[0]
		var target: Vector2 = entry[1]
		_add_document(doc)
		doc.position = Vector2(-520, target.y + 40)
		_tween_property(doc, "position", target, 0.35, delay)
		delay += 0.08
	Sfx.play("paper")


func _add_document(doc: DocumentView) -> void:
	doc.drag_bounds = Rect2(Vector2.ZERO, DESK_SIZE)
	doc.evidence_clicked.connect(_on_evidence_clicked)
	doc.set_inspect(inspect)
	_desk.add_child(doc)
	_docs.append(doc)


func _dismiss_documents() -> void:
	_overlay.clear()
	_banner.visible = false
	for doc in _docs:
		_tween_property(doc, "position:x", -700.0, 0.35)
	_tween_property(_portrait, "modulate:a", 0.0, 0.4, 0.3)
	Sfx.play("paper")


func _place_stamp(approve: bool, code: String) -> void:
	if _claim_doc == null:
		return
	var mark := StampMark.create(approve, code)
	mark.position = Vector2(_claim_doc.size.x / 2.0 - mark.size.x / 2.0 + _rng.randf_range(-30, 30), _claim_doc.size.y - mark.size.y - 30 + _rng.randf_range(-20, 10))
	mark.rotation_degrees = _rng.randf_range(-9.0, 9.0)
	mark.scale = Vector2(1.6, 1.6)
	mark.modulate.a = 0.0
	_claim_doc.overlay.add_child(mark)
	_claim_doc.move_to_front()
	_tween_property(mark, "scale", Vector2.ONE, 0.12)
	_tween_property(mark, "modulate:a", 1.0, 0.08)
	Sfx.play("stamp")
	_shake()


func _print_citation(result: Dictionary) -> void:
	var slip := Paperwork.citation_slip(int(result["warning"]), int(result["fine"]))
	_add_document(slip)
	slip.position = Vector2(560, DESK_SIZE.y)
	slip.rotation_degrees = -3.0
	_tween_property(slip, "position:y", DESK_SIZE.y - 240, 0.3)
	Sfx.play("buzz")


func _show_feedback(result: Dictionary) -> void:
	var pay: int = result["pay"]
	var anchor := Vector2(_pay_label.position.x, TOP_H + 8)
	FloatingText.spawn(self, UiTheme.signed_money(pay), Palette.GREEN if pay >= 0 else Palette.RED, anchor)
	var d: float = result["discontent"]
	if absf(d) >= 0.05:
		var text := "%s%s%% discontent" % ["+" if d > 0 else "-", _fmt_points(absf(d))]
		FloatingText.spawn(self, text, Palette.RED if d > 0 else Palette.GREEN, Vector2(_meter.position.x, TOP_H + 8), 0.15)
	if pay > 0:
		Sfx.play("cash")


func _fmt_points(v: float) -> String:
	return str(int(v)) if is_equal_approx(v, roundf(v)) else "%.1f" % v


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
	_build_top_bar()
	_overlay = CiteOverlay.new()
	add_child(_overlay)
	_bind_buttons()


func _build_top_bar() -> void:
	add_child(_bg(Rect2(0, 0, 1920, TOP_H), Palette.BG_DARK))
	add_child(_bg(Rect2(0, TOP_H - 2, 1920, 2), Palette.WALL_LIGHT))
	var date := DateUtil.game_date(day)
	_day_label = _place_label("DAY %d  -  %s %s" % [day, DateUtil.weekday(date).to_upper(), DateUtil.fmt(date)], Vector2(24, 16), UiTheme.SIZE_BODY, Palette.TEXT_LIGHT)
	_patient_label = _place_label("", Vector2(560, 16), UiTheme.SIZE_BODY, Palette.TEXT_LIGHT)
	_effects_label = _place_label("", Vector2(820, 16), UiTheme.SIZE_BODY, Palette.AMBER)
	_place_label("DISCONTENT", Vector2(1150, 20), UiTheme.SIZE_SMALL, Palette.TEXT_DIM)
	_meter = DiscontentMeter.new()
	_meter.position = Vector2(1270, 18)
	add_child(_meter)
	_meter_label = _place_label("", Vector2(1584, 16), UiTheme.SIZE_BODY, Palette.TEXT_LIGHT)
	_pay_label = _place_label("", Vector2(1680, 16), UiTheme.SIZE_BODY, Palette.TEXT_LIGHT)


func _build_booth() -> void:
	_stage.add_child(_bg(Rect2(0, TOP_H, BOOTH_W, 1080 - TOP_H), Palette.WALL))
	_stage.add_child(_bg(Rect2(0, TOP_H + 20, BOOTH_W, 6), Palette.WALL_LIGHT))
	var poster_row := CenterContainer.new()
	poster_row.position = Vector2(0, TOP_H + 36)
	poster_row.size = Vector2(BOOTH_W, 40)
	poster_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var poster := PanelContainer.new()
	poster.add_theme_stylebox_override("panel", UiTheme.flat_box(Palette.PAPER_ALT, Palette.INK_FADED, 2, 14, 6))
	poster.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var slogan := NewsPool.SLOGANS[(day - 1) % NewsPool.SLOGANS.size()]
	poster.add_child(UiTheme.label(slogan, UiTheme.SIZE_SMALL, Palette.INK))
	poster_row.add_child(poster)
	_stage.add_child(poster_row)
	# Window frame and the patient behind it.
	_stage.add_child(_bg(Rect2(54, TOP_H + 96, 452, 512), Palette.DESK_DARK))
	_stage.add_child(_bg(Rect2(74, TOP_H + 116, 412, 472), Palette.WALL))
	_portrait = PortraitView.new()
	_portrait.position = Vector2(78, TOP_H + 120)
	_portrait.scale = Vector2(1.25, 1.2)
	_stage.add_child(_portrait)
	_portrait.clear()
	# Speech bubble.
	var bubble_box := PanelContainer.new()
	bubble_box.add_theme_stylebox_override("panel", UiTheme.flat_box(Palette.PAPER, Palette.INK, 2, 16, 12))
	bubble_box.position = Vector2(40, TOP_H + 630)
	bubble_box.custom_minimum_size = Vector2(480, 150)
	bubble_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bubble = UiTheme.para("", 440, UiTheme.SIZE_BODY, Palette.INK)
	bubble_box.add_child(_bubble)
	_stage.add_child(bubble_box)
	_next_button = UiTheme.button("NEXT!", UiTheme.SIZE_BIG, 480)
	_next_button.position = Vector2(40, TOP_H + 800)
	_next_button.custom_minimum_size = Vector2(480, 88)
	_stage.add_child(_next_button)
	_stage.add_child(_bg(Rect2(0, 1080 - 112, BOOTH_W, 112), Palette.DESK_DARK))
	_place_label_on(_stage, "DESK 11  -  ADJUSTER #4471", Vector2(24, 1080 - 70), UiTheme.SIZE_SMALL, Palette.TEXT_DIM)


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
	_rulebook = RulebookView.new()
	_rulebook.setup(day)
	_rulebook.drag_bounds = Rect2(Vector2.ZERO, DESK_SIZE)
	_rulebook.position = Vector2(DESK_SIZE.x - RulebookView.WIDTH - 12, 12)
	_rulebook.rule_clicked.connect(_on_rule_clicked)
	_rulebook.denybot_pressed.connect(_on_denybot_pressed)
	_desk.add_child(_rulebook)
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
	var hint_bg := _bg(Rect2(BOOTH_W, TOP_H + DESK_SIZE.y, DESK_SIZE.x, HINT_H), Color(0, 0, 0, 0.35))
	_stage.add_child(hint_bg)
	_hint_label = _place_label_on(_stage, "", Vector2(BOOTH_W + 20, TOP_H + DESK_SIZE.y + 10), UiTheme.SIZE_SMALL, Palette.TEXT_LIGHT)


func _build_tray() -> void:
	var y := 1080.0 - TRAY_H
	_stage.add_child(_bg(Rect2(BOOTH_W, y, 1920 - BOOTH_W, TRAY_H), Palette.DESK_DARK))
	_inspect_button = UiTheme.button("INSPECT (SPACE)", UiTheme.SIZE_BODY, 280)
	_inspect_button.position = Vector2(BOOTH_W + 20, y + 20)
	_inspect_button.custom_minimum_size = Vector2(280, 72)
	_stage.add_child(_inspect_button)
	_cite_label = _place_label_on(_stage, "", Vector2(BOOTH_W + 320, y + 42), UiTheme.SIZE_BODY, Palette.HIGHLIGHT)
	_approve_button = _stamp_button("APPROVE", Palette.GREEN, Palette.GREEN_DARK)
	_approve_button.position = Vector2(1920 - 600, y + 16)
	_stage.add_child(_approve_button)
	_deny_button = _stamp_button("DENY", Palette.RED, Palette.RED_DARK)
	_deny_button.position = Vector2(1920 - 300, y + 16)
	_stage.add_child(_deny_button)
	_approve_button.disabled = true
	_deny_button.disabled = true


func _stamp_button(text: String, color: Color, dark: Color) -> Button:
	var b := UiTheme.button(text, UiTheme.SIZE_TITLE, 280)
	b.custom_minimum_size = Vector2(280, 80)
	b.add_theme_stylebox_override("normal", UiTheme.flat_box(dark, Palette.INK, 3, 16, 8))
	b.add_theme_stylebox_override("hover", UiTheme.flat_box(color, Palette.INK, 3, 16, 8))
	b.add_theme_stylebox_override("pressed", UiTheme.flat_box(dark.darkened(0.3), Palette.INK, 3, 16, 8))
	b.add_theme_stylebox_override("disabled", UiTheme.flat_box(Palette.DESK, Palette.DESK_LIGHT, 3, 16, 8))
	return b


func _bind_buttons() -> void:
	_next_button.pressed.connect(call_next_patient)
	_inspect_button.pressed.connect(func() -> void: _set_inspect(not inspect))
	_approve_button.pressed.connect(stamp.bind(true))
	_deny_button.pressed.connect(stamp.bind(false))


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("inspect_toggle"):
		_set_inspect(not inspect)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("cancel_inspect") and inspect:
		_set_inspect(false)
		get_viewport().set_input_as_handled()


func _update_hud(animate: bool) -> void:
	var run := GameState.run
	_patient_label.text = "PATIENT %d OF %d" % [maxi(index + 1, 1), claims.size()] if index >= 0 else "%d PATIENTS TODAY" % claims.size()
	_pay_label.text = "TODAY %s" % UiTheme.money(GameState.pay_so_far())
	_meter.set_value(run.discontent, animate)
	_meter_label.text = "%d%%" % roundi(run.discontent)
	var effects: PackedStringArray = []
	if run.effects.get("protest", false):
		effects.append("PROTEST OUTSIDE")
	if run.effects.get("audit", false):
		effects.append("AUDIT IN PROGRESS")
	if run.effects.get("compassion", false):
		effects.append("COMPASSION DAY")
	_effects_label.text = "  ".join(effects)
	if run.effects.get("compassion", false):
		_approve_button.text = "APPROVE (FREE)"


func _refresh_hint() -> void:
	var text := ""
	if current == null:
		text = "Press NEXT! to call the first patient."
	elif stamped:
		text = "That's everyone. Press END SHIFT." if index >= claims.size() - 1 else "Press NEXT! for the next patient."
		if current.is_player:
			text = ""
	elif inspect:
		text = "INSPECTING: click a rule in the rulebook, then the field that breaks it. Esc to stop."
	elif cited_rule != "":
		text = "Reason cited. Stamp DENY to deny with %s, or APPROVE anyway." % cited_rule
	elif current.is_player:
		text = ""
	elif stamps_today == 0 and DAY_HINTS[day] != "":
		text = DAY_HINTS[day]
	elif day == 1 and stamps_today < 3:
		text = "Found a problem? INSPECT, click the rule, then the date that breaks it. Or just stamp."
	else:
		text = "Drag papers to read them. INSPECT (Space) to cite a reason, then stamp."
	_hint_label.text = text


func _shake() -> void:
	if fast:
		return
	var tween := create_tween()
	for i in 4:
		tween.tween_property(_stage, "position", Vector2(_rng.randf_range(-6, 6), _rng.randf_range(-4, 4)), 0.03)
	tween.tween_property(_stage, "position", Vector2.ZERO, 0.04)


func _tween_property(target: Object, property: String, value: Variant, duration: float, delay: float = 0.0) -> void:
	if fast:
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
