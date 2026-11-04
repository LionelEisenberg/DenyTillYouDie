extends RefCounted
## Claim's own helpers: the treatment line on the claim form and the summary the
## night reads.

var t: TestContext


func test_treatment_summary_keeps_authored_labels() -> void:
	var c := Claim.new()
	c.bill_lines = [Claim.make_line("ct_head"), Claim.make_line("mri_knee")]
	t.eq(c.treatment_summary(), "CT SCAN, HEAD / MRI, KNEE")
	c.bill_lines = [Claim.make_line("er_visit"), Claim.make_line("stroke_tpa")]
	t.eq(c.treatment_summary(), "EMERGENCY ROOM VISIT / CLOT-BUSTING DRUG (tPA)")


func test_summary_says_whether_the_diagnosis_can_kill() -> void:
	var c := Claim.new()
	t.eq(c.summary()["fatal"], true, "no diagnosis id: assume it can")
	for id: String in ["acl_tear", "kidney_stone", "depression"]:
		c.diagnosis_id = id
		t.eq(c.summary()["fatal"], false, id)
	for id: String in ["heart_attack", "sepsis", "wrist_fx", "hypertensive_crisis"]:
		c.diagnosis_id = id
		t.eq(c.summary()["fatal"], true, id)
	c.diagnosis_id = "no_such_diagnosis"
	t.eq(c.summary()["fatal"], true, "unknown id: assume it can")
