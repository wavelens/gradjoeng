class_name Effects


class WorkerMessage:
	var worker_id: String
	var outbound: bool
	var kind: String
	var size: int
	var job_id: String

	func _init(p_worker_id: String, p_outbound: bool, p_kind: String, p_size: int, p_job_id: String = "") -> void:
		worker_id = p_worker_id
		outbound = p_outbound
		kind = p_kind
		size = p_size
		job_id = p_job_id


class WorkerLoad:
	var worker_id: String
	var cpu: Variant

	func _init(p_worker_id: String, p_cpu: Variant) -> void:
		worker_id = p_worker_id
		cpu = p_cpu


class WorkerLink:
	var worker_id: String
	var connected: bool

	func _init(p_worker_id: String, p_connected: bool) -> void:
		worker_id = p_worker_id
		connected = p_connected


class WorkerNetwork:
	var worker_id: String
	var mbps: Variant

	func _init(p_worker_id: String, p_mbps: Variant) -> void:
		worker_id = p_worker_id
		mbps = p_mbps


class EvaluationChanged:
	var evaluation_id: String
	var phase: String
	var repository: String
	var group: String

	func _init(p_evaluation_id: String, p_phase: String = "", p_repository: String = "", p_group: String = "") -> void:
		evaluation_id = p_evaluation_id
		phase = p_phase
		repository = p_repository
		group = p_group


class BuildChanged:
	var build_id: String
	var evaluation_id: String
	var state: String
	var derivation_build: String

	func _init(p_build_id: String, p_evaluation_id: String, p_state: String, p_derivation_build: String = "") -> void:
		build_id = p_build_id
		evaluation_id = p_evaluation_id
		state = p_state
		derivation_build = p_derivation_build


class JobDispatched:
	var worker_id: String
	var evaluation_id: String
	var derivation_build: String
	var score: float

	func _init(p_worker_id: String, p_evaluation_id: String, p_derivation_build: String, p_score: float = 0.0) -> void:
		worker_id = p_worker_id
		evaluation_id = p_evaluation_id
		derivation_build = p_derivation_build
		score = p_score


class ServerPulse:
	var kind: String

	func _init(p_kind: String) -> void:
		kind = p_kind


class CacheAccess:
	var cache_id: String
	var kind: String
	var hit: bool
	var size: int

	func _init(p_cache_id: String, p_kind: String, p_hit: bool, p_size: int) -> void:
		cache_id = p_cache_id
		kind = p_kind
		hit = p_hit
		size = p_size


class CacheStored:
	var cache_id: String

	func _init(p_cache_id: String) -> void:
		cache_id = p_cache_id


class CacheQueried:
	pass


class Headline:
	var text: String
	var tone: String
	var subject: String
	var fallback: String

	func _init(p_text: String, p_tone: String, p_subject: String = "", p_fallback: String = "") -> void:
		text = p_text
		tone = p_tone
		subject = p_subject
		fallback = p_fallback


class Names:
	var names: Dictionary

	func _init(p_names: Dictionary) -> void:
		names = p_names


class CachesListed:
	var caches: Dictionary

	func _init(p_caches: Dictionary) -> void:
		caches = p_caches
