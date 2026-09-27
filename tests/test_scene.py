import json
import math
from pathlib import Path

from gradjoeng.fx import Comet, Echo, Ripple, Spark
from gradjoeng.parser import BuildChanged, CacheAccess, CacheStored, EvaluationChanged, Headline, JobDispatched, QueueDepth, ServerPulse, WorkerLoad, WorkerMessage, parse
from gradjoeng.scene import CALM_DELAY, CALM_FADE, EVAL_FADE, EVAL_LINGER, EVAL_STALE, Scene

FIXTURE = Path(__file__).parent / "fixtures" / "events.jsonl"


def scene() -> Scene:
    return Scene((1280, 800))


def fx_of(s: Scene, kind) -> list:
    return [f for f in s.fx if isinstance(f, kind)]


def test_worker_message_spawns_worker_and_comet():
    s = scene()
    s.apply(WorkerMessage("w1", outbound=True, kind="assign_job", size=320))
    assert "w1" in s.workers
    assert len(fx_of(s, Comet)) == 1
    assert s.hud.messages == 1


def test_comet_arrival_heats_worker():
    s = scene()
    s.apply(WorkerMessage("w1", outbound=True, kind="assign_job", size=320))
    for _ in range(120):
        s.update(1 / 60)
    assert not fx_of(s, Comet)
    assert s.workers["w1"].heat > 0


def test_workers_are_spread_evenly():
    s = scene()
    for worker in ("a", "b", "c", "d"):
        s.apply(WorkerMessage(worker, outbound=False, kind="request_job", size=0))
    targets = sorted(w.target for w in s.workers.values())
    gaps = {round(b - a, 6) for a, b in zip(targets, targets[1:])}
    assert len(gaps) == 1


def test_evaluation_lifecycle_retires_after_linger():
    s = scene()
    s.apply(EvaluationChanged("e1", "queued", "https://github.com/wavelens/gobgp.nix"))
    assert s.evaluations["e1"].label == "gobgp.nix"
    s.apply(EvaluationChanged("e1", "completed", None))
    assert fx_of(s, Spark) and fx_of(s, Ripple)
    s.update(EVAL_LINGER + EVAL_FADE / 2)
    assert 0 < s.evaluations["e1"].alpha < 1
    s.update(EVAL_FADE)
    assert "e1" not in s.evaluations


def test_evaluation_slots_are_reused():
    s = scene()
    s.apply(EvaluationChanged("e1", "completed", None))
    s.update(EVAL_LINGER + EVAL_FADE + 1)
    s.apply(EvaluationChanged("e2", "queued", None))
    assert s.evaluations["e2"].slot == 0


def test_build_failure_counts_once_and_shakes():
    s = scene()
    s.apply(BuildChanged("b1", "e1", "building"))
    s.apply(BuildChanged("b1", "e1", "failed"))
    s.apply(BuildChanged("b1", "e1", "failed"))
    assert s.hud.failed == 1
    assert s.shake > 0
    assert s.evaluations["e1"].builds["b1"].state == "failed"


def test_build_without_evaluation_uses_known_owner():
    s = scene()
    s.apply(BuildChanged("b1", "e1", "queued"))
    s.apply(BuildChanged("b1", None, "completed"))
    assert s.evaluations["e1"].builds["b1"].state == "completed"
    assert s.hud.completed == 1


def test_evaluation_electron_orbits_server_then_hops_to_worker_and_back():
    s = scene()
    s.apply(EvaluationChanged("e1", "queued", None))
    assert s.evaluations["e1"].electron.host == "server"
    s.apply(JobDispatched("w1", "e1", None))
    assert s.evaluations["e1"].electron.host == "worker:w1"
    s.apply(EvaluationChanged("e1", "building", None))
    assert s.evaluations["e1"].electron.host == "server"


def test_build_electron_hops_to_worker_and_back():
    s = scene()
    s.apply(BuildChanged("b1", "e1", "queued"))
    build = s.evaluations["e1"].builds["b1"]
    assert build.electron.host == "evaluation:e1"
    s.apply(JobDispatched("w1", "e1", "b1"))
    assert build.electron.host == "worker:w1"
    assert s.evaluations["e1"].electron.host == "server"
    s.apply(BuildChanged("b1", "e1", "completed"))
    assert build.electron.host == "evaluation:e1"


def test_worker_orbits_are_shelled():
    s = scene()
    for build in ("b1", "b2"):
        s.apply(BuildChanged(build, "e1", "queued"))
        s.apply(JobDispatched("w1", "e1", build))
    builds = s.evaluations["e1"].builds
    assert builds["b1"].electron.orbit.radius < builds["b2"].electron.orbit.radius


def test_electrons_settle_on_their_host_orbit():
    s = scene()
    s.apply(EvaluationChanged("e1", "queued", None))
    s.apply(JobDispatched("w1", "e1", None))
    s.update(2.0)
    worker, evaluation = s.workers["w1"], s.evaluations["e1"]
    distance = math.dist(worker.pos, evaluation.pos)
    assert distance <= evaluation.electron.orbit.radius + 1


def test_resize_rescales_orbits():
    s = scene()
    s.apply(EvaluationChanged("e1", "queued", None))
    radius = s.evaluations["e1"].electron.orbit.radius
    s.apply(BuildChanged("b1", "e2", "queued"))
    s.apply(JobDispatched("w1", "e2", "b1"))
    worker_radius = s.evaluations["e2"].builds["b1"].electron.orbit.radius
    s.resize((640, 400))
    assert s.evaluations["e1"].electron.orbit.radius == radius / 2
    assert s.evaluations["e2"].builds["b1"].electron.orbit.radius == worker_radius / 2


def test_worker_orbits_are_compact_and_stay_on_screen():
    s = Scene((1280, 800))
    s.apply(EvaluationChanged("e1", "queued", None))
    for i in range(5):
        s.apply(BuildChanged(f"b{i}", "e1", "queued"))
        s.apply(JobDispatched("w1", "e1", f"b{i}"))
    radii = [b.electron.orbit.radius for b in s.evaluations["e1"].builds.values()]
    assert 0.06 * s.unit <= min(radii) and max(radii) <= 0.16 * s.unit
    for step in range(600):
        s.update(1 / 20)
        for build in s.evaluations["e1"].builds.values():
            x, y = build.pos
            assert 0 <= x <= 1280 and 0 <= y <= 800


def test_queue_depth_pulse_and_headline():
    s = scene()
    s.apply(QueueDepth(1, 2, 3))
    s.apply(ServerPulse("graph"))
    s.apply(Headline("hello", "good"))
    assert (s.hud.active, s.hud.pending, s.hud.workers) == (1, 2, 3)
    assert s.core_flash > 0
    assert s.headlines[0].text == "hello"


def test_fx_expire():
    s = scene()
    s.apply(ServerPulse("cache"))
    for _ in range(600):
        s.update(1 / 60)
    assert not s.fx


def test_full_replay_is_stable():
    s = scene()
    for line in FIXTURE.read_text().splitlines():
        for effect in parse(json.loads(line)):
            s.apply(effect)
        s.update(1 / 60)
    assert s.workers
    assert s.hud.completed >= 1


def test_stale_evaluation_retires():
    s = scene()
    s.apply(BuildChanged("b1", "e1", "created"))
    s.update(EVAL_STALE / 2)
    s.apply(BuildChanged("b1", "e1", "building"))
    s.update(EVAL_STALE / 2 + EVAL_FADE / 2)
    assert "e1" in s.evaluations
    s.update(EVAL_STALE)
    assert "e1" not in s.evaluations


def test_evaluations_stay_on_screen():
    s = Scene((1280, 800))
    for i in range(12):
        s.apply(EvaluationChanged(f"e{i}", "queued", None))
    s.update(1.0)
    for evaluation in s.evaluations.values():
        x, y = evaluation.pos
        assert 60 <= x <= 1220 and 60 <= y <= 740


def test_evaluation_build_orbits_hug_evaluation_and_rescale():
    s = scene()
    s.apply(BuildChanged("b1", "e1", "completed"))
    orbit = s.evaluations["e1"].builds["b1"].electron.orbit
    assert 0.035 * s.unit <= orbit.radius < 0.05 * s.unit
    radius = orbit.radius
    s.resize((640, 400))
    assert orbit.radius == radius / 2


def test_cache_access_tracks_hits_misses_and_bytes():
    s = scene()
    s.apply(CacheAccess("c1", "narinfo", True, 0))
    s.apply(CacheAccess("c1", "narinfo", False, 0))
    s.apply(CacheAccess("c1", "nar", True, 2048))
    cache = s.caches["c1"]
    assert (cache.hits, cache.misses, cache.served) == (1, 1, 2048)
    assert len(fx_of(s, Comet)) == 3


def test_caches_sit_on_screen_apart_from_each_other():
    s = scene()
    for cache in ("c1", "c2", "c3"):
        s.apply(CacheAccess(cache, "narinfo", True, 0))
    positions = [c.pos for c in s.caches.values()]
    assert len({x for x, _ in positions}) == 3
    assert all(0 <= x <= s.width and 0 <= y <= s.height for x, y in positions)


def test_stored_nar_flies_from_server_into_every_cache():
    s = scene()
    s.apply(CacheStored())
    assert fx_of(s, Comet) == []
    s.apply(CacheAccess("c1", "narinfo", True, 0))
    s.apply(CacheAccess("c2", "narinfo", True, 0))
    before = len(fx_of(s, Comet))
    s.apply(CacheStored())
    assert len(fx_of(s, Comet)) == before + 2


def test_evaluation_on_far_side_of_server_orbit_is_behind():
    s = scene()
    s.apply(EvaluationChanged("e1", "queued", None))
    evaluation = s.evaluations["e1"]
    s.update(2.0)
    evaluation.electron.orbit.phase = -math.pi / 2
    assert evaluation.behind
    evaluation.electron.orbit.phase = math.pi / 2
    assert not evaluation.behind
    s.apply(JobDispatched("w1", "e1", None))
    evaluation.electron.orbit.phase = -math.pi / 2
    assert not evaluation.behind


def test_messages_of_the_same_job_stream_share_a_route():
    s = scene()
    for _ in range(3):
        s.apply(WorkerMessage("w1", outbound=False, kind="log_chunk", size=10, job_id="eval:e1"))
    s.apply(WorkerMessage("w1", outbound=False, kind="nar_push", size=10, job_id="eval:e1"))
    s.apply(WorkerMessage("w1", outbound=False, kind="nar_push", size=10, job_id="eval:e1"))
    logs, nars = fx_of(s, Comet)[:3], fx_of(s, Comet)[3:]
    assert len({(c.bend, c.duration) for c in logs}) == 1
    assert len({(c.bend, c.duration) for c in nars}) == 1
    assert logs[0].bend != nars[0].bend


def returned_echo(score: float) -> Echo:
    s = scene()
    s.apply(EvaluationChanged("e1", "queued", None))
    s.apply(JobDispatched("w1", "e1", None, score))
    (ping,) = fx_of(s, Echo)
    assert ping.target() == s.workers["w1"].pos
    s.update(ping.duration + 0.01)
    (echo,) = fx_of(s, Echo)
    assert echo.target() == s.evaluations["e1"].pos
    return echo


def test_dispatch_score_echoes_back_from_the_worker():
    good, bad = returned_echo(3000.0), returned_echo(20.0)
    assert good.strength > 0.8 > 0.2 > bad.strength
    assert good.color[1] > good.color[0] and bad.color[0] > bad.color[1]


def orbit_path(orbit) -> tuple:
    return orbit.radius, orbit.aspect, orbit.tilt, orbit.speed


def test_evaluations_of_same_group_share_orbit_path_in_formation():
    s = scene()
    s.apply(EvaluationChanged("e1", "queued", None, group="p1"))
    s.apply(EvaluationChanged("e2", "queued", None, group="p2"))
    s.apply(EvaluationChanged("e3", "queued", None, group="p1"))
    e1, e2, e3 = (s.evaluations[i].electron.orbit for i in ("e1", "e2", "e3"))
    assert orbit_path(e1) == orbit_path(e3)
    assert orbit_path(e1) != orbit_path(e2)
    assert e1.phase != e3.phase


def test_late_group_moves_evaluation_onto_group_orbit():
    s = scene()
    s.apply(EvaluationChanged("e1", "queued", None, group="p1"))
    s.apply(BuildChanged("b1", "e2", "queued"))
    s.apply(EvaluationChanged("e2", None, None, group="p1"))
    assert s.evaluations["e2"].slot == s.evaluations["e1"].slot
    assert orbit_path(s.evaluations["e2"].electron.orbit) == orbit_path(s.evaluations["e1"].electron.orbit)


def test_evaluation_returning_home_rejoins_group_orbit():
    s = scene()
    s.apply(EvaluationChanged("e1", "queued", None, group="p1"))
    s.apply(EvaluationChanged("e2", "queued", None, group="p1"))
    s.apply(JobDispatched("w1", "e2", None))
    s.apply(EvaluationChanged("e2", "building", None, group="p1"))
    assert orbit_path(s.evaluations["e2"].electron.orbit) == orbit_path(s.evaluations["e1"].electron.orbit)


def test_created_builds_are_hidden_until_they_progress():
    s = scene()
    s.apply(BuildChanged("b1", "e1", "created"))
    s.apply(BuildChanged("b2", "e1", "queued"))
    assert [build.id for build in s.evaluations["e1"].visible_builds] == ["b2"]


def test_substituted_build_arrives_on_comet_from_cache():
    s = scene()
    s.apply(CacheAccess("c1", "narinfo", True, 0))
    s.fx.clear()
    s.apply(BuildChanged("b1", "e1", "substituted"))
    build = s.evaluations["e1"].builds["b1"]
    comets = fx_of(s, Comet)
    assert len(comets) == 1 and comets[0].source() == s.caches["c1"].pos
    assert not build.visible and not fx_of(s, Spark)
    s.update(comets[0].duration + 0.01)
    assert build.visible and fx_of(s, Spark)


def test_substituted_build_without_cache_falls_from_above():
    s = scene()
    s.apply(BuildChanged("b1", "e1", "substituted"))
    assert fx_of(s, Comet)[0].source()[1] < 0


def test_banner_fades_in_when_workers_idle_and_hides_when_busy():
    s = scene()
    assert s.banner == 0
    s.update(CALM_DELAY + CALM_FADE)
    assert s.banner == 1
    s.apply(EvaluationChanged("e1", "queued", None))
    s.apply(JobDispatched("w1", "e1", None))
    s.update(0.1)
    assert s.banner == 0


def test_worker_load_sets_cpu_and_overload_throws_sparks():
    s = scene()
    s.apply(WorkerLoad("w1", 40.0))
    worker = s.workers["w1"]
    assert worker.cpu == 40.0 and not worker.unstable
    s.apply(WorkerLoad("w1", 95.0))
    assert worker.unstable
    for _ in range(60):
        s.update(1 / 20)
    assert fx_of(s, Spark)
