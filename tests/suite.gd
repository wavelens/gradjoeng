# SPDX-FileCopyrightText: 2026 Wavelens GmbH <info@wavelens.io>
#
# SPDX-License-Identifier: MIT

class_name Suite
extends RefCounted

var failures: PackedStringArray = []


func check(condition: bool, message: String = "condition is false") -> void:
	if not condition:
		failures.append(message)


func equal(actual: Variant, expected: Variant, message: String = "") -> void:
	if typeof(actual) != typeof(expected) or actual != expected:
		failures.append("%s expected %s, got %s" % [message, var_to_str(expected), var_to_str(actual)])


func near(actual: float, expected: float, tolerance: float = 1e-4, message: String = "") -> void:
	if absf(actual - expected) > tolerance:
		failures.append("%s expected %s +- %s, got %s" % [message, expected, tolerance, actual])
