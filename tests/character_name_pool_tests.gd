extends "res://tests/introduction_page_preview.gd"

const Draft = preload("res://scripts/entry/character_creation_draft.gd")

func run() -> void:
	create_timer(25).timeout.connect(func(): quit(2))
	AudioServer.set_bus_mute(0, true)
	var pool: Array = JSON.parse_string(FileAccess.get_file_as_string("res://data/character_name_pool.json")).names
	var lookup := {}
	var ids := {}
	var counts := {"male": 0, "female": 0}
	var compounds := {"male": 0, "female": 0}
	var valid := true
	for entry: Dictionary in pool:
		var full: String = entry.surname + entry.given_name
		valid = valid and not lookup.has(full) and not ids.has(entry.id)
		valid = valid and full.length() in [2, 3] and entry.gender in counts
		if entry.surname.length() == 2:
			compounds[entry.gender] += 1
			valid = valid and entry.given_name.length() == 1
		counts[entry.gender] += 1
		lookup[full] = entry
		ids[entry.id] = true
	check(valid and pool.size() == 100, "100 distinct valid names and IDs")
	check(counts.male == 50 and counts.female == 50, "50 per gender")
	check(compounds.male == 8 and compounds.female == 8, "eight compound surnames per gender")
	for old in ["张辰宇", "杨笑一", "林知秋", "沈云舟", "江望舒"]:
		check(not lookup.has(old), "old placeholder removed")
	for scope in ["", "male", "female"]:
		var draft := Draft.new(pool)
		draft.gender = scope
		var previous := ""
		for cycle in 3:
			var seen := {}
			var correct := true
			for index in (100 if scope.is_empty() else 50):
				var full := draft.draw_name()
				correct = correct and not seen.has(full) and full != previous
				correct = correct and (scope.is_empty() or lookup[full].gender == scope)
				correct = correct and draft.surname == lookup[full].surname and draft.given_name == lookup[full].given_name
				seen[full] = true
				previous = full
			check(correct, "complete shuffle cycle, correct gender and surname split: " + scope)
	var alternating := Draft.new(pool)
	var seen_male := {}
	var seen_female := {}
	var switched_ok := true
	for index in 50:
		alternating.gender = "male"
		var male := alternating.draw_name()
		switched_ok = switched_ok and lookup[male].gender == "male" and not seen_male.has(male)
		seen_male[male] = true
		alternating.gender = "female"
		var female := alternating.draw_name()
		switched_ok = switched_ok and lookup[female].gender == "female" and not seen_female.has(female)
		seen_female[female] = true
	check(switched_ok, "gender switching preserves each bag")
	var page = PAGE.instantiate()
	root.add_child(page)
	current_scene = page
	await settle()
	page.show_page(3)
	await settle()
	var form = page.identity_form
	await click(form.dice_button)
	await form.roll_finished
	check(page.creation_draft.gender.is_empty() and lookup.has(form.name_input.text), "unselected gender draws mixed pool without assigning gender")
	for index in 2:
		var prior: String = form.name_input.text
		await click(form.gender_buttons[index])
		check(form.name_input.text == prior, "gender choice does not rewrite current name")
		await click(form.dice_button)
		await form.roll_finished
		check(lookup[form.name_input.text].gender == ("male" if index == 0 else "female"), "dice applies selected gender")
		check(page.creation_draft.full_name == form.name_input.text, "result updates input and draft together")
	await click(form.gender_buttons[0])
	await click(form.dice_button)
	await click(form.gender_buttons[1])
	await form.roll_finished
	check(lookup[form.name_input.text].gender == "female", "gender changed during dice uses current selection at completion")
	print("CHARACTER_NAME_POOL_CHECKS=", checks, " FAILURES=", failures)
	quit(1 if failures else 0)
