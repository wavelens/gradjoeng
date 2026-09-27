import json
import threading
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from queue import Queue

import pytest
from websockets.sync.server import serve

from gradjoeng.ingest import IngestFile, IngestWeb, MetricsPoll, Replay, events_url, parse_timestamp, pump


def event(at: str, name: str = "graph.requeued") -> dict:
    return {"event": name, "at": at, "content": {}}


class ListIngest:
    def __init__(self, events):
        self.events = iter(events)
        self.closed = False

    def __iter__(self):
        return self

    def __next__(self):
        return next(self.events)

    def close(self):
        self.closed = True


def test_parse_timestamp_handles_nanoseconds_and_zulu():
    earlier = parse_timestamp("2026-09-26T23:22:44.842033933Z")
    later = parse_timestamp("2026-09-26T23:22:45.342033933Z")
    assert later - earlier == pytest.approx(0.5)


def test_ingest_file_yields_events_and_skips_blank_lines(tmp_path):
    path = tmp_path / "events.jsonl"
    path.write_text(json.dumps(event("2026-01-01T00:00:00Z", "a")) + "\n\n" + json.dumps(event("2026-01-01T00:00:01Z", "b")) + "\n")
    ingest = IngestFile(str(path))
    assert [e["event"] for e in ingest] == ["a", "b"]
    ingest.close()


def test_ingest_file_skips_malformed_lines(tmp_path):
    path = tmp_path / "events.jsonl"
    path.write_text("not json\n[1, 2]\n" + json.dumps(event("2026-01-01T00:00:00Z", "ok")) + "\n")
    assert [e["event"] for e in IngestFile(str(path))] == ["ok"]


def test_replay_sleeps_scaled_and_capped_gaps():
    sleeps = []
    source = ListIngest([
        event("2026-01-01T00:00:00Z"),
        event("2026-01-01T00:00:02Z"),
        event("2026-01-01T00:01:00Z"),
        {"event": "no.timestamp", "content": {}},
    ])
    replay = Replay(source, speed=2.0, max_gap=5.0, sleep=sleeps.append)
    assert len(list(replay)) == 4
    assert sleeps == [pytest.approx(1.0), pytest.approx(5.0)]


def test_replay_close_closes_source():
    source = ListIngest([])
    Replay(source, speed=1.0).close()
    assert source.closed


def test_pump_forwards_events_then_closes():
    source = ListIngest([event("2026-01-01T00:00:00Z", "a"), event("2026-01-01T00:00:00Z", "b")])
    queue = Queue()
    pump(source, queue).join(timeout=2)
    assert [queue.get_nowait()["event"] for _ in range(2)] == ["a", "b"]
    assert source.closed


def test_ingest_web_sends_bearer_token_and_decodes_frames():
    headers = {}

    def handler(connection):
        headers["authorization"] = connection.request.headers.get("Authorization")
        headers["path"] = connection.request.path
        connection.send(json.dumps(event("2026-01-01T00:00:00Z", "evaluation.queued")))
        connection.send("garbage")
        connection.send(json.dumps(event("2026-01-01T00:00:01Z", "build.completed")))

    with serve(handler, "127.0.0.1", 0) as server:
        threading.Thread(target=server.serve_forever, daemon=True).start()
        port = server.socket.getsockname()[1]
        ingest = IngestWeb(f"http://127.0.0.1:{port}", "secret")
        names = [e["event"] for e in ingest]
        server.shutdown()

    assert headers["authorization"] == "Bearer secret"
    assert headers["path"] == "/api/v1/metrics/events"
    assert names == ["evaluation.queued", "build.completed"]


def test_events_url_maps_base_url_to_websocket_endpoint():
    assert events_url("https://gradient.example") == "wss://gradient.example/api/v1/metrics/events"
    assert events_url("http://127.0.0.1:3000/") == "ws://127.0.0.1:3000/api/v1/metrics/events"


def serve_workers(workers: list[dict], seen: list[dict]) -> ThreadingHTTPServer:
    class Handler(BaseHTTPRequestHandler):
        def do_GET(self):
            seen.append({"path": self.path, "authorization": self.headers.get("Authorization")})
            body = json.dumps({"error": False, "message": workers}).encode()
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.end_headers()
            self.wfile.write(body)

        def log_message(self, *args):
            pass

    server = ThreadingHTTPServer(("127.0.0.1", 0), Handler)
    threading.Thread(target=server.serve_forever, daemon=True).start()
    return server


def test_metrics_poll_emits_worker_metrics_every_interval():
    seen, sleeps = [], []
    workers = [{"id": "w1", "cpu_usage_pct": 42.5}, {"id": None, "cpu_usage_pct": None}, {"id": "w2", "cpu_usage_pct": None}]
    server = serve_workers(workers, seen)
    poll = MetricsPoll(f"http://127.0.0.1:{server.server_address[1]}", "secret", interval=5.0, sleep=sleeps.append)
    events = [next(poll) for _ in range(4)]
    server.shutdown()

    assert [e["content"] for e in events] == [
        {"worker_id": "w1", "cpu_usage_pct": 42.5},
        {"worker_id": "w2", "cpu_usage_pct": None},
    ] * 2
    assert {e["event"] for e in events} == {"worker.metrics"}
    assert sleeps == [5.0]
    assert seen[0] == {"path": "/api/v1/board/workers", "authorization": "Bearer secret"}


def test_metrics_poll_survives_unreachable_server():
    sleeps = []

    def sleep(seconds):
        sleeps.append(seconds)
        if len(sleeps) == 2:
            raise StopIteration

    poll = MetricsPoll("http://127.0.0.1:1", None, interval=3.0, sleep=sleep)
    assert list(poll) == []
    assert sleeps == [3.0, 3.0]
