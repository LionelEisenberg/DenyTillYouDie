class_name ClaimConsequence

enum ConsequenceType {
	GET_MONEY,
	GET_GOODWILL,
	SPEND_GOODWILL,
	START_EVENT
}

var type: ConsequenceType
var value: Variant

func _init(_type: ConsequenceType, _value: Variant):
	type = _type
	value = _value

func _to_string() -> String:
	return "THE CONSEQUENCE " + str(type) + " OF VALUE " + str(value)
