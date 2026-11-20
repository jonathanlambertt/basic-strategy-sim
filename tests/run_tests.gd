extends SceneTree
## Headless tests: godot --headless --path . --script res://tests/run_tests.gd

var failures := 0
var checks := 0

# Card ids (spades): rank - 1. J/Q/K = 10/11/12.
const A := 0
const C2 := 1
const C3 := 2
const C4 := 3
const C5 := 4
const C6 := 5
const C7 := 6
const C8 := 7
const C9 := 8
const C10 := 9
const J := 10
const Q := 11
const K := 12


func _init() -> void:
	test_hand_totals()
	test_charts()
	test_decisions()
	test_engine_rounds()
	test_simulation()
	print("")
	if failures == 0:
		print("ALL %d CHECKS PASSED" % checks)
	else:
		print("%d OF %d CHECKS FAILED" % [failures, checks])
	quit(1 if failures > 0 else 0)


func check(cond: bool, what: String) -> void:
	checks += 1
	if not cond:
		failures += 1
		print("FAIL: " + what)


func eq(got: Variant, want: Variant, what: String) -> void:
	checks += 1
	if got != want:
		failures += 1
		print("FAIL: %s  got=%s want=%s" % [what, got, want])


func make_rules(h17: bool, das: bool, ls: bool, decks: int = 6) -> Rules:
	var r := Rules.new()
	r.h17 = h17
	r.das = das
	r.surrender = ls
	r.decks = decks
	return r


# ------------------------------------------------------------ hands

func test_hand_totals() -> void:
	eq(Hand.total_of([A, C6]), 17, "A6 total")
	check(Hand.is_soft_list([A, C6]), "A6 soft")
	eq(Hand.total_of([A, C6, K]), 17, "A6K total")
	check(not Hand.is_soft_list([A, C6, K]), "A6K hard")
	eq(Hand.total_of([A, A]), 12, "AA total")
	eq(Hand.total_of([A, A, C9]), 21, "AA9 total")
	eq(Hand.total_of([A, A, A, A]), 14, "AAAA total")
	eq(Hand.total_of([K, Q, C2]), 22, "KQ2 total")
	var h := Hand.new(10)
	h.cards = [A, K]
	check(h.is_blackjack(), "AK blackjack")
	h.from_split = true
	check(not h.is_blackjack(), "AK after split is not blackjack")
	var p := Hand.new(10)
	p.cards = [K, Q]
	check(p.is_pair(), "KQ counts as a pair")
	eq(Hand.value_of(13 + 12), 10, "king of hearts value")
	eq(Hand.suit_of(13 * 3 + 4), 3, "diamond suit")


# ------------------------------------------------------------ charts

# Expected tables typed directly from the published 4-8 deck strategy.
# Columns: 2 3 4 5 6 7 8 9 10 A. Base = S17, DAS, late surrender.
const BASE_HARD := {
	8: "H H H H H H H H H H",
	9: "H D D D D H H H H H",
	10: "D D D D D D D D H H",
	11: "D D D D D D D D D H",
	12: "H H S S S H H H H H",
	13: "S S S S S H H H H H",
	14: "S S S S S H H H H H",
	15: "S S S S S H H H RH H",
	16: "S S S S S H H RH RH RH",
	17: "S S S S S S S S S S",
}
const BASE_SOFT := {
	13: "H H H D D H H H H H",
	14: "H H H D D H H H H H",
	15: "H H D D D H H H H H",
	16: "H H D D D H H H H H",
	17: "H D D D D H H H H H",
	18: "S DS DS DS DS S S H H H",
	19: "S S S S S S S S S S",
	20: "S S S S S S S S S S",
}
const BASE_PAIR := {
	2: "P P P P P P H H H H",
	3: "P P P P P P H H H H",
	4: "H H H P P H H H H H",
	5: "D D D D D D D D H H",
	6: "P P P P P H H H H H",
	7: "P P P P P P H H H H",
	8: "P P P P P P P P P P",
	9: "P P P P P S P P S S",
	10: "S S S S S S S S S S",
	11: "P P P P P P P P P P",
}
const COLS := ["2", "3", "4", "5", "6", "7", "8", "9", "10", "A"]


func _table(src: Dictionary) -> Dictionary:
	var out := {}
	for k in src:
		out[k] = Array(src[k].split(" "))
	return out


func set_cell(t: Dictionary, row: int, col: String, code: String) -> void:
	t[row][COLS.find(col)] = code


func expected_chart(h17: bool, das: bool, ls: bool) -> Dictionary:
	var hard := _table(BASE_HARD)
	var soft := _table(BASE_SOFT)
	var pair := _table(BASE_PAIR)
	if h17:
		set_cell(hard, 11, "A", "D")
		set_cell(hard, 15, "A", "RH")
		hard[17] = Array("S S S S S S S S S RS".split(" "))
		set_cell(soft, 18, "2", "DS")
		set_cell(soft, 19, "6", "DS")
		set_cell(pair, 8, "A", "RP")
	if not das:
		pair[2] = Array("H H P P P P H H H H".split(" "))
		pair[3] = Array("H H P P P P H H H H".split(" "))
		pair[4] = Array("H H H H H H H H H H".split(" "))
		pair[6] = Array("H P P P P H H H H H".split(" "))
	if not ls:
		for t in [hard, soft, pair]:
			for k in t:
				for i in 10:
					match t[k][i]:
						"RH":
							t[k][i] = "H"
						"RS":
							t[k][i] = "S"
						"RP":
							t[k][i] = "P"
	return {"hard": hard, "soft": soft, "pair": pair}


func test_charts() -> void:
	for h17 in [false, true]:
		for das in [false, true]:
			for ls in [false, true]:
				for decks in Rules.DECK_OPTIONS:
					var r := make_rules(h17, das, ls, decks)
					var got := Strategy.chart(r)
					var want := expected_chart(h17, das, ls)
					var tag := "%dD h17=%s das=%s ls=%s" % [decks, h17, das, ls]
					for cat in ["hard", "soft", "pair"]:
						for k in want[cat]:
							for i in 10:
								eq(got[cat][k][i], want[cat][k][i], "%s %s %s vs %s" % [tag, cat, k, COLS[i]])
					# Rows outside the typed tables.
					for t in range(4, 8):
						for i in 10:
							eq(got["hard"][t][i], "H", "%s hard %d" % [tag, t])
					for t in range(18, 22):
						for i in 10:
							eq(got["hard"][t][i], "S", "%s hard %d" % [tag, t])
					for i in 10:
						eq(got["soft"][21][i], "S", "%s soft 21" % tag)
						eq(got["soft"][12][i], "H", "%s soft 12" % tag)


# ------------------------------------------------------------ decisions

func act_of(cards: Array, up: int, r: Rules, dbl := true, spl := true, sur := true) -> String:
	return Strategy.evaluate(cards, up, r, dbl, spl, sur)["action"]


func test_decisions() -> void:
	var s17 := make_rules(false, true, true)
	var h17 := make_rules(true, true, true)
	var s17_nols := make_rules(false, true, false)
	eq(act_of([C10, C6], 10, s17), "surrender", "16 v 10 LS")
	eq(act_of([C10, C6], 10, s17_nols), "hit", "16 v 10 no LS")
	eq(act_of([C10, C4, C2], 10, s17, false, false, false), "hit", "3-card 16 v 10")
	eq(Strategy.evaluate([C10, C4, C2], 10, s17, false, false, false)["note"], "CAN'T SURRENDER", "3-card 16 note")
	eq(act_of([C10, C6], 6, s17), "stand", "16 v 6")
	eq(act_of([A, C7], 4, s17), "double", "A7 v 4")
	eq(act_of([A, C3, C4], 4, s17, false, false, false), "stand", "3-card soft 18 v 4")
	eq(act_of([A, C7], 2, s17), "stand", "A7 v 2 S17")
	eq(act_of([A, C7], 2, h17), "double", "A7 v 2 H17")
	eq(act_of([A, C7], 9, s17), "hit", "A7 v 9")
	eq(act_of([A, C8], 6, h17), "double", "A8 v 6 H17")
	eq(act_of([A, C8], 6, s17), "stand", "A8 v 6 S17")
	eq(act_of([C8, C8], 11, h17), "surrender", "88 v A H17 LS")
	eq(act_of([C8, C8], 11, h17, true, true, false), "split", "88 v A H17 after split")
	eq(act_of([C8, C8], 11, s17), "split", "88 v A S17")
	eq(act_of([C8, C8], 10, s17, true, false, false), "hit", "88 v 10 can't split")
	eq(Strategy.evaluate([C8, C8], 10, s17, true, false, false)["note"], "CAN'T SPLIT", "88 can't split note")
	eq(Strategy.evaluate([C8, C8], 10, s17, true, false, false)["category"], "hard", "88 can't split category")
	eq(act_of([A, A], 6, s17), "split", "AA v 6")
	eq(act_of([A, A], 6, s17, false, false, false), "hit", "AA can't split")
	eq(act_of([C5, C5], 9, s17), "double", "55 v 9")
	eq(act_of([C5, C5], 10, s17), "hit", "55 v 10")
	eq(act_of([C6, C5], 11, s17), "hit", "11 v A S17")
	eq(act_of([C6, C5], 11, h17), "double", "11 v A H17")
	eq(act_of([C6, C5], 11, h17, false), "hit", "3-card style 11 v A H17")
	eq(act_of([K, Q], 6, s17), "stand", "KQ v 6")
	eq(Strategy.evaluate([K, Q], 6, s17, true, true, true)["category"], "pair", "KQ category")
	eq(Strategy.evaluate([K, Q], 6, s17, true, true, true)["label"], "PAIR 10,10 VS 6", "KQ label")
	eq(Strategy.evaluate([A, C6], 11, s17, true, false, true)["label"], "SOFT 17 VS A", "A6 label")
	eq(act_of([C10, C7], 11, h17), "surrender", "17 v A H17 LS")
	eq(act_of([C10, C7], 11, h17, true, true, false), "stand", "17 v A H17 can't surrender")
	eq(act_of([C9, C6], 11, h17), "surrender", "15 v A H17 LS")
	eq(act_of([C9, C6], 11, s17), "hit", "15 v A S17 LS")
	eq(act_of([C2, C2], 2, make_rules(false, false, true)), "hit", "22 v 2 no DAS")
	eq(act_of([C2, C2], 2, s17), "split", "22 v 2 DAS")
	eq(Strategy.up_value_of(A), 11, "ace up value")
	eq(Strategy.up_value_of(Q), 10, "queen up value")


# ------------------------------------------------------------ engine

func new_engine(r: Rules, cards: Array) -> BlackjackEngine:
	var e := BlackjackEngine.new(r, 1)
	for c in cards:
		e.shoe.rigged.append(c)
	return e


func last_settle(events: Array) -> Dictionary:
	for i in range(events.size() - 1, -1, -1):
		if events[i]["t"] == "settle":
			return events[i]
	return {}


func test_engine_rounds() -> void:
	var s17 := make_rules(false, true, true)

	# Player blackjack vs 9.
	var e := new_engine(s17, [A, C9, K, C7])
	var ev := e.start_round(10)
	eq(last_settle(ev)["results"][0]["result"], "BLACKJACK", "bj result")
	eq(e.bankroll, 1015.0, "bj pays 3:2")
	eq(e.phase, BlackjackEngine.Phase.ROUND_OVER, "bj ends round")

	# Dealer blackjack, insurance declined.
	e = new_engine(s17, [C10, A, C9, K])
	ev = e.start_round(10)
	eq(e.phase, BlackjackEngine.Phase.INSURANCE, "insurance offered")
	ev = e.insurance(false)
	eq(last_settle(ev)["results"][0]["result"], "LOSE", "dealer bj lose")
	eq(e.bankroll, 990.0, "dealer bj loses bet")
	eq(e.stats.correct, 1, "declining insurance is correct")

	# Dealer blackjack, insurance taken.
	e = new_engine(s17, [C10, A, C9, K])
	e.start_round(10)
	e.insurance(true)
	eq(e.bankroll, 1000.0, "insurance covers dealer bj")
	eq(e.stats.correct, 0, "taking insurance is a mistake")

	# Even money: player bj vs ace, dealer no bj.
	e = new_engine(s17, [A, A, K, C7])
	ev = e.start_round(10)
	check(ev[ev.size() - 1]["even_money"], "even money flagged")
	ev = e.insurance(true)
	eq(e.bankroll, 1010.0, "even money nets 1:1")

	# Dealer 10 up, no blackjack, player stands 20 vs 17: peek then play.
	e = new_engine(s17, [C10, C10, K, C7])
	ev = e.start_round(10)
	eq(e.phase, BlackjackEngine.Phase.PLAYER, "player phase after peek")
	var peeked := false
	for x in ev:
		if x["t"] == "peek":
			peeked = true
			check(not x["bj"], "peek no bj")
	check(peeked, "dealer peeks with 10 up")
	ev = e.act("stand")
	eq(last_settle(ev)["results"][0]["result"], "WIN", "20 beats 17")
	eq(e.bankroll, 1010.0, "win pays 1:1")

	# Split 8s vs 6, double the first hand, both win when dealer busts.
	e = new_engine(s17, [C8, C6, C8, C10, C3, C10, C2, K])
	e.start_round(10)
	var av := e.available()
	check(av["split"] and av["double"] and av["surrender"], "88 options")
	e.act("split")
	eq(e.hands.size(), 2, "split makes two hands")
	eq(e.hands[0].cards.size(), 2, "first split hand gets second card")
	eq(e.hands[1].cards.size(), 1, "second split hand waits")
	av = e.available()
	check(av["double"], "DAS allows double")
	check(not av["surrender"], "no surrender after split")
	e.act("double")
	eq(e.active, 1, "moves to second hand")
	eq(e.hands[1].cards.size(), 2, "second hand gets its card")
	ev = e.act("stand")
	var st := last_settle(ev)
	eq(st["results"][0]["result"], "WIN", "doubled split hand wins")
	eq(st["results"][1]["result"], "WIN", "second split hand wins")
	eq(e.bankroll, 1030.0, "split + double payout")
	eq(st["net"], 30.0, "round net")

	# No DAS: no double after split.
	e = new_engine(make_rules(false, false, true), [C8, C6, C8, C10, C3, C10, C2, K])
	e.start_round(10)
	e.act("split")
	check(not e.available()["double"], "no DAS blocks double")

	# Surrender 16 vs 10.
	e = new_engine(s17, [C10, C10, C6, C7])
	e.start_round(10)
	ev = e.act("surrender")
	eq(last_settle(ev)["results"][0]["result"], "SURRENDER", "surrender result")
	eq(e.bankroll, 995.0, "surrender returns half")
	eq(e.dealer.cards.size(), 2, "dealer doesn't draw after surrender")
	eq(e.stats.correct, 1, "surrender 16 v 10 correct")

	# Bust: dealer doesn't draw.
	e = new_engine(s17, [C10, C6, C6, C10, C10])
	e.start_round(10)
	ev = e.act("hit")
	eq(last_settle(ev)["results"][0]["result"], "BUST", "bust")
	eq(e.bankroll, 990.0, "bust loses")
	eq(e.dealer.cards.size(), 2, "dealer doesn't draw when player busts")
	eq(e.stats.correct, 0, "hitting 16 v 6 is a mistake")

	# H17 vs S17: dealer A,6.
	for h in [false, true]:
		e = new_engine(make_rules(h, true, true), [C10, A, C8, C6, C2])
		e.start_round(10)
		e.insurance(false)
		ev = e.act("stand")
		if h:
			eq(e.dealer.total(), 19, "H17 dealer hits soft 17")
			eq(last_settle(ev)["results"][0]["result"], "LOSE", "H17 18 loses to 19")
		else:
			eq(e.dealer.total(), 17, "S17 dealer stands soft 17")
			eq(last_settle(ev)["results"][0]["result"], "WIN", "S17 18 beats 17")

	# Split aces: one card each, 21 pays 1:1.
	e = new_engine(s17, [A, C5, A, C10, C9, K, C10])
	e.start_round(10)
	ev = e.act("split")
	st = last_settle(ev)
	eq(e.phase, BlackjackEngine.Phase.ROUND_OVER, "split aces finish automatically")
	eq(e.hands[0].cards.size(), 2, "split ace one card")
	eq(e.hands[1].cards.size(), 2, "split ace one card (2)")
	eq(st["results"][1]["result"], "WIN", "split ace 21 is a win, not blackjack")
	eq(e.bankroll, 1020.0, "split aces payout")

	# Re-split to the 4-hand cap.
	e = new_engine(s17, [C8, C6, C8, C10, C8, C8, C8, C2, C2, C2, C2, K])
	e.start_round(10)
	e.act("split") # hands: [8,8] [8] -> hand0 gets 8
	eq(e.hands.size(), 2, "resplit 1")
	e.act("split") # [8,8][8][8]
	eq(e.hands.size(), 3, "resplit 2")
	e.act("split")
	eq(e.hands.size(), 4, "resplit 3")
	check(not e.available()["split"], "can't split past 4 hands")

	# Push.
	e = new_engine(s17, [C10, C10, C8, C8])
	e.start_round(10)
	ev = e.act("stand")
	eq(last_settle(ev)["results"][0]["result"], "PUSH", "push")
	eq(e.bankroll, 1000.0, "push returns bet")

	# Hitting to 21 auto-stands.
	e = new_engine(s17, [C5, C10, C6, C8, K])
	e.start_round(10)
	ev = e.act("hit")
	eq(e.phase, BlackjackEngine.Phase.ROUND_OVER, "21 auto-stands")
	eq(last_settle(ev)["results"][0]["result"], "WIN", "21 beats 18")

	# Can't double when short of money.
	e = new_engine(s17, [C6, C10, C5, C7])
	e.bankroll = 15
	e.start_round(10)
	check(not e.available()["double"], "can't afford double")
	eq(e.best_play()["action"], "hit", "11 v 10 fallback when can't afford double")


# ------------------------------------------------------------ simulation

func test_simulation() -> void:
	for h in [false, true]:
		var r := make_rules(h, true, true)
		var e := BlackjackEngine.new(r, 12345)
		e.bankroll = 1e9
		var start := e.bankroll
		var wagered := 0.0
		var net_sum := 0.0
		var rounds := 200000
		var t0 := Time.get_ticks_msec()
		for n in rounds:
			var ev := e.start_round(10)
			wagered += 10
			while e.phase != BlackjackEngine.Phase.ROUND_OVER:
				if e.phase == BlackjackEngine.Phase.INSURANCE:
					ev = e.insurance(false)
				else:
					ev = e.act(e.best_play()["action"])
			net_sum += last_settle(ev)["net"]
		var edge := (e.bankroll - start) / wagered * 100.0
		print("sim h17=%s: %d rounds in %d ms, player edge %.3f%% of initial bets, accuracy %.1f%%" % [
			h, rounds, Time.get_ticks_msec() - t0, edge, e.stats.accuracy()])
		eq(snappedf(net_sum, 0.01), snappedf(e.bankroll - start, 0.01), "sim h17=%s net adds up" % h)
		eq(e.stats.accuracy(), 100.0, "sim h17=%s autoplay is 100%% accurate" % h)
		# Expected around -0.3% (S17) / -0.5% (H17); 200k rounds has ~0.26% standard error.
		check(edge > -1.4 and edge < 0.6, "sim h17=%s edge plausible (%.3f%%)" % [h, edge])
