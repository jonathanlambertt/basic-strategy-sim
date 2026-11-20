class_name Stats
extends RefCounted
## Session accuracy against basic strategy, plus round results.

const CATEGORIES: Array[String] = ["hard", "soft", "pair", "insurance"]
const CATEGORY_NAMES := {"hard": "HARD", "soft": "SOFT", "pair": "PAIRS", "insurance": "INSURANCE"}

var decisions := 0
var correct := 0
var streak := 0
var best_streak := 0
## category -> [correct, total]
var by_category := {}
## key -> {label, best, note, rule, misses, last_taken}
var misses := {}

var rounds := 0
var hands_won := 0
var hands_lost := 0
var hands_pushed := 0
var blackjacks := 0
var net := 0.0


func _init() -> void:
	reset()


func reset() -> void:
	decisions = 0
	correct = 0
	streak = 0
	best_streak = 0
	by_category = {}
	for c in CATEGORIES:
		by_category[c] = [0, 0]
	misses = {}
	rounds = 0
	hands_won = 0
	hands_lost = 0
	hands_pushed = 0
	blackjacks = 0
	net = 0.0


## Records one decision. Returns true if it matched basic strategy.
func record(category: String, label: String, best: String, taken: String, note: String = "", rule: String = "") -> bool:
	var ok := best == taken
	decisions += 1
	var cat: Array = by_category[category]
	cat[1] += 1
	if ok:
		correct += 1
		cat[0] += 1
		streak += 1
		best_streak = maxi(best_streak, streak)
	else:
		streak = 0
		var key := label + "|" + best
		if not misses.has(key):
			misses[key] = {"label": label, "best": best, "note": note, "rule": rule, "misses": 0, "last_taken": ""}
		misses[key]["misses"] += 1
		misses[key]["last_taken"] = taken
	return ok


## 0..100, or -1 when there is nothing to measure yet.
func accuracy() -> float:
	if decisions == 0:
		return -1.0
	return 100.0 * correct / decisions


func category_accuracy(category: String) -> float:
	var cat: Array = by_category[category]
	if cat[1] == 0:
		return -1.0
	return 100.0 * cat[0] / cat[1]


## Most-missed spots, most frequent first.
func top_misses(count: int) -> Array:
	var list := misses.values()
	list.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a["misses"] != b["misses"]:
			return a["misses"] > b["misses"]
		return a["label"] < b["label"])
	return list.slice(0, count)


func record_hand_result(result: String) -> void:
	match result:
		"WIN":
			hands_won += 1
		"BLACKJACK":
			hands_won += 1
			blackjacks += 1
		"PUSH":
			hands_pushed += 1
		_:
			hands_lost += 1
