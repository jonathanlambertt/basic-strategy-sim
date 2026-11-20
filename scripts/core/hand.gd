class_name Hand
extends RefCounted
## A blackjack hand. Cards are ints 0..51: rank = id % 13 + 1 (1 = ace, 11-13 = J Q K),
## suit = id / 13 (0 spades, 1 hearts, 2 clubs, 3 diamonds).

const SUIT_NAMES: Array[String] = ["SPADES", "HEARTS", "CLUBS", "DIAMONDS"]
const RANK_NAMES: Array[String] = ["", "A", "2", "3", "4", "5", "6", "7", "8", "9", "10", "J", "Q", "K"]

var cards: Array[int] = []
var bet: float = 0.0
var doubled := false
var from_split := false
var split_aces := false
var stood := false
var surrendered := false


func _init(stake: float = 0.0) -> void:
	bet = stake


static func rank_of(card: int) -> int:
	return card % 13 + 1


@warning_ignore("integer_division")
static func suit_of(card: int) -> int:
	return card / 13


static func is_red(card: int) -> bool:
	var s := suit_of(card)
	return s == 1 or s == 3


## Blackjack value with the ace counted as 1 (J/Q/K count 10).
static func value_of(card: int) -> int:
	return mini(rank_of(card), 10)


static func rank_name(card: int) -> String:
	return RANK_NAMES[rank_of(card)]


static func hard_sum_of(card_list: Array) -> int:
	var s := 0
	for c in card_list:
		s += value_of(c)
	return s


static func has_ace(card_list: Array) -> bool:
	for c in card_list:
		if rank_of(c) == 1:
			return true
	return false


## Soft = an ace is currently counted as 11 without busting.
static func is_soft_list(card_list: Array) -> bool:
	return has_ace(card_list) and hard_sum_of(card_list) + 10 <= 21


static func total_of(card_list: Array) -> int:
	var s := hard_sum_of(card_list)
	if has_ace(card_list) and s + 10 <= 21:
		s += 10
	return s


func total() -> int:
	return total_of(cards)


func is_soft() -> bool:
	return is_soft_list(cards)


func is_bust() -> bool:
	return total() > 21


## A natural: two-card 21 on an original (non-split) hand.
func is_blackjack() -> bool:
	return cards.size() == 2 and total() == 21 and not from_split


## Two cards of equal blackjack value (any two 10-value cards count as a pair).
func is_pair() -> bool:
	return cards.size() == 2 and value_of(cards[0]) == value_of(cards[1])


## Finished: no more decisions on this hand.
func is_done() -> bool:
	return stood or surrendered or doubled or is_bust()


## Is this hand still in contention when the dealer plays?
func is_live() -> bool:
	return not surrendered and not is_bust()
