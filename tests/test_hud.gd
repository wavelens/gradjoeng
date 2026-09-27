extends Suite


func test_contact_line_lists_dect_only_when_given() -> void:
	equal(Hud.contact_line("1234"), "Matrix: @derdennisop:matrix.org   Dect: 1234")
	equal(Hud.contact_line(""), "Matrix: @derdennisop:matrix.org")
