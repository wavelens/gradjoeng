from queue import Queue

import pytest

from gradjoeng.ingest import Replay
from gradjoeng.main import drain, parse_args, shift_speed
from gradjoeng.scene import Scene


class Empty:
    def __iter__(self):
        return self

    def __next__(self):
        raise StopIteration

    def close(self):
        pass


def test_parse_args_file_replay():
    args = parse_args(["--file", "events/1.log", "--speed", "4", "--size", "800x600"])
    assert (args.file, args.speed, args.size) == ("events/1.log", 4.0, (800, 600))


def test_parse_args_url_takes_base_and_poll_interval():
    args = parse_args(["--url", "https://gradient.example", "--poll", "2.5"])
    assert (args.url, args.poll) == ("https://gradient.example", 2.5)
    assert parse_args(["--url", "https://gradient.example"]).poll == 5.0


def test_parse_args_requires_a_source():
    with pytest.raises(SystemExit):
        parse_args([])


def test_parse_args_rejects_token_without_url():
    with pytest.raises(SystemExit):
        parse_args(["--file", "x", "--token", "t"])


def test_shift_speed_walks_steps_and_clamps():
    replay = Replay(Empty(), speed=1.0)
    shift_speed(replay, 1)
    assert replay.speed == 2.0
    for _ in range(20):
        shift_speed(replay, -1)
    assert replay.speed == 0.25


def test_drain_applies_queued_events():
    events = Queue()
    events.put({"event": "worker.queue_depth", "content": {"active": 2, "pending": 5, "workers": 1}})
    scene = Scene((640, 400))
    drain(events, scene)
    assert (scene.hud.active, scene.hud.pending) == (2, 5)
