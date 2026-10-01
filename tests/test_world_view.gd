# SPDX-FileCopyrightText: 2026 Wavelens GmbH <info@wavelens.io>
#
# SPDX-License-Identifier: MIT

extends Suite


func test_planet_seed_is_stable_per_worker_and_in_unit_range() -> void:
	var seeds := ["w1", "w2", "w3"].map(WorldView.planet_seed)
	equal(WorldView.planet_seed("w1"), seeds[0])
	check(seeds.all(func(s: float): return s >= 0.0 and s < 1.0), "unit range")
	check(seeds[0] != seeds[1] and seeds[1] != seeds[2], "distinct worlds")


func test_reconnecting_link_strikes_like_a_halogen_lamp() -> void:
	var samples := range(85).map(func(i): return WorldView.flicker(i / 100.0))
	check(samples.has(0.0), "dark gaps while striking")
	check(samples.any(func(level): return level > 1.0), "bright strikes")
	for progress in [0.85, 0.9, 1.0]:
		equal(WorldView.flicker(progress), 1.0, "steady at %s" % progress)
	equal(WorldView.flicker(0.3), WorldView.flicker(0.3), "same strike pattern every time")
