class_name Strategy
extends RefCounted
## Total-dependent basic strategy for 4-8 decks, dealer peeks, blackjack 3:2.
## Source: Wizard of Odds 4-8 deck strategy (S17 base chart plus H17 changes),
## with double after split and late surrender variations.
##
## Cell codes:
##   H  hit            S  stand
##   D  double, else hit           DS double, else stand
##   P  split
##   RH surrender, else hit        RS surrender, else stand
##   RP surrender, else split

const UP_LABELS: Array[String] = ["2", "3", "4", "5", "6", "7", "8", "9", "10", "A"]

const HIT := "hit"
const STAND := "stand"
const DOUBLE := "double"
const SPLIT := "split"
const SURRENDER := "surrender"

const ACTION_NAMES := {
	"hit": "HIT", "stand": "STAND", "double": "DOUBLE", "split": "SPLIT", "surrender": "SURRENDER",
	"insure": "TAKE INSURANCE", "decline": "NO INSURANCE",
}

static var _cache := {}


# ---------------------------------------------------------------- chart

## Returns {"hard": {total: row}, "soft": {total: row}, "pair": {value: row}}.
## Each row is 10 codes for dealer up cards 2..10, A. Pair value 11 = aces.
static func chart(r: Rules) -> Dictionary:
	var key := r.chart_key()
	if not _cache.has(key):
		_cache[key] = _build(r)
	return _cache[key]


static func _build(r: Rules) -> Dictionary:
	var hard := {}
	var soft := {}
	var pair := {}
	for t in range(4, 22):
		hard[t] = _row(func(up: int) -> String: return hard_cell(t, up, r))
	for t in range(12, 22):
		soft[t] = _row(func(up: int) -> String: return soft_cell(t, up, r))
	for v in range(2, 12):
		pair[v] = _row(func(up: int) -> String: return pair_cell(v, up, r))
	return {"hard": hard, "soft": soft, "pair": pair}


static func _row(cell: Callable) -> Array[String]:
	var row: Array[String] = []
	for up in range(2, 12):
		row.append(cell.call(up))
	return row


## up: 2..10, 11 = ace.
static func hard_cell(t: int, up: int, r: Rules) -> String:
	if r.surrender:
		if t == 16 and up >= 9:
			return "RH"
		if t == 15 and (up == 10 or (r.h17 and up == 11)):
			return "RH"
		if t == 17 and r.h17 and up == 11:
			return "RS"
	if t <= 8:
		return "H"
	if t == 9:
		return "D" if up >= 3 and up <= 6 else "H"
	if t == 10:
		return "D" if up <= 9 else "H"
	if t == 11:
		return "D" if up <= 10 or r.h17 else "H"
	if t == 12:
		return "S" if up >= 4 and up <= 6 else "H"
	if t <= 16:
		return "S" if up <= 6 else "H"
	return "S"


static func soft_cell(t: int, up: int, r: Rules) -> String:
	if t >= 20:
		return "S"
	if t == 19:
		return "DS" if r.h17 and up == 6 else "S"
	if t == 18:
		if up >= 9:
			return "H"
		if up >= 3 and up <= 6:
			return "DS"
		if up == 2:
			return "DS" if r.h17 else "S"
		return "S" # 7, 8
	if t == 17:
		return "D" if up >= 3 and up <= 6 else "H"
	if t == 15 or t == 16:
		return "D" if up >= 4 and up <= 6 else "H"
	if t == 13 or t == 14:
		return "D" if up >= 5 and up <= 6 else "H"
	return "H" # soft 12 (A,A that can't be split)


## v: pair card value 2..10, 11 = aces.
static func pair_cell(v: int, up: int, r: Rules) -> String:
	match v:
		11:
			return "P"
		10:
			return "S"
		9:
			return "P" if up <= 6 or up == 8 or up == 9 else "S"
		8:
			return "RP" if r.h17 and r.surrender and up == 11 else "P"
		7:
			return "P" if up <= 7 else "H"
		6:
			return "P" if up <= 6 and (up >= 3 or r.das) else "H"
		5:
			return hard_cell(10, up, r)
		4:
			return "P" if r.das and (up == 5 or up == 6) else "H"
		_: # 2, 3
			return "P" if up <= 7 and (up >= 4 or r.das) else "H"


# ---------------------------------------------------------------- decisions

## Dealer up card as a chart column value: 2..10, ace = 11.
static func up_value_of(card: int) -> int:
	var v := Hand.value_of(card)
	return 11 if v == 1 else v


static func column(up_value: int) -> int:
	return up_value - 2


## Turns a chart code into the action to take, given what the table allows right now.
static func resolve(code: String, can_double: bool, can_split: bool, can_surrender: bool) -> String:
	match code:
		"H":
			return HIT
		"S":
			return STAND
		"D":
			return DOUBLE if can_double else HIT
		"DS":
			return DOUBLE if can_double else STAND
		"P":
			return SPLIT if can_split else HIT
		"RH":
			return SURRENDER if can_surrender else HIT
		"RS":
			return SURRENDER if can_surrender else STAND
		"RP":
			if can_surrender:
				return SURRENDER
			return SPLIT if can_split else HIT
	push_error("Unknown strategy code: " + code)
	return STAND


## The basic strategy play for a hand.
## Returns {action, code, category ("hard"/"soft"/"pair"), label, note, rule}.
static func evaluate(cards: Array, up_value: int, r: Rules, can_double: bool, can_split: bool, can_surrender: bool) -> Dictionary:
	var ch := chart(r)
	var col := column(up_value)
	var is_pair: bool = cards.size() == 2 and Hand.value_of(cards[0]) == Hand.value_of(cards[1])
	var pv := 0
	if is_pair:
		pv = Hand.value_of(cards[0])
		if pv == 1:
			pv = 11
	var total := Hand.total_of(cards)
	var soft := Hand.is_soft_list(cards)
	var code: String
	var category: String
	var key: int
	var note := ""

	if is_pair and can_split:
		category = "pair"
		key = pv
		code = ch["pair"][pv][col]
	else:
		if is_pair:
			var pcode: String = ch["pair"][pv][col]
			if pcode == "P" or pcode == "RP":
				note = "CAN'T SPLIT"
		category = "soft" if soft else "hard"
		key = total
		code = ch[category][total][col]

	var action := resolve(code, can_double, can_split and is_pair, can_surrender)
	if note == "":
		if (code == "D" or code == "DS") and not can_double:
			note = "CAN'T DOUBLE"
		elif (code == "RH" or code == "RS" or code == "RP") and not can_surrender:
			note = "CAN'T SURRENDER"

	var up_label := UP_LABELS[col]
	var label: String
	match category:
		"pair":
			var n := pair_name(pv)
			label = "PAIR %s,%s VS %s" % [n, n, up_label]
		"soft":
			label = "SOFT %d VS %s" % [total, up_label]
		_:
			label = "HARD %d VS %s" % [total, up_label]
	return {
		"action": action,
		"code": code,
		"category": category,
		"label": label,
		"note": note,
		"rule": rule_text(category, key, r),
	}


static func pair_name(pv: int) -> String:
	return "A" if pv == 11 else str(pv)


# ---------------------------------------------------------------- explanations

## One-line rule of thumb for a chart row.
static func rule_text(category: String, key: int, r: Rules) -> String:
	match category:
		"hard":
			return _hard_rule(key, r)
		"soft":
			return _soft_rule(key, r)
		"pair":
			return _pair_rule(key, r)
		"insurance":
			return "NEVER TAKE INSURANCE OR EVEN MONEY."
	return ""


static func _hard_rule(t: int, r: Rules) -> String:
	if t <= 8:
		return "HARD 8 OR LESS: ALWAYS HIT."
	match t:
		9:
			return "HARD 9: DOUBLE VS 3-6, OTHERWISE HIT."
		10:
			return "HARD 10: DOUBLE VS 2-9, OTHERWISE HIT."
		11:
			if r.h17:
				return "HARD 11: ALWAYS DOUBLE, EVEN VS A."
			return "HARD 11: DOUBLE VS 2-10, HIT VS A."
		12:
			return "HARD 12: STAND VS 4-6, OTHERWISE HIT."
		15:
			if r.surrender:
				if r.h17:
					return "HARD 15: STAND VS 2-6, SURRENDER VS 10 AND A, OTHERWISE HIT."
				return "HARD 15: STAND VS 2-6, SURRENDER VS 10, OTHERWISE HIT."
		16:
			if r.surrender:
				return "HARD 16: STAND VS 2-6, SURRENDER VS 9, 10 AND A, OTHERWISE HIT."
		17:
			if r.surrender and r.h17:
				return "HARD 17: STAND, EXCEPT SURRENDER VS A."
	if t <= 16:
		return "HARD 13-16: STAND VS 2-6, OTHERWISE HIT."
	return "HARD 17+: ALWAYS STAND."


static func _soft_rule(t: int, r: Rules) -> String:
	match t:
		12:
			return "SOFT 12 (A,A YOU CAN'T SPLIT): HIT."
		13, 14:
			return "A,2 AND A,3: DOUBLE VS 5-6, OTHERWISE HIT."
		15, 16:
			return "A,4 AND A,5: DOUBLE VS 4-6, OTHERWISE HIT."
		17:
			return "A,6: DOUBLE VS 3-6, OTHERWISE HIT."
		18:
			if r.h17:
				return "A,7: DOUBLE VS 2-6 (ELSE STAND), STAND VS 7-8, HIT VS 9, 10, A."
			return "A,7: DOUBLE VS 3-6 (ELSE STAND), STAND VS 2, 7, 8, HIT VS 9, 10, A."
		19:
			if r.h17:
				return "A,8: DOUBLE VS 6 (ELSE STAND), OTHERWISE STAND."
			return "A,8: ALWAYS STAND."
	return "SOFT 20+: ALWAYS STAND."


static func _pair_rule(v: int, r: Rules) -> String:
	match v:
		11:
			return "A,A: ALWAYS SPLIT."
		10:
			return "10,10: NEVER SPLIT. 20 IS ALREADY A STRONG HAND."
		9:
			return "9,9: SPLIT VS 2-6 AND 8-9, STAND VS 7, 10, A."
		8:
			if r.h17 and r.surrender:
				return "8,8: ALWAYS SPLIT, EXCEPT SURRENDER VS A."
			return "8,8: ALWAYS SPLIT."
		7:
			return "7,7: SPLIT VS 2-7, OTHERWISE HIT."
		6:
			if r.das:
				return "6,6: SPLIT VS 2-6, OTHERWISE HIT."
			return "6,6: SPLIT VS 3-6, OTHERWISE HIT."
		5:
			return "5,5: NEVER SPLIT. PLAY IT AS A HARD 10."
		4:
			if r.das:
				return "4,4: SPLIT VS 5-6, OTHERWISE HIT."
			return "4,4: NEVER SPLIT. HIT."
	if r.das:
		return "%d,%d: SPLIT VS 2-7, OTHERWISE HIT." % [v, v]
	return "%d,%d: SPLIT VS 4-7, OTHERWISE HIT." % [v, v]


## Sections for the guide page: [{title, lines}].
static func guide(r: Rules) -> Array[Dictionary]:
	var sections: Array[Dictionary] = []

	sections.append({"title": "YOUR TABLE", "lines": r.describe()})

	sections.append({"title": "HOW TO READ THE CHART", "lines": [
		"FIND YOUR HAND ON THE LEFT AND THE DEALER'S UP CARD ALONG THE TOP.",
		"CHECK PAIRS FIRST, THEN SOFT HANDS (AN ACE COUNTED AS 11), THEN HARD HANDS.",
		"H = HIT · S = STAND · P = SPLIT · D = DOUBLE, OR HIT IF YOU CAN'T · DS = DOUBLE, OR STAND IF YOU CAN'T",
		"RH / RS / RP: SURRENDER, OR HIT / STAND / SPLIT IF SURRENDER ISN'T POSSIBLE.",
		"YOU CAN ONLY DOUBLE OR SURRENDER ON YOUR FIRST TWO CARDS. AFTER THAT, USE THE FALLBACK.",
	]})

	var hard_lines: Array[String] = []
	for t in [8, 9, 10, 11, 12, 13]:
		hard_lines.append(_hard_rule(t, r))
	if r.surrender:
		hard_lines.append(_hard_rule(15, r))
		hard_lines.append(_hard_rule(16, r))
	hard_lines.append(_hard_rule(17, r))
	if r.surrender and r.h17:
		hard_lines.append("HARD 18+: ALWAYS STAND.")
	sections.append({"title": "HARD HANDS (NO ACE, OR ACE COUNTED AS 1)", "lines": hard_lines})

	var soft_lines: Array[String] = []
	for t in [13, 15, 17, 18, 19]:
		soft_lines.append(_soft_rule(t, r))
	soft_lines.append("A,9: ALWAYS STAND.")
	sections.append({"title": "SOFT HANDS (ACE COUNTED AS 11)", "lines": soft_lines})

	var pair_lines: Array[String] = []
	for v in [11, 8, 10, 5, 9, 7, 6, 4, 2]:
		var line := _pair_rule(v, r)
		if v == 2:
			line = line.replace("2,2:", "2,2 AND 3,3:")
		pair_lines.append(line)
	sections.append({"title": "PAIRS", "lines": pair_lines})

	if r.surrender:
		var s := "SURRENDER HARD 16 VS 9, 10, A AND HARD 15 VS 10."
		if r.h17:
			s = "SURRENDER HARD 16 VS 9, 10, A, HARD 15 VS 10 AND A, HARD 17 VS A, AND 8,8 VS A."
		var surrender_lines: Array[String] = [s]
		if not r.h17:
			surrender_lines.append("NEVER SURRENDER 8,8. SPLIT IT.")
		surrender_lines.append("SURRENDER IS ONLY YOUR FIRST DECISION, NEVER AFTER A HIT OR A SPLIT.")
		sections.append({"title": "LATE SURRENDER", "lines": surrender_lines})

	sections.append({"title": "INSURANCE", "lines": [
		"NEVER TAKE INSURANCE OR EVEN MONEY. IT'S A SIDE BET THAT LOSES OVER TIME.",
	]})

	var change_lines: Array[String] = []
	if r.h17:
		change_lines.append("THE DEALER HITS SOFT 17 AND BUSTS A LITTLE MORE OFTEN, SO THREE EXTRA DOUBLES PAY: 11 VS A, A,7 VS 2, A,8 VS 6.")
		if r.surrender:
			change_lines.append("H17 ALSO ADDS THREE SURRENDERS VS AN ACE: HARD 15, HARD 17 AND 8,8.")
	else:
		change_lines.append("THE DEALER STANDS ON SOFT 17. IF THEY HIT IT (H17) YOU WOULD ALSO DOUBLE 11 VS A, A,7 VS 2 AND A,8 VS 6.")
	if r.das:
		change_lines.append("DOUBLE AFTER SPLIT MAKES SMALL PAIRS WORTH SPLITTING MORE OFTEN: 2,2 AND 3,3 VS 2-7, 4,4 VS 5-6, 6,6 VS 2-6.")
	else:
		change_lines.append("WITHOUT DOUBLE AFTER SPLIT, SPLIT SMALL PAIRS LESS: 2,2 AND 3,3 ONLY VS 4-7, 6,6 VS 3-6, AND NEVER 4,4.")
	if not r.surrender:
		change_lines.append("NO SURRENDER, SO PLAY HARD 15 AND 16 BY THE NORMAL HIT AND STAND RULES.")
	change_lines.append("4, 6 AND 8 DECKS ALL USE THIS SAME CHART.")
	sections.append({"title": "WHAT YOUR RULES CHANGE", "lines": change_lines})

	sections.append({"title": "WHY IT WORKS", "lines": [
		"DEALER 2-6 IS WEAK. THEY MUST HIT 12-16 AND BUST OFTEN, SO DON'T RISK BUSTING YOURSELF.",
		"DEALER 7-A IS STRONG. THEY USUALLY FINISH WITH 17-21, SO A HARD 12-16 NEEDS ANOTHER CARD.",
		"DOUBLE WHEN ONE MORE CARD IS LIKELY TO MAKE A STRONG HAND AND THE DEALER IS WEAK.",
		"SOFT HANDS CAN'T BUST ON ONE HIT, SO YOU CAN HIT AND DOUBLE THEM MORE.",
		"SPLIT 8S TO ESCAPE 16. SPLIT ACES FOR TWO SHOTS AT 21. KEEP 10S: 20 WINS MOST OF THE TIME.",
		"THIS IS THE BEST PLAY OVER THE LONG RUN WITHOUT COUNTING CARDS, NOT A PROMISE FOR ONE HAND.",
	]})
	return sections
