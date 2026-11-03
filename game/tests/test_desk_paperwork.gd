extends RefCounted
## What the papers on the desk say, and how big they say it.

var t: TestContext


func _claims(day: int, seed_value: int = 41) -> Array[Claim]:
	return ClaimGenerator.new(seed_value, "Pat Doe").generate_day(day)


## Every Label under `node`, depth first.
func _labels(node: Node) -> Array[Label]:
	var found: Array[Label] = []
	if node is Label:
		found.append(node as Label)
	for child in node.get_children():
		found.append_array(_labels(child))
	return found


func _texts(node: Node) -> PackedStringArray:
	var texts: PackedStringArray = []
	for l in _labels(node):
		texts.append(l.text)
	return texts


func _size_of(l: Label) -> int:
	return l.get_theme_font_size("font_size")


func test_medical_history_dates_are_full_dates() -> void:
	var checked := 0
	for day in [5, 6, 7]:
		for c in _claims(day):
			var doc := Paperwork.medical_history(c)
			for i in c.history.size():
				var row := doc.find_row("history.entry.%d" % i)
				var full := DateUtil.fmt(int(c.history[i]["date"]))
				t.ok(_texts(row).has(full), "entry %d shows %s, got %s" % [i, full, _texts(row)])
				checked += 1
			doc.free()
	t.ok(checked > 10, "checked %d history entries" % checked)


func test_bill_lines_are_body_size() -> void:
	var c := _claims(6)[0]
	var doc := Paperwork.itemized_bill(c)
	for i in c.bill_lines.size():
		var row := doc.find_row("bill.line.%d" % i)
		var labels := _labels(row)
		t.eq(labels.size(), 2, "label and amount")
		for l in labels:
			t.eq(_size_of(l), UiTheme.SIZE_BODY, "bill line %d: %s" % [i, l.text])
	t.ok(_texts(doc.find_row("bill.line.0")).has(UiTheme.money(int(c.bill_lines[0]["cost"]))), "amount shown")
	for l in _labels(doc.find_row("bill.total")):
		t.ok(_size_of(l) > UiTheme.SIZE_BODY, "the total still stands out")
	doc.free()


func test_history_entries_are_body_size() -> void:
	var c := _claims(5)[0]
	var doc := Paperwork.medical_history(c)
	t.ok(c.history.size() > 0, "has history")
	for i in c.history.size():
		for l in _labels(doc.find_row("history.entry.%d" % i)):
			t.eq(_size_of(l), UiTheme.SIZE_BODY, "history %d: %s" % [i, l.text])
	doc.free()


func test_early_treatment_line_is_body_size() -> void:
	var c := _claims(1)[0]
	t.ok(not c.shows_bill(), "day 1 has no itemized bill")
	var doc := Paperwork.claim_form(c)
	var row := doc.find_row("claim.treatment")
	t.ok(_texts(row).has(c.treatment_summary()), "the treatment summary is on the form")
	for l in _labels(row):
		if l.text == c.treatment_summary():
			t.eq(_size_of(l), UiTheme.SIZE_BODY, "treatment value")
	doc.free()


func test_citation_slip_counts_down_the_free_warnings() -> void:
	var first := Paperwork.citation_slip(1, 0)
	t.ok(_texts(first).has("Warning 1 of %d. One more before fines start." % Economy.FREE_WARNINGS), "first warning: %s" % _texts(first))
	first.free()
	var last := Paperwork.citation_slip(Economy.FREE_WARNINGS, 0)
	var last_line := "Warning %d of %d. Further citations today will be fined." % [Economy.FREE_WARNINGS, Economy.FREE_WARNINGS]
	t.ok(_texts(last).has(last_line), "last free warning: %s" % _texts(last))
	last.free()
	var fined := Paperwork.citation_slip(Economy.FREE_WARNINGS + 1, Economy.CITATION_FINE)
	t.ok(_texts(fined).has("Fine deducted: %s" % UiTheme.money(Economy.CITATION_FINE)), "fine: %s" % _texts(fined))
	fined.free()
