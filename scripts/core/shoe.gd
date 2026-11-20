class_name Shoe
extends RefCounted
## A multi-deck shoe with a cut card.

var decks: int
var cards: Array[int] = []
var next_index := 0
var cut_index := 0
var rng := RandomNumberGenerator.new()
## Cards forced to come out next, in order (used by tests).
var rigged: Array[int] = []


func _init(deck_count: int = 6, seed_value: int = -1) -> void:
	decks = deck_count
	if seed_value >= 0:
		rng.seed = seed_value
	else:
		rng.randomize()
	shuffle_new()


func shuffle_new() -> void:
	cards.clear()
	for d in decks:
		for c in 52:
			cards.append(c)
	# Fisher-Yates
	for i in range(cards.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp := cards[i]
		cards[i] = cards[j]
		cards[j] = tmp
	next_index = 0
	cut_index = int(cards.size() * Rules.PENETRATION)


func draw() -> int:
	if not rigged.is_empty():
		return rigged.pop_front()
	if next_index >= cards.size():
		# Only reachable if a round outlasts the whole shoe; reshuffle so play can continue.
		shuffle_new()
	var c := cards[next_index]
	next_index += 1
	return c


## True once the cut card has come out; checked between rounds.
func needs_shuffle() -> bool:
	return next_index >= cut_index


func total_cards() -> int:
	return cards.size()


func remaining() -> int:
	return cards.size() - next_index


## 1.0 = fresh shoe, 0.0 = cut card reached.
func fraction_until_cut() -> float:
	if cut_index <= 0:
		return 0.0
	return clampf(float(cut_index - next_index) / float(cut_index), 0.0, 1.0)
