extends Suite


func test_satellite_faces_the_sun_with_panels_and_dish() -> void:
	var satellite := Satellite.new()
	satellite.place(Vector3(0, 17, -14), 0.0, 0.0, 0.0)
	var toward_sun := -Vector3(0, 17, -14).normalized()
	check((-satellite.basis.z).normalized().is_equal_approx(toward_sun), "dish and panels face the sun")
	check(satellite.get_children().filter(func(part): return part.name.begins_with("Panel")).size() == 2, "two solar wings")
	satellite.free()


func test_beacon_blinks_white_flashes_on_hits_and_strobes_red_on_misses() -> void:
	var idle_on := Satellite.beacon(0.05, 0.0, 0.0)
	check(idle_on.v > 0.5 and absf(idle_on.r - idle_on.b) < 0.2, "white navigation blink")
	check(Satellite.beacon(0.6, 0.0, 0.0).v < 0.2, "mostly dark between blinks")
	check(Satellite.beacon(0.6, 1.0, 0.0).v > 0.5, "a hit lights it up")
	var alarm := Satellite.beacon(0.01, 0.0, 1.0)
	check(alarm.r > 0.8 and alarm.g < 0.4, "a miss strobes red: %s" % alarm)
