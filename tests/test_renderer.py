import json
import os
from pathlib import Path

os.environ.setdefault("SDL_VIDEODRIVER", "dummy")
os.environ.setdefault("SDL_AUDIODRIVER", "dummy")

import pygame

from gradjoeng.parser import parse
from gradjoeng.renderer import TITLE, Renderer
from gradjoeng.scene import Scene

FIXTURE = Path(__file__).parent / "fixtures" / "events.jsonl"


def test_renders_replayed_scene():
    renderer = Renderer((640, 400))
    scene = Scene((640, 400))
    for line in FIXTURE.read_text().splitlines():
        for effect in parse(json.loads(line)):
            scene.apply(effect)
        scene.update(1 / 60)
        renderer.draw(scene)

    assert pygame.display.get_caption()[0] == TITLE
    assert pygame.transform.average_color(renderer.screen)[:3] != (0, 0, 0)
    pygame.quit()


def test_resize_adopts_window_size():
    renderer = Renderer((640, 400))
    scene = Scene((640, 400))
    pygame.display.set_mode((320, 200), pygame.RESIZABLE)
    scene.resize(renderer.resize())
    assert (scene.width, scene.height) == (320, 200)
    renderer.draw(scene)
    assert renderer.canvas.get_size() == (320, 200)
    pygame.quit()
