import os

import pytest

os.environ.setdefault("SDL_VIDEODRIVER", "dummy")

moderngl = pytest.importorskip("moderngl")

from gradjoeng.batch import collect
from gradjoeng.camera import Camera
from gradjoeng.gpu import Frame, Pipeline
from gradjoeng.parser import WorkerMessage
from gradjoeng.scene import Scene

SIZE = (640, 400)


@pytest.fixture(scope="module")
def ctx():
    for options in ({"backend": "egl"}, {}):
        try:
            context = moderngl.create_standalone_context(require=330, **options)
        except Exception:
            continue
        yield context
        context.release()
        return
    pytest.skip("no OpenGL 3.3 context available")


def render(ctx, scene: Scene, camera: Camera) -> bytes:
    pipeline = Pipeline(ctx, SIZE)
    target = ctx.simple_framebuffer(SIZE)
    overlay = bytes(SIZE[0] * SIZE[1] * 4)
    pipeline.render(Frame(camera, scene.time, 1.0, (0.0, 0.0), collect(scene), overlay), target)
    return target.read(components=3)


def pixel(data: bytes, x: int, y: int) -> tuple[int, int, int]:
    offset = ((SIZE[1] - 1 - y) * SIZE[0] + x) * 3
    return tuple(data[offset : offset + 3])


def test_black_hole_casts_a_shadow_and_lights_its_disk(ctx):
    data = render(ctx, Scene(), Camera(yaw=0.0, pitch=0.35))
    assert sum(pixel(data, 320, 200)) < 60
    assert max(data) > 200


def test_workers_render_in_front_of_the_shadow(ctx):
    scene = Scene()
    scene.apply(WorkerMessage("w1", outbound=False, kind="request_job", size=0))
    scene.update(0.01)
    camera = Camera(yaw=0.0, pitch=0.0)
    scene.workers["w1"].pos = (0.0, 0.0, -6.0)
    data = render(ctx, scene, camera)
    assert sum(pixel(data, 320, 200)) > 150
