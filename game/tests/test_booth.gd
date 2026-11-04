extends RefCounted
## The booth: the waiting room behind the glass, the NOW SERVING board, patients
## who walk and talk, event days, the day-7 climax, and what citation slips say.

var t: TestContext
var gs: Node
var tree: SceneTree
var desk: DeskScreen
## Widgets a test made outside the desk, freed after it.
var _made: Array[Node] = []


## A portrait that notes every block it paints (where it lands on the grid, and
## its color) instead of painting it.
class RecordingPortrait extends PortraitView:
	var blocks: Array[Dictionary] = []

	func _b(x: int, y: int, w: int, h: int, c: Color) -> void:
		var r := Rect2i(x + _off.x, y + _off.y, maxi(w, 0), maxi(h, 0)).intersection(Rect2i(0, 0, GRID_W, GRID_H))
		if r.has_area():
			blocks.append({"rect": r, "color": c})


func before_each() -> void:
	tree = Engine.get_main_loop() as SceneTree
	gs = tree.root.get_node("GameState")
	gs.save_path_override = TestContext.save_path()
	gs.new_run("Pat Doe", 77)


func after_each() -> void:
	Engine.set_meta("reduce_motion", false)
	tree.paused = false
	if desk and is_instance_valid(desk):
		desk.queue_free()
	desk = null
	for node in _made:
		if is_instance_valid(node):
			node.queue_free()
	_made.clear()
	await tree.process_frame
	gs.delete_save()
	gs.save_path_override = ""


func _open(day: int) -> void:
	if desk and is_instance_valid(desk):
		desk.queue_free()
		await tree.process_frame
	gs.run.day = day
	desk = DeskScreen.new()
	desk.fast = true
	desk.training_enabled = false
	tree.root.add_child(desk)
	await tree.process_frame


## Waits in real time until `condition` holds or `seconds` pass.
func _until(condition: Callable, seconds: float) -> void:
	var deadline := Time.get_ticks_msec() + int(seconds * 1000.0)
	while not condition.call() and Time.get_ticks_msec() < deadline:
		await tree.process_frame


func _click(c: Control) -> void:
	var at := tree.root.get_final_transform() * (c.get_global_transform_with_canvas() * (c.size / 2.0))
	for pressed: bool in [true, false]:
		var e := InputEventMouseButton.new()
		e.button_index = MOUSE_BUTTON_LEFT
		e.pressed = pressed
		e.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
		e.position = at
		e.global_position = at
		tree.root.push_input(e)


## A widget added to the tree for one test.
func _add(node: Node) -> void:
	_made.append(node)
	tree.root.add_child(node)


## What `p` paints at the moment.
func _painted(p: RecordingPortrait) -> Array[Dictionary]:
	p.blocks.clear()
	p.queue_redraw()
	await tree.process_frame
	await tree.process_frame
	return p.blocks


## The painted blocks in `color`.
static func _in_color(blocks: Array[Dictionary], color: Color) -> Array[Dictionary]:
	return blocks.filter(func(b: Dictionary) -> bool: return (b["color"] as Color).is_equal_approx(color))


## Plays day 7 in fast mode up to (not including) the adjuster's own claim.
func _up_to_the_adjuster() -> void:
	while not desk.claims[desk.index + 1].is_player:
		desk.call_next_patient()
		await desk.stamp(false)


## Finds a Label under `node` whose text starts with `prefix`.
func _label_starting(node: Node, prefix: String) -> Label:
	if node is Label and (node as Label).text.begins_with(prefix):
		return node
	for child in node.get_children():
		var found := _label_starting(child, prefix)
		if found:
			return found
	return null


# --- the day-7 climax ------------------------------------------------------------

func test_only_the_adjusters_own_claim_cuts_to_black() -> void:
	for approve: bool in [false, true]:
		await _open(7)
		var payloads: Array[Dictionary] = []
		desk.done.connect(func(p: Dictionary) -> void: payloads.append(p))
		while true:
			desk.call_next_patient()
			var c := desk.active_claim()
			if c.is_player:
				break
			t.ok(desk._board.value < 1000 and not desk._board.fourth_lit(), "the fourth digit stays dark for %s" % c.name)
			await desk.stamp(approve)
			t.ok(payloads.is_empty(), "stamping %s sends nothing" % c.name)
		t.eq(desk.waiting_count(), 0, "nobody waits behind the adjuster")
		t.eq(desk._booth.waiting, 0, "the waiting room is empty")
		t.eq(desk._board.value, DeskScreen.PLAYER_TICKET, "now serving 4471")
		t.ok(desk._board.fourth_lit(), "the fourth digit lights for the first time")
		t.ok(desk.ambience_quiet, "the room goes quiet once the papers are down")
		t.ok(not desk._booth.lights, "the back window is dark")
		t.near(desk._booth_lights.color.a, 0.2, 0.001, "the booth stays 20% darker")
		t.near(desk._booth.sheen, 0.12, 0.001, "under a heavier glare")
		await desk.stamp(approve)
		t.eq(payloads.size(), 1, "the stamp finishes the screen")
		t.eq(payloads[0].get("cut", false), true, "with a cut (approve=%s)" % approve)


func test_the_staged_climax_runs_and_cuts() -> void:
	await _open(7)
	while not desk.claims[desk.index + 1].is_player:
		desk.call_next_patient()
		await desk.stamp(false)
	var payloads: Array[Dictionary] = []
	desk.done.connect(func(p: Dictionary) -> void: payloads.append(p))
	desk.fast = false
	var saved := desk.saved_today
	desk.call_next_patient()
	t.ok(desk._approve_button.disabled, "no stamping until every paper is down")
	t.eq(desk._docs.size(), 0, "the papers come one at a time")
	t.near(desk._portrait.modulate.a, 0.0, 0.01, "the face fades in instead of walking")
	t.eq(desk._portrait.fig_offset, Vector2i.ZERO, "and never walks")
	t.ok(not desk.ambience_quiet)
	await _until(func() -> bool: return desk._docs.size() == 1, 3.0)
	var one_at := Time.get_ticks_msec()
	await _until(func() -> bool: return desk._docs.size() == 2, 2.0)
	t.near((Time.get_ticks_msec() - one_at) / 1000.0, 0.5, 0.15, "half a second apart")
	await _until(func() -> bool: return not desk._approve_button.disabled, 4.0)
	t.ok(not desk._approve_button.disabled, "the stamps wake up once the last paper lands")
	t.ok(desk.ambience_quiet, "and the room drains to the hum")
	t.ok(not desk._booth.lights)
	t.eq(desk._bubble.text, "...", "the adjuster says nothing")
	t.ok(desk._bubble.visible_characters < 3, "one slow dot at a time")
	desk.stamp(false)
	await _until(func() -> bool: return desk._last_mark != null, 3.0)
	t.ok(desk._last_mark != null, "the stamp lands")
	t.ok(payloads.is_empty(), "then a moment of stillness")
	_click(desk._bubble_box)
	await _until(func() -> bool: return not payloads.is_empty(), 1.0)
	t.eq(payloads.size(), 1, "a click ends the stillness")
	t.eq(payloads[0].get("cut", false), true)
	t.eq(desk.saved_today, saved, "the adjuster's own claim is not the plan's saving")
	t.eq(Engine.time_scale, 1.0)


func test_the_last_stillness_waits_while_the_game_is_paused() -> void:
	await _open(7)
	await _up_to_the_adjuster()
	desk.call_next_patient()
	var payloads: Array[Dictionary] = []
	desk.done.connect(func(p: Dictionary) -> void: payloads.append(p))
	desk.fast = false
	desk.stamp(false)
	await _until(func() -> bool: return desk._climax_waiting, 3.0)
	t.ok(desk._climax_waiting, "the stamp is down and the desk holds still")
	tree.paused = true # The Esc menu.
	await _until(func() -> bool: return not payloads.is_empty(), 2.2)
	t.ok(payloads.is_empty(), "the 1.5 s of stillness don't run out behind the menu")
	tree.paused = false
	await _until(func() -> bool: return not payloads.is_empty(), 3.0)
	t.eq(payloads.size(), 1, "they run out once the game goes on")
	t.eq(payloads[0].get("cut", false), true)
	t.eq(Engine.time_scale, 1.0)


func test_reduce_motion_stages_the_climax_without_moving() -> void:
	Engine.set_meta("reduce_motion", true)
	await _open(7)
	await _up_to_the_adjuster()
	var payloads: Array[Dictionary] = []
	desk.done.connect(func(p: Dictionary) -> void: payloads.append(p))
	desk.fast = false
	desk.call_next_patient()
	var flickered := [false]
	await _until(func() -> bool:
		flickered[0] = flickered[0] or desk._booth_lights.color.a > 0.3
		return not desk._approve_button.disabled, 8.0)
	t.ok(not desk._approve_button.disabled, "the papers land and the stamps wake")
	t.ok(not flickered[0], "the lights don't flicker")
	t.near(desk._booth_lights.color.a, 0.2, 0.001, "they just stay low")
	t.ok(not desk._booth.lights, "and the back window is dark")
	t.eq(desk._portrait.fig_offset, Vector2i.ZERO)
	t.eq(desk._claim_doc.position, Vector2(20, 16), "no paper slid")
	desk.stamp(false)
	t.ok(desk._last_mark != null, "the stamp lands without a flight")
	t.ok(desk._deny_tool.visible, "the stamp never leaves the tray")
	t.eq(Engine.time_scale, 1.0, "no hitstop")
	t.eq(desk._stage.position, Vector2.ZERO, "no shake")
	await _until(func() -> bool: return not payloads.is_empty(), 4.0)
	t.eq(payloads.size(), 1, "the cut still comes")
	t.eq(payloads[0].get("cut", false), true)


# --- the waiting room and the board ---------------------------------------------------

func test_the_waiting_room_empties_one_patient_at_a_time() -> void:
	await _open(1)
	var n := desk.claims.size()
	var start := DeskScreen.ticket_start(gs.run.run_seed, 1)
	t.ok(start >= 30 and start <= 70, "tickets start at %d" % start)
	t.eq(desk.waiting_count(), n, "everyone waits before the first NEXT!")
	t.eq(desk._booth.waiting, n)
	for k in n:
		desk.call_next_patient()
		t.eq(desk.waiting_count(), n - k - 1, "one fewer after NEXT! %d" % (k + 1))
		t.eq(desk._booth.waiting, n - k - 1)
		t.eq(desk._board.value, start + k, "the board after %d patients" % k)
		t.eq(desk._board.shown(), start + k)
		await desk.stamp(true)


func test_day_7_never_counts_the_adjuster_as_waiting() -> void:
	await _open(7)
	var others := desk.claims.size() - 1
	t.ok(desk.claims[others].is_player, "the last claim is the adjuster's")
	t.eq(desk.waiting_count(), others, "only the patients wait")
	t.eq(desk._booth._kinds.size(), others, "one silhouette each")


func test_portrait_blocks_are_square() -> void:
	var p := PortraitView.new()
	t.eq(p.size, Vector2(320, 384), "8 px blocks by default")
	t.ok(p.draw_wall, "with its own wall")
	p.block = 10
	t.eq(p.size, Vector2(400, 480), "10 px blocks: 400 by 480")
	p.free()
	await _open(1)
	t.eq(desk._portrait.block, 10)
	t.ok(not desk._portrait.draw_wall, "the desk draws the room instead")
	t.eq(desk._portrait.scale, Vector2.ONE, "no squash")
	t.eq(Rect2(desk._booth.position, desk._booth.size), DeskScreen.WINDOW_RECT, "the room fills the window")
	t.ok(desk._booth.clip_contents, "and crops the figure")
	t.ok(desk._portrait.get_parent() == desk._booth, "behind the glass")


func test_the_window_light_follows_patients_not_time() -> void:
	var booth := BoothView.new()
	booth.set_progress(0.0)
	t.eq(booth.window_light(), BoothView.MORNING, "pale morning")
	booth.set_progress(1.0)
	t.eq(booth.window_light(), BoothView.DUSK, "amber dusk")
	booth.set_lights(false)
	t.eq(booth.window_light(), Palette.BG_DARK, "dark")
	booth.free()
	await _open(1)
	t.near(desk._booth.progress, 0.0, 0.001)
	for i in desk.claims.size():
		desk.call_next_patient()
		await desk.stamp(true)
	t.near(desk._booth.progress, 1.0, 0.001, "dusk at the last patient")


func test_the_shutter_is_down_until_the_first_patient() -> void:
	await _open(1)
	t.eq(desk._booth.shutter, 1.0, "closed before the shift")
	desk.call_next_patient()
	t.eq(desk._booth.shutter, 0.0, "up for the first patient")


func test_waiting_heads_never_crowd_the_one_at_the_glass() -> void:
	var booth := BoothView.new()
	_add(booth)
	var kinds: Array[int] = []
	for i in BoothView.MAX_SEATS:
		kinds.append([BoothView.Shape.HAT, BoothView.Shape.LONG_HAIR, BoothView.Shape.CHILD][i % 3])
	booth.setup(kinds)
	booth.set_waiting(kinds.size())
	t.eq(booth.seated().size(), BoothView.MAX_SEATS, "with nobody at the glass, everyone shows")
	var hid_some := false
	for s in range(1, 41):
		var age := 6 + (s * 7) % 80
		booth.portrait.with_parent = age < 16 and s % 2 == 0
		booth.portrait.show_patient(s * 101, age, s % 5 == 0)
		var cover := booth.portrait.coverage()
		var seated := booth.seated()
		hid_some = hid_some or seated.size() < BoothView.MAX_SEATS
		for sat in seated:
			var head := BoothView._head_box(BoothView.SEATS[sat.y], kinds[sat.x])
			var cells := 0
			var hidden := 0
			var near := 0
			for y in range(head.position.y, head.end.y):
				for x in range(head.position.x - BoothView.HEAD_CLEARANCE, head.end.x + BoothView.HEAD_CLEARANCE):
					var covered := x >= 0 and x < BoothView.GRID_W and cover[y * BoothView.GRID_W + x] != 0
					if x >= head.position.x and x < head.end.x:
						cells += 1
						hidden += int(covered)
					else:
						near += int(covered)
			t.ok(hidden == cells or (hidden == 0 and near == 0), "seat %d beside face %d (age %d): wholly behind it or clear of it" % [sat.y, s * 101, age])
	t.ok(hid_some, "the faces at the glass hide the heads beside them")
	booth.portrait.with_parent = false
	booth.portrait.show_patient(7, 40, false)
	var seats: Array[int] = []
	for sat in booth.seated():
		seats.append(sat.y)
	t.ok(seats.has(0) and seats.has(BoothView.MAX_SEATS - 1), "the far seats stay in view: %s" % [seats])
	booth.portrait.fig_offset = Vector2i(-DeskScreen.WALK_FROM, 0)
	t.eq(booth.seated().size(), BoothView.MAX_SEATS, "a patient still out of sight hides nobody")
	booth.portrait.fig_offset = Vector2i.ZERO
	booth.portrait.clear()
	t.eq(booth.seated().size(), BoothView.MAX_SEATS, "nor does an empty window")


func test_a_seat_just_vacated_stays_empty_until_the_next_call() -> void:
	var booth := BoothView.new()
	_add(booth)
	var kinds: Array[int] = []
	for i in 9:
		kinds.append(BoothView.Shape.HAT)
	booth.setup(kinds)
	booth.set_waiting(9)
	t.eq(_patients(booth.seated()), [0, 1, 2, 3, 4, 5, 6], "seven seats for nine patients")
	t.eq(booth.seat_of(7), booth.seat_of(0), "patient 7 will take patient 0's seat")
	booth.set_waiting(8)
	t.eq(_patients(booth.seated()), [1, 2, 3, 4, 5, 6], "but doesn't sit straight down where patient 0 got up")
	booth.set_waiting(7)
	t.eq(_patients(booth.seated()), [2, 3, 4, 5, 6, 7], "one call later, they do")
	t.ok(booth.seated().has(Vector2i(7, booth.seat_of(0))), "in that seat")
	booth.set_waiting(1)
	t.eq(_patients(booth.seated()), [8], "the last one waits alone")


func test_those_who_wait_longest_sit_by_the_walls() -> void:
	var booth := BoothView.new()
	_add(booth)
	var walls: Array[int] = [0, BoothView.MAX_SEATS - 1]
	for n in range(1, 11):
		var kinds: Array[int] = []
		for i in n:
			kinds.append(BoothView.Shape.HAT)
		booth.setup(kinds)
		var seated := mini(n, BoothView.MAX_SEATS)
		var seats := {}
		for k in seated:
			seats[booth.seat_of(k)] = true
		t.eq(seats.size(), seated, "%d patients: a seat each" % n)
		t.eq(booth.seat_of(seated - 1), 0, "%d patients: the longest wait by the left wall" % n)
		if seated > 1:
			t.eq(booth.seat_of(seated - 2), BoothView.MAX_SEATS - 1, "%d patients: the next longest by the right wall" % n)
		for k in range(BoothView.MAX_SEATS, n):
			var shared := booth.seat_of(k)
			t.eq(shared, booth.seat_of(k - BoothView.MAX_SEATS), "%d patients: patient %d takes the seat of patient %d" % [n, k, k - BoothView.MAX_SEATS])
			t.ok(not walls.has(shared), "%d patients: a seat in the middle, so the walls stay filled" % n)
	# So with someone at the glass, the room still shows who is waiting.
	var five: Array[int] = [BoothView.Shape.HAT, BoothView.Shape.LONG_HAIR, BoothView.Shape.HAT, BoothView.Shape.LONG_HAIR, BoothView.Shape.HAT]
	booth.setup(five)
	booth.set_waiting(4)
	booth.portrait.show_patient(7, 40, false)
	var seen := 0
	var cover := booth.portrait.coverage()
	for sat in booth.seated():
		var head := BoothView._head_box(BoothView.SEATS[sat.y], five[sat.x])
		var hidden := true
		for y in range(head.position.y, head.end.y):
			for x in range(head.position.x, head.end.x):
				if x >= 0 and x < BoothView.GRID_W and cover[y * BoothView.GRID_W + x] == 0:
					hidden = false
		seen += int(not hidden)
	t.ok(seen >= 2, "and at least two of them show past the one at the glass (%d)" % seen)


static func _patients(seated: Array[Vector2i]) -> Array[int]:
	var out: Array[int] = []
	for sat in seated:
		out.append(sat.x)
	return out


# --- walking and talking ------------------------------------------------------------

func test_fast_mode_walks_are_instant() -> void:
	await _open(1)
	desk.call_next_patient()
	t.eq(desk._portrait.fig_offset, Vector2i.ZERO, "at the window at once")
	t.ok(desk._portrait.is_shown())
	await desk.stamp(false)
	t.ok(not desk._portrait.is_shown(), "gone at once after the stamp")


func test_a_real_arrival_walks_in_on_the_grid() -> void:
	await _open(1)
	desk.call_next_patient()
	await desk.stamp(true)
	desk.fast = false
	desk.call_next_patient()
	t.ok(desk._portrait.fig_offset.x < 0, "starts off to the left: %s" % desk._portrait.fig_offset)
	var columns := {}
	var until := Time.get_ticks_msec() + 1000
	while Time.get_ticks_msec() < until:
		columns[desk._portrait.fig_offset.x] = true
		await tree.process_frame
	t.eq(desk._portrait.fig_offset, Vector2i.ZERO, "at the window after a second")
	for x: int in columns:
		t.eq(posmod(x, 2), 0, "two-block steps (column %d)" % x)
	t.ok(columns.size() > 3, "in several steps")
	desk.fast = true


func test_a_patient_starts_out_of_sight() -> void:
	var p := RecordingPortrait.new()
	p.block = BoothView.BLOCK
	p.draw_wall = false
	_add(p)
	for s in range(1, 61):
		var age := 4 + (s * 13) % 90
		p.show_patient(s * 37, age, s % 4 == 0)
		p.fig_offset = Vector2i(-DeskScreen.WALK_FROM, 0)
		var painted: Array[Dictionary] = await _painted(p)
		t.eq(painted.size(), 0, "face %d (age %d), outline and shadow, is off the glass before the walk" % [s * 37, age])
		p.fig_offset = Vector2i(-DeskScreen.WALK_FROM + 2, 0)
		painted = await _painted(p)
		if age >= 16:
			t.ok(painted.size() > 0, "and one step in, an adult's shoulder shows (face %d)" % (s * 37))


func test_a_parent_s_hand_rests_on_the_child_only_at_the_counter() -> void:
	var p := RecordingPortrait.new()
	p.block = BoothView.BLOCK
	p.draw_wall = false
	_add(p)
	p.show_patient(4242, 7, false)
	var coat: Color = p._parent_cloth
	var edge := PortraitView.PARENT_EDGE
	var painted: Array[Dictionary] = await _painted(p)
	t.eq(_in_color(painted, coat).size(), 0, "a child alone: no parent")
	p.with_parent = true
	painted = await _painted(p)
	var coat_blocks := _in_color(painted, coat)
	var strip := coat_blocks.filter(func(b: Dictionary) -> bool: return (b["rect"] as Rect2i).position.x >= edge)
	var sleeve := coat_blocks.filter(func(b: Dictionary) -> bool: return (b["rect"] as Rect2i).end.x <= edge)
	t.ok(not strip.is_empty(), "the parent's coat at the window's edge")
	t.ok(not sleeve.is_empty(), "a sleeve reaching for the child")
	t.ok(not _in_color(painted, coat.darkened(0.3)).is_empty(), "a cuff")
	var hand := _in_color(painted, p._parent_skin).filter(func(b: Dictionary) -> bool: return (b["rect"] as Rect2i).position.y >= p._sh - 1)
	t.ok(not hand.is_empty(), "and a hand on the shoulder")
	for offset: Vector2i in [Vector2i(-6, 0), Vector2i(4, 0), Vector2i(0, 1)]:
		p.fig_offset = offset
		painted = await _painted(p)
		var walking := offset.x != 0
		var cuff := _in_color(painted, coat.darkened(0.3))
		t.eq(cuff.is_empty(), walking, "the hand is on the shoulder only at the counter (offset %s)" % offset)
	p.fig_offset = Vector2i(-6, 0)
	painted = await _painted(p)
	t.eq(_leftmost(_in_color(painted, coat)), edge, "walking in, the parent is already at the counter")
	p.fig_offset = Vector2i(2, 0)
	painted = await _painted(p)
	t.eq(_leftmost(_in_color(painted, coat)), edge + 2, "walking out, the parent goes with the child")
	var cover := p.coverage()
	t.eq(cover[10 * PortraitView.GRID_W + edge + 1], 1, "the coat counts as covering the glass")
	p.fig_offset = Vector2i(4, 0)
	painted = await _painted(p)
	t.eq(_in_color(painted, coat).size(), 0, "two steps out, the parent has left the frame")


static func _leftmost(blocks: Array[Dictionary]) -> int:
	var x := 1 << 30
	for b in blocks:
		x = mini(x, (b["rect"] as Rect2i).position.x)
	return x


func test_patients_blink() -> void:
	await _open(1)
	desk.call_next_patient()
	var p := desk._portrait
	t.ok(p._blink_timer != null, "the patient at the window blinks")
	t.ok(not p._blink_timer.is_stopped(), "on a running timer")
	t.ok(p._blink_timer.wait_time >= 2.5 and p._blink_timer.wait_time <= 5.5, "every 2.5 to 5.5 s")
	t.ok(not p._blinking)
	p._blink_timer.timeout.emit()
	t.ok(p._blinking, "the lids close")
	t.near(p._blink_timer.wait_time, PortraitView.BLINK_TIME, 0.001, "briefly")
	p._blink_timer.timeout.emit()
	t.ok(not p._blinking, "and open again")
	var photo := PortraitView.new()
	photo.show_patient(5, 40, false)
	t.ok(photo._blink_timer == null, "a photo holds still")
	photo.free()


func test_a_child_comes_with_a_parent() -> void:
	await _open(2)
	var saw_child := false
	for i in desk.claims.size():
		desk.call_next_patient()
		var c := desk.active_claim()
		t.eq(desk._portrait.with_parent, c.is_child() and c.parent_speaks, "%s, %d" % [c.name, c.age])
		saw_child = saw_child or c.is_child()
		await desk.stamp(true)
	t.ok(saw_child, "Lily came with a parent")


func test_speech_types_and_a_click_finishes_it() -> void:
	await _open(1)
	desk.call_next_patient()
	t.eq(desk._bubble.visible_characters, -1, "fast mode shows the line at once")
	await desk.stamp(true)
	desk.fast = false
	desk.call_next_patient()
	var line := desk._bubble.text
	t.ok(line.length() > 3, "a line to say")
	t.ok(desk._bubble.visible_characters >= 0 and desk._bubble.visible_characters < line.length(), "still typing right after NEXT!")
	desk._set_inspect(true)
	t.ok(desk.inspect, "typing doesn't hold up inspect mode")
	desk._set_inspect(false)
	await _until(func() -> bool: return not desk._approve_button.disabled, 3.0)
	t.ok(not desk._approve_button.disabled, "or the stamps, once the claim form is down")
	t.ok(desk._typing, "while the line is still typing")
	_click(desk._bubble_box)
	await tree.process_frame
	t.eq(desk._bubble.visible_characters, -1, "a click on the bubble shows it all")
	t.ok(not desk._typing)
	desk.fast = true


func test_the_stamps_wake_when_the_claim_form_lands() -> void:
	await _open(1)
	desk.call_next_patient()
	t.ok(not desk._approve_button.disabled, "fast mode: the papers are down at once")
	await desk.stamp(true)
	desk.fast = false
	desk.call_next_patient()
	var rest := Vector2(20, 16)
	t.ok(desk._approve_button.disabled and desk._deny_button.disabled, "no stamping while the papers are in the air")
	t.ok(desk._claim_doc.position != rest, "the claim form is still on its way")
	await _until(func() -> bool: return not desk._approve_button.disabled, 3.0)
	t.eq(desk._claim_doc.position, rest, "the stamps wake as the claim form lands")
	t.ok(not desk._deny_button.disabled)
	desk.fast = true


func test_reduce_motion_keeps_the_booth_still() -> void:
	Engine.set_meta("reduce_motion", true)
	await _open(1)
	desk.fast = false
	desk.call_next_patient()
	t.eq(desk._booth.shutter, 0.0, "the shutter is simply up")
	t.eq(desk._portrait.fig_offset, Vector2i.ZERO, "the patient is at the glass at once")
	t.eq(desk._claim_doc.position, Vector2(20, 16), "the papers are down")
	t.ok(not desk._approve_button.disabled, "and the stamps live")
	var froze := [false]
	desk.stamp(false)
	t.ok(desk._last_mark != null, "the impression lands without a flight")
	t.ok(desk._approve_tool.visible and desk._deny_tool.visible, "no stamp leaves the tray")
	t.eq(desk._stage.position, Vector2.ZERO, "no shake")
	t.eq(desk._pay_label.text, "TODAY %s" % UiTheme.money(gs.pay_so_far()), "the pay readout changes at once")
	t.eq(desk._meter_label.text, "%d%%" % roundi(gs.run.discontent), "and the meter")
	var pops: Array[FloatingText] = []
	for child in desk.get_children():
		if child is FloatingText:
			pops.append(child)
	t.eq(pops.size(), 2, "the pay and discontent pops still show")
	var spots: Array[Vector2] = []
	for pop in pops:
		spots.append(pop.position)
	await _until(func() -> bool:
		froze[0] = froze[0] or Engine.time_scale == 0.0
		return false, 0.4)
	for i in pops.size():
		t.ok(is_instance_valid(pops[i]) and pops[i].position == spots[i], "a pop fades where it is instead of flying off")
	await _until(func() -> bool:
		froze[0] = froze[0] or Engine.time_scale == 0.0
		return not desk._next_button.disabled, 4.0)
	t.ok(not froze[0], "no hitstop")
	t.ok(not desk._portrait.is_shown(), "the patient is simply gone")
	t.eq(desk._portrait.fig_offset, Vector2i.ZERO)
	desk.fast = true


func test_end_shift_closes_the_window_and_punches_out() -> void:
	await _open(1)
	var n := desk.claims.size()
	for i in n:
		desk.call_next_patient()
		await desk.stamp(true)
	var payloads: Array[Dictionary] = []
	desk.done.connect(func(p: Dictionary) -> void: payloads.append(p))
	desk.fast = false
	desk.call_next_patient()
	t.ok(payloads.is_empty(), "END SHIFT takes a moment")
	await _until(func() -> bool: return desk._booth.shutter >= 1.0, 3.0)
	t.eq(desk._booth.shutter, 1.0, "the shutter comes down")
	var out_text := "OUT   %s" % DeskScreen.clock_out(n)
	await _until(func() -> bool:
		var punched := _label_starting(desk._desk, "OUT   ")
		return punched != null and punched.modulate.a >= 1.0, 3.0)
	var out := _label_starting(desk._desk, "OUT   ")
	t.ok(out != null and out.text == out_text, "the time card is punched %s" % out_text)
	t.ok(payloads.is_empty(), "and held a moment")
	await _until(func() -> bool: return not payloads.is_empty(), 3.0)
	t.eq(payloads.size(), 1, "then the shift is over")
	t.eq(gs.run.stats["processed"], n)


func test_end_shift_waits_while_the_game_is_paused() -> void:
	await _open(1)
	for i in desk.claims.size():
		desk.call_next_patient()
		await desk.stamp(true)
	var payloads: Array[Dictionary] = []
	desk.done.connect(func(p: Dictionary) -> void: payloads.append(p))
	desk.fast = false
	desk.call_next_patient()
	await _until(func() -> bool: return _label_starting(desk._desk, "OUT   ") != null, 3.0)
	var out := _label_starting(desk._desk, "OUT   ")
	t.ok(out != null, "the shutter is down and the time card is out")
	if out == null:
		return
	tree.paused = true # The Esc menu, before the clock punches the card...
	await _until(func() -> bool: return false, 0.9)
	t.eq(out.modulate.a, 0.0, "the card isn't punched behind the menu")
	tree.paused = false
	await _until(func() -> bool: return out.modulate.a >= 1.0, 2.0)
	t.eq(out.modulate.a, 1.0, "it's punched once the game goes on")
	tree.paused = true # ...and again while the punched card is held.
	await _until(func() -> bool: return not payloads.is_empty(), 1.6)
	t.ok(payloads.is_empty(), "the shift doesn't end behind the menu")
	tree.paused = false
	await _until(func() -> bool: return not payloads.is_empty(), 3.0)
	t.eq(payloads.size(), 1, "it ends once the game goes on")


func test_the_time_clock() -> void:
	t.eq(DeskScreen.clock_out(0), "08:00")
	t.eq(DeskScreen.clock_out(5), "13:50", "70 minutes a patient")
	t.eq(DeskScreen.clock_out(8), "17:20")
	t.eq(DeskScreen.clock_out(14), "00:20", "past midnight it wraps")


func test_speech_voices() -> void:
	var c := Claim.new()
	c.age = 40
	t.eq(DeskScreen.voice_for(c), "voice_mid")
	c.age = 70
	t.eq(DeskScreen.voice_for(c), "voice_low")
	c.age = 8
	t.eq(DeskScreen.voice_for(c), "voice_high", "a child speaking")
	c.parent_speaks = true
	t.eq(DeskScreen.voice_for(c), "voice_mid", "never the child's voice when the parent speaks")
	c.is_player = true
	t.eq(DeskScreen.voice_for(c), "", "the adjuster has no voice")


# --- events -----------------------------------------------------------------------

## Event lines a claim could open with, with {child} filled in.
func _event_pool(id: String, c: Claim) -> PackedStringArray:
	var pool: PackedStringArray = []
	for line: String in EventLines.ARRIVAL[id]:
		pool.append(line)
	for line: String in EventLines.ARRIVAL_PARENT[id]:
		var filled := line.replace("{child}", c.first_name())
		pool.append(filled.left(1).to_upper() + filled.substr(1))
	return pool


func test_protest_days_bring_protest_lines() -> void:
	var total := 0
	for day in range(1, 8):
		gs.run.effects = {"protest": true, "audit": false, "compassion": false}
		await _open(day)
		var expected := 0
		var got := 0
		for c in desk.claims:
			var line := desk._arrival_line(c)
			var event := _event_pool("protest", c).has(line)
			if c.scripted_id != "" or c.is_player:
				t.ok(not event, "never for %s" % c.name)
				continue
			if posmod(c.line_seed, 3) == 0:
				expected += 1
			if event:
				got += 1
		t.eq(got, expected, "about one random patient in three on day %d" % day)
		total += got
	t.ok(total > 0, "%d protest lines this week" % total)
	gs.run.effects = {"protest": false, "audit": false, "compassion": false}
	await _open(3)
	for c in desk.claims:
		t.eq(EventLines.opening(c, gs.run.effects), "", "no event, no event line")


func test_event_lines_and_posters_read_right() -> void:
	for id: String in EventLines.EVENTS:
		t.ok((EventLines.ARRIVAL[id] as Array).size() >= 3, "%s adult lines" % id)
		t.ok((EventLines.ARRIVAL_PARENT[id] as Array).size() >= 2, "%s parent lines" % id)
		for line: String in EventLines.ARRIVAL_PARENT[id]:
			t.ok(line.contains("{child}"), "parent lines name the child: %s" % line)
		var poster: String = EventLines.POSTERS[id]
		t.ok(poster.length() <= 40, "short poster: %s" % poster)
		t.eq(EventLines.poster({id: true}, 10.0, "We care.*"), poster)
	t.eq(EventLines.poster({}, 85.0, "We care.*"), "We hear you.*", "at high discontent")
	t.eq(EventLines.poster({}, 20.0, "We care.*"), "We care.*", "otherwise the usual slogan")
	for line in EventLines.POSTERS.values() + [EventLines.HIGH_DISCONTENT_POSTER]:
		for i in (line as String).length():
			t.ok((line as String).unicode_at(i) < 128, "ASCII: %s" % line)


func test_event_days_dress_the_booth() -> void:
	gs.run.effects = {"protest": false, "audit": true, "compassion": false}
	await _open(4)
	t.eq(desk._poster_label.text, "Regulators are our partners.", "the audit poster")
	t.ok(desk._booth.effects.get("audit", false), "the auditor stands at the back")
	gs.run.effects = {"protest": false, "audit": false, "compassion": true}
	await _open(5)
	t.eq(desk._poster_label.text, "COMPASSION DAY. Approve visibly.*")
	desk.call_next_patient()
	await desk.stamp(true)
	desk.call_next_patient()
	await desk.stamp(true)
	t.eq(desk._booth.processed, 2, "the balloons sag a row per patient")


# --- citation slips -------------------------------------------------------------------

## A clean claim, ready to break one rule at a time.
func _claim() -> Claim:
	var c := Claim.new()
	c.name = "Ana Lee"
	c.card_name = "Ana Lee"
	c.dob = DateUtil.from_ymd(1980, 5, 2)
	c.card_dob = c.dob
	c.member_id = "BMH-123-4567"
	c.card_member_id = c.member_id
	c.provider = "St. Agnes Medical Center"
	c.date_of_service = DateUtil.from_ymd(2026, 2, 8)
	c.coverage_through = DateUtil.from_ymd(2026, 12, 31)
	c.member_since = DateUtil.from_ymd(2024, 1, 1)
	c.diagnosis = "Asthma flare-up"
	c.diagnosis_id = "asthma_flare"
	c.condition = "asthma"
	c.bill_lines = [Claim.make_line("office_visit")]
	return c


func _explained(c: Claim, rule: String) -> String:
	for v in RuleChecker.violations(c, 6):
		if v["rule"] == rule:
			return CitationText.explain(c, v)
	return "(no %s violation)" % rule


func test_citation_text_names_each_rule_and_the_facts() -> void:
	t.eq(RuleChecker.violations(_claim(), 6).size(), 0, "the base claim is clean")
	var c := _claim()
	c.coverage_through = DateUtil.from_ymd(2026, 1, 30)
	t.eq(_explained(c, "R-01"), "R-01 COVERAGE LAPSED. Coverage through 01/30/2026; service 02/08/2026.")
	c = _claim()
	c.provider = "Harbor Point Medical Center"
	t.eq(_explained(c, "R-02"), "R-02 OUT-OF-NETWORK. Harbor Point Medical Center is not in the Network Directory.")
	c = _claim()
	c.name = "Ana Leee"
	t.eq(_explained(c, "R-03"), "R-03 CLERICAL MISMATCH. Claim: Ana Leee. Card: Ana Lee.")
	c = _claim()
	c.member_id = "BMH-123-4568"
	t.eq(_explained(c, "R-03"), "R-03 CLERICAL MISMATCH. Claim: BMH-123-4568. Card: BMH-123-4567.")
	c = _claim()
	c.dob = DateUtil.from_ymd(1980, 5, 3)
	t.eq(_explained(c, "R-03"), "R-03 CLERICAL MISMATCH. Claim: 05/03/1980. Card: 05/02/1980.")
	c = _claim()
	c.bill_lines.append(Claim.make_line("mri_brain"))
	t.eq(_explained(c, "R-04"), "R-04 NO PRIOR AUTH. MRI, BRAIN needs authorization; PRIOR AUTH # is blank.")
	c = _claim()
	c.history = [{"date": DateUtil.from_ymd(2023, 6, 14), "label": "Asthma", "condition": "asthma"}]
	t.eq(_explained(c, "R-05"), "R-05 PRE-EXISTING. Asthma on record 06/14/2023, before member since 01/01/2024.")
	c = _claim()
	c.bill_lines.append(Claim.make_line("acupuncture"))
	t.eq(_explained(c, "R-06"), "R-06 EXCLUDED SERVICE. ACUPUNCTURE (6 SESSIONS) is on the Exclusions list.")
	t.eq(CitationText.explain(_claim(), {"rule": "R-07", "evidence": PackedStringArray()}), "", "DenyBot never explains")
