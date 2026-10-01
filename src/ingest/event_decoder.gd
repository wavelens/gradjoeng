# SPDX-FileCopyrightText: 2026 Wavelens GmbH <info@wavelens.io>
#
# SPDX-License-Identifier: MIT

class_name EventDecoder


static func decode(raw: String) -> Variant:
	var json := JSON.new()
	if json.parse(raw) != OK or not json.data is Dictionary:
		return null
	return json.data
