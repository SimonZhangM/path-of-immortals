extends SceneTree

func _initialize() -> void:
	var expected := ["正月","杏月","桃月","槐月","榴月","荷月","兰月","桂月","菊月","良月","冬月","腊月"]
	var failures := 0
	if not WorldCalendar.configuration_error().is_empty(): failures += 1
	var calendar := WorldCalendar.initial()
	for month in range(1,13):
		for day in [1,10,20,30]:
			calendar.elapsed_days = (month-1)*30+day-1
			var before := calendar.duplicate(true)
			var suffix: String = {1:"初一",10:"初十",20:"二十",30:"三十"}[day]
			var parts := WorldCalendar.date_parts(calendar)
			if WorldCalendar.month_day(month,day) != expected[month-1]+suffix or not WorldCalendar.date_text(calendar,true).ends_with(expected[month-1]+suffix) or not WorldCalendar.date_text(calendar).ends_with(expected[month-1]+suffix) or parts.month!=month or parts.day!=day or calendar!=before:
				failures += 1
				push_error("Month name / unchanged numeric date: %d/%d" % [month,day])
	print("CALENDAR MONTH NAMES: 12 months x 4 dates; ",failures," failures; no UI or save mutation")
	quit(1 if failures else 0)
