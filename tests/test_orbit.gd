# SPDX-FileCopyrightText: 2026 Wavelens GmbH <info@wavelens.io>
#
# SPDX-License-Identifier: MIT

extends Suite


func test_orbit_is_a_tilted_circle_in_3d() -> void:
	var orbit := Orbit.new(2.0, 0.5, 0.3, 1.0)
	var points := range(16).map(func(i): return orbit.offset(i * TAU / 16))
	for point in points:
		near(point.length(), 2.0, 1e-4, "radius")
		near(point.dot(orbit.normal), 0.0, 1e-4, "in plane")
	check(points.any(func(p): return absf(p.y) > 0.5), "inclined orbits leave the ground plane")


func test_flat_orbit_stays_in_ground_plane() -> void:
	var orbit := Orbit.new(3.0, 0.0, 0.0, 1.0)
	check(orbit.current().is_equal_approx(Vector3(3, 0, 0)), "starts on node axis")
	orbit.advance(PI / 2)
	check(orbit.current().is_equal_approx(Vector3(0, 0, -3)) or orbit.current().is_equal_approx(Vector3(0, 0, 3)), "quarter turn")


func test_kepler_speed_slows_outer_orbits() -> void:
	check(absf(Orbit.kepler_speed(4.0, 1)) < absf(Orbit.kepler_speed(1.0, 1)), "outer is slower")
	check(Orbit.kepler_speed(1.0, -1) < 0, "direction")


func test_electron_settles_on_orbit() -> void:
	var host := Vector3(1, 0, 1)
	var electron := Electron.new("server", func(): return host, Orbit.new(0.5, 0.0, 0.0, 0.0), host, 0.0)
	electron.update(Electron.HOP_TIME / 2)
	check(not electron.position.is_equal_approx(Vector3(1.5, 0, 1)), "still hopping")
	electron.update(Electron.HOP_TIME)
	check(electron.position.is_equal_approx(Vector3(1.5, 0, 1)), "on orbit")
	check(not electron.trail.is_empty(), "trail")


func test_electron_jump_starts_from_current_position_and_can_hold() -> void:
	var electron := Electron.new("a", func(): return Vector3.ZERO, Orbit.new(0.1, 0.0, 0.0, 0.0), Vector3.ZERO)
	electron.update(0.01)
	var start := electron.position
	electron.jump("b", func(): return Vector3(10, 0, 0), Orbit.new(0.2, 0.0, 0.0, 0.0), 0.5)
	electron.update(0.4)
	check(electron.position.is_equal_approx(start), "holds before hopping")
	electron.update(Electron.HOP_TIME + 0.2)
	check(electron.position.is_equal_approx(Vector3(10.2, 0, 0)), "lands on new orbit")


func test_frame_maps_the_unit_ring_onto_the_orbit() -> void:
	var orbit := Orbit.new(3.0, 0.4, 1.1, 0.5)
	for angle in [0.0, 1.0, 2.5, 4.0]:
		var on_ring: Vector3 = orbit.frame() * Vector3(cos(angle), 0.0, sin(angle))
		check(on_ring.is_equal_approx(orbit.offset(angle)), "angle %s" % angle)
