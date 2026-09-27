import math
import random
from collections import deque
from dataclasses import dataclass, field
from typing import Iterator

from .fx import PULSE_COLORS, Anchor, Color, Comet, Echo, Ripple, Vec, burst, cpu_color, message_color, state_color
from .orbit import Electron, Orbit, kepler_speed
from .parser import BAD, GOOD, BuildChanged, CacheAccess, CacheStored, Effect, EvaluationChanged, Headline, JobDispatched, QueueDepth, ServerPulse, WorkerLoad, WorkerMessage

WORKER_SPIN = 0.07
EVAL_LINGER = 10.0
EVAL_FADE = 3.0
EVAL_STALE = 90.0
MAX_FX = 2500
UNASSIGNED = "unassigned"
SERVER = "server"
TERMINAL_PHASES = {"completed", "failed", "aborted"}
WORKER_PHASES = {"fetching", "evaluating"}
GOLDEN_ANGLE = math.pi * (3 - math.sqrt(5))
CACHE_HIT_COLOR = (80, 150, 255)
CACHE_MISS_COLOR = (255, 90, 110)
NAR_COLOR = (235, 80, 255)
STORE_COLOR = (170, 90, 255)
PING_COLOR = (200, 225, 255)
ECHO_GOOD = (60, 240, 130)
ECHO_BAD = (255, 70, 90)
ECHO_TIME = 0.45
SCORE_HALF = 600.0
FORMATION_GAP = 0.45
CALM_DELAY = 10.0
CALM_FADE = 1.5
UNSTABLE_CPU = 90.0
UNSTABLE_SPARK_RATE = 4.0


@dataclass
class Worker:
    id: str
    target: float
    angle: float
    heat: float = 1.0
    pos: Vec = (0.0, 0.0)
    cpu: float | None = None

    @property
    def unstable(self) -> bool:
        return self.cpu is not None and self.cpu >= UNSTABLE_CPU


@dataclass
class Cache:
    id: str
    pos: Vec = (0.0, 0.0)
    flash: float = 1.0
    hits: int = 0
    misses: int = 0
    served: int = 0


@dataclass
class Build:
    id: str
    state: str
    index: int
    electron: Electron
    flash: float = 1.0
    incoming: bool = False

    @property
    def pos(self) -> Vec:
        return self.electron.pos

    @property
    def visible(self) -> bool:
        return self.state != "created" and not self.incoming


@dataclass
class Evaluation:
    id: str
    phase: str
    label: str
    slot: int
    group: str
    electron: Electron
    builds: dict[str, Build] = field(default_factory=dict)
    flash: float = 1.0
    idle: float = 0.0
    alpha: float = 1.0

    @property
    def pos(self) -> Vec:
        return self.electron.pos

    @property
    def visible_builds(self) -> list[Build]:
        return [build for build in self.builds.values() if build.visible]

    @property
    def behind(self) -> bool:
        electron = self.electron
        return electron.host == SERVER and electron.hop >= 1 and not electron.orbit.in_front()

    @property
    def finished(self) -> bool:
        return self.phase in TERMINAL_PHASES

    @property
    def linger(self) -> float:
        return EVAL_LINGER if self.finished else EVAL_STALE


@dataclass
class Hud:
    active: int = 0
    pending: int = 0
    workers: int = 0
    completed: int = 0
    failed: int = 0
    messages: int = 0


@dataclass
class Line:
    text: str
    tone: str
    born: float


class Scene:
    def __init__(self, size: tuple[int, int]):
        self.time = 0.0
        self.workers: dict[str, Worker] = {}
        self.evaluations: dict[str, Evaluation] = {}
        self.caches: dict[str, Cache] = {}
        self.build_owner: dict[str, str] = {}
        self.fx: list = []
        self.headlines: deque[Line] = deque(maxlen=9)
        self.hud = Hud()
        self.shake = 0.0
        self.core_flash = 0.0
        self.calm = 0.0
        self.unit = min(size)
        self.resize(size)

    def resize(self, size: tuple[int, int]) -> None:
        factor = min(size) / self.unit
        self.width, self.height = size
        self.center: Vec = (self.width / 2, self.height / 2)
        self.unit = min(size)
        for electron in self._electrons():
            electron.orbit.rescale(factor)
        self._place_caches()

    def server_pos(self) -> Vec:
        return self.center

    @property
    def banner(self) -> float:
        return min(max((self.calm - CALM_DELAY) / CALM_FADE, 0.0), 1.0)

    def apply(self, effect: Effect) -> None:
        match effect:
            case WorkerMessage():
                self._message(effect)
            case EvaluationChanged():
                self._evaluation_changed(effect)
            case BuildChanged():
                self._build_changed(effect)
            case WorkerLoad(worker_id, cpu):
                self._worker(worker_id).cpu = cpu
            case JobDispatched():
                self._dispatch(effect)
            case QueueDepth(active, pending, workers):
                self.hud.active, self.hud.pending, self.hud.workers = active, pending, workers
            case ServerPulse(kind):
                self._pulse(kind)
            case CacheAccess():
                self._cache_access(effect)
            case CacheStored():
                self._cache_stored()
            case Headline(text, tone):
                self.headlines.appendleft(Line(text, tone, self.time))

    def update(self, dt: float) -> None:
        self.time += dt
        self.shake *= 0.02 ** dt
        self.core_flash *= 0.08 ** dt
        self.calm = 0.0 if self._workers_busy() else self.calm + dt
        self._update_workers(dt)
        self._update_evaluations(dt)
        for cache in self.caches.values():
            cache.flash *= 0.1 ** dt
        current, self.fx = self.fx, []
        self.fx = [f for f in current if f.update(dt)] + self.fx

    def _spawn(self, *effects) -> None:
        self.fx.extend(effects)

    def _message(self, message: WorkerMessage) -> None:
        self.hud.messages += 1
        worker = self._worker(message.worker_id)
        if len(self.fx) > MAX_FX:
            return
        worker_anchor = lambda: worker.pos
        source, target = (self.server_pos, worker_anchor) if message.outbound else (worker_anchor, self.server_pos)

        def arrive() -> None:
            if message.outbound:
                worker.heat = 1.0
            else:
                self.core_flash = max(self.core_flash, 0.35)

        size = 1.5 + math.log10(message.size + 1) * 0.9
        route = random.Random(f"{message.worker_id}:{message.job_id}:{message.kind}") if message.job_id else random
        self._spawn(Comet(source, target, message_color(message.kind), size, route.uniform(0.55, 0.9), route.uniform(-0.3, 0.3), arrive))

    def _evaluation_changed(self, change: EvaluationChanged) -> None:
        evaluation = self._evaluation(change.evaluation_id)
        evaluation.flash = 1.0
        evaluation.idle = 0.0
        if change.group:
            self._join(evaluation, change.group)
        if change.repository:
            evaluation.label = change.repository.rstrip("/").rsplit("/", 1)[-1].removesuffix(".git")
        if change.phase is None:
            self._spawn(Comet(self.server_pos, lambda: evaluation.pos, (255, 220, 120), 2.0, 0.7, 0.2))
            return
        if change.phase == evaluation.phase:
            return
        evaluation.phase = change.phase
        if change.phase not in WORKER_PHASES:
            self._send_home(evaluation)
        color = state_color(change.phase)
        anchor = lambda: evaluation.pos
        self._spawn(Ripple(anchor, color, 70, 1.0))
        if change.phase == "completed":
            self._spawn(*burst(evaluation.pos, color, 90, 380, 1.6), Ripple(anchor, (255, 255, 255), 160, 1.4, 3))
        elif change.phase in BAD:
            self.shake = max(self.shake, 1.0)
            self._spawn(*burst(evaluation.pos, color, 120, 460, 1.8), Ripple(anchor, color, 220, 1.2, 4))

    def _build_changed(self, change: BuildChanged) -> None:
        owner = change.evaluation_id or self.build_owner.get(change.build_id, UNASSIGNED)
        evaluation = self._evaluation(owner)
        build = self._build(evaluation, change.build_id)
        if build.state == change.state:
            return
        build.state = change.state
        if change.state != "building":
            self._send_build_home(evaluation, build)
        build.flash = 1.0
        evaluation.idle = 0.0
        evaluation.flash = max(evaluation.flash, 0.5)
        color = state_color(change.state)
        if change.state == "substituted":
            self.hud.completed += 1
            self._substitute(build, color)
        elif change.state in GOOD:
            self.hud.completed += 1
            self._spawn(*burst(build.pos, color, 18, 180, 0.9))
        elif change.state in BAD:
            self.hud.failed += 1
            self.shake = max(self.shake, 0.5)
            self._spawn(*burst(build.pos, color, 45, 300, 1.3), Ripple(lambda: build.pos, color, 60, 0.8))

    def _substitute(self, build: Build, color: Color) -> None:
        build.incoming = True

        def arrive() -> None:
            build.incoming = False
            build.flash = 1.0
            self._spawn(*burst(build.pos, color, 18, 180, 0.9))

        source = self._substitution_source(build)
        self._spawn(Comet(source, lambda: build.pos, color, 2.5, random.uniform(0.7, 1.0), random.uniform(-0.3, 0.3), arrive))

    def _substitution_source(self, build: Build) -> Anchor:
        if self.caches:
            cache = random.choice(list(self.caches.values()))
            return lambda: cache.pos
        x = build.pos[0] + random.uniform(-0.2, 0.2) * self.unit
        return lambda: (x, -30.0)

    def _dispatch(self, dispatch: JobDispatched) -> None:
        worker = self._worker(dispatch.worker_id)
        worker.heat = 1.0
        self._spawn(Ripple(lambda: worker.pos, (255, 190, 80), 50, 0.7))
        owner = dispatch.evaluation_id or self.build_owner.get(dispatch.build_id or "")
        if owner is None:
            return
        evaluation = self._evaluation(owner)
        job = self._build(evaluation, dispatch.build_id) if dispatch.build_id else evaluation
        self._echo(lambda: job.pos, lambda: worker.pos, dispatch.score)
        job.electron.jump(worker_host(worker.id), lambda: worker.pos, self._worker_orbit(worker.id), hold=2 * ECHO_TIME)

    def _echo(self, job: Anchor, worker: Anchor, score: float) -> None:
        quality = max(score, 0.0) / (max(score, 0.0) + SCORE_HALF)
        color = tuple(int(bad + (good - bad) * quality) for good, bad in zip(ECHO_GOOD, ECHO_BAD))
        echo = Echo(worker, job, color, 0.1 + 0.9 * quality, ECHO_TIME)
        self._spawn(Echo(job, worker, PING_COLOR, 1.0, ECHO_TIME, lambda: self._spawn(echo)))

    def _send_home(self, evaluation: Evaluation) -> None:
        if evaluation.electron.host != SERVER:
            evaluation.electron.jump(SERVER, self.server_pos, self._server_orbit(evaluation.slot, evaluation.group))

    def _join(self, evaluation: Evaluation, group: str) -> None:
        if evaluation.group == group:
            return
        slot = self._lane(group)
        if evaluation.electron.host == SERVER:
            evaluation.electron.jump(SERVER, self.server_pos, self._server_orbit(slot, group))
        evaluation.group, evaluation.slot = group, slot

    def _send_build_home(self, evaluation: Evaluation, build: Build) -> None:
        host = evaluation_host(evaluation.id)
        if build.electron.host != host:
            build.electron.jump(host, lambda: evaluation.pos, self._build_orbit(build.index))

    def _pulse(self, kind: str) -> None:
        self.core_flash = 1.0
        self._spawn(Ripple(self.server_pos, PULSE_COLORS.get(kind, (200, 200, 255)), self.unit * 0.12, 0.9))

    def _cache_access(self, access: CacheAccess) -> None:
        cache = self._cache(access.cache_id)
        cache.flash = 1.0
        if access.kind == "nar":
            cache.served += access.size
            color, size = NAR_COLOR, 1.5 + math.log10(access.size + 1) * 0.9
        elif access.hit:
            cache.hits += 1
            color, size = CACHE_HIT_COLOR, 2.0
        else:
            cache.misses += 1
            color, size = CACHE_MISS_COLOR, 2.0
        drift = random.uniform(-0.25, 0.25) * self.unit
        client = lambda: (cache.pos[0] + drift, -30.0)
        self._spawn(Comet(lambda: cache.pos, client, color, size, random.uniform(0.6, 0.9), random.uniform(-0.3, 0.3)))

    def _cache_stored(self) -> None:
        for cache in self.caches.values():
            def arrive(cache: Cache = cache) -> None:
                cache.flash = 1.0

            self._spawn(Comet(self.server_pos, lambda cache=cache: cache.pos, STORE_COLOR, 3.0, 0.9, random.uniform(-0.2, 0.2), arrive))

    def _cache(self, cache_id: str) -> Cache:
        if cache_id not in self.caches:
            self.caches[cache_id] = Cache(cache_id)
            self._place_caches()
        return self.caches[cache_id]

    def _place_caches(self) -> None:
        spacing = min(self.unit * 0.35, self.width / (len(self.caches) + 1))
        for index, cache in enumerate(sorted(self.caches.values(), key=lambda c: c.id)):
            offset = index - (len(self.caches) - 1) / 2
            cache.pos = (self.center[0] + offset * spacing, self.unit * 0.1)

    def _worker(self, worker_id: str) -> Worker:
        if worker_id not in self.workers:
            self.workers[worker_id] = Worker(worker_id, 0.0, random.uniform(0, math.tau))
            for index, worker in enumerate(sorted(self.workers.values(), key=lambda w: w.id)):
                worker.target = index * math.tau / len(self.workers)
            self._place_worker(self.workers[worker_id])
        return self.workers[worker_id]

    def _evaluation(self, evaluation_id: str) -> Evaluation:
        if evaluation_id not in self.evaluations:
            slot = self._lane(evaluation_id)
            label = "unassigned" if evaluation_id == UNASSIGNED else evaluation_id[:8]
            electron = Electron(SERVER, self.server_pos, self._server_orbit(slot, evaluation_id), pos=self.center, hop=0.0)
            self.evaluations[evaluation_id] = Evaluation(evaluation_id, "queued", label, slot, evaluation_id, electron)
        return self.evaluations[evaluation_id]

    def _lane(self, group: str) -> int:
        lanes = {e.group: e.slot for e in self.evaluations.values()}
        if group in lanes:
            return lanes[group]
        taken = set(lanes.values())
        return next(i for i in range(len(taken) + 1) if i not in taken)

    def _build(self, evaluation: Evaluation, build_id: str) -> Build:
        if build_id not in evaluation.builds:
            index = len(evaluation.builds)
            electron = Electron(evaluation_host(evaluation.id), lambda: evaluation.pos, self._build_orbit(index), pos=evaluation.pos, hop=0.0)
            evaluation.builds[build_id] = Build(build_id, "created", index, electron)
            self.build_owner[build_id] = evaluation.id
        return evaluation.builds[build_id]

    def _electrons(self) -> Iterator[Electron]:
        for evaluation in self.evaluations.values():
            yield evaluation.electron
            yield from (build.electron for build in evaluation.builds.values())

    def _workers_busy(self) -> bool:
        return any(electron.host.startswith("worker:") for electron in self._electrons())

    def _electrons_on(self, host: str) -> int:
        return sum(electron.host == host for electron in self._electrons())

    def _server_orbit(self, slot: int, group: str) -> Orbit:
        radius = self.unit * (0.24 + 0.057 * (slot % 4))
        speed = kepler_speed(radius, 1 if slot % 2 else -1)
        return Orbit(radius, 0.34, slot * GOLDEN_ANGLE, speed, self._formation_phase(group, speed))

    def _formation_phase(self, group: str, speed: float) -> float:
        siblings = [e.electron.orbit for e in self.evaluations.values() if e.group == group and e.electron.host == SERVER]
        if not siblings:
            return random.uniform(0, math.tau)
        return siblings[0].phase - math.copysign(FORMATION_GAP, speed) * len(siblings)

    def _build_orbit(self, index: int) -> Orbit:
        radius = self.unit * (0.038 + 0.01 * math.sqrt(index))
        return Orbit(radius, 0.5, index * GOLDEN_ANGLE, kepler_speed(radius, 1) * 1.6, random.uniform(0, math.tau))

    def _worker_orbit(self, worker_id: str) -> Orbit:
        radius = self.unit * (0.07 + 0.02 * (self._electrons_on(worker_host(worker_id)) % 5))
        return Orbit(radius, 0.4, random.uniform(-0.5, 0.5), kepler_speed(radius, 1) * 1.3, random.uniform(0, math.tau))

    def _update_workers(self, dt: float) -> None:
        for worker in self.workers.values():
            delta = (worker.target - worker.angle + math.pi) % math.tau - math.pi
            worker.angle += delta * min(dt * 2.5, 1.0)
            worker.heat *= 0.25 ** dt
            self._place_worker(worker)
            if worker.unstable and random.random() < dt * UNSTABLE_SPARK_RATE:
                self._spawn(*burst(worker.pos, cpu_color(worker.cpu), 8, 140, 0.6))

    def _update_evaluations(self, dt: float) -> None:
        for evaluation in list(self.evaluations.values()):
            evaluation.flash *= 0.1 ** dt
            evaluation.idle += dt
            evaluation.alpha = 1 - min(max((evaluation.idle - evaluation.linger) / EVAL_FADE, 0.0), 1.0)
            if evaluation.alpha <= 0:
                self._retire(evaluation)
                continue
            evaluation.electron.update(dt)
            for build in evaluation.builds.values():
                build.flash *= 0.1 ** dt
                build.electron.update(dt)

    def _retire(self, evaluation: Evaluation) -> None:
        del self.evaluations[evaluation.id]
        for build_id in evaluation.builds:
            self.build_owner.pop(build_id, None)

    def _place_worker(self, worker: Worker) -> None:
        angle = worker.angle + self.time * WORKER_SPIN
        margin = self.unit * 0.25
        rx, ry = max(self.width / 2 - margin, 60), max(self.height / 2 - margin, 60)
        worker.pos = (self.center[0] + math.cos(angle) * rx, self.center[1] + math.sin(angle) * ry)


def worker_host(worker_id: str) -> str:
    return f"worker:{worker_id}"


def evaluation_host(evaluation_id: str) -> str:
    return f"evaluation:{evaluation_id}"
