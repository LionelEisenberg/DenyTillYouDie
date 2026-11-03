extends RefCounted
## Desk layout with the real font: the rulebook keeps its width, every paper
## lands on the desk, and the font is smoothed only when the canvas is scaled.

var t: TestContext
var gs: Node
var tree: SceneTree
var desk: DeskScreen


func before_each() -> void:
	tree = Engine.get_main_loop() as SceneTree
	gs = tree.root.get_node("GameState")
	gs.save_path_override = TestContext.save_path()
	gs.new_run("Pat Doe", 77)


func after_each() -> void:
	if desk and is_instance_valid(desk):
		desk.queue_free()
	desk = null
	await tree.process_frame
	UiTheme.fit_font_to_window(tree.root)
	gs.delete_save()
	gs.save_path_override = ""


func _open_desk(day: int) -> void:
	if desk and is_instance_valid(desk):
		desk.queue_free()
		await tree.process_frame
	gs.run.day = day
	desk = DeskScreen.new()
	desk.fast = true
	# The real font: layout depends on MatchupPro's metrics.
	desk.theme = UiTheme.build()
	tree.root.add_child(desk)
	await _settle()


func _settle() -> void:
	for i in 3:
		await tree.process_frame


func _rect(c: Control) -> Rect2:
	return Rect2(c.position, c.size)


func test_rulebook_width_is_the_same_on_every_page_on_day_7() -> void:
	await _open_desk(7)
	var book := desk._rulebook
	t.eq(book._pages.size(), 5, "day 7 has five tabs")
	for page: String in book._pages:
		book.show_page(page)
		await _settle()
		t.eq(book.size.x, RulebookView.WIDTH, "%s page width" % page)
		t.ok(book.position.x >= 0.0 and book.position.x + book.size.x <= DeskScreen.DESK_SIZE.x, "%s page fits the desk" % page)
		t.ok(book.position.y + book.size.y <= DeskScreen.DESK_SIZE.y, "%s page fits the desk's height" % page)


func test_rulebook_width_is_the_same_every_day() -> void:
	for day in range(1, 8):
		var book := RulebookView.new()
		book.theme = UiTheme.build()
		book.setup(day)
		tree.root.add_child(book)
		for page: String in book._pages:
			book.show_page(page)
			await _settle()
			t.eq(book.size.x, RulebookView.WIDTH, "day %d %s page width" % [day, page])
		book.queue_free()
	await tree.process_frame


func test_every_paper_lands_on_the_desk_without_overlaps() -> void:
	var checked := 0
	for day in range(1, 8):
		await _open_desk(day)
		var book := _rect(desk._rulebook)
		for i in desk.claims.size():
			desk.call_next_patient()
			await _settle()
			var c := desk.active_claim()
			var rects: Array[Rect2] = []
			for n in desk._docs.size():
				var r := _rect(desk._docs[n])
				var where := "day %d patient %d, paper %d at %s" % [day, i + 1, n, r]
				t.ok(Rect2(Vector2.ZERO, DeskScreen.DESK_SIZE).encloses(r), "on the desk. " + where)
				t.ok(not r.intersects(book), "clear of the rulebook. " + where)
				for other in rects:
					t.ok(not r.intersects(other), "clear of the other papers. " + where)
				rects.append(r)
				checked += 1
			if c.is_player:
				break
			await desk.stamp(true)
	t.ok(checked > 80, "checked %d papers" % checked)


func test_font_is_smoothed_only_at_fractional_scales() -> void:
	UiTheme.fit_font_to_scale(1600.0 / 1920.0)
	t.eq(UiTheme.font().antialiasing, TextServer.FONT_ANTIALIASING_GRAY, "the default 1600x900 window smooths the font")
	UiTheme.fit_font_to_scale(2560.0 / 1920.0)
	t.eq(UiTheme.font().antialiasing, TextServer.FONT_ANTIALIASING_GRAY, "so does 2560x1440")
	UiTheme.fit_font_to_scale(1.0)
	t.eq(UiTheme.font().antialiasing, TextServer.FONT_ANTIALIASING_NONE, "1920x1080 keeps hard pixel edges")
	UiTheme.fit_font_to_scale(2.0)
	t.eq(UiTheme.font().antialiasing, TextServer.FONT_ANTIALIASING_NONE, "so does 3840x2160")
	UiTheme.fit_font_to_window(tree.root)
	t.eq(UiTheme.font().antialiasing, TextServer.FONT_ANTIALIASING_GRAY, "the tiny headless window is a fractional scale")
	var import_text := FileAccess.get_file_as_string("res://assets/fonts/MatchupPro.ttf.import")
	t.ok(import_text.contains("\nantialiasing=1\n"), "the font is imported with gray antialiasing")
