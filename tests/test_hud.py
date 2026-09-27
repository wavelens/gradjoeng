import os

os.environ.setdefault("SDL_VIDEODRIVER", "dummy")

from gradjoeng.batch import Label
from gradjoeng.camera import Camera
from gradjoeng.hud import Hud, occluded
from gradjoeng.scene import Scene

SIZE = (320, 200)


def test_hud_paints_rgba_overlay():
    hud = Hud(SIZE)
    pixels = hud.paint(Scene(), Camera(), "live", [Label("hello", (1.0, 0.0, 0.0), -10, (255, 255, 255))])
    assert len(pixels) == SIZE[0] * SIZE[1] * 4
    assert any(pixels[3::4])


def test_labels_behind_the_black_hole_are_hidden():
    camera = Camera(yaw=0.0, pitch=0.0)
    assert occluded(camera, (0.0, 0.0, 3.0), SIZE)
    assert not occluded(camera, (0.0, 0.0, -3.0), SIZE)
    assert not occluded(camera, (8.0, 0.0, 3.0), SIZE)
