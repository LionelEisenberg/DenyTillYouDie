class_name Fmt
## Text formatting for game rules that write prose: money, name lists, plurals.


## "$1,234" / "-$56".
static func money(amount: int) -> String:
	var digits := str(absi(amount))
	var grouped := ""
	while digits.length() > 3:
		grouped = "," + digits.substr(digits.length() - 3) + grouped
		digits = digits.substr(0, digits.length() - 3)
	return ("-" if amount < 0 else "") + "$" + digits + grouped


## "+$15" / "-$6" for deltas.
static func signed_money(amount: int) -> String:
	return ("+" if amount >= 0 else "") + money(amount)


## "A", "A and B", "A, B and C".
static func join_names(names: PackedStringArray) -> String:
	if names.size() <= 1:
		return "".join(names)
	return ", ".join(names.slice(0, names.size() - 1)) + " and " + names[names.size() - 1]


## "1 appeal" / "2 appeals". `plural_form` defaults to `singular` + "s".
static func plural(n: int, singular: String, plural_form: String = "") -> String:
	var word := singular
	if n != 1:
		word = plural_form if plural_form != "" else singular + "s"
	return "%d %s" % [n, word]
