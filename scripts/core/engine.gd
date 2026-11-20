class_name BlackjackEngine
extends RefCounted
## Pure game logic for one player against the dealer. Every call returns a list of
## events (Dictionaries) describing what happened, in order, so the view can animate them.
##
## Event types ("t"):
##   shuffle                         new shoe
##   bank      value                 bankroll changed
##   deal      to ("p"/"d"), hand, card, down
##   insurance even_money            insurance offered, waiting for insurance()
##   peek      bj                    dealer checked the hole card
##   reveal    card                  hole card turned over
##   split     hand                  hands[hand] split; its 2nd card moved to hand + 1
##   double    hand
##   surrender hand
##   active    hand                  waiting for the player to act on this hand
##   decision  correct, best, taken, label, note, rule, category
##   settle    results [{hand, result, net}], insurance_net, net, dealer_total

enum Phase { BETTING, INSURANCE, PLAYER, ROUND_OVER }

const MIN_BET := 5.0
const START_BANKROLL := 1000.0

var rules: Rules
var shoe: Shoe
var stats := Stats.new()
var bankroll := START_BANKROLL
var phase := Phase.BETTING
var hands: Array[Hand] = []
var dealer := Hand.new()
var active := 0
var insurance_bet := 0.0
var hole_revealed := false

var _events: Array[Dictionary] = []
var _bank_at_start := 0.0


func _init(start_rules: Rules = null, seed_value: int = -1) -> void:
	rules = start_rules.copy() if start_rules else Rules.new()
	shoe = Shoe.new(rules.decks, seed_value)


func is_between_rounds() -> bool:
	return phase == Phase.BETTING or phase == Phase.ROUND_OVER


## Applies new rules between rounds. A deck-count change brings a fresh shoe.
## Returns true if a new shoe was shuffled.
func set_rules(new_rules: Rules) -> bool:
	if not is_between_rounds():
		push_error("Rules can only change between rounds")
		return false
	var reshuffle := new_rules.decks != rules.decks
	rules = new_rules.copy()
	if reshuffle:
		shoe = Shoe.new(rules.decks)
	return reshuffle


func reset_bankroll() -> void:
	bankroll = START_BANKROLL


func can_start(bet: float) -> bool:
	return is_between_rounds() and bet >= MIN_BET and bet <= bankroll


# ---------------------------------------------------------------- round flow

func start_round(bet: float) -> Array[Dictionary]:
	_events = []
	if not can_start(bet):
		push_error("Cannot start round with bet %s" % bet)
		return _events
	if shoe.needs_shuffle():
		shoe.shuffle_new()
		_emit({"t": "shuffle"})
	_bank_at_start = bankroll
	bankroll -= bet
	hands = [Hand.new(bet)]
	dealer = Hand.new()
	active = 0
	insurance_bet = 0.0
	hole_revealed = false
	_emit({"t": "bank", "value": bankroll})

	_deal_player(0)
	_deal_dealer(false)
	_deal_player(0)
	_deal_dealer(true)

	if Hand.rank_of(dealer.cards[0]) == 1 and bankroll >= bet / 2.0:
		phase = Phase.INSURANCE
		_emit({"t": "insurance", "even_money": hands[0].is_blackjack()})
		return _events
	_after_insurance()
	return _events


func insurance(take: bool) -> Array[Dictionary]:
	_events = []
	if phase != Phase.INSURANCE:
		push_error("No insurance offer pending")
		return _events
	var label := "EVEN MONEY (BLACKJACK VS A)" if hands[0].is_blackjack() else "INSURANCE VS A"
	_record("insurance", label, "decline", "insure" if take else "decline", "",
		Strategy.rule_text("insurance", 0, rules))
	if take:
		insurance_bet = hands[0].bet / 2.0
		bankroll -= insurance_bet
		_emit({"t": "bank", "value": bankroll})
	_after_insurance()
	return _events


func _after_insurance() -> void:
	var up_value := Hand.value_of(dealer.cards[0])
	var dealer_bj := dealer.is_blackjack()
	if up_value == 1 or up_value == 10:
		_emit({"t": "peek", "bj": dealer_bj})
	if dealer_bj or hands[0].is_blackjack():
		_finish_round()
		return
	phase = Phase.PLAYER
	_activate(0)


## What the player may do on the active hand.
func available() -> Dictionary:
	var none := {"hit": false, "stand": false, "double": false, "split": false, "surrender": false}
	if phase != Phase.PLAYER:
		return none
	var h := hands[active]
	if h.is_done():
		return none
	return {
		"hit": true,
		"stand": true,
		"double": h.cards.size() == 2 and not h.split_aces and (rules.das or not h.from_split) and bankroll >= h.bet,
		"split": h.is_pair() and hands.size() < Rules.MAX_HANDS and bankroll >= h.bet,
		"surrender": rules.surrender and hands.size() == 1 and h.cards.size() == 2 and not h.from_split,
	}


## Basic strategy for the active hand (see Strategy.evaluate), or {} when no decision is pending.
func best_play() -> Dictionary:
	if phase != Phase.PLAYER:
		return {}
	var av := available()
	return Strategy.evaluate(hands[active].cards, Strategy.up_value_of(dealer.cards[0]), rules,
		av["double"], av["split"], av["surrender"])


func act(action: String) -> Array[Dictionary]:
	_events = []
	var av := available()
	if not av.get(action, false):
		push_error("Action not available: " + action)
		return _events
	var best := best_play()
	_record(best["category"], best["label"], best["action"], action, best["note"], best["rule"])

	var h := hands[active]
	match action:
		"hit":
			_deal_player(active)
			if h.is_bust() or h.total() == 21:
				h.stood = not h.is_bust()
				_advance()
			else:
				_emit({"t": "active", "hand": active})
		"stand":
			h.stood = true
			_advance()
		"double":
			bankroll -= h.bet
			h.bet *= 2.0
			h.doubled = true
			_emit({"t": "double", "hand": active})
			_emit({"t": "bank", "value": bankroll})
			_deal_player(active)
			_advance()
		"split":
			_split(active)
		"surrender":
			h.surrendered = true
			bankroll += h.bet / 2.0
			_emit({"t": "surrender", "hand": active})
			_emit({"t": "bank", "value": bankroll})
			_advance()
	return _events


func _split(i: int) -> void:
	var h := hands[i]
	bankroll -= h.bet
	var nh := Hand.new(h.bet)
	nh.cards.append(h.cards.pop_back())
	var aces := Hand.rank_of(h.cards[0]) == 1
	h.from_split = true
	nh.from_split = true
	h.split_aces = aces
	nh.split_aces = aces
	hands.insert(i + 1, nh)
	_emit({"t": "split", "hand": i})
	_emit({"t": "bank", "value": bankroll})
	if aces:
		# Split aces get exactly one card each and can't be played further.
		_deal_player(i)
		_deal_player(i + 1)
		h.stood = true
		nh.stood = true
		_advance()
	else:
		_activate(i)


## Makes hand i the active hand, giving a split hand its second card first.
func _activate(i: int) -> void:
	active = i
	var h := hands[i]
	if h.cards.size() < 2:
		_deal_player(i)
	if h.split_aces or h.total() == 21:
		h.stood = true
		_advance()
		return
	_emit({"t": "active", "hand": i})


func _advance() -> void:
	for j in range(active + 1, hands.size()):
		if not hands[j].is_done():
			_activate(j)
			return
	_finish_round()


func _dealer_should_hit() -> bool:
	var t := dealer.total()
	if t < 17:
		return true
	return t == 17 and dealer.is_soft() and rules.h17


func _finish_round() -> void:
	phase = Phase.ROUND_OVER
	_reveal()
	var dealer_bj := dealer.is_blackjack()
	var needs_dealer := false
	if not dealer_bj:
		for h in hands:
			if h.is_live() and not h.is_blackjack():
				needs_dealer = true
	if needs_dealer:
		while _dealer_should_hit():
			_deal_dealer(false)

	var results: Array[Dictionary] = []
	var dt := dealer.total()
	for i in hands.size():
		var h := hands[i]
		var result: String
		var ret := 0.0 # amount returned to the bankroll now, stake included
		if h.surrendered:
			result = "SURRENDER"
		elif h.is_bust():
			result = "BUST"
		elif dealer_bj:
			if h.is_blackjack():
				result = "PUSH"
				ret = h.bet
			else:
				result = "LOSE"
		elif h.is_blackjack():
			result = "BLACKJACK"
			ret = h.bet + h.bet * Rules.BLACKJACK_PAYS
		elif dealer.is_bust() or h.total() > dt:
			result = "WIN"
			ret = h.bet * 2.0
		elif h.total() == dt:
			result = "PUSH"
			ret = h.bet
		else:
			result = "LOSE"
		bankroll += ret
		var hand_net := ret - h.bet
		if h.surrendered:
			hand_net = -h.bet / 2.0
		results.append({"hand": i, "result": result, "net": hand_net})
		stats.record_hand_result(result)

	var insurance_net := 0.0
	if insurance_bet > 0.0:
		if dealer_bj:
			bankroll += insurance_bet * (1.0 + Rules.INSURANCE_PAYS)
			insurance_net = insurance_bet * Rules.INSURANCE_PAYS
		else:
			insurance_net = -insurance_bet

	var round_net := bankroll - _bank_at_start
	stats.rounds += 1
	stats.net += round_net
	_emit({"t": "settle", "results": results, "insurance_net": insurance_net, "net": round_net,
		"dealer_total": dt, "dealer_bj": dealer_bj})
	_emit({"t": "bank", "value": bankroll})


# ---------------------------------------------------------------- helpers

func _reveal() -> void:
	if not hole_revealed:
		hole_revealed = true
		_emit({"t": "reveal", "card": dealer.cards[1]})


func _deal_player(i: int) -> void:
	var c := shoe.draw()
	hands[i].cards.append(c)
	_emit({"t": "deal", "to": "p", "hand": i, "card": c, "down": false})


func _deal_dealer(down: bool) -> void:
	var c := shoe.draw()
	dealer.cards.append(c)
	_emit({"t": "deal", "to": "d", "hand": 0, "card": c, "down": down})


func _record(category: String, label: String, best: String, taken: String, note: String, rule: String) -> void:
	var ok := stats.record(category, label, best, taken, note, rule)
	_emit({"t": "decision", "correct": ok, "best": best, "taken": taken, "label": label,
		"note": note, "rule": rule, "category": category})


func _emit(e: Dictionary) -> void:
	_events.append(e)
