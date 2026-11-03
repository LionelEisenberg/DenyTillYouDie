class_name DateUtil
## Dates are whole days since 1970-01-01, shown as MM/DD/YYYY.

const SECONDS_PER_DAY := 86400
const DAY_ONE := Vector3i(2026, 3, 2)
const WEEKDAYS: PackedStringArray = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]


static func from_ymd(year: int, month: int, day: int) -> int:
	var unix := Time.get_unix_time_from_datetime_dict({"year": year, "month": month, "day": day, "hour": 0, "minute": 0, "second": 0})
	return unix / SECONDS_PER_DAY


static func to_ymd(days: int) -> Vector3i:
	var d := Time.get_datetime_dict_from_unix_time(days * SECONDS_PER_DAY)
	return Vector3i(d["year"], d["month"], d["day"])


static func fmt(days: int) -> String:
	var v := to_ymd(days)
	return "%02d/%02d/%04d" % [v.y, v.z, v.x]


static func fmt_month_year(days: int) -> String:
	var v := to_ymd(days)
	return "%02d/%04d" % [v.y, v.x]


static func weekday(days: int) -> String:
	var d := Time.get_datetime_dict_from_unix_time(days * SECONDS_PER_DAY)
	return WEEKDAYS[d["weekday"]]


## The calendar date of a campaign day (day 1 is Monday 03/02/2026).
static func game_date(day: int) -> int:
	return from_ymd(DAY_ONE.x, DAY_ONE.y, DAY_ONE.z) + day - 1


## Whole years from `birth` to `on`.
static func age_on(birth: int, on: int) -> int:
	var b := to_ymd(birth)
	var o := to_ymd(on)
	var years := o.x - b.x
	if o.y < b.y or (o.y == b.y and o.z < b.z):
		years -= 1
	return years


## A long, newspaper-style date: "Monday, March 2, 2026".
static func fmt_long(days: int) -> String:
	const MONTHS: PackedStringArray = ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"]
	var v := to_ymd(days)
	return "%s, %s %d, %d" % [weekday(days), MONTHS[v.y - 1], v.z, v.x]
