extends Suite


func test_planet_seed_is_stable_per_worker_and_in_unit_range() -> void:
	var seeds := ["w1", "w2", "w3"].map(WorldView.planet_seed)
	equal(WorldView.planet_seed("w1"), seeds[0])
	check(seeds.all(func(s: float): return s >= 0.0 and s < 1.0), "unit range")
	check(seeds[0] != seeds[1] and seeds[1] != seeds[2], "distinct worlds")
