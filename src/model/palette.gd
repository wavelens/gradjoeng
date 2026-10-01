# SPDX-FileCopyrightText: 2026 Wavelens GmbH <info@wavelens.io>
#
# SPDX-License-Identifier: MIT

class_name Palette

const STATES := {
	"created": Color("5a6482"),
	"queued": Color("7882b4"),
	"waiting": Color("7882b4"),
	"evaluating": Color("ffc846"),
	"fetching": Color("ffa03c"),
	"building": Color("3c96ff"),
	"retrying": Color("ff8228"),
	"completed": Color("32f078"),
	"substituted": Color("3ce1eb"),
	"failed": Color("ff3250"),
	"dependency_failed": Color("dc328c"),
	"timeout": Color("ff5a1e"),
	"aborted": Color("8c8c96"),
}
const MESSAGES := [
	["log", Color("46ff8c")],
	["cache", Color("5096ff")],
	["known", Color("5096ff")],
	["nar", Color("eb50ff")],
	["job", Color("ffaa32")],
	["credential", Color("ffeb50")],
	["metrics", Color("9696d2")],
]
const TONES := {"good": Color("3cf082"), "bad": Color("ff465a"), "info": Color("aab4dc")}
const CPU_GRADIENT := [Color("32f078"), Color("3c96ff"), Color("ff3250")]

const WORKER := Color("3cdcff")
const CACHE := Color("5a82ff")
const CACHE_HIT := Color("5096ff")
const CACHE_MISS := Color("ff5a6e")
const NAR := Color("eb50ff")
const STORE := Color("aa5aff")
const PING := Color("c8e1ff")
const ECHO_GOOD := Color("3cf082")
const ECHO_BAD := Color("ff465a")
const PROGRESS := Color("ffdc78")
const LINK := Color("161e37")
const ATMOSPHERE := Color("4d8cff")
const LINK_PACKET := Color("78c8ff")


static func state(name: String) -> Color:
	return STATES.get(name, Color("c8c8d2"))


static func message(kind: String) -> Color:
	for entry in MESSAGES:
		if kind.contains(entry[0]):
			return entry[1]
	return Color("dcdcff")


static func tone(name: String) -> Color:
	return TONES.get(name, TONES["info"])


static func cpu(percent: float) -> Color:
	var position := clampf(percent, 0.0, 100.0) / 100.0 * (CPU_GRADIENT.size() - 1)
	var index := mini(int(position), CPU_GRADIENT.size() - 2)
	return CPU_GRADIENT[index].lerp(CPU_GRADIENT[index + 1], position - index)


static func shade(color: Color, factor: float) -> Color:
	return Color(color.r * factor, color.g * factor, color.b * factor, color.a)
