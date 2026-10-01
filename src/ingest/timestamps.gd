# SPDX-FileCopyrightText: 2026 Wavelens GmbH <info@wavelens.io>
#
# SPDX-License-Identifier: MIT

class_name Timestamps


static func parse(value: String) -> float:
	var seconds := float(Time.get_unix_time_from_datetime_string(value.substr(0, 19)))
	if value.length() <= 20 or value[19] != ".":
		return seconds
	var digits := ""
	for character in value.substr(20):
		if not character.is_valid_int():
			break
		digits += character
	return seconds + ("0." + digits).to_float()
