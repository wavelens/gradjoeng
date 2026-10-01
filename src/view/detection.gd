# SPDX-FileCopyrightText: 2026 Wavelens GmbH <info@wavelens.io>
#
# SPDX-License-Identifier: MIT

class_name Detection
## Timeline of the camera's object recognition: a burst of short beats, a fast decode, then a quick release.

const BEATS := {
	"snap": Vector2(0.0, 0.12),
	"settle": Vector2(0.0, 0.2),
	"flash": Vector2(0.0, 0.09),
	"sweep": Vector2(0.08, 0.15),
	"blink": Vector2(0.15, 0.16),
	"rail": Vector2(0.28, 0.14),
	"leader": Vector2(0.36, 0.12),
	"pill": Vector2(0.45, 0.15),
	"kind": Vector2(0.52, 0.1),
	"exit": Vector2(2.95, 0.18),
}
const IDENTIFY := 0.5
const SOLVE := 0.6
const DURATION := 3.15
const FLICKER := 30.0
const SEARCH := 4096
const GLYPHS := "0123456789abcdef#%&@$<>/|=+*"
const PRINT_RATE := 90.0
const FLIP_ODDS := 6
const CRACKLE_ODDS := 4
const CRACKLE := 0.35


static func active(age: float) -> bool:
	return age >= 0.0 and age < DURATION


static func beat(age: float, name: String) -> float:
	var window: Vector2 = BEATS[name]
	return clampf((age - window.x) / window.y, 0.0, 1.0)


static func decoded(text: String, age: float, seed: int) -> String:
	if age < IDENTIFY:
		return ""
	var rng := RandomNumberGenerator.new()
	var slot := int(age * FLICKER)
	var result := ""
	for i in text.length():
		rng.seed = hash([seed, i])
		var lock_at := IDENTIFY + SOLVE * clampf((float(i) + rng.randf_range(-2.0, 2.0)) / maxf(text.length(), 1.0), 0.05, 1.0)
		if age >= lock_at or text[i] == " ":
			result += text[i]
			continue
		rng.seed = hash([seed, i, slot])
		result += GLYPHS[rng.randi() % GLYPHS.length()]
	return result


static func distortion(age: float, seed: int) -> float:
	var entry := pow(1.0 - beat(age, "settle"), 2.0)
	var decoding := solving(age) > 0.0 and solving(age) < 1.0
	var crackle := CRACKLE if decoding and absi(hash([seed, int(age * FLICKER)])) % CRACKLE_ODDS == 0 else 0.0
	return maxf(maxf(entry, crackle), beat(age, "exit"))


static func solving(age: float) -> float:
	return clampf((age - IDENTIFY) / SOLVE, 0.0, 1.0)


static func candidates(age: float) -> int:
	return maxi(1, int(SEARCH * pow(1.0 - solving(age), 3.0)))


static func confidence(age: float) -> float:
	var settle := clampf(age / (IDENTIFY + SOLVE), 0.0, 1.0)
	return minf(12.0 + 87.6 * settle * settle + sin(age * 53.0) * 3.0 * (1.0 - settle), 99.6)


static func stream(seed: int, age: float, length: int, delay: float = 0.0) -> String:
	var shown := clampi(mini(int((age - delay) * PRINT_RATE), int((DURATION - age) * PRINT_RATE)), 0, length)
	var slot := int(age * FLICKER)
	var result := ""
	for i in shown:
		var bit := hash([seed, i]) & 1
		if hash([seed, i, slot]) % FLIP_ODDS == 0:
			bit ^= 1
		result += str(bit)
	return result


static func bits(seed: int, slot: int, length: int) -> String:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([seed, slot])
	var result := ""
	for i in length:
		result += "1" if rng.randi() & 1 else "0"
	return result
