# SPDX-FileCopyrightText: 2026 Wavelens GmbH <info@wavelens.io>
#
# SPDX-License-Identifier: MIT

extends Suite


func test_cache_names_from_cache_list() -> void:
	var body := JSON.stringify({"error": false, "message": {"items": [{"id": "c1", "name": "main", "display_name": "Main Cache"}, {"id": "c2", "name": "x", "display_name": ""}], "total": 2}})
	equal(NameDirectory.cache_names(body), {"c1": "Main Cache", "c2": "x"})
	equal(NameDirectory.cache_names("garbage"), {})


func test_project_names_from_paginated_project_list() -> void:
	var body := JSON.stringify({"error": false, "message": {"items": [{"id": "p1", "name": "gradient"}, {"id": "p2", "name": "nixos"}], "total": 2, "page": 1, "per_page": 100}})
	equal(NameDirectory.project_names(body), ["gradient", "nixos"])
	var plain := JSON.stringify({"error": false, "message": [{"id": "p1", "name": "gradient"}]})
	equal(NameDirectory.project_names(plain), ["gradient"])


func test_worker_names_from_project_workers() -> void:
	var body := JSON.stringify({"error": false, "message": [{"worker_id": "w1", "display_name": "builder-01"}, {"worker_id": "w2", "display_name": ""}]})
	equal(NameDirectory.worker_names(body), {"w1": "builder-01"})


func test_names_event_wraps_directory() -> void:
	equal(NameDirectory.names_event({"w1": "a"}), {"event": "directory.names", "content": {"names": {"w1": "a"}}})


func test_caches_event_lists_known_caches() -> void:
	equal(NameDirectory.caches_event({"c1": "main"}), {"event": "directory.caches", "content": {"caches": {"c1": "main"}}})


func test_evaluation_names_from_evaluation_record() -> void:
	var body := JSON.stringify({"error": false, "message": {"id": "e1", "repository": "https://github.com/wavelens/gobgp.nix.git"}})
	equal(NameDirectory.evaluation_names("e1", body), {"e1": "gobgp.nix"})
	equal(NameDirectory.evaluation_names("e1", "garbage"), {})


func test_unnamed_evaluation_needs_lookup_only_without_repository() -> void:
	equal(NameDirectory.unnamed_evaluation({"event": "evaluation.started", "content": {"evaluation_id": "e1", "repository": null}}), "e1")
	equal(NameDirectory.unnamed_evaluation({"event": "worker.job_dispatched", "content": {"evaluation_id": "e1"}}), "e1")
	equal(NameDirectory.unnamed_evaluation({"event": "evaluation.queued", "content": {"evaluation_id": "e1", "repository": "https://x/y"}}), "")
	equal(NameDirectory.unnamed_evaluation({"event": "proto.client.log_chunk", "content": {"job_id": "eval:e1"}}), "")
