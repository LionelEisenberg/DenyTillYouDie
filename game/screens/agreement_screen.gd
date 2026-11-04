class_name AgreementScreen
extends ScreenBase
## The employment agreement. The name signed here is the one on your own claim
## on day 7. Each typed letter strikes like a typewriter. Signing inks the name
## in blue, stamps the sheet RECEIVED, hangs up on the hold music, and after a
## moment of silence clips a staff badge on; CLIP ON BADGE starts the week.

const INK_TIME := 0.45
## The silence after the hold music hangs up, before the badge.
const HUSH := 0.6

var name_edit: LineEdit
var back_button: Button
var sign_button: Button
## Shown once the badge is on the sheet; it finishes the screen.
var clip_button: Button
var signed: bool = false
var signature: Label
var received: StampMark
var badge: IdBadge

var _sign_holder: Control
var _sheet: Control
var _badge_pin: Control
var _payload: Dictionary = {}


func _ready() -> void:
	var bg := UiTheme.rect(Palette.DESK)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var column := centered_paper(1180)
	_sheet = column.get_parent() as Control
	var title := UiTheme.label("BENEVOLENCE MUTUAL", UiTheme.SIZE_BIG, Palette.INK)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)
	var sub := UiTheme.label("EMPLOYMENT AGREEMENT  -  CLAIMS ADJUSTER #4471, DESK 11", UiTheme.SIZE_BODY, Palette.INK_FADED)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(sub)
	column.add_child(UiTheme.rect(Palette.PAPER_SHADE, Vector2(0, 2)))
	for paragraph in NewsPool.AGREEMENT:
		column.add_child(UiTheme.para(paragraph, 1100, UiTheme.SIZE_SMALL, Palette.INK))
	column.add_child(UiTheme.rect(Palette.PAPER_SHADE, Vector2(0, 2)))

	var sign_row := HBoxContainer.new()
	sign_row.add_theme_constant_override("separation", 16)
	sign_row.add_child(UiTheme.label("EMPLOYEE NAME", UiTheme.SIZE_BODY, Palette.INK))
	name_edit = LineEdit.new()
	name_edit.placeholder_text = "Sign here"
	name_edit.max_length = 22
	name_edit.custom_minimum_size = Vector2(460, 0)
	name_edit.add_theme_font_size_override("font_size", UiTheme.SIZE_TITLE)
	name_edit.text_submitted.connect(func(_t: String) -> void: _sign())
	name_edit.text_changed.connect(func(_t: String) -> void: Sfx.play("typewriter"))
	sign_row.add_child(name_edit)
	# The signature replaces the field; a plain holder lets it slant.
	_sign_holder = Control.new()
	_sign_holder.custom_minimum_size = Vector2(460, 48)
	_sign_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sign_holder.visible = false
	signature = UiTheme.label("", UiTheme.SIZE_BIG, Palette.INK_BLUE)
	signature.position = Vector2(12, -2)
	signature.rotation_degrees = -3.0
	_sign_holder.add_child(signature)
	sign_row.add_child(_sign_holder)
	var date := UiTheme.label("DATE  %s" % DateUtil.fmt(DateUtil.game_date(1)), UiTheme.SIZE_BODY, Palette.INK_FADED)
	date.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	date.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	sign_row.add_child(date)
	column.add_child(sign_row)

	back_button = UiTheme.button("BACK", UiTheme.SIZE_BODY, 160)
	back_button.pressed.connect(func() -> void: finish({"back": true}))
	sign_button = UiTheme.button("SIGN AND START WORK", UiTheme.SIZE_BODY, 360)
	sign_button.pressed.connect(_sign)
	clip_button = UiTheme.button("CLIP ON BADGE", UiTheme.SIZE_BODY, 360)
	clip_button.pressed.connect(func() -> void: finish(_payload))
	clip_button.visible = false
	var holder := HBoxContainer.new()
	holder.add_child(back_button)
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	holder.add_child(gap)
	holder.add_child(sign_button)
	holder.add_child(clip_button)
	column.add_child(holder)
	if GameState.has_save():
		column.add_child(UiTheme.label("Signing starts a new week and replaces your saved one.", UiTheme.SIZE_SMALL, Palette.RED_DARK))
	column.add_child(UiTheme.label("*Terms, conditions and exclusions apply.", UiTheme.SIZE_SMALL, Palette.INK_FADED))


func on_shown() -> void:
	name_edit.grab_focus()


# Esc while typing the name: the field would take it just to stop editing, and
# the Esc menu would need a second press. Stop editing here and let the key
# through; the menu gives the field its focus (and editing) back when it closes.
func _input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo or key.keycode != KEY_ESCAPE:
		return
	if name_edit.has_focus() and name_edit.is_editing():
		name_edit.unedit()


# The stamp and the badge sit over the sheet, outside its containers; keep them
# on the laid-out spots (the tour may sign before the first layout pass).
func _process(_delta: float) -> void:
	if received != null:
		received.position = _stamp_spot()
	if _badge_pin != null:
		_badge_pin.position = _badge_spot()


## The name as the run will record it: trimmed, or the default when blank.
func signed_name() -> String:
	var n := name_edit.text.strip_edges()
	return n if n != "" else GameState.DEFAULT_NAME


## Shows the signed sheet at once (signature, stamp, badge and CLIP ON BADGE)
## without finishing. For the screenshot tour; does nothing once signed.
func show_signed() -> void:
	if signed:
		return
	_begin_signing()
	_ink_signature(false)
	_stamp_received(false)
	_clip_badge(false)


func _sign() -> void:
	if signed:
		return
	if fast:
		signed = true
		finish({"name": name_edit.text})
		return
	_begin_signing()
	_ink_signature(true)
	Sfx.play("pen_scratch")
	await _beat(INK_TIME + 0.1)
	_stamp_received(true)
	await _beat(0.45)
	# The hold music hangs up with the handset (Ambience hears it), then silence.
	Sfx.play("handset")
	await _beat(HUSH)
	_clip_badge(true)


## A pause in the signing that also holds while the Esc menu is open.
func _beat(seconds: float) -> void:
	await get_tree().create_timer(seconds, false).timeout


func _begin_signing() -> void:
	signed = true
	_payload = {"name": name_edit.text}
	back_button.disabled = true
	sign_button.disabled = true
	name_edit.editable = false


func _ink_signature(animate: bool) -> void:
	signature.text = signed_name()
	name_edit.visible = false
	_sign_holder.visible = true
	if animate:
		signature.visible_ratio = 0.0
		create_tween().tween_property(signature, "visible_ratio", 1.0, INK_TIME)


## RECEIVED - CLAIMS INTEGRITY, stamped beside the signature.
func _stamp_received(animate: bool) -> void:
	received = StampMark.create(false, "CLAIMS INTEGRITY")
	received.word = "RECEIVED"
	received.rotation_degrees = -7.0
	received.position = _stamp_spot()
	add_child(received)
	if animate and not Engine.get_meta("reduce_motion", false):
		received.scale = Vector2(1.5, 1.5)
		var tween := create_tween()
		tween.tween_property(received, "scale", Vector2.ONE, 0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tween.tween_callback(Sfx.play.bind("stamp"))
	elif animate:
		Sfx.play("stamp")


## The badge drops onto the sheet, tilted as if just clipped on.
func _clip_badge(animate: bool) -> void:
	badge = IdBadge.create(signed_name(), IdBadge.FULL)
	# The pin sits where the badge rests and turns about the clip; the drop
	# moves the badge inside it.
	_badge_pin = Control.new()
	_badge_pin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_badge_pin.size = badge.size
	_badge_pin.pivot_offset = Vector2(badge.size.x / 2.0, 0.0)
	_badge_pin.position = _badge_spot()
	_badge_pin.add_child(badge)
	add_child(_badge_pin)
	sign_button.visible = false
	clip_button.visible = true
	clip_button.grab_focus()
	if not animate or Engine.get_meta("reduce_motion", false):
		_badge_pin.rotation_degrees = -4.0
		if animate:
			Sfx.play("card_tick")
		return
	badge.position = Vector2(0, -70)
	_badge_pin.rotation_degrees = -10.0
	_badge_pin.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(badge, "position", Vector2.ZERO, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(_badge_pin, "modulate:a", 1.0, 0.1)
	tween.parallel().tween_property(_badge_pin, "rotation_degrees", -3.0, 0.22)
	tween.tween_callback(Sfx.play.bind("card_tick"))
	tween.tween_property(_badge_pin, "rotation_degrees", -4.0, 0.12).set_trans(Tween.TRANS_SINE)


## Beside the signature and riding up over the last clause: clear of the date
## and of the buttons below.
func _stamp_spot() -> Vector2:
	var spot := _sign_holder.get_global_rect()
	return Vector2(spot.end.x + 12.0, spot.position.y - 8.0 - received.size.y / 2.0)


## Over the top right of the clauses, clear of the signature line.
func _badge_spot() -> Vector2:
	var sheet := _sheet.get_global_rect()
	return Vector2(sheet.end.x - badge.size.x - 70.0, sheet.position.y + 128.0)
