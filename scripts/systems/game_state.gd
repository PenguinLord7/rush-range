extends Node
## Session score / stats for a range run. Reset when a game starts.

var score: int = 0
var shots_fired: int = 0
var shots_hit: int = 0
var targets_destroyed: int = 0

func reset_run() -> void:
	score = 0
	shots_fired = 0
	shots_hit = 0
	targets_destroyed = 0
	Events.score_changed.emit(score)
	Events.notice.emit("")

func add_score(points: int) -> void:
	score += points
	Events.score_changed.emit(score)

func register_shot() -> void:
	shots_fired += 1

func register_hit() -> void:
	shots_hit += 1

func register_destroyed() -> void:
	targets_destroyed += 1

func accuracy() -> float:
	if shots_fired == 0:
		return 0.0
	return float(shots_hit) / float(shots_fired)
