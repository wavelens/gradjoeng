import json
import re
import threading
import time
from abc import ABC, abstractmethod
from collections import deque
from datetime import datetime
from queue import Queue
from typing import Callable, Iterable, Iterator
from urllib.parse import urlsplit
from urllib.request import Request, urlopen

from websockets.exceptions import ConnectionClosed
from websockets.sync.client import connect

Event = dict

_FRACTION = re.compile(r"\.(\d+)")
EVENTS_PATH = "api/v1/metrics/events"
WORKERS_PATH = "api/v1/board/workers"
WEBSOCKET_SCHEMES = {"http": "ws", "https": "wss"}


def api_url(base: str, path: str) -> str:
    return f"{base.rstrip('/')}/{path}"


def events_url(base: str) -> str:
    url = urlsplit(api_url(base, EVENTS_PATH))
    return url._replace(scheme=WEBSOCKET_SCHEMES.get(url.scheme, url.scheme)).geturl()


def bearer(token: str | None) -> dict[str, str]:
    return {"Authorization": f"Bearer {token}"} if token else {}


def parse_timestamp(value: str) -> float:
    micro = _FRACTION.sub(lambda m: "." + m.group(1)[:6].ljust(6, "0"), value.replace("Z", "+00:00"), count=1)
    return datetime.fromisoformat(micro).timestamp()


def decode(raw: str | bytes) -> Event | None:
    try:
        event = json.loads(raw)
    except ValueError:
        return None
    return event if isinstance(event, dict) else None


def first_event(frames: Iterable[str | bytes]) -> Event:
    for frame in frames:
        if (event := decode(frame)) is not None:
            return event
    raise StopIteration


class Ingest(ABC):
    def __iter__(self) -> Iterator[Event]:
        return self

    @abstractmethod
    def __next__(self) -> Event: ...

    def close(self) -> None:
        pass


class IngestFile(Ingest):
    def __init__(self, path: str):
        self.fs = open(path, "r", encoding="utf-8")

    def __next__(self) -> Event:
        return first_event(line for line in self.fs if line.strip())

    def close(self) -> None:
        self.fs.close()


class IngestWeb(Ingest):
    def __init__(self, base: str, token: str | None):
        self.ws = connect(events_url(base), additional_headers=bearer(token))

    def _frames(self) -> Iterator[str | bytes]:
        try:
            while True:
                yield self.ws.recv()
        except ConnectionClosed:
            return

    def __next__(self) -> Event:
        return first_event(self._frames())

    def close(self) -> None:
        self.ws.close()


class MetricsPoll(Ingest):
    """Polls the connected workers every `interval` seconds and emits their load as `worker.metrics` events."""

    def __init__(self, base: str, token: str | None, interval: float, sleep: Callable[[float], None] = time.sleep):
        self.request = Request(api_url(base, WORKERS_PATH), headers=bearer(token))
        self.interval = interval
        self.sleep = sleep
        self.pending: deque[Event] = deque()
        self.polled = False

    def __next__(self) -> Event:
        while not self.pending:
            if self.polled:
                self.sleep(self.interval)
            self.polled = True
            self.pending.extend(worker_metrics(worker) for worker in self._workers() if worker.get("id"))
        return self.pending.popleft()

    def _workers(self) -> list[dict]:
        try:
            with urlopen(self.request, timeout=self.interval) as response:
                body = json.load(response)
        except (OSError, ValueError):
            return []
        workers = body.get("message") if isinstance(body, dict) else None
        return [worker for worker in workers if isinstance(worker, dict)] if isinstance(workers, list) else []


def worker_metrics(worker: dict) -> Event:
    return {"event": "worker.metrics", "content": {"worker_id": worker["id"], "cpu_usage_pct": worker.get("cpu_usage_pct")}}


class Replay(Ingest):
    """Re-emits recorded events with their original spacing, scaled by `speed` and capped at `max_gap` seconds."""

    def __init__(self, source: Ingest, speed: float, max_gap: float = 1.5, sleep: Callable[[float], None] = time.sleep):
        self.source = source
        self.speed = speed
        self.max_gap = max_gap
        self.sleep = sleep
        self.previous: float | None = None

    def __next__(self) -> Event:
        event = next(self.source)
        if "at" not in event:
            return event

        at = parse_timestamp(event["at"])
        if self.previous is not None:
            self.sleep(min(max(at - self.previous, 0.0) / self.speed, self.max_gap))

        self.previous = at
        return event

    def close(self) -> None:
        self.source.close()


def pump(ingest: Ingest, queue: Queue) -> threading.Thread:
    def run() -> None:
        try:
            for event in ingest:
                queue.put(event)
        finally:
            ingest.close()

    thread = threading.Thread(target=run, name="ingest", daemon=True)
    thread.start()
    return thread
