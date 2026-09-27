import math

import pytest

from gradjoeng.orbit import HOP_TIME, Electron, Orbit


def test_orbit_offset_follows_tilted_ellipse():
    orbit = Orbit(radius=100, aspect=0.5, tilt=math.pi / 2, speed=1.0)
    assert orbit.offset() == pytest.approx((0.0, 100.0))
    orbit.advance(math.pi / 2)
    assert orbit.offset() == pytest.approx((-50.0, 0.0))


def test_orbit_path_is_closed_ellipse():
    orbit = Orbit(radius=80, aspect=0.3, tilt=0.4, speed=2.0)
    path = orbit.path(32)
    assert len(path) == 32
    assert max(math.hypot(x, y) for x, y in path) == pytest.approx(80, rel=1e-3)
    assert min(math.hypot(x, y) for x, y in path) == pytest.approx(24, rel=5e-2)


def test_orbit_rescale():
    orbit = Orbit(radius=100, aspect=0.5, tilt=0.0, speed=1.0)
    orbit.rescale(0.5)
    assert orbit.radius == 50


def test_electron_settles_on_orbit():
    host = (100.0, 100.0)
    electron = Electron("server", lambda: host, Orbit(50, 1.0, 0.0, 0.0), pos=host, hop=0.0)
    electron.update(HOP_TIME / 2)
    assert electron.pos != pytest.approx((150.0, 100.0))
    electron.update(HOP_TIME)
    assert electron.pos == pytest.approx((150.0, 100.0))
    assert electron.trail


def test_electron_jump_starts_from_current_position():
    electron = Electron("server", lambda: (0.0, 0.0), Orbit(10, 1.0, 0.0, 0.0), pos=(10.0, 0.0))
    electron.update(0.01)
    electron.jump("worker:w1", lambda: (200.0, 0.0), Orbit(20, 1.0, 0.0, 0.0))
    assert electron.host == "worker:w1"
    electron.update(0.001)
    assert electron.pos[0] == pytest.approx(10.0, abs=1.0)
    electron.update(HOP_TIME)
    assert electron.pos == pytest.approx((220.0, 0.0))


def test_orbit_near_half_faces_the_viewer():
    orbit = Orbit(radius=100, aspect=0.5, tilt=0.0, speed=1.0, phase=math.pi / 2)
    assert orbit.in_front()
    assert not orbit.in_front(-math.pi / 2)
    near, far = orbit.arc(front=True, points=16), orbit.arc(front=False, points=16)
    assert all(y >= -1e-9 for _, y in near) and all(y <= 1e-9 for _, y in far)


def test_electron_jump_can_hold_before_hopping():
    electron = Electron("a", lambda: (0.0, 0.0), Orbit(10, 1.0, 0.0, 0.0), pos=(0.0, 0.0), hop=1.0)
    electron.jump("b", lambda: (100.0, 0.0), Orbit(10, 1.0, 0.0, 0.0), hold=0.5)
    electron.update(0.4)
    assert electron.pos == (0.0, 0.0)
    electron.update(HOP_TIME + 0.2)
    assert electron.pos == pytest.approx((110.0, 0.0))
