extends RefCounted

var t: TestContext


func test_money_groups_thousands() -> void:
	t.eq(Fmt.money(0), "$0")
	t.eq(Fmt.money(7), "$7")
	t.eq(Fmt.money(999), "$999")
	t.eq(Fmt.money(1000), "$1,000")
	t.eq(Fmt.money(1234), "$1,234")
	t.eq(Fmt.money(67900), "$67,900")
	t.eq(Fmt.money(1234567), "$1,234,567")


func test_money_puts_the_sign_before_the_dollar() -> void:
	t.eq(Fmt.money(-56), "-$56")
	t.eq(Fmt.money(-43), "-$43", "never $-43")
	t.eq(Fmt.money(-1234), "-$1,234")


func test_signed_money() -> void:
	t.eq(Fmt.signed_money(15), "+$15")
	t.eq(Fmt.signed_money(-6), "-$6")
	t.eq(Fmt.signed_money(0), "+$0")
	t.eq(Fmt.signed_money(2500), "+$2,500")


func test_join_names() -> void:
	t.eq(Fmt.join_names(PackedStringArray()), "")
	t.eq(Fmt.join_names(PackedStringArray(["Sam"])), "Sam")
	t.eq(Fmt.join_names(PackedStringArray(["Sam", "Riley"])), "Sam and Riley")
	t.eq(Fmt.join_names(PackedStringArray(["Sam", "Riley", "Mom"])), "Sam, Riley and Mom")
	t.eq(Fmt.join_names(PackedStringArray(["A", "B", "C", "D"])), "A, B, C and D")


func test_plural() -> void:
	t.eq(Fmt.plural(1, "appeal"), "1 appeal")
	t.eq(Fmt.plural(2, "appeal"), "2 appeals")
	t.eq(Fmt.plural(0, "appeal"), "0 appeals")
	t.eq(Fmt.plural(1, "family", "families"), "1 family")
	t.eq(Fmt.plural(3, "family", "families"), "3 families")
