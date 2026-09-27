from gradjoeng.batch import ARCS, CORE, LINE_FLOATS, SPRITE_FLOATS, Batch, collect
from gradjoeng.parser import BuildChanged, EvaluationChanged, JobDispatched, WorkerMessage
from gradjoeng.scene import Scene


def busy_scene() -> Scene:
    scene = Scene()
    scene.apply(WorkerMessage("w1", outbound=True, kind="assign_job", size=300))
    scene.apply(EvaluationChanged("e1", "queued", "https://example.org/repo.git"))
    scene.apply(BuildChanged("b1", "e1", "queued"))
    scene.apply(JobDispatched("w1", "e1", "b1"))
    scene.apply(BuildChanged("b2", "e1", "failed"))
    for _ in range(10):
        scene.update(1 / 30)
    return scene


def test_batch_packs_sprites_and_lines():
    batch = Batch()
    batch.sprite((1.0, 2.0, 3.0), 0.5, (255, 0, 0), 2.0, CORE, 0.25)
    batch.polyline([(0.0, 0.0, 0.0), (1.0, 0.0, 0.0), (1.0, 1.0, 0.0)], (0, 255, 0), 1.0, closed=True)
    assert list(batch.sprites) == [1.0, 2.0, 3.0, 0.5, 2.0, 0.0, 0.0, CORE, 0.25]
    assert batch.sprite_count == 1
    assert batch.line_vertices == 6
    assert len(batch.lines) == 6 * LINE_FLOATS


def test_collect_draws_every_body():
    batch = collect(busy_scene())
    assert batch.sprite_count > 20
    assert {ARCS, CORE} <= set(batch.sprites[7::SPRITE_FLOATS])
    assert batch.line_vertices > 64 * 2
    assert {"repo", "queued", "worker w1"} <= {label.text for label in batch.labels}
