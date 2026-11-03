extends RefCounted

var t: TestContext


func test_game_date_day_one() -> void:
	var d := DateUtil.game_date(1)
	t.eq(DateUtil.fmt(d), "03/02/2026")
	t.eq(DateUtil.weekday(d), "Monday")


func test_day_seven_is_sunday() -> void:
	var d := DateUtil.game_date(7)
	t.eq(DateUtil.fmt(d), "03/08/2026")
	t.eq(DateUtil.weekday(d), "Sunday")


func test_from_ymd_round_trips() -> void:
	var d := DateUtil.from_ymd(1961, 7, 14)
	t.eq(DateUtil.fmt(d), "07/14/1961")
	var parts := DateUtil.to_ymd(d)
	t.eq(parts, Vector3i(1961, 7, 14))


func test_month_year_format() -> void:
	t.eq(DateUtil.fmt_month_year(DateUtil.from_ymd(2025, 11, 3)), "11/2025")


func test_day_arithmetic_crosses_months() -> void:
	t.eq(DateUtil.fmt(DateUtil.game_date(1) - 2), "02/28/2026")
