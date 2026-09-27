from gradjoeng.parser import (
    BuildChanged,
    CacheAccess,
    CacheStored,
    EvaluationChanged,
    Headline,
    JobDispatched,
    QueueDepth,
    ServerPulse,
    WorkerLoad,
    WorkerMessage,
    parse,
)


def ev(name: str, **content) -> dict:
    return {"event": name, "at": "2026-09-26T23:22:44Z", "content": content}


def test_proto_client_message_flows_to_server():
    effects = parse(ev("proto.client.log_chunk", direction="client", worker_id="w1", job_id="eval:e1", len=None))
    assert effects == [WorkerMessage("w1", outbound=False, kind="log_chunk", size=0, job_id="eval:e1")]


def test_proto_server_message_flows_to_worker():
    effects = parse(ev("proto.server.assign_job", direction="server", worker_id="w1", len=320))
    assert effects == [WorkerMessage("w1", outbound=True, kind="assign_job", size=320)]


def test_proto_without_worker_is_ignored():
    assert parse(ev("proto.client.request_job", direction="client", worker_id=None)) == []


def test_evaluation_queued_carries_repository():
    effects = parse(ev("evaluation.queued", evaluation_id="e1", status=0, repository="https://github.com/wavelens/gobgp.nix"))
    assert effects[0] == EvaluationChanged("e1", phase="queued", repository="https://github.com/wavelens/gobgp.nix")
    assert isinstance(effects[1], Headline)


def test_evaluation_status_codes_map_to_phases():
    assert parse(ev("evaluation.started", evaluation_id="e1", status=8))[0].phase == "fetching"
    assert parse(ev("evaluation.building", evaluation_id="e1", status=3))[0].phase == "building"
    assert parse(ev("evaluation.completed", evaluation_id="e1", status=5))[0].phase == "completed"
    assert parse(ev("evaluation.failed", evaluation_id="e1", status=6))[0].phase == "failed"


def test_evaluation_progress_keeps_phase():
    assert parse(ev("evaluation.progress", evaluation_id="e1", task="t")) == [EvaluationChanged("e1", phase=None, repository=None, group="t")]


def test_evaluation_groups_by_project_before_task():
    assert parse(ev("evaluation.queued", evaluation_id="e1", status=0, project="p", task="t"))[0].group == "p"
    assert parse(ev("evaluation.queued", evaluation_id="e1", status=0, project=None, task="t"))[0].group == "t"


def test_build_status_codes_map_to_states():
    assert parse(ev("build.status_changed", build_id="b1", evaluation_id="e1", status=0)) == [BuildChanged("b1", "e1", "created")]
    assert parse(ev("build.completed", build_id="b1", evaluation_id="e1", status=3))[0].state == "completed"
    assert parse(ev("build.failed", build_id="b1", evaluation_id="e1", status=6))[0].state == "dependency_failed"
    assert parse(ev("build.substituted", build_id="b1", evaluation_id="e1", status=7))[0].state == "substituted"


def test_terminal_build_emits_toned_headline():
    headline = parse(ev("build.failed", build_id="b1", evaluation_id="e1", status=4))[1]
    assert headline.tone == "bad"


def test_worker_events():
    assert parse(ev("worker.job_dispatched", worker_id="w1", evaluation_id="e1", build_id=None))[0] == JobDispatched("w1", "e1", None)
    assert parse(ev("worker.job_dispatched", worker_id="w1", evaluation_id="e1", build_id="b1"))[0] == JobDispatched("w1", "e1", "b1")
    assert parse(ev("worker.job_dispatched", worker_id="w1", evaluation_id="e1", score=2057.7))[0].score == 2057.7
    assert parse(ev("worker.queue_depth", active=1, pending=2, workers=3)) == [QueueDepth(1, 2, 3)]


def test_graph_and_cache_pulse_the_server():
    assert parse(ev("graph.requeued", requeued=0)) == [ServerPulse("graph")]
    assert parse(ev("graph.ingested", evaluation_id="e1"))[0] == ServerPulse("graph")
    assert parse(ev("cache.nar.fetched")) == [ServerPulse("cache")]


def test_cache_events_address_their_cache():
    assert parse(ev("cache.narinfo.served", cache="c1", hash="h", hit=False)) == [CacheAccess("c1", "narinfo", False, 0)]
    assert parse(ev("cache.nar.fetched", cache="c1", hash="h", size=96941)) == [CacheAccess("c1", "nar", True, 96941)]


def test_committed_nar_is_stored_in_caches():
    assert CacheStored() in parse(ev("graph.nar_committed", created=True))


def test_unknown_events_become_headlines():
    assert parse(ev("mystery.thing")) == [Headline("mystery.thing", "info")]


def test_malformed_event_is_ignored():
    assert parse({"content": None}) == []


def test_worker_metrics_carry_cpu_usage():
    assert parse(ev("worker.metrics", worker_id="w1", cpu_usage_pct=91.5)) == [WorkerLoad("w1", 91.5)]
    assert parse(ev("worker.metrics", worker_id="w1", cpu_usage_pct=None)) == [WorkerLoad("w1", None)]
