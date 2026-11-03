class_name TestContext
extends RefCounted
## Assertion helper handed to every test object as `t`.

var current: String = ""
var failures: PackedStringArray = []
var checks: int = 0


func ok(condition: bool, msg: String = "") -> void:
	checks += 1
	if not condition:
		_fail("expected true. %s" % msg)


func eq(actual: Variant, expected: Variant, msg: String = "") -> void:
	checks += 1
	var both_numbers := _is_number(actual) and _is_number(expected)
	if both_numbers:
		if not is_equal_approx(float(actual), float(expected)):
			_fail("expected %s, got %s. %s" % [expected, actual, msg])
	elif typeof(actual) != typeof(expected) or actual != expected:
		_fail("expected %s (%s), got %s (%s). %s" % [expected, type_string(typeof(expected)), actual, type_string(typeof(actual)), msg])


func near(actual: float, expected: float, epsilon: float, msg: String = "") -> void:
	checks += 1
	if absf(actual - expected) > epsilon:
		_fail("expected %s ± %s, got %s. %s" % [expected, epsilon, actual, msg])


func _is_number(v: Variant) -> bool:
	return typeof(v) == TYPE_INT or typeof(v) == TYPE_FLOAT


func _fail(text: String) -> void:
	failures.append("%s: %s" % [current, text])
