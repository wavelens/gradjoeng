from dataclasses import dataclass
from typing import Callable

EVALUATION_PHASES = ("queued", "evaluating", "evaluating", "building", "waiting", "completed", "failed", "aborted", "fetching")
BUILD_STATES = ("created", "queued", "building", "completed", "failed", "aborted", "dependency_failed", "substituted", "retrying", "timeout")

GOOD = {"completed", "substituted"}
BAD = {"failed", "dependency_failed", "timeout", "aborted"}


@dataclass(frozen=True)
class WorkerMessage:
    worker_id: str
    outbound: bool
    kind: str
    size: int
    job_id: str | None = None


@dataclass(frozen=True)
class EvaluationChanged:
    evaluation_id: str
    phase: str | None
    repository: str | None
    group: str | None = None


@dataclass(frozen=True)
class BuildChanged:
    build_id: str
    evaluation_id: str | None
    state: str


@dataclass(frozen=True)
class JobDispatched:
    worker_id: str
    evaluation_id: str | None
    build_id: str | None
    score: float = 0.0


@dataclass(frozen=True)
class WorkerLoad:
    worker_id: str
    cpu: float | None


@dataclass(frozen=True)
class QueueDepth:
    active: int
    pending: int
    workers: int


@dataclass(frozen=True)
class ServerPulse:
    kind: str


@dataclass(frozen=True)
class CacheAccess:
    cache_id: str
    kind: str
    hit: bool
    size: int


@dataclass(frozen=True)
class CacheStored:
    pass


@dataclass(frozen=True)
class Headline:
    text: str
    tone: str


Effect = WorkerMessage | WorkerLoad | EvaluationChanged | BuildChanged | JobDispatched | QueueDepth | ServerPulse | CacheAccess | CacheStored | Headline


def parse(event: dict) -> list[Effect]:
    name = event.get("event")
    if not isinstance(name, str):
        return []
    content = event.get("content") or {}
    handler = HANDLERS.get(name.split(".", 1)[0], _unknown)
    return handler(name, content)


def tone_of(state: str | None) -> str:
    return "good" if state in GOOD else "bad" if state in BAD else "info"


def short(identifier: str | None) -> str:
    return (identifier or "?")[:8]


def lookup(table: tuple[str, ...], code, fallback: str) -> str:
    return table[code] if isinstance(code, int) and 0 <= code < len(table) else fallback


def suffix(name: str) -> str:
    return name.rsplit(".", 1)[-1]


def _proto(name: str, content: dict) -> list[Effect]:
    worker = content.get("worker_id")
    if not worker:
        return []
    return [WorkerMessage(worker, content.get("direction") == "server", suffix(name), content.get("len") or 0, content.get("job_id"))]


def _evaluation(name: str, content: dict) -> list[Effect]:
    evaluation = content.get("evaluation_id")
    if not evaluation:
        return []
    group = content.get("project") or content.get("task")
    if "status" not in content:
        return [EvaluationChanged(evaluation, None, None, group)]
    phase = lookup(EVALUATION_PHASES, content["status"], suffix(name))
    return [
        EvaluationChanged(evaluation, phase, content.get("repository"), group),
        Headline(f"evaluation {phase:<10} {short(evaluation)}", tone_of(phase)),
    ]


def _build(name: str, content: dict) -> list[Effect]:
    build = content.get("build_id")
    if not build:
        return []
    state = lookup(BUILD_STATES, content.get("status"), suffix(name))
    effects: list[Effect] = [BuildChanged(build, content.get("evaluation_id"), state)]
    if tone_of(state) != "info":
        effects.append(Headline(f"build      {state:<10} {short(build)}", tone_of(state)))
    return effects


def _worker(name: str, content: dict) -> list[Effect]:
    if name == "worker.metrics" and content.get("worker_id"):
        return [WorkerLoad(content["worker_id"], content.get("cpu_usage_pct"))]
    if name == "worker.queue_depth":
        return [QueueDepth(content.get("active", 0), content.get("pending", 0), content.get("workers", 0))]
    if name == "worker.job_dispatched" and content.get("worker_id"):
        return [
            JobDispatched(content["worker_id"], content.get("evaluation_id"), content.get("build_id"), content.get("score") or 0.0),
            Headline(f"dispatch   -> worker  {short(content['worker_id'])}", "info"),
        ]
    return [Headline(name, "info")]


def _graph(name: str, content: dict) -> list[Effect]:
    pulse = ServerPulse("graph")
    if name == "graph.requeued" and not content.get("requeued"):
        return [pulse]
    if name == "graph.nar_committed":
        return [pulse, CacheStored(), Headline(name, "info")]
    return [pulse, Headline(name, "info")]


def _cache(name: str, content: dict) -> list[Effect]:
    cache = content.get("cache")
    if not cache:
        return [ServerPulse("cache")]
    kind = name.split(".")[1]
    return [CacheAccess(cache, kind, content.get("hit", True), content.get("size") or 0)]


def _unknown(name: str, content: dict) -> list[Effect]:
    return [Headline(name, "info")]


HANDLERS: dict[str, Callable[[str, dict], list[Effect]]] = {
    "proto": _proto,
    "evaluation": _evaluation,
    "build": _build,
    "worker": _worker,
    "graph": _graph,
    "cache": _cache,
}
